import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../models/channel.dart';
import '../models/series.dart';
import '../models/vod_item.dart';
import '../providers/content_provider.dart';
import '../services/recording_service.dart';
import '../services/watch_progress_service.dart';

class PlayerScreen extends StatefulWidget {
  final Channel? channel;
  final String? streamUrl;
  final String? title;
  final List<Episode>? episodes;
  final int? initialEpisodeIndex;
  final Series? series;
  final bool isLive;
  final String? contentId;
  final bool startFromBeginning;

  const PlayerScreen({
    super.key, this.channel, this.streamUrl, this.title,
    this.episodes, this.initialEpisodeIndex, this.series, this.isLive = false, this.contentId, this.startFromBeginning = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

enum PlaybackStartChoice { resume, fromBeginning, cancel }

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription? _posSub, _durSub, _playSub, _errorSub, _bufferingSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _showControls = true;
  bool _showHistory = false;
  bool _showDrawer = false;
  String? _selectedLiveCategory;
  // Keep the current programme/episode visible even in very long lazy lists.
  final ScrollController _channelListScroll = ScrollController();
  final ScrollController _categoryListScroll = ScrollController();
  final FocusNode _drawerCloseFocus = FocusNode(debugLabel: 'Navigation schließen');
  final FocusNode _categoryAllFocus = FocusNode(debugLabel: 'Alle Sender');
  final FocusNode _historyCloseFocus = FocusNode(debugLabel: 'Verlauf schließen');
  final ScrollController _episodeListScroll = ScrollController();
  static const double _navigationRowExtent = 72;
  // Invalidates pending scroll requests when a drawer/category changes.
  int _navigationScrollEpoch = 0;
  int _focusedRowRequest = 0;

  void _scrollToCurrentNavigationItem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showDrawer) return;
      if (widget.episodes != null && _episodeListScroll.hasClients) {
        _jumpToNavigationIndex(_episodeListScroll, _currentEpisode);
      } else if (widget.channel != null && _channelListScroll.hasClients) {
        final channels = context.read<ContentProvider>().channels;
        final visible = _selectedLiveCategory == null ? channels : channels
            .where((c) => (c.category ?? '') == _selectedLiveCategory).toList();
        final index = visible.indexWhere((c) => c.id == widget.channel!.id);
        if (index >= 0) _jumpToNavigationIndex(_channelListScroll, index);
      }
    });
  }

  void _jumpToNavigationIndex(ScrollController controller, int index) {
    if (!controller.hasClients || index < 0) return;
    final position = controller.position;
    final target = (index * _navigationRowExtent - position.viewportDimension / 3)
        .clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    controller.jumpTo(target);
  }

  // Keep the remote's focused row visible even when a lazy list scrolls.
  // A focused row can be recycled in long lists; ensureVisible works with
  // the mounted row instead of assuming that every item is built.
  void _keepFocusedNavigationRowVisible(BuildContext rowContext, bool focused) {
    if (!focused || !_showDrawer) return;
    // Rapid D-pad repeats can queue many post-frame scroll requests. Only the
    // newest focused row may scroll, and never after a drawer/category change.
    final request = ++_focusedRowRequest;
    final epoch = _navigationScrollEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showDrawer || !rowContext.mounted ||
          request != _focusedRowRequest || epoch != _navigationScrollEpoch) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        alignment: 0.25,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  int _selectedHistoryTab = 0;
  int _videoFitIndex = 0;
  static const List<BoxFit> _videoFits = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
  String _videoFitLabel(int index) => AppLocalizations.of(context).t(['player_fit_original', 'player_fit_cover', 'player_fit_stretch'][index]);
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _queueSyncTimer;
  Timer? _reconnectTimer;
  Timer? _stallMonitor;
  Duration _lastObservedPlaybackPosition = Duration.zero;
  DateTime? _lastPlaybackProgressAt;
  static const Duration _stallTimeout = Duration(seconds: 35);
  static const Duration _bufferingTimeout = Duration(seconds: 60);
  bool _buffering = false;
  DateTime? _bufferingStartedAt;

  bool _appInForeground = true;
  Duration? _reconnectResumePosition;
  bool _streamFailed = false;
  bool _reconnecting = false;
  int _automaticReconnects = 0;
  int _streamLoadGeneration = 0;
  static const int _maxAutomaticReconnects = 2;
  final WatchProgressService _progressService = WatchProgressService();
  final FocusNode _playerSurfaceFocus = FocusNode(debugLabel: 'Player-Oberfläche');
  final FocusNode _subtitleButtonFocus = FocusNode(debugLabel: 'Untertitel');
  final FocusNode _audioButtonFocus = FocusNode(debugLabel: 'Audiosprache');
  bool _restoreAttempted = false;
  bool _saveInFlight = false;
  int _currentEpisode = 0;

  String? get _currentUrl {
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      return widget.episodes![_currentEpisode].streamUrl;
    }
    return widget.streamUrl ?? widget.channel?.streamUrl;
  }

  String? get _progressContentId {
    if (widget.isLive) return null;
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      final episode = widget.episodes![_currentEpisode];
      return widget.series == null ? episode.id : '${widget.series!.id}::${episode.id}';
    }
    return widget.contentId;
  }

  String get _currentTitle {
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      return widget.episodes![_currentEpisode].title;
    }
    return widget.title ?? widget.channel?.name ?? 'Stream';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _videoController = VideoController(_player);
    _currentEpisode = widget.initialEpisodeIndex ?? 0;
    _posSub = _player.stream.position.listen((p) {
      if (!mounted) return;
      if (p > _lastObservedPlaybackPosition) {
        _lastObservedPlaybackPosition = p;
        _lastPlaybackProgressAt = DateTime.now();
      }
      setState(() => _position = p);
    });
    _durSub = _player.stream.duration.listen((d) { if (mounted) setState(() => _duration = d); });
    _playSub = _player.stream.playing.listen((p) {
      if (mounted) setState(() {
        _playing = p;
        if (p) {
          _streamFailed = false;
          _reconnecting = false;
          _lastPlaybackProgressAt = DateTime.now();
        } else {
          _lastPlaybackProgressAt = null;
        }
      });
    });
    // Buffering is not a playback failure. Allow a bounded grace period so
    // slow connections can recover, without hanging indefinitely.
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (buffering) {
        _bufferingStartedAt ??= DateTime.now();
      } else {
        _bufferingStartedAt = null;
        _lastPlaybackProgressAt = DateTime.now();
        _lastObservedPlaybackPosition = _position;
      }
      _buffering = buffering;
    });
    // Do not show raw player errors: stream URLs can contain account secrets.
    _errorSub = _player.stream.error.listen((_) => _handlePlaybackFailure());
    _loadStream();
    RecordingService.refreshStatus();
    _stallMonitor = Timer.periodic(const Duration(seconds: 5), (_) => _checkPlaybackStall());
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
    // Retry queued offline progress while the player remains open.
    _queueSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _progressService.flushPending());
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<ContentProvider>();
      if (widget.channel != null) library.addToHistory(widget.channel!);
      if (widget.contentId != null && !widget.isLive && widget.episodes == null) {
        for (final item in library.vodItems) {
          if (item.id == widget.contentId) { library.addVodToHistory(item); break; }
        }
      }
      if (widget.series != null) _recordCurrentEpisodeHistory(library);
    });
  }

  void _recordCurrentEpisodeHistory([ContentProvider? provider]) {
    final library = provider ?? context.read<ContentProvider>();
    final series = widget.series;
    final episodes = widget.episodes;
    if (series == null || episodes == null || episodes.isEmpty ||
        _currentEpisode < 0 || _currentEpisode >= episodes.length) return;
    final episode = episodes[_currentEpisode];
    var seasonNumber = 1;
    for (final season in series.seasons) {
      if (season.episodes.any((candidate) => candidate.id == episode.id)) {
        seasonNumber = season.number;
        break;
      }
    }
    library.addSeriesEpisodeToHistory(series, episode, seasonNumber);
  }

  // Detect streams that silently stop advancing without emitting a player error.
  // Never reconnect deliberately paused playback or content near its end.
  void _checkPlaybackStall() {
    if (!mounted || !_appInForeground || !_playing || _streamFailed || _reconnecting) return;
    if (_buffering) {
      final since = _bufferingStartedAt;
      if (since == null || DateTime.now().difference(since) < _bufferingTimeout) return;
      _handlePlaybackFailure();
      return;
    }
    final last = _lastPlaybackProgressAt;
    if (last == null || DateTime.now().difference(last) < _stallTimeout) return;
    if (!widget.isLive && _duration > Duration.zero &&
        _position >= _duration - const Duration(seconds: 3)) return;
    _handlePlaybackFailure();
  }

  void _handlePlaybackFailure() {
    if (!mounted || _streamFailed) return;
    // Do not schedule retries while the operating system suspends playback.
    if (!_appInForeground) return;
    setState(() { _streamFailed = true; _reconnecting = false; _showControls = true; });
    _hideTimer?.cancel();
    if (_automaticReconnects >= _maxAutomaticReconnects) return;
    _automaticReconnects++;
    final generation = _streamLoadGeneration;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 2 * _automaticReconnects), () {
      if (!mounted || generation != _streamLoadGeneration) return;
      _loadStream(reconnect: true);
    });
  }

  Future<void> _loadStream({bool reconnect = false}) async {
    final url = _currentUrl;
    if (url == null || url.isEmpty) {
      _handlePlaybackFailure();
      return;
    }
    _reconnectTimer?.cancel();
    final generation = ++_streamLoadGeneration;
    if (!reconnect) _automaticReconnects = 0;
    // Keep the position before Media.open resets player position streams.
    final resumeAt = reconnect && !widget.isLive
        ? (_reconnectResumePosition ?? _position)
        : Duration.zero;
    _reconnectResumePosition = reconnect ? resumeAt : null;
    _lastPlaybackProgressAt = DateTime.now();
    _lastObservedPlaybackPosition = Duration.zero;
    _buffering = false;
    _bufferingStartedAt = null;
    if (mounted) setState(() { _reconnecting = reconnect; _streamFailed = false; });
    try {
      await _player.open(Media(url));
      if (!mounted || generation != _streamLoadGeneration) return;
      // Reconnect always takes precedence over stored progress. A first open
      // may fail before the initial progress lookup; in that case the retry
      // must still resume at the position captured before Media.open.
      if (reconnect && !widget.isLive) {
        if (resumeAt > Duration.zero && generation == _streamLoadGeneration) {
          await _player.seek(resumeAt);
        }
      } else if (!_restoreAttempted && !widget.isLive &&
          !widget.startFromBeginning) {
        _restoreAttempted = true;
        final id = _progressContentId;
        if (id != null) {
          // Saved progress is optional: a storage/network failure must not
          // interrupt otherwise playable media or trigger a reconnect loop.
          int? saved;
          try {
            final sourceKey = context.read<ContentProvider>().sourceKey;
            saved = await _progressService.loadPosition(
              sourceKey: sourceKey, contentId: id,
              contentType: widget.episodes != null ? 'series' : 'vod');
          } catch (_) {
            saved = null;
          }
          if (saved != null && saved > 0 && mounted &&
              generation == _streamLoadGeneration) {
            await _player.seek(Duration(seconds: saved));
          }
        }
      }
      if (mounted && generation == _streamLoadGeneration) {
        _reconnectResumePosition = null;
        setState(() => _reconnecting = false);
      }
    } catch (_) {
      if (mounted && generation == _streamLoadGeneration) _handlePlaybackFailure();
    }
  }

  void _retryPlaybackManually() {
    _automaticReconnects = 0;
    _loadStream(reconnect: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      // Background playback can pause position updates; reset stall clock.
      _lastPlaybackProgressAt = DateTime.now();
      _lastObservedPlaybackPosition = _position;
      // Time spent suspended must not count toward a buffering timeout.
      if (_buffering) _bufferingStartedAt = DateTime.now();
      _progressService.flushPending();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _appInForeground = false;
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    if (widget.isLive || !mounted || _saveInFlight) return;
    final id = _progressContentId;
    final position = _position.inSeconds;
    final duration = _duration.inSeconds;
    if (id == null || id.isEmpty || position < 5) return;
    _saveInFlight = true;
    try {
      await _progressService.savePosition(
        sourceKey: context.read<ContentProvider>().sourceKey,
        contentId: id,
        contentType: widget.episodes != null ? 'series' : 'vod',
        title: _currentTitle,
        positionSeconds: position,
        durationSeconds: duration,
      );
    } catch (_) {} finally {
      _saveInFlight = false;
    }
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Overlay widgets own their remote actions; never toggle playback behind them.
    if (_showDrawer || _showHistory) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // On Live TV, Right opens the history sidebar from the player surface.
    // For films and episodes, hidden controls reserve Left/Right for seeking.
    if (key == LogicalKeyboardKey.arrowRight && widget.isLive &&
        _playerSurfaceFocus.hasPrimaryFocus) {
      _toggleHistorySidebar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowLeft) {
      // Focused controls retain their normal D-pad traversal. Only seek when
      // the controls are hidden and the content has a seekable timeline.
      if (!widget.isLive && !_showControls && !_streamFailed && !_reconnecting) {
        final delta = key == LogicalKeyboardKey.arrowRight ? 10 : -10;
        final target = _position + Duration(seconds: delta);
        final upper = _duration > Duration.zero ? _duration : const Duration(days: 365);
        _player.seek(target < Duration.zero ? Duration.zero : (target > upper ? upper : target));
        setState(() => _showControls = true);
        _startHideTimer();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
      // Child buttons receive Enter/Select first. Never let a bubbled event
      // also toggle playback when the retry button or a control has focus.
      if (_showControls && !_playerSurfaceFocus.hasPrimaryFocus) {
        return KeyEventResult.ignored;
      }
      if (_streamFailed || _reconnecting) return KeyEventResult.ignored;
      // Live TV must never be paused by OK. Open its channel/category
      // navigation instead; the recording control remains accessible.
      if (widget.isLive) {
        _toggleLiveControls();
        return KeyEventResult.handled;
      }
      _playing ? _player.pause() : _player.play();
      setState(() => _showControls = true);
      _startHideTimer();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) && !_showControls) {
      setState(() => _showControls = true);
      _startHideTimer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleLiveControls() {
    if (!mounted || _showDrawer || _showHistory) return;
    _hideTimer?.cancel();
    setState(() => _showControls = !_showControls);
    if (!_showControls) _restorePlayerFocus();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (widget.isLive) return;
    _hideTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _streamFailed || _reconnecting) return;
      // Preserve remote focus: hiding a focused control can strand the D-pad.
      if (_showControls && !_playerSurfaceFocus.hasPrimaryFocus) return;
      setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _queueSyncTimer?.cancel();
    _reconnectTimer?.cancel();
    _stallMonitor?.cancel();
    _streamLoadGeneration++;
    _channelListScroll.dispose();
    _categoryListScroll.dispose();
    _drawerCloseFocus.dispose();
    _categoryAllFocus.dispose();
    _historyCloseFocus.dispose();
    _episodeListScroll.dispose();
    _playerSurfaceFocus.dispose();
    _subtitleButtonFocus.dispose();
    _audioButtonFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress();
    _posSub?.cancel(); _durSub?.cancel(); _playSub?.cancel(); _errorSub?.cancel(); _bufferingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_showDrawer) { _closeNavigationDrawer(); return; }
        if (_showHistory) { _closeHistorySidebar(); return; }
        if (_showControls) { setState(() => _showControls = false); return; }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _playerSurfaceFocus,
          autofocus: true,
          onKeyEvent: _handleRemoteKey,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_showDrawer || _showHistory) return;
            if (widget.isLive) {
              _toggleLiveControls();
            } else {
              setState(() => _showControls = true);
              _startHideTimer();
            }
          },
          child: Stack(
            children: [
              Center(child: Video(
                controller: _videoController,
                fit: _videoFits[_videoFitIndex],
                // The package's built-in controls are the unwanted seek bar
                // seen after our Live TV overlay disappears.
                controls: widget.isLive ? NoVideoControls : null,
              )),
              // A full-surface touch target remains above the video widget,
              // so taps restore our own navigation even when it is hidden.
              if (widget.isLive && !_showDrawer && !_showHistory)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleLiveControls,
                  ),
                ),
              if (_showControls) ExcludeFocus(
                excluding: _showDrawer || _showHistory || _streamFailed || _reconnecting,
                child: FocusTraversalGroup(child: _buildControls())),
              if (_streamFailed || _reconnecting)
                Center(child: Card(
                  color: const Color(0xEE142033),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off, color: Colors.white70, size: 36),
                      const SizedBox(height: 12),
                      Text(_reconnecting ? 'Verbindung wird wiederhergestellt …' :
                        'Wiedergabe unterbrochen. Bitte Verbindung prüfen.',
                        style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        autofocus: _streamFailed,
                        onPressed: _reconnecting ? null : _retryPlaybackManually,
                        icon: const Icon(Icons.refresh), label: const Text('Erneut versuchen'),
                      ),
                    ]),
                  ),
                )),
              // Tap outside an open sidebar to close only that sidebar.
              // This transparent layer sits above player controls but below
              // the sidebar, so list items remain fully interactive.
              if (_showDrawer || _showHistory)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_showDrawer) {
                        _closeNavigationDrawer();
                      } else if (_showHistory) {
                        _closeHistorySidebar();
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
              if (_showHistory) FocusTraversalGroup(child: _buildHistorySidebar()),
              if (_showDrawer && widget.episodes != null) FocusTraversalGroup(child: _buildEpisodesDrawer()),
              if (_showDrawer && widget.isLive) FocusTraversalGroup(child: _buildLiveNavigationDrawer()),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildControls() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.transparent, Colors.black87],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  InkWell(
                    focusColor: AppTheme.electricBlue.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(_currentTitle,
                           style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                           overflow: TextOverflow.ellipsis),
                         if (widget.isLive &&
                             (widget.channel?.category ?? '').trim().isNotEmpty)
                           Text(widget.channel!.category!.trim(),
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                             style: const TextStyle(color: Colors.white70, fontSize: 13)),
                       ],
                     ),
                   ),
                   if (widget.isLive)
                     ValueListenableBuilder<RecordingStatus>(
                       valueListenable: RecordingService.status,
                       builder: (context, recording, _) {
                         final busy = recording.isBusy;
                         final stopping = recording.phase == RecordingPhase.stopping;
                         final starting = recording.phase == RecordingPhase.starting;
                         final writing = recording.writing;
                         final label = stopping
                             ? 'Aufnahme wird beendet …'
                             : starting
                                 ? 'Aufnahme startet …'
                                 : writing
                                     ? 'Aufnahme stoppen'
                                     : 'Aufnehmen';
                         return Tooltip(
                           message: recording.error ?? label,
                           child: InkWell(
                             focusColor: AppTheme.electricBlue.withOpacity(0.38),
                             borderRadius: BorderRadius.circular(12),
                             onTap: (stopping || starting) ? null : _toggleRecording,
                             child: Container(
                               padding: const EdgeInsets.symmetric(
                                 horizontal: 16, vertical: 10),
                               decoration: BoxDecoration(
                                 color: writing ? Colors.red : Colors.white.withOpacity(0.2),
                                 borderRadius: BorderRadius.circular(24),
                               ),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Icon(busy ? Icons.stop : Icons.fiber_manual_record,
                                       color: Colors.white, size: 20),
                                   const SizedBox(width: 8),
                                   Text(label, style: const TextStyle(color: Colors.white)),
                                 ],
                               ),
                             ),
                           ),
                         );
                       },
                     ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.episodes != null)
                  InkWell(
                    focusColor: AppTheme.electricBlue.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async { if (_currentEpisode > 0) { await _saveProgress(); setState(() { _currentEpisode--; _restoreAttempted = false; _position = Duration.zero; _duration = Duration.zero; }); _recordCurrentEpisodeHistory(); _loadStream(); } },
                    child: const Icon(Icons.skip_previous, color: Colors.white, size: 40),
                  ),
                if (widget.episodes != null) const SizedBox(width: 32),
                if (!widget.isLive)
                  InkWell(
                    focusColor: AppTheme.electricBlue.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _playing ? _player.pause() : _player.play(),
                    child: Icon(_playing ? Icons.pause_circle : Icons.play_circle,
                        color: Colors.white, size: 72),
                  ),
                if (widget.episodes != null) const SizedBox(width: 32),
                if (widget.episodes != null)
                  InkWell(
                    focusColor: AppTheme.electricBlue.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      if (widget.episodes != null && _currentEpisode < widget.episodes!.length - 1) {
                        await _saveProgress();
                        setState(() { _currentEpisode++; _restoreAttempted = false; _position = Duration.zero; _duration = Duration.zero; });
                        _recordCurrentEpisodeHistory();
                        _loadStream();
                      }
                    },
                    child: const Icon(Icons.skip_next, color: Colors.white, size: 40),
                  ),
              ],
            ),
            if (!widget.isLive) _buildProgressBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (!widget.isLive) ...[
                    _controlButton(Icons.replay_10, AppLocalizations.of(context).t('player_seek_back'), () => _seekBy(-10)),
                    _controlButton(Icons.forward_10, AppLocalizations.of(context).t('player_seek_forward'), () => _seekBy(10)),
                  ],
                  _controlButton(Icons.closed_caption, AppLocalizations.of(context).t('player_subtitles'), _showSubtitleTracks, focusNode: _subtitleButtonFocus),
                  _controlButton(Icons.audiotrack, AppLocalizations.of(context).t('player_audio'), _showAudioTracks, focusNode: _audioButtonFocus),
                  _controlButton(Icons.aspect_ratio, "${AppLocalizations.of(context).t('player_video_fit')}: ${_videoFitLabel(_videoFitIndex)}", _cycleVideoFit),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.episodes != null || widget.isLive)
                    InkWell(
                      focusColor: AppTheme.electricBlue.withOpacity(0.38),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openNavigationDrawer,
                      child: _pill(widget.isLive ? AppLocalizations.of(context).t('player_channels_folders') : AppLocalizations.of(context).t('player_episodes'), Icons.list),
                    ),
                  if (widget.isLive) ...[
                    IconButton(focusColor: AppTheme.electricBlue.withOpacity(0.38), onPressed: _zapPrevious, tooltip: AppLocalizations.of(context).t('player_previous_channel'), icon: const Icon(Icons.skip_previous, color: Colors.white)),
                    IconButton(focusColor: AppTheme.electricBlue.withOpacity(0.38), onPressed: _zapNext, tooltip: AppLocalizations.of(context).t('player_next_channel'), icon: const Icon(Icons.skip_next, color: Colors.white)),
                  ],
                  const SizedBox(width: 12),
                  InkWell(
                    focusColor: AppTheme.electricBlue.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _toggleHistorySidebar,
                    child: _pill(AppLocalizations.of(context).t('player_history'), Icons.history),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, String tooltip, VoidCallback onPressed, {FocusNode? focusNode}) {
    return Tooltip(
      message: tooltip,
      child: Focus(
        focusNode: focusNode,
        child: Material(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  void _seekBy(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final upper = _duration > Duration.zero ? _duration : const Duration(days: 365);
    _player.seek(target < Duration.zero ? Duration.zero : (target > upper ? upper : target));
    _startHideTimer();
  }

  void _cycleVideoFit() {
    setState(() => _videoFitIndex = (_videoFitIndex + 1) % _videoFits.length);
    _startHideTimer();
  }

  Future<void> _showAudioTracks() async {
    try {
      final options = _player.state.tracks.audio.where((track) => track.id != 'auto' && track.id != 'no').toList(growable: false);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xF0161D2A),
        builder: (sheetContext) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            ListTile(title: Text(AppLocalizations.of(context).t('player_audio'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            _trackOptionTile(
              context: sheetContext,
              icon: Icons.auto_awesome,
              label: AppLocalizations.of(context).t('player_auto'),
              selected: _player.state.track.audio.id == 'auto',
              onTap: () => _applyAudioTrack(AudioTrack.auto()),
            ),
            if (options.isEmpty)
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white70),
                title: Text(AppLocalizations.of(context).t('player_no_audio_tracks'), style: TextStyle(color: Colors.white70)),
              ),
            ...options.map((track) => _trackOptionTile(
              context: sheetContext,
              icon: Icons.audiotrack,
              label: _trackLabel(track.title, track.language, track.id),
              selected: _player.state.track.audio.id == track.id,
              onTap: () => _applyAudioTrack(track),
            )),
          ]),
        ),
      );
      _restoreTrackButtonFocus(_audioButtonFocus);
    } catch (_) {
      _showTrackMessage('Die Audiospurauswahl wird von diesem Stream oder Player derzeit nicht bereitgestellt.');
    }
  }

  Future<void> _showSubtitleTracks() async {
    try {
      final options = _player.state.tracks.subtitle.where((track) => track.id != 'auto' && track.id != 'no').toList(growable: false);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xF0161D2A),
        builder: (sheetContext) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            ListTile(title: Text(AppLocalizations.of(context).t('player_subtitles'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            _trackOptionTile(
              context: sheetContext,
              icon: Icons.auto_awesome,
              label: AppLocalizations.of(context).t('player_auto'),
              selected: _player.state.track.subtitle.id == 'auto',
              onTap: () => _applySubtitleTrack(SubtitleTrack.auto()),
            ),
            _trackOptionTile(
              context: sheetContext,
              icon: Icons.subtitles_off,
              label: AppLocalizations.of(context).t('player_off'),
              selected: _player.state.track.subtitle.id == 'no',
              onTap: () => _applySubtitleTrack(SubtitleTrack.no()),
            ),
            if (options.isEmpty)
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white70),
                title: Text(AppLocalizations.of(context).t('player_no_subtitles'), style: TextStyle(color: Colors.white70)),
              ),
            ...options.map((track) => _trackOptionTile(
              context: sheetContext,
              icon: Icons.closed_caption,
              label: _trackLabel(track.title, track.language, track.id),
              selected: _player.state.track.subtitle.id == track.id,
              onTap: () => _applySubtitleTrack(track),
            )),
          ]),
        ),
      );
      _restoreTrackButtonFocus(_subtitleButtonFocus);
    } catch (_) {
      _showTrackMessage('Die Untertitelauswahl wird von diesem Stream oder Player derzeit nicht bereitgestellt.');
    }
  }

  void _restoreTrackButtonFocus(FocusNode node) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.canRequestFocus) return;
      node.requestFocus();
      _startHideTimer();
    });
  }

  Widget _trackOptionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(selected ? Icons.check_circle : icon, color: selected ? Colors.lightBlueAccent : Colors.white70),
      title: Text(label, style: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected ? const Icon(Icons.check, color: Colors.lightBlueAccent) : null,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _applyAudioTrack(AudioTrack track) async {
    try {
      await _player.setAudioTrack(track);
    } catch (_) {
      _showTrackMessage('Die Audiospur konnte nicht gewechselt werden.');
    }
  }

  Future<void> _applySubtitleTrack(SubtitleTrack track) async {
    try {
      await _player.setSubtitleTrack(track);
    } catch (_) {
      _showTrackMessage('Die Untertiteleinstellung konnte nicht geändert werden.');
    }
  }

  String _trackLabel(String? rawTitle, String? rawLanguage, String id) {
    final title = rawTitle?.trim() ?? '';
    final language = rawLanguage?.trim() ?? '';
    final parts = <String>[
      if (title.isNotEmpty) title,
      if (language.isNotEmpty && language != title) language,
      if (title.isEmpty && language.isEmpty && id.isNotEmpty) id,
    ];
    return parts.isEmpty ? 'Unbekannte Spur' : parts.join(' · ');
  }

  void _showTrackMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProgressBar() {
    final maxVal = _duration.inMilliseconds.toDouble();
    final currentVal = _position.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(_fmt(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppTheme.electricBlue,
                thumbColor: AppTheme.electricBlue,
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(
                value: currentVal,
                max: maxVal > 0 ? maxVal : 1.0,
                onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(_fmt(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHistorySidebar() {
    final library = context.watch<ContentProvider>();
    final lists = <List<RecentPlaybackEntry>>[
      library.recentLive,
      library.recentVod,
      library.recentSeries,
    ];
    final names = <String>[AppLocalizations.of(context).t('nav_live'), AppLocalizations.of(context).t('nav_vod'), AppLocalizations.of(context).t('nav_series')];
    final types = <RecentPlaybackType>[
      RecentPlaybackType.live,
      RecentPlaybackType.vod,
      RecentPlaybackType.series,
    ];
    final icons = <IconData>[
      Icons.live_tv_rounded,
      Icons.movie_rounded,
      Icons.video_library_rounded,
    ];
    final entries = lists[_selectedHistoryTab].take(10).toList(growable: false);
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: MediaQuery.sizeOf(context).width.clamp(0.0, 380.0).toDouble(),
            decoration: BoxDecoration(
              color: const Color(0xE6101724),
              border: Border(
                left: BorderSide(color: Colors.white.withOpacity(0.16)),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(AppLocalizations.of(context).t('player_history'), style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        )),
                      ),
                      IconButton(
                        focusNode: _historyCloseFocus,
                        tooltip: AppLocalizations.of(context).t('player_close'),
                        focusColor: AppTheme.electricBlue.withOpacity(0.38),
                        onPressed: _closeHistorySidebar,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: List.generate(3, (index) {
                      final selected = index == _selectedHistoryTab;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Material(
                            color: selected
                                ? AppTheme.electricBlue.withOpacity(0.28)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              focusColor: AppTheme.electricBlue.withOpacity(0.45),
                              onTap: () => setState(() => _selectedHistoryTab = index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icons[index], color: Colors.white, size: 20),
                                    const SizedBox(height: 4),
                                    Text(names[index], style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                    )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text("${AppLocalizations.of(context).t('player_recent')}: ${entries.length}/10",
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      IconButton(
                        tooltip: "${AppLocalizations.of(context).t('player_clear_history')}: ${names[_selectedHistoryTab]}",
                        focusColor: AppTheme.electricBlue.withOpacity(0.38),
                        onPressed: entries.isEmpty ? null : () => _confirmClearHistory(
                          types[_selectedHistoryTab], names[_selectedHistoryTab]),
                        icon: Icon(Icons.delete_outline_rounded,
                          color: entries.isEmpty ? Colors.white24 : Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(AppLocalizations.of(context).t('player_history_empty'),
                            style: TextStyle(color: Colors.white70)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Material(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                child: ListTile(
                                  focusColor: AppTheme.electricBlue.withOpacity(0.38),
                                  onTap: () => _openRecentEntry(entry),
                                  leading: _historyImage(entry.imageUrl,
                                    entry.type == RecentPlaybackType.live
                                        ? Icons.tv : Icons.movie),
                                  title: Text(entry.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  trailing: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white70),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(RecentPlaybackType type, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('player_clear_history_question')),
        content: Text("${AppLocalizations.of(context).t('player_clear_history_confirm')} $label?"),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context).t('player_cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(AppLocalizations.of(context).t('player_clear_history')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<ContentProvider>().clearRecentHistory(type);
    }
  }

  Widget _historyImage(String? url, IconData fallback) {
    if (url == null || url.isEmpty) return CircleAvatar(backgroundColor: Colors.white12, child: Icon(fallback, color: Colors.white70));
    return ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(url, width: 44, height: 52, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => CircleAvatar(backgroundColor: Colors.white12, child: Icon(fallback, color: Colors.white70))));
  }

  Future<void> _openRecentEntry(RecentPlaybackEntry entry) async {
    setState(() => _showHistory = false);
    if (entry.channel != null) {
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: entry.channel, isLive: true)));
      return;
    }
    if (entry.vod != null) {
      final item = entry.vod!;
      final saved = await _progressService.loadPosition(
        sourceKey: context.read<ContentProvider>().sourceKey,
        contentId: item.id,
        contentType: 'vod',
      );
      if (!mounted) return;
      final choice = await _askPlaybackStart(savedPosition: saved, hasProgress: saved != null);
      if (choice == null || !mounted) return;
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerScreen(
        streamUrl: item.streamUrl, title: item.title, contentId: item.id,
        startFromBeginning: choice == PlaybackStartChoice.fromBeginning,
      )));
      return;
    }
    if (entry.series != null) {
      final series = entry.series!;
      final episodes = series.seasons.expand((season) => season.episodes).toList(growable: false);
      if (episodes.isEmpty) return;
      final episodeId = entry.id.contains('::') ? entry.id.split('::').last : null;
      final selectedIndex = episodeId == null ? 0 : episodes.indexWhere((episode) => episode.id == episodeId);
      final resumeIndex = selectedIndex >= 0 ? selectedIndex : 0;
      final selectedEpisode = episodes[resumeIndex];
      final savedPosition = await _progressService.loadPosition(
        sourceKey: context.read<ContentProvider>().sourceKey,
        contentId: '${series.id}::${selectedEpisode.id}',
        contentType: 'series',
      );
      if (!mounted) return;
      final choice = await _askPlaybackStart(savedPosition: savedPosition, isSeries: true, hasProgress: savedPosition != null);
      if (choice == null || !mounted) return;
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerScreen(
        episodes: episodes, initialEpisodeIndex: resumeIndex,
        title: series.title, series: series,
        startFromBeginning: choice == PlaybackStartChoice.fromBeginning,
      )));
    }
  }

  Future<PlaybackStartChoice?> _askPlaybackStart({int? savedPosition, bool isSeries = false, bool hasProgress = false}) {
    final duration = Duration(seconds: savedPosition ?? 0);
    final label = _fmt(duration);
    return showDialog<PlaybackStartChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).t(isSeries ? 'player_resume_series' : 'player_resume_movie')),
        content: Text(hasProgress ? (isSeries ? 'Deine letzte Wiedergabeposition in dieser Episode: $label' : 'Deine letzte Wiedergabeposition: $label') : (isSeries ? 'Möchtest du diese Episode abspielen?' : 'Dieser Film wurde noch nicht angesehen. Möchtest du ihn starten?')),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(dialogContext, PlaybackStartChoice.cancel), child: Text(AppLocalizations.of(context).t('player_cancel'))),
          TextButton(onPressed: () => Navigator.pop(dialogContext, PlaybackStartChoice.fromBeginning), child: Text(AppLocalizations.of(context).t('player_from_start'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, PlaybackStartChoice.resume), child: Text(AppLocalizations.of(context).t('player_continue'))),
        ],
      ),
    ).then((choice) => choice == PlaybackStartChoice.cancel ? null : choice);
  }

  void _zapBy(int offset) {
    final library = context.read<ContentProvider>();
    if (library.channels.isEmpty || widget.channel == null) return;
    final current = library.channels.indexWhere((c) => c.id == widget.channel!.id);
    final base = current < 0 ? 0 : current;
    final next = (base + offset + library.channels.length) % library.channels.length;
    final channel = library.channels[next];
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(channel: channel, isLive: true)));
  }

  void _restorePlayerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showDrawer && !_showHistory) _playerSurfaceFocus.requestFocus();
    });
  }

  void _toggleHistorySidebar() {
    if (_showHistory) {
      _closeHistorySidebar();
      return;
    }
    _hideTimer?.cancel();
    setState(() {
      _showDrawer = false;
      _selectedHistoryTab = widget.isLive ? 0 : (widget.episodes != null ? 2 : 1);
      _showHistory = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showHistory) _historyCloseFocus.requestFocus();
    });
  }

  void _closeHistorySidebar() {
    setState(() => _showHistory = false);
    _restorePlayerFocus();
  }

  void _closeNavigationDrawer() {
    _navigationScrollEpoch++;
    _focusedRowRequest++;
    setState(() => _showDrawer = false);
    _restorePlayerFocus();
  }

  void _openNavigationDrawer() {
    if (_showDrawer) return;
    _navigationScrollEpoch++;
    _focusedRowRequest++;
    setState(() { _showDrawer = true; _showHistory = false; });
    _hideTimer?.cancel();
    _scrollToCurrentNavigationItem();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showDrawer && widget.isLive) _categoryAllFocus.requestFocus();
    });
  }

  void _zapPrevious() => _zapBy(-1);
  void _zapNext() => _zapBy(1);

  Widget _buildLiveNavigationDrawer() {
    final channels = context.watch<ContentProvider>().channels;
    final categories = channels.map((c) => c.category ?? '')
        .where((c) => c.isNotEmpty).toSet().toList()..sort();
    final visible = _selectedLiveCategory == null
        ? channels
        : channels.where((c) => (c.category ?? '') == _selectedLiveCategory).toList();
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: MediaQuery.sizeOf(context).width.clamp(0.0, 360.0).toDouble(),
            decoration: BoxDecoration(color: const Color(0xE6101724),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.16)))),
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 18, 12, 10), child: Row(children: [
                Expanded(child: Text(AppLocalizations.of(context).t('player_channels_folders'), style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
                IconButton(focusNode: _drawerCloseFocus, tooltip: AppLocalizations.of(context).t('player_close'), focusColor: AppTheme.electricBlue.withOpacity(0.38), onPressed: _closeNavigationDrawer, icon: const Icon(Icons.close, color: Colors.white70)),
              ])),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: FocusTraversalGroup(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 126,
                        child: ListView(
                          controller: _categoryListScroll,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          children: [
                            _categoryTile(AppLocalizations.of(context).t('player_all'), null, autofocus: true),
                            ...categories.map((category) => _categoryTile(category, category)),
                          ],
                        ),
                      ),
                      const VerticalDivider(color: Colors.white24, width: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: _channelListScroll,
                          itemExtent: _navigationRowExtent,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final channel = visible[index];
                            final selected = channel.id == widget.channel?.id;
                            return Builder(builder: (rowContext) => Focus(
                              onFocusChange: (focused) =>
                                  _keepFocusedNavigationRowVisible(rowContext, focused),
                              child: ListTile(
                              // Category navigation owns initial focus; channel rows
                              // gain focus only when the user moves into the list.
                              autofocus: false,
                              dense: true,
                              selected: selected,
                              selectedTileColor: AppTheme.electricBlue.withOpacity(0.22),
                              leading: channel.logoUrl == null || channel.logoUrl!.isEmpty
                                ? const Icon(Icons.live_tv, color: Colors.white70, size: 20)
                                : SizedBox(width: 34, height: 30, child: Image.network(channel.logoUrl!, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.white70))),
                              title: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(
                                builder: (_) => PlayerScreen(channel: channel, isLive: true))),
                            )));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(String label, String? category, {bool autofocus = false}) {
    final selected = _selectedLiveCategory == category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? AppTheme.electricBlue.withOpacity(0.28) : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(9),
        child: ListTile(
          focusColor: AppTheme.electricBlue.withOpacity(0.38),
          autofocus: autofocus,
          focusNode: category == null ? _categoryAllFocus : null,
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          selected: selected,
          selectedTileColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white, fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
          onTap: () {
            _navigationScrollEpoch++;
            _focusedRowRequest++;
            setState(() => _selectedLiveCategory = category);
            if (_channelListScroll.hasClients) _channelListScroll.jumpTo(0);
            _scrollToCurrentNavigationItem();
            // Preserve the category focus while the channel list rebuilds.
          },
        ),
      ),
    );
  }

  Widget _buildEpisodesDrawer() {
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: MediaQuery.sizeOf(context).width.clamp(0.0, 360.0).toDouble(),
            decoration: BoxDecoration(color: const Color(0xE6101724),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.16)))),
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(18), child: Align(alignment: Alignment.centerLeft,
                child: Text(AppLocalizations.of(context).t('player_seasons_episodes'), style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)))),
              Expanded(child: FocusTraversalGroup(child: ListView.builder(
          controller: _episodeListScroll,
          itemExtent: _navigationRowExtent,
          itemCount: widget.episodes!.length,
          itemBuilder: (context, i) {
            final ep = widget.episodes![i];
            return Builder(builder: (rowContext) => Focus(
              onFocusChange: (focused) =>
                  _keepFocusedNavigationRowVisible(rowContext, focused),
              child: InkWell(
              autofocus: i == _currentEpisode,
              focusColor: AppTheme.electricBlue.withOpacity(0.38),
              onTap: () async {
                await _saveProgress();
                _navigationScrollEpoch++;
                _focusedRowRequest++;
                if (!mounted) return;
                setState(() { _currentEpisode = i; _showDrawer = false; _restoreAttempted = false; _position = Duration.zero; _duration = Duration.zero; });
                _restorePlayerFocus();
                _recordCurrentEpisodeHistory();
                _loadStream();
              },
              child: ListTile(
                focusColor: AppTheme.electricBlue.withOpacity(0.38),
                selected: i == _currentEpisode,
                leading: Text('${ep.number}', style: const TextStyle(color: Colors.white)),
                title: Text(ep.title, style: const TextStyle(color: Colors.white)),
              ),
            )));
          },
        ))),
          ]),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    final state = await RecordingService.refreshStatus();
    if (!mounted) return;

    if (state.isBusy) {
      await RecordingService.stop();
      if (!mounted) return;
      _showTrackMessage('Aufnahme wird beendet …');

      // The Android recorder closes its file asynchronously. Export only
      // after the service reports that writing has finished.
      RecordingStatus finished = RecordingService.status.value;
      var stopped = false;
      for (var attempt = 0; attempt < 40; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        finished = await RecordingService.refreshStatus();
        if (!mounted) return;
        if (!finished.isBusy && !finished.writing) {
          stopped = true;
          break;
        }
      }
      if (!mounted) return;
      if (!stopped) {
        _showTrackMessage(
          'Aufnahme wird noch beendet. Bitte Status prüfen.',
        );
        return;
      }
      if (finished.error != null && finished.error!.isNotEmpty) {
        _showTrackMessage(finished.error!);
      }
      if (finished.outputPath == null || finished.outputPath!.isEmpty ||
          finished.bytesWritten <= 0) {
        _showTrackMessage('Keine gespeicherte Aufnahme zum Exportieren vorhanden.');
        return;
      }
      try {
        final uri = await RecordingService.exportLastRecording();
        if (!mounted) return;
        _showTrackMessage(uri == null
            ? 'Export abgebrochen. Originalaufnahme bleibt gespeichert.'
            : 'Aufnahme am gewählten Speicherort gespeichert.');
      } on PlatformException catch (error) {
        if (!mounted) return;
        _showTrackMessage(error.message ?? 'Export nicht möglich. Original bleibt erhalten.');
      } catch (_) {
        if (!mounted) return;
        _showTrackMessage('Export nicht möglich. Original bleibt erhalten.');
      }
      return;
    }

    final url = _currentUrl;
    if (url == null || url.trim().isEmpty) {
      _showTrackMessage('Keine Stream-Adresse für die Aufnahme vorhanden.');
      return;
    }
    final accepted = await RecordingService.start(
      widget.channel?.name ?? _currentTitle,
      streamUrl: url,
    );
    if (!mounted) return;
    _showTrackMessage(accepted
        ? 'Aufnahmestart angefordert. REC erscheint bei aktiver Aufnahme.'
        : (RecordingService.status.value.error ??
            'Aufnahme konnte nicht gestartet werden.'));
  }

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
