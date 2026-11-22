import '../widgets/profile_clock.dart';
import '../services/profile_history_service.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../services/media_engine.dart';
import '../services/live_stream_format.dart';
import '../services/live_stream_format_preferences.dart';
import '../services/tv_playback_diagnostics.dart';
import '../services/tv_media3_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/platform/device_layout.dart';
import '../models/channel.dart';
import '../models/series.dart';
import '../models/vod_item.dart';
import '../providers/content_provider.dart';
import '../providers/family_session_provider.dart';
import '../services/recording_service.dart';
import '../services/download_service.dart';
import '../services/watch_progress_service.dart';
import '../widgets/favorites_quick_filter.dart';
import '../models/epg_programme.dart';
import '../services/epg_repository.dart';
import '../services/playlist_source_store.dart';
import '../services/epg_source_resolver.dart';
import '../widgets/channel_epg_panel.dart';
import '../widgets/tv_epg_timeline.dart';

class PlayerScreen extends StatefulWidget {
  final Channel? channel;
  final String? streamUrl;
  final String? title;
  final List<Episode>? episodes;
  final int? initialEpisodeIndex;
  final Series? series;
  final bool isLive;
  final String? contentId;
  final String? offlineDownloadId;
  final bool startFromBeginning;

  const PlayerScreen({
    super.key, this.channel, this.streamUrl, this.title,
    this.episodes, this.initialEpisodeIndex, this.series, this.isLive = false, this.contentId, this.offlineDownloadId, this.startFromBeginning = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

enum PlaybackStartChoice { resume, fromBeginning, cancel }

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver, FavoritesQuickFilter<PlayerScreen> {
  @override
  String get sortArea => 'live';
  // A single media player survives Live TV channel changes.
  Channel? _activeChannel;
  final EpgRepository _epgRepository = EpgRepository.shared;
  Future<List<EpgProgramme>>? _epgFuture;
  String? _epgChannelKey;

  void _prepareEpg() {
    if (!widget.isLive || !mounted) return;
    final channel = _activeChannel;
    // Some providers omit epg_channel_id even when their XMLTV guide uses
    // the stream ID. Keep the lookup conservative: use that ID only when
    // no explicit guide identifier is supplied.
    final channelId = (channel?.epgChannelId?.trim().isNotEmpty ?? false)
        ? channel!.epgChannelId!.trim()
        : channel?.id.trim();
    if (channelId == null || channelId.isEmpty) {
      _epgChannelKey = null;
      _epgFuture = null;
      return;
    }
    final key = '${_contentProvider.sourceKey}::$channelId';
    if (_epgChannelKey == key) return;
    _epgChannelKey = key;
    _epgFuture = () async {
      final config = await PlaylistSourceStore().read(_contentProvider.sourceKey);
      final url = EpgSourceResolver.resolve(config);
      if (url == null || url.trim().isEmpty) return <EpgProgramme>[];
      return _epgRepository.programmes(url, channelId);
    }();
  }

  List<Channel>? _indexedChannelList;
  Map<String, List<Channel>> _channelById = const {};
  // Reuse the authorized channel list across channel zaps and overlay rebuilds.
  // Every family/content notification invalidates this cache before checking
  // revocation, so a changed child-profile rule cannot reuse stale access.
  List<Channel>? _allowedLiveChannelCache;
  List<Channel>? _allowedLiveChannelSource;
  String? _allowedLiveChannelSourceKey;

  void _invalidateAllowedLiveChannels() {
    _allowedLiveChannelCache = null;
    _allowedLiveChannelSource = null;
    _allowedLiveChannelSourceKey = null;
  }

  List<Channel> _allowedLiveChannels() {
    final library = context.read<ContentProvider>();
    final family = context.read<FamilySessionProvider>();
    if (!family.isReady) return const <Channel>[];
    final source = library.channels;
    final cached = _allowedLiveChannelCache;
    if (cached != null && identical(source, _allowedLiveChannelSource) &&
        library.sourceKey == _allowedLiveChannelSourceKey) return cached;
    final allowed = source.where(_canPlayChannel).toList(growable: false);
    _allowedLiveChannelSource = source;
    _allowedLiveChannelSourceKey = library.sourceKey;
    _allowedLiveChannelCache = allowed;
    return allowed;
  }

  Future<void> _openQueue = Future<void>.value();
  bool _playerDisposalStarted = false;
  late final TvPlaybackDiagnostics _tvDiagnostics;
  // Android TV Live uses Media3; media_kit remains the mobile/VOD engine.
  bool get _useTvMedia3 => widget.isLive && DeviceLayout.isTelevision;
  String _tvMedia3Url = '';
  int _tvMedia3Epoch = 0;
  late final Player _player;
  late final VideoController _videoController;
  late final FamilySessionProvider _familySession;
  // A player route belongs to the profile that opened it. Switching to a
  // different profile ends this route's playback even when both profiles may
  // access the same content. Never silently carry a decoder across profiles.
  late final String? _openingProfileId;
  late final String? _openingAccountId;
  bool get _belongsToOpeningProfile {
    final current = _familySession.activeProfile;
    return current != null &&
        current.id == _openingProfileId &&
        current.accountUserId == _openingAccountId;
  }
  late final ProfileHistoryService _historyService;
  List<Map<String,dynamic>> _profileHistory = [];
  Future<void> _updateHistory(Future<List<Map<String,dynamic>>> request) async {
    try {
      final rows = await request;
      if (mounted && _historyService.isCurrent && _historyService.source == _contentProvider.sourceKey) {
        // Updating the history cache must not rebuild the live video surface.
        // Only repaint when the history sidebar is actually visible.
        if (_showHistory) {
          setState(() => _profileHistory = rows);
        } else {
          _profileHistory = rows;
        }
      }
    } catch (_) { /* Playback must not depend on history storage. */ }
  }
  List<RecentPlaybackEntry> _historyEntries(RecentPlaybackType type, ContentProvider library) {
    if (!_historyService.isCurrent || _historyService.source != library.sourceKey) return [];
    // The history sidebar requests all three tabs. Index only the catalogue
    // needed by this tab; large IPTV lists must not be reindexed three times.
    final channelById = type == RecentPlaybackType.live
        ? {for (final item in library.channels) item.id: item}
        : <String, Channel>{};
    final vodById = type == RecentPlaybackType.vod
        ? {for (final item in library.vodItems) item.id: item}
        : <String, VodItem>{};
    final seriesById = type == RecentPlaybackType.series
        ? {for (final item in library.series) item.id: item}
        : <String, Series>{};
    final result = <RecentPlaybackEntry>[];
    for (final row in _profileHistory) {
      if (row['content_type'] != type.name) continue;
      final id = row['content_id'];
      if (id is! String) continue;
      final viewed = DateTime.tryParse(row['viewed_at'] as String? ?? '');
      if (viewed == null) continue;
      if (type == RecentPlaybackType.live) {
        final item = channelById[id];
        if (item != null) result.add(RecentPlaybackEntry(type: type, id: id,
          title: item.name, imageUrl: item.logoUrl, channel: item,
          viewedAt: viewed, sourceKey: library.sourceKey));
      } else if (type == RecentPlaybackType.vod) {
        final item = vodById[id];
        if (item != null) result.add(RecentPlaybackEntry(type: type, id: id,
          title: item.title, imageUrl: item.posterUrl ?? item.backdropUrl,
          vod: item, viewedAt: viewed, sourceKey: library.sourceKey));
      } else {
        final separator = id.indexOf('::');
        if (separator < 0) continue;
        final item = seriesById[id.substring(0, separator)];
        if (item == null) continue;
        final episodeId = id.substring(separator + 2);
        for (final season in item.seasons) {
          for (final episode in season.episodes) {
            if (episode.id != episodeId) continue;
            result.add(RecentPlaybackEntry(type: type, id: id,
              title: '${item.title} · S${season.number} E${episode.number} · ${episode.title}',
              imageUrl: episode.stillUrl ?? item.posterUrl, series: item,
              viewedAt: viewed, sourceKey: library.sourceKey));
            break;
          }
        }
      }
    }
    return result;
  }
  late final ContentProvider _contentProvider;
  bool _playbackRevoked = false;
  StreamSubscription? _posSub, _durSub, _playSub, _errorSub, _bufferingSub;
  // Position callbacks may arrive dozens of times per second. A TV needs at
  // most one UI progress update per second; the exact value is retained for
  // progress saving and stall monitoring without rebuilding the video tree.
  int _lastTvVodRenderedSecond = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _showControls = true;
  // TV Live drawer: first LEFT channels, second LEFT categories + channels.
  bool _tvDrawerShowCategories = false;
  bool _showHistory = false;
  bool _showDrawer = false;
  String? _selectedLiveCategory;
  // Keep the current programme/episode visible even in very long lazy lists.
  final ScrollController _channelListScroll = ScrollController();
  final ScrollController _categoryListScroll = ScrollController();
  final FocusNode _drawerCloseFocus = FocusNode(debugLabel: 'Navigation schließen');
  final Map<String, FocusNode> _tvDrawerChannelNodes = {};
  int? _tvDrawerPendingIndex;
  String? _tvDrawerPendingChannelId;
  int _tvDrawerFocusRequest = 0;

  FocusNode _tvDrawerNode(Channel channel) => _tvDrawerChannelNodes.putIfAbsent(
    channel.id, () => FocusNode(debugLabel: 'TV-Sender ${channel.id}'));

  KeyEventResult _handleTvDrawerChannelKey(KeyEvent event, List<Channel> channels, int index) {
    if (!DeviceLayout.isTelevision || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    // Handle OK at the same focus boundary as D-pad movement. A lazy row
    // may still hold focus while the latest requested destination is pending.
    // Letting ListTile handle OK independently could open the previous row.
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _activateTvDrawerChannel(channels, index);
      return KeyEventResult.handled;
    }
    final direction = event.logicalKey == LogicalKeyboardKey.arrowDown ? 1
        : event.logicalKey == LogicalKeyboardKey.arrowUp ? -1 : 0;
    if (direction == 0) return KeyEventResult.ignored;
    // Repeated remote keys can arrive before Flutter builds the next lazy row.
    // Advance from the pending target, not the still-focused old row.
    // A favourites or permission refresh can change the channel list between
    // two remote key presses. Never advance from a stale numeric position.
    final pending = _tvDrawerPendingIndex;
    final pendingStillMatches = pending != null &&
        pending >= 0 && pending < channels.length &&
        channels[pending].id == _tvDrawerPendingChannelId;
    if (pending != null && !pendingStillMatches) {
      _tvDrawerPendingIndex = null;
      _tvDrawerPendingChannelId = null;
      ++_tvDrawerFocusRequest;
    }
    final current = pendingStillMatches ? pending : index;
    final next = (current + direction).clamp(0, channels.length - 1);
    if (next == current) return KeyEventResult.handled;
    _tvDrawerPendingIndex = next;
    _tvDrawerPendingChannelId = channels[next].id;
    final epoch = _navigationScrollEpoch;
    final request = ++_tvDrawerFocusRequest;
    _jumpToNavigationIndex(_channelListScroll, next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showDrawer || epoch != _navigationScrollEpoch ||
          request != _tvDrawerFocusRequest || next >= channels.length) return;
      // The lazy row can be rebuilt after a favourites/profile refresh while
      // this callback waits for a frame. Never focus a stale or forbidden row.
      final currentVisible = _visibleLiveChannels(_allowedLiveChannels());
      if (next >= currentVisible.length ||
          currentVisible[next].id != channels[next].id) {
        _tvDrawerPendingIndex = null;
        _tvDrawerPendingChannelId = null;
        ++_tvDrawerFocusRequest;
        return;
      }
      final node = _tvDrawerNode(currentVisible[next]);
      if (node.context != null) {
        node.requestFocus();
        _tvDrawerPendingIndex = null;
        _tvDrawerPendingChannelId = null;
      } else {
        // If the lazy row is not mounted yet, try after its next layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_showDrawer || epoch != _navigationScrollEpoch ||
              request != _tvDrawerFocusRequest) return;
          final latestVisible = _visibleLiveChannels(_allowedLiveChannels());
          if (next >= latestVisible.length ||
              latestVisible[next].id != channels[next].id) {
            _tvDrawerPendingIndex = null;
            _tvDrawerPendingChannelId = null;
            ++_tvDrawerFocusRequest;
            return;
          }
          final target = _tvDrawerNode(latestVisible[next]);
          if (target.context != null) {
            target.requestFocus();
            _tvDrawerPendingIndex = null;
            _tvDrawerPendingChannelId = null;
          }
        });
      }
    });
    return KeyEventResult.handled;
  }
  final FocusNode _categoryAllFocus = FocusNode(debugLabel: 'Alle Sender');
  final FocusNode _historyCloseFocus = FocusNode(debugLabel: 'Verlauf schließen');
  final ScrollController _episodeListScroll = ScrollController();
  static const double _navigationRowExtent = 72;
  // Invalidates pending scroll requests when a drawer/category changes.
  int _navigationScrollEpoch = 0;
  int _focusedRowRequest = 0;

  void _scrollToCurrentNavigationItem() {
    final epoch = _navigationScrollEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showDrawer || epoch != _navigationScrollEpoch) return;
      if (widget.episodes != null && _episodeListScroll.hasClients) {
        _jumpToNavigationIndex(_episodeListScroll, _currentEpisode);
        return;
      }
      if (!widget.isLive || !_channelListScroll.hasClients) return;
      final channels = _allowedLiveChannels();
      final visible = _visibleLiveChannels(channels);
      if (!DeviceLayout.isTelevision) {
        final index = visible.indexWhere((c) => c.id == _activeChannel?.id);
        if (index >= 0) _jumpToNavigationIndex(_channelListScroll, index);
        return;
      }
      // A favourite filter or permission update can remove the playing
      // channel. Always give the TV remote a real focus target in that case.
      final current = visible.indexWhere((c) => c.id == _activeChannel?.id);
      final index = current >= 0 ? current : (visible.isEmpty ? -1 : 0);
      if (index < 0) {
        _drawerCloseFocus.requestFocus();
        return;
      }
      final targetId = visible[index].id;
      _jumpToNavigationIndex(_channelListScroll, index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showDrawer || epoch != _navigationScrollEpoch) return;
        // Do not focus a stale row after an asynchronous permissions refresh.
        final latest = _visibleLiveChannels(_allowedLiveChannels());
        if (index >= latest.length || latest[index].id != targetId) {
          _drawerCloseFocus.requestFocus();
          return;
        }
        final targetNode = _tvDrawerNode(latest[index]);
        if (targetNode.context != null) {
          targetNode.requestFocus();
        } else {
          // Never leave the remote on an unfocusable video surface.
          _drawerCloseFocus.requestFocus();
        }
      });
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
  // Only Android TV Media3: detect a native open that never reaches READY/BUFFERING.
  static const Duration _tvMedia3StartupTimeout = Duration(seconds: 30);
  DateTime? _tvMedia3AwaitingFirstStateAt;
  // STATE_IDLE after a successful native callback must not hang forever.
  static const Duration _tvMedia3IdleTimeout = Duration(seconds: 25);
  DateTime? _tvMedia3IdleSince;
  bool _buffering = false;
  DateTime? _bufferingStartedAt;
  DateTime? _stablePlaybackStartedAt;
  static const Duration _stablePlaybackReset = Duration(seconds: 90);

  bool _appInForeground = true;
  Duration? _reconnectResumePosition;
  bool _streamFailed = false;
  bool _reconnecting = false;
  int _automaticReconnects = 0;
  int _streamLoadGeneration = 0;
  static const int _maxAutomaticReconnects = 2;
  late final WatchProgressService _progressService;
  final FocusNode _playerSurfaceFocus = FocusNode(debugLabel: 'Player-Oberfläche');
  final FocusNode _subtitleButtonFocus = FocusNode(debugLabel: 'Untertitel');
  final FocusNode _audioButtonFocus = FocusNode(debugLabel: 'Audiosprache');
  final FocusNode _recordButtonFocus = FocusNode(debugLabel: 'Aufnahme');
  final FocusNode _navigationButtonFocus = FocusNode(debugLabel: 'Sender und Ordner');
  final FocusNode _tvEpgFocus = FocusNode(debugLabel: 'TV EPG Timeline');
  final FocusNode _historyButtonFocus = FocusNode(debugLabel: 'Verlauf');
  bool _restoreAttempted = false;
  bool _saveInFlight = false;
  int _currentEpisode = 0;

  void _indexChannels(ContentProvider library) {
    if (identical(_indexedChannelList, library.channels)) return;
    _indexedChannelList = library.channels;
    final index = <String, List<Channel>>{};
    for (final channel in library.channels) {
      index.putIfAbsent(channel.id, () => <Channel>[]).add(channel);
    }
    _channelById = index;
  }

  // A rapid D-pad sequence may leave the old row focused while the lazy
  // target row is still being built. OK must select the pending destination.
  void _activateTvDrawerChannel(List<Channel> visible, int tappedIndex) {
    if (visible.isEmpty || tappedIndex < 0 || tappedIndex >= visible.length) return;
    final pending = DeviceLayout.isTelevision ? _tvDrawerPendingIndex : null;
    // A favorites/profile refresh can rebuild the visible list while a
    // remote focus request is pending. Never use a stale numeric index to
    // launch a different channel after that rebuild.
    final targetIndex = pending != null && pending >= 0 &&
            pending < visible.length &&
            visible[pending].id == _tvDrawerPendingChannelId
        ? pending : tappedIndex;
    _tvDrawerPendingIndex = null;
    _tvDrawerPendingChannelId = null;
    ++_tvDrawerFocusRequest;
    _switchLiveChannel(visible[targetIndex]);
  }

  void _switchLiveChannel(Channel channel) {
    _tvDrawerPendingIndex = null;
    _tvDrawerPendingChannelId = null;
    ++_tvDrawerFocusRequest;
    if (!mounted || !widget.isLive || _playbackRevoked ||
        !_canPlayChannel(channel)) return;
    // A provider can reuse the same ID and URL in separate categories or
    // playlist sources. Treat these as distinct authorization contexts.
    if (_activeChannel?.id == channel.id &&
        _activeChannel?.streamUrl == channel.streamUrl &&
        _activeChannel?.categoryKey == channel.categoryKey &&
        _activeChannel?.sourceKey == channel.sourceKey) {
      _closeNavigationDrawerIfOpen();
      _closeHistoryIfOpen();
      return;
    }
    ++_streamLoadGeneration;
    _reconnectTimer?.cancel();
    _navigationScrollEpoch++;
    _focusedRowRequest++;
    setState(() {
      _activeChannel = channel;
      _showDrawer = false;
      _showHistory = false;
      _selectedLiveCategory = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _buffering = false;
      _bufferingStartedAt = null;
      _stablePlaybackStartedAt = null;
      _playing = false;
      _streamFailed = false;
      _reconnecting = false;
      _automaticReconnects = 0;
    });
    _epgChannelKey = null;
    _epgFuture = null;
    _restorePlayerFocus();
    _updateHistory(_historyService.record('live', channel.id));
    unawaited(_loadStream());
  }

  void _closeNavigationDrawerIfOpen() {
    if (_showDrawer) _closeNavigationDrawer();
  }

  void _closeHistoryIfOpen() {
    if (_showHistory) _closeHistorySidebar();
  }

  String? get _currentUrl {
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      return widget.episodes![_currentEpisode].streamUrl;
    }
    return widget.isLive
        ? (_activeChannel?.streamUrl ?? widget.streamUrl)
        : (widget.streamUrl ?? _activeChannel?.streamUrl);
  }

  String? get _progressContentId {
    if (widget.isLive || widget.offlineDownloadId != null) return null;
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
    return widget.title ?? _activeChannel?.name ?? 'Stream';
  }

  @override
  void initState() {
    super.initState();
    // Enter live TV fullscreen cleanly; controls appear only on explicit OK.
    if (widget.isLive && DeviceLayout.isTelevision) _showControls = false;
    WidgetsBinding.instance.addObserver(this);
    _activeChannel = widget.channel;
    _tvDiagnostics = TvPlaybackDiagnostics(
      enabled: DeviceLayout.isTelevision && widget.isLive,
    );
    _player = MediaEngine.createPlayer();
    _videoController = VideoController(_player);
    _familySession = context.read<FamilySessionProvider>();
    _openingProfileId = _familySession.activeProfile?.id;
    _openingAccountId = _familySession.activeProfile?.accountUserId;
    _progressService = WatchProgressService(family: _familySession);
    _familySession.addListener(_onFamilySessionChanged);
    if (widget.offlineDownloadId != null) {
      DownloadService.entries.addListener(_onFamilySessionChanged);
    }
    _contentProvider = context.read<ContentProvider>();
    _historyService = ProfileHistoryService(_familySession, _contentProvider.sourceKey);
    _contentProvider.addListener(_onFamilySessionChanged);
    _currentEpisode = widget.initialEpisodeIndex ?? 0;
    _posSub = _player.stream.position.listen((p) {
      if (_useTvMedia3) return;
      if (!mounted) return;
      if (p > _lastObservedPlaybackPosition) {
        _lastObservedPlaybackPosition = p;
        _lastPlaybackProgressAt = DateTime.now();
      }
      if (DeviceLayout.isTelevision && widget.isLive) {
        // Live playback has no seek bar. Keep stall detection current without
        // rebuilding the video surface and thousands of navigation entries.
        _position = p;
      } else if (DeviceLayout.isTelevision && !widget.isLive) {
        _position = p;
        final second = p.inSeconds;
        if (second != _lastTvVodRenderedSecond) {
          _lastTvVodRenderedSecond = second;
          // Avoid rebuilding the entire TV video/overlay tree while hidden.
          // On opening controls, the latest _position is already available.
          if (_showControls || _showHistory || _showDrawer) setState(() {});
        }
      } else {
        setState(() => _position = p);
      }
    });
    _durSub = _player.stream.duration.listen((d) {
      if (_useTvMedia3) return;
      if (!mounted || d == _duration) return;
      if (DeviceLayout.isTelevision && widget.isLive) {
        _duration = d;
      } else {
        setState(() => _duration = d);
      }
    });
    _playSub = _player.stream.playing.listen((p) {
      if (_useTvMedia3) return;
      if (!mounted) return;
      _tvDiagnostics.playing(p);
      final changed = _playing != p || (p && (_streamFailed || _reconnecting));
      void update() {
        final wasPlaying = _playing;
        _playing = p;
        if (p) {
          _streamFailed = false;
          _reconnecting = false;
          // Repeated playing=true events must not reset the VOD stall clock.
          // Only an actual transition into playing starts a new grace period.
          if (!wasPlaying) _lastPlaybackProgressAt = DateTime.now();
          // Buffering is not stable playback, even if the player says playing.
          if (!_buffering) _stablePlaybackStartedAt ??= DateTime.now();
        } else {
          _lastPlaybackProgressAt = null;
          _stablePlaybackStartedAt = null;
        }
      }
      if (changed) {
        setState(update);
      } else {
        update();
      }
    });
    // Buffering is not a playback failure. Allow a bounded grace period so
    // slow connections can recover, without hanging indefinitely.
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (_useTvMedia3) return;
      if (!mounted) return;
      _tvDiagnostics.buffering(buffering);
      if (buffering) {
        _stablePlaybackStartedAt = null;
        _bufferingStartedAt ??= DateTime.now();
      } else {
        _bufferingStartedAt = null;
        _lastPlaybackProgressAt = DateTime.now();
        _lastObservedPlaybackPosition = _position;
        if (_playing) _stablePlaybackStartedAt ??= DateTime.now();
      }
      _buffering = buffering;
    });
    // Do not show raw player errors: stream URLs can contain account secrets.
    _errorSub = _player.stream.error.listen((_) {
      if (_useTvMedia3) return;
      _tvDiagnostics.failure('native-player-error');
      _handlePlaybackFailure();
    });
    _loadStream();
    RecordingService.refreshStatus();
    _stallMonitor = Timer.periodic(const Duration(seconds: 5), (_) => _checkPlaybackStall());
    // Live TV has no seekable watch progress. Avoid waking the Dart UI
    // isolate every 15 seconds for a guaranteed no-op during playback.
    if (!widget.isLive) {
      _progressTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _saveProgress());
    }
    // Live TV has no seekable watch progress. Avoid periodic Supabase/disk
    // synchronization while the TV decoder is handling a continuous stream.
    // Pending VOD progress is still flushed during VOD playback; Live TV
    // history is recorded independently by ProfileHistoryService.
    if (!widget.isLive) {
      _queueSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!_appInForeground || _playbackRevoked) return;
        unawaited(_progressService.flushPending());
      });
    }
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Keep the TV video unobstructed on initial playback. The user opens
      // channel navigation explicitly via the remote; never open a drawer
      // automatically while the decoder is starting.
      if (!mounted || _playbackRevoked || !_isCurrentStreamAuthorized()) return;
      final library = context.read<ContentProvider>();
      if (_activeChannel != null) _updateHistory(_historyService.record('live', _activeChannel!.id));
      if (widget.contentId != null && !widget.isLive && widget.episodes == null) {
        for (final item in library.vodItems) {
          if (item.id == widget.contentId) { _updateHistory(_historyService.record('vod', item.id)); break; }
        }
      }
      if (widget.series != null) _recordCurrentEpisodeHistory(library);
    });
  }

  void _recordCurrentEpisodeHistory([ContentProvider? provider]) {
    if (!mounted || _playbackRevoked || !_isCurrentStreamAuthorized()) return;
    final series = widget.series;
    final episodes = widget.episodes;
    if (series == null || episodes == null || episodes.isEmpty ||
        _currentEpisode < 0 || _currentEpisode >= episodes.length) return;
    final episode = episodes[_currentEpisode];
    _updateHistory(_historyService.record('series', '${series.id}::${episode.id}'));
  }

  // Detect streams that silently stop advancing without emitting a player error.
  // Never reconnect deliberately paused playback or content near its end.
  void _checkPlaybackStall() {
    if (!mounted || !_appInForeground || _streamFailed) return;
    // A platform-view creation/open can stall without emitting any Media3
    // event. Do not let _reconnecting suppress this startup watchdog.
    if (_useTvMedia3 && _tvMedia3AwaitingFirstStateAt != null) {
      if (DateTime.now().difference(_tvMedia3AwaitingFirstStateAt!) >=
          _tvMedia3StartupTimeout) {
        _tvMedia3AwaitingFirstStateAt = null;
        _tvMedia3IdleSince = null;
        _tvDiagnostics.failure('media3-startup-timeout');
        _handlePlaybackFailure();
      }
      return;
    }
    // Media3 STATE_IDLE=1 is neither buffering nor playing. A decoder can
    // remain idle without raising an error, especially after a failed source
    // transition. Check this before the reconnect guard, as a retry can still
    // be waiting for its first usable frame.
    if (_useTvMedia3 && _tvMedia3IdleSince != null) {
      if (DateTime.now().difference(_tvMedia3IdleSince!) >=
          _tvMedia3IdleTimeout) {
        _tvMedia3IdleSince = null;
        _tvDiagnostics.failure('media3-idle-timeout');
        _handlePlaybackFailure();
      }
      return;
    }
    if (_reconnecting) return;
    // A buffering player may report playing=false; check buffering first.
    if (_buffering) {
      final since = _bufferingStartedAt;
      if (since == null || DateTime.now().difference(since) < _bufferingTimeout) return;
      _tvDiagnostics.failure('buffering-timeout');
      _handlePlaybackFailure();
      return;
    }
    if (!_playing) return;
    // Live stream positions may remain static even while video is decoding.
    // Only explicit player errors and sustained buffering trigger Live TV retries.
    if (widget.isLive) {
      final stableSince = _stablePlaybackStartedAt;
      if (stableSince != null &&
          DateTime.now().difference(stableSince) >= _stablePlaybackReset) {
        _automaticReconnects = 0;
      }
      return;
    }
    final last = _lastPlaybackProgressAt;
    if (last == null || DateTime.now().difference(last) < _stallTimeout) return;
    if (!widget.isLive && _duration > Duration.zero &&
        _position >= _duration - const Duration(seconds: 3)) return;
    _handlePlaybackFailure();
  }

  void _handlePlaybackFailure({bool allowAutomaticRetry = true}) {
    // Native error events can arrive after permission revocation or while
    // a route is being disposed. Never schedule a retry in either state.
    if (!mounted || _playerDisposalStarted || _playbackRevoked ||
        !_isCurrentStreamAuthorized() || _streamFailed) return;
    // Do not schedule retries while the operating system suspends playback.
    if (!_appInForeground) return;
    _tvMedia3AwaitingFirstStateAt = null;
    _tvMedia3IdleSince = null;
    setState(() { _streamFailed = true; _reconnecting = false; _showControls = !widget.isLive || !DeviceLayout.isTelevision; });
    _hideTimer?.cancel();
    if (!allowAutomaticRetry ||
        _automaticReconnects >= _maxAutomaticReconnects) return;
    _automaticReconnects++;
    final generation = _streamLoadGeneration;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 2 * _automaticReconnects), () {
      if (!mounted || generation != _streamLoadGeneration ||
          !_streamFailed || !_appInForeground || _playbackRevoked ||
          !_isCurrentStreamAuthorized()) return;
      _reconnectTimer = null;
      unawaited(_loadStream(reconnect: true));
    });
  }

  void _onFamilySessionChanged() {
    _invalidateAllowedLiveChannels();
    if (!mounted || _playbackRevoked) return;
    if (_belongsToOpeningProfile && _isCurrentStreamAuthorized()) return;
    _tvMedia3AwaitingFirstStateAt = null;
    _tvMedia3IdleSince = null;

    // A revoked permission must stop an already opened media stream,
    // including while a reconnect or asynchronous open is in flight.
    _playbackRevoked = true;
    ++_streamLoadGeneration;
    _reconnectTimer?.cancel();
    _stallMonitor?.cancel();
    _hideTimer?.cancel();
    // Serialize revocation with queued Media.open calls. A stop racing with
    // an in-flight open could otherwise finish first and leave media playing.
    final previousOpen = _openQueue;
    final revocation = Completer<void>();
    _openQueue = revocation.future;
    // Remove the native view's playable URL immediately. Its own serialized
    // method-channel queue orders stop after any already running open. Waiting
    // for the unrelated Dart queue here would leave revoked TV video visible.
    if (_useTvMedia3 && mounted) {
      setState(() { _tvMedia3Url = ''; ++_tvMedia3Epoch; });
    }
    unawaited(() async {
      try {
        await previousOpen.catchError((Object _) {});
        if (!_useTvMedia3) {
          await _player.stop();
        }
      } catch (_) {
        // Revocation must remain terminal even if the native player fails.
      } finally {
        revocation.complete();
      }
    }());
    if (mounted) {
      setState(() {
        _playing = false;
        _reconnecting = false;
        _streamFailed = true;
        _showControls = true;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(
          'Die Wiedergabe wurde wegen geänderter Profilberechtigungen beendet.',
        )),
      );
    }
  }

  bool _canPlayChannel(Channel channel) {
    final family = context.read<FamilySessionProvider>();
    final library = context.read<ContentProvider>();
    if (!family.isReady || channel.sourceKey != library.sourceKey) return false;
    _indexChannels(library);
    final candidates = _channelById[channel.id];
    if (candidates == null || !candidates.any((current) =>
        current.streamUrl == channel.streamUrl &&
        current.categoryKey == channel.categoryKey &&
        current.sourceKey == channel.sourceKey)) return false;
    return family.canAccessCategory(
      sourceKey: channel.sourceKey ?? '',
      contentType: 'live',
      categoryKey: channel.categoryKey ?? '',
    );
  }

  bool _canPlayVod(VodItem item) {
    final family = context.read<FamilySessionProvider>();
    final library = context.read<ContentProvider>();
    if (!family.isReady) return false;
    final current = library.vodItems.where((candidate) =>
        candidate.id == item.id && candidate.streamUrl == item.streamUrl &&
        candidate.categoryKey == item.categoryKey);
    // Duplicate catalogue IDs/URLs may be listed in folders with different
    // parental rules. History and direct playback must use the same
    // fail-closed rule rather than trusting the first matching entry.
    return current.isNotEmpty && current.every((candidate) =>
        family.canAccessCategory(
          sourceKey: library.sourceKey,
          contentType: 'vod',
          categoryKey: candidate.categoryKey ?? '',
        ));
  }

  bool _canPlaySeries(Series item) {
    final family = context.read<FamilySessionProvider>();
    final library = context.read<ContentProvider>();
    if (!family.isReady) return false;
    // Parental rules apply to an entire series or folder, never individual
    // seasons or episodes. A duplicate provider series ID in a blocked folder
    // must not create an alternate route to the same series.
    final matches = library.series.where((candidate) => candidate.id == item.id);
    return matches.isNotEmpty && matches.every((candidate) =>
        family.canAccessCategory(
          sourceKey: library.sourceKey,
          contentType: 'series',
          categoryKey: candidate.categoryKey ?? '',
        ));
  }

  void _switchEpisode(int nextIndex, {bool closeDrawer = false}) {
    final episodes = widget.episodes;
    if (!mounted || _playbackRevoked || episodes == null ||
        nextIndex < 0 || nextIndex >= episodes.length ||
        nextIndex == _currentEpisode) return;
    // Capture the previous episode's progress synchronously. Never delay
    // playback for a database write, profile refresh or episode permission
    // request. Actual profile revocation is handled by the session listener,
    // and _loadStream checks the locally active series permission.
    unawaited(_saveProgress());
    if (closeDrawer) {
      _navigationScrollEpoch++;
      _focusedRowRequest++;
    }
    setState(() {
      _currentEpisode = nextIndex;
      if (closeDrawer) _showDrawer = false;
      _restoreAttempted = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    if (closeDrawer) _restorePlayerFocus();
    _recordCurrentEpisodeHistory();
    unawaited(_loadStream());
  }

  bool _canOpenRecent(RecentPlaybackEntry entry) {
    final library = context.read<ContentProvider>();
    if (entry.sourceKey != library.sourceKey) return false;
    if (entry.channel != null) return _canPlayChannel(entry.channel!);
    if (entry.vod != null) return _canPlayVod(entry.vod!);
    if (entry.series != null) return _canPlaySeries(entry.series!);
    return false;
  }

  bool _isCurrentStreamAuthorized() {
    final family = context.read<FamilySessionProvider>();
    final content = context.read<ContentProvider>();
    final channel = _activeChannel;
    bool permitted = family.isReady && _belongsToOpeningProfile;
    if (!permitted) return false;
    final offlineId = widget.offlineDownloadId;
    if (offlineId != null) {
      final profile = family.activeProfile;
      return permitted && profile != null && channel == null &&
          widget.episodes == null && !widget.isLive &&
          DownloadService.authorizesOffline(offlineId, profile.accountUserId,
              profile.id, _currentUrl);
    }

    if (permitted && channel != null) {
      permitted = _canPlayChannel(channel);
    } else if (permitted && widget.episodes != null && widget.series != null) {
      // Only the selected episode URL may play; category access is decided
      // once per series, not re-requested for each episode.
      final episodes = widget.episodes!;
      permitted = _currentEpisode >= 0 && _currentEpisode < episodes.length &&
          episodes[_currentEpisode].streamUrl == _currentUrl &&
          _canPlaySeries(widget.series!);
    } else if (permitted && (family.isChild || widget.contentId != null)) {
      // A child may only play an item that is still present in the
      // current source catalog with an explicitly permitted category.
      // Bare URLs, downloaded files and stale history entries fail closed.
      if (widget.contentId != null && widget.streamUrl != null) {
        final matching = content.vodItems.where(
          (item) => item.id == widget.contentId &&
              item.streamUrl == widget.streamUrl,
        );
        // Duplicate catalog IDs/URLs may belong to different folders.
        // Never authorize a stream using only the first matching folder:
        // every matching catalog entry must remain permitted, and the
        // currently playing URL must still be the requested catalog URL.
        permitted = _currentUrl == widget.streamUrl &&
            matching.isNotEmpty &&
            matching.every((item) => family.canAccessCategory(
              sourceKey: content.sourceKey,
              contentType: 'vod',
              categoryKey: item.categoryKey ?? '',
            ));
      } else {
        permitted = false;
      }
    }

    return permitted;
  }

  Future<void> _loadStream({bool reconnect = false}) async {
    if (_playerDisposalStarted || !mounted) return;
    final permitted = !_playbackRevoked && _isCurrentStreamAuthorized();

    if (!permitted) {
      // Fail closed immediately: callbacks or retry timers must not revive a
      // stream while the queued native stop is still waiting for an open.
      _playbackRevoked = true;
      _reconnectTimer?.cancel();
      _stallMonitor?.cancel();
      _tvMedia3AwaitingFirstStateAt = null;
      _tvMedia3IdleSince = null;
      ++_streamLoadGeneration;
      // Do not race a pending native Media.open with a permission stop.
      // Reserve the queue immediately, before the first await.
      final previousOpen = _openQueue;
      final stopping = Completer<void>();
      _openQueue = stopping.future;
      // Native TV stop must be requested immediately. Waiting on the Dart
      // media_kit queue can leave a revoked channel visible on Android TV.
      // TvMedia3View serializes its own native open/stop operations.
      if (_useTvMedia3 && mounted) {
        setState(() { _tvMedia3Url = ''; ++_tvMedia3Epoch; });
      }
      try {
        await previousOpen.catchError((Object _) {});
        if (!_playerDisposalStarted && !_useTvMedia3) {
          await _player.stop();
        }
      } catch (_) {
        // An inaccessible stream must never be reopened on stop failure.
      } finally {
        stopping.complete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Dieser Inhalt ist für das Profil nicht freigegeben.',
          )),
        );
      }
      return;
    }
    final url = _currentUrl;
    if (url == null || url.isEmpty) {
      _handlePlaybackFailure();
      return;
    }
    _reconnectTimer?.cancel();
    final generation = ++_streamLoadGeneration;
    _tvDiagnostics.streamOpened(reconnect: reconnect);
    if (!reconnect) _automaticReconnects = 0;
    _stablePlaybackStartedAt = null;
    // Keep the position before Media.open resets player position streams.
    final resumeAt = reconnect && !widget.isLive
        ? (_reconnectResumePosition ?? _position)
        : Duration.zero;
    _reconnectResumePosition = reconnect ? resumeAt : null;
    _lastPlaybackProgressAt = DateTime.now();
    _lastObservedPlaybackPosition = Duration.zero;
    _buffering = false;
    _bufferingStartedAt = null;
    _tvMedia3AwaitingFirstStateAt = null;
    _tvMedia3IdleSince = null;
    _playing = false;
    if (mounted) setState(() { _reconnecting = reconnect; _streamFailed = false; });
    // Keep the queue reserved through post-open seeks and progress restore.
    // Otherwise dispose() or a newer channel open may race those operations.
    final previousOpen = _openQueue;
    final opening = Completer<void>();
    _openQueue = opening.future;
    var revokeAfterOpen = false;
    try {
      await previousOpen.catchError((Object _) {});
      if (!mounted || _playerDisposalStarted ||
          generation != _streamLoadGeneration ||
          !_isCurrentStreamAuthorized()) return;
      // Only Xtream Live TV on Android TV may use the preferred HLS/TS
      // variant. M3U URLs, movies, series and mobile playback stay unchanged.
      // The original URL is always retained as a fallback. Never log URLs:
      // Xtream addresses can contain usernames and passwords.
      final candidates = <String>[url];
      if (widget.isLive && DeviceLayout.isTelevision) {
        // Preference storage failure must never prevent channel playback.
        LiveStreamFormat preference = LiveStreamFormat.automatic;
        try {
          preference = await LiveStreamFormatPreferences.load(isTv: true);
        } catch (_) {
          // Preserve the original stream when local storage is unavailable.
        }
        candidates
          ..clear()
          ..addAll(LiveStreamFormatResolver.candidates(url, preference));
      }
      if (!mounted || _playerDisposalStarted ||
          generation != _streamLoadGeneration ||
          !_isCurrentStreamAuthorized()) return;
      if (_useTvMedia3) {
        // Media3 owns the only active decoder for Android TV Live.
        // Reopen the existing native player even when retrying the same URL.
        if (mounted && generation == _streamLoadGeneration &&
            _isCurrentStreamAuthorized()) {
          // Arm only once the native view is requested; canceled on its first
          // state callback, a newer open, permission loss or app suspension.
          _tvMedia3AwaitingFirstStateAt = DateTime.now();
          setState(() {
            _tvMedia3Url = candidates.first;
            ++_tvMedia3Epoch;
          });
        }
        return;
      }
      for (var index = 0; index < candidates.length; index++) {
        try {
          await _player.open(Media(candidates[index]));
          break;
        } catch (_) {
          // Only a synchronous/awaited open failure triggers this fallback.
          // A later native decoder failure needs separate diagnostics.
          if (index == candidates.length - 1) rethrow;
          if (!mounted || _playerDisposalStarted ||
              generation != _streamLoadGeneration ||
              !_isCurrentStreamAuthorized()) return;
        }
      }
      if (!mounted || _playerDisposalStarted ||
          generation != _streamLoadGeneration) return;
      if (!_isCurrentStreamAuthorized()) {
        // Do not enqueue a revocation stop until this open has released its
        // queue slot. Otherwise the stop can wait on the operation that is
        // itself waiting for the stop (or race the native open).
        revokeAfterOpen = true;
        return;
      }
      // Reconnect always takes precedence over stored progress. A first open
      // may fail before the initial progress lookup; in that case the retry
      // must still resume at the position captured before Media.open.
      if (reconnect && !widget.isLive) {
        if (resumeAt > Duration.zero && mounted && !_playerDisposalStarted &&
            generation == _streamLoadGeneration && _isCurrentStreamAuthorized()) {
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
              !_playerDisposalStarted && _isCurrentStreamAuthorized() &&
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
      if (mounted && !_playerDisposalStarted &&
          generation == _streamLoadGeneration) _handlePlaybackFailure();
    } finally {
      opening.complete();
      if (revokeAfterOpen && mounted && !_playerDisposalStarted) {
        _onFamilySessionChanged();
      }
    }
  }

  void _onTvMedia3State(int state, bool playing) {
    // Native callbacks queued before Activity.pause must not revive playback
    // state or consume recovery policy while Android owns the lifecycle.
    if (!_useTvMedia3 || !mounted || _playerDisposalStarted ||
        !_appInForeground || _playbackRevoked || _tvMedia3Url.isEmpty) return;
    _tvMedia3AwaitingFirstStateAt = null;
    // Media3 Player.STATE_BUFFERING=2, READY=3, ENDED=4.
    // Do not restart the clock on repeated IDLE callbacks: that would allow
    // an indefinitely idle decoder to escape the watchdog.
    if (state == 1) {
      _tvMedia3IdleSince ??= DateTime.now();
    } else {
      _tvMedia3IdleSince = null;
    }
    final buffering = state == 2;
    _tvDiagnostics.buffering(buffering);
    _tvDiagnostics.playing(playing);
    _buffering = buffering;
    if (buffering) {
      _bufferingStartedAt ??= DateTime.now();
      _stablePlaybackStartedAt = null;
    } else {
      _bufferingStartedAt = null;
      if (playing) _stablePlaybackStartedAt ??= DateTime.now();
    }
    // A late READY/playing callback can arrive while a delayed retry is
    // pending. Cancel that retry rather than tearing down recovered playback.
    if (playing) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _tvMedia3IdleSince = null;
      _tvMedia3AwaitingFirstStateAt = null;
    }
    if (_playing != playing || (playing && (_streamFailed || _reconnecting))) {
      setState(() {
        _playing = playing;
        if (playing) {
          _streamFailed = false;
          _reconnecting = false;
        }
      });
    }
    if (state == 4) {
      _tvDiagnostics.failure('media3-ended');
      _handlePlaybackFailure();
    }
  }

  void _onTvMedia3Error(String code) {
    // Native callbacks queued before Activity.pause must not revive playback
    // state or consume recovery policy while Android owns the lifecycle.
    if (!_useTvMedia3 || !mounted || _playerDisposalStarted ||
        !_appInForeground || _playbackRevoked || _tvMedia3Url.isEmpty) return;
    _tvMedia3AwaitingFirstStateAt = null;
    // Native side forwards error codes only, never credential-bearing URLs.
    _tvMedia3IdleSince = null;
    // These Media3 errors describe an unsupported source/codec or a blocked
    // cleartext transport. Reopening the identical URL cannot fix them and
    // needlessly churns the TV decoder. Keep manual retry available after
    // the source or device configuration has been corrected.
    const nonRecoverableCodes = <String>{
      'ERROR_CODE_DECODING_FORMAT_UNSUPPORTED',
      'ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED',
      'ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED',
      'ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED',
    };
    _tvDiagnostics.failure('media3-error');
    _handlePlaybackFailure(
      allowAutomaticRetry: !nonRecoverableCodes.contains(code),
    );
  }

  void _retryPlaybackManually() {
    _automaticReconnects = 0;
    _loadStream(reconnect: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final returningFromBackground = !_appInForeground;
      _appInForeground = true;
      // The Android TV PlatformView stops and clears Media3 on Activity pause.
      // Reopen its single native decoder only when returning from the
      // background and only for a still-authorized, previously opened stream.
      // Never restart a revoked or failed stream (manual retry remains possible).
      if (returningFromBackground && _useTvMedia3 &&
          !_playerDisposalStarted && !_playbackRevoked &&
          _tvMedia3Url.isNotEmpty && !_streamFailed &&
          _isCurrentStreamAuthorized()) {
        unawaited(_loadStream(reconnect: true));
      }
      // Background playback can pause position updates; reset stall clock.
      _lastPlaybackProgressAt = DateTime.now();
      _lastObservedPlaybackPosition = _position;
      // Time spent suspended must not count toward a buffering timeout.
      if (_buffering) _bufferingStartedAt = DateTime.now();
      _progressService.flushPending();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _appInForeground = false;
      _tvMedia3AwaitingFirstStateAt = null;
      _tvMedia3IdleSince = null;
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    if (widget.isLive || !mounted || _saveInFlight ||
        _playbackRevoked || !_isCurrentStreamAuthorized()) return;
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
    if (_showDrawer && widget.isLive && DeviceLayout.isTelevision &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        !_tvDrawerShowCategories) {
      _expandTvDrawerCategories();
      return KeyEventResult.handled;
    }
    if (_showDrawer || _showHistory) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // TV remote: LEFT opens channels; RIGHT opens the three history tabs.
    // No seek operation is available for live television.
    if (widget.isLive && DeviceLayout.isTelevision &&
        key == LogicalKeyboardKey.arrowLeft &&
        _playerSurfaceFocus.hasPrimaryFocus) {
      _openNavigationDrawer();
      return KeyEventResult.handled;
    }
    if (widget.isLive && DeviceLayout.isTelevision &&
        key == LogicalKeyboardKey.arrowRight &&
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
      // OK on the video surface opens the controls for all media types.
      // Playback itself is changed only by the explicit play/pause control.
      // In Live TV, a second OK on the surface may hide the overlay.
      if (widget.isLive) {
        _toggleLiveControls();
      } else {
        if (!_showControls) setState(() => _showControls = true);
        _focusFirstPlayerAction();
        _startHideTimer();
      }
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) &&
        _playerSurfaceFocus.hasPrimaryFocus && !_showDrawer && !_showHistory) {
      if (!_showControls) setState(() => _showControls = true);
      _focusFirstPlayerAction();
      _startHideTimer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusFirstPlayerAction() {
    // A queued controls-focus callback must not steal focus after the user
    // opens/closes the TV channel drawer during the same frame.
    final navigationEpoch = _navigationScrollEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showControls || _showDrawer || _showHistory ||
          navigationEpoch != _navigationScrollEpoch) return;
      if (widget.isLive) {
        _recordButtonFocus.requestFocus();
      } else {
        _subtitleButtonFocus.requestFocus();
      }
    });
  }

  void _toggleLiveControls() {
    if (!mounted || _showDrawer || _showHistory) return;
    _hideTimer?.cancel();
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _prepareEpg();
      _focusFirstPlayerAction();
    } else {
      _restorePlayerFocus();
    }
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

  Future<void> _disposePlayerAfterOpens(Future<void> pendingOpens) async {
    // Never dispose the native player concurrently with an outstanding open.
    // A timeout would resume disposal while that open still owns the player.
    // If the backend never completes, retain the player rather than race it;
    // the native backend needs a separate cancellable-open mechanism to
    // guarantee bounded cleanup in that failure case.
    try {
      await pendingOpens;
    } catch (_) {
      // An unsuccessful open still releases the queue; cleanup may proceed.
    }
    try {
      await _player.dispose();
    } catch (_) {
      // A failed native backend must not crash navigation.
    }
  }

  @override
  void dispose() {
    _epgRepository.dispose();
    _familySession.removeListener(_onFamilySessionChanged);
    DownloadService.entries.removeListener(_onFamilySessionChanged);
    _contentProvider.removeListener(_onFamilySessionChanged);
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _queueSyncTimer?.cancel();
    _reconnectTimer?.cancel();
    _stallMonitor?.cancel();
    _streamLoadGeneration++;
    _playerDisposalStarted = true;
    final pendingOpens = _openQueue;
    unawaited(_disposePlayerAfterOpens(pendingOpens));
    _channelListScroll.dispose();
    _categoryListScroll.dispose();
    _drawerCloseFocus.dispose();
    for (final node in _tvDrawerChannelNodes.values) { node.dispose(); }
    _tvDrawerChannelNodes.clear();
    _categoryAllFocus.dispose();
    _historyCloseFocus.dispose();
    _episodeListScroll.dispose();
    _playerSurfaceFocus.dispose();
    _subtitleButtonFocus.dispose();
    _audioButtonFocus.dispose();
    _recordButtonFocus.dispose();
    _navigationButtonFocus.dispose();
    _tvEpgFocus.dispose();
    _historyButtonFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress();
    _posSub?.cancel(); _durSub?.cancel(); _playSub?.cancel(); _errorSub?.cancel(); _bufferingSub?.cancel();
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
        if (_showControls) {
          _hideTimer?.cancel();
          // Invalidate focus callbacks queued by the controls/EPG before
          // returning to the video surface. Back must never reopen an overlay
          // or focus a control that has just been removed from the tree.
          ++_navigationScrollEpoch;
          ++_focusedRowRequest;
          setState(() => _showControls = false);
          _restorePlayerFocus();
          return;
        }
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
              if (!_showControls) setState(() => _showControls = true);
              _startHideTimer();
            }
          },
          child: Stack(
            children: [
              if (_useTvMedia3)
                Positioned.fill(
                  child: TvMedia3View(
                    url: _tvMedia3Url,
                    reloadToken: _tvMedia3Epoch,
                    onState: _onTvMedia3State,
                    onError: _onTvMedia3Error,
                  ),
                )
              else Center(child: Video(
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
                             (_activeChannel?.category ?? '').trim().isNotEmpty)
                           Text(_activeChannel!.category!.trim(),
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                             style: const TextStyle(color: Colors.white70, fontSize: 13)),
                       ],
                     ),
                   ),
                   const ProfileClock(onVideo: true),
                   if (widget.isLive)
                     Focus(
                       onKeyEvent: (node, event) {
                         if (DeviceLayout.isTelevision &&
                             event is KeyDownEvent &&
                             (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                              event.logicalKey == LogicalKeyboardKey.arrowUp) &&
                             _tvEpgFocus.canRequestFocus) {
                           _tvEpgFocus.requestFocus();
                           return KeyEventResult.handled;
                         }
                         return KeyEventResult.ignored;
                       },
                       child: ValueListenableBuilder<RecordingStatus>(
                       valueListenable: RecordingService.status,
                       builder: (context, recording, _) {
                         final busy = recording.isBusy;
                         final stopping = recording.phase == RecordingPhase.stopping;
                         final starting = recording.phase == RecordingPhase.starting;
                         final writing = recording.writing;
                         final language = Localizations.localeOf(context).languageCode;
                         const labels = <String, List<String>>{
                           'de': ['Aufnehmen', 'Aufnahme stoppen', 'Aufnahme startet …', 'Aufnahme wird beendet …'],
                           'tr': ['Kayıt başlat', 'Kaydı durdur', 'Kayıt başlatılıyor …', 'Kayıt durduruluyor …'],
                           'en': ['Record', 'Stop recording', 'Starting recording …', 'Stopping recording …'],
                           'ru': ['Записать', 'Остановить запись', 'Запись начинается …', 'Запись останавливается …'],
                           'pl': ['Nagrywaj', 'Zatrzymaj nagrywanie', 'Rozpoczynanie nagrywania …', 'Zatrzymywanie nagrywania …'],
                           'es': ['Grabar', 'Detener grabación', 'Iniciando grabación …', 'Deteniendo grabación …'],
                           'fr': ['Enregistrer', 'Arrêter l’enregistrement', 'Démarrage de l’enregistrement …', 'Arrêt de l’enregistrement …'],
                           'ar': ['تسجيل', 'إيقاف التسجيل', 'بدء التسجيل …', 'إيقاف التسجيل …'],
                         };
                         final words = labels[language] ?? labels['en']!;
                         final label = words[stopping ? 3 : starting ? 2 : writing ? 1 : 0];
                         return Tooltip(
                           message: recording.error ?? label,
                           child: InkWell(
                             focusColor: AppTheme.electricBlue.withOpacity(0.38),
                             borderRadius: BorderRadius.circular(12),
                             focusNode: _recordButtonFocus,
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
                     )),
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
                    onTap: () => _switchEpisode(_currentEpisode - 1),
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
                    onTap: () => _switchEpisode(_currentEpisode + 1),
                    child: const Icon(Icons.skip_next, color: Colors.white, size: 40),
                  ),
              ],
            ),
            // On TV the EPG focus target must exist even while XMLTV is
            // loading, unavailable or failed. Otherwise Up from the player
            // controls can request focus on an unattached FocusNode.
            if (widget.isLive && (DeviceLayout.isTelevision || _epgFuture != null))
              Flexible(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FutureBuilder<List<EpgProgramme>>(
                  future: _epgFuture,
                  builder: (context, snapshot) {
                    final programmes = snapshot.data ?? const <EpgProgramme>[];
                    if (DeviceLayout.isTelevision) {
                      return TvEpgTimeline(
                        programmes: programmes,
                        focusNode: _tvEpgFocus,
                        onExitDown: () {
                          if (mounted && _showControls && !_showDrawer) {
                            _recordButtonFocus.requestFocus();
                          }
                        },
                      );
                    }
                    if (snapshot.hasError) {
                      return const Text('EPG konnte nicht geladen werden',
                          style: TextStyle(color: Colors.white70));
                    }
                    if (!snapshot.hasData) {
                      return const Text('EPG wird geladen …',
                          style: TextStyle(color: Colors.white70));
                    }
                    return ChannelEpgPanel(programmes: programmes);
                  },
                ),
              )),
            if (!widget.isLive) _buildProgressBar(),
            // Live TV uses a minimal channel-navigation overlay. Subtitle,
            // audio-track, aspect-ratio and seek actions are VOD-only.
            if (!widget.isLive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _controlButton(Icons.replay_10, AppLocalizations.of(context).t('player_seek_back'), () => _seekBy(-10)),
                    _controlButton(Icons.forward_10, AppLocalizations.of(context).t('player_seek_forward'), () => _seekBy(10)),
                    _controlButton(Icons.closed_caption, AppLocalizations.of(context).t('player_subtitles'), _showSubtitleTracks, focusNode: _subtitleButtonFocus),
                    _controlButton(Icons.audiotrack, AppLocalizations.of(context).t('player_audio'), _showAudioTracks, focusNode: _audioButtonFocus),
                    _controlButton(Icons.aspect_ratio, "${AppLocalizations.of(context).t('player_video_fit')}: ${_videoFitLabel(_videoFitIndex)}", _cycleVideoFit),
                  ],
                ),
              ),
            if (!widget.isLive || !DeviceLayout.isTelevision)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.episodes != null || widget.isLive)
                    Focus(
                      onKeyEvent: (node, event) {
                        if (DeviceLayout.isTelevision && widget.isLive &&
                            event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.arrowUp &&
                            _tvEpgFocus.canRequestFocus) {
                          _tvEpgFocus.requestFocus();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: InkWell(
                        focusColor: AppTheme.electricBlue.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(12),
                        focusNode: _navigationButtonFocus,
                        onTap: _openNavigationDrawer,
                        child: _pill(widget.isLive ? AppLocalizations.of(context).t('player_channels_folders') : AppLocalizations.of(context).t('player_episodes'), Icons.list),
                      ),
                    ),
                  if (widget.isLive) ...[
                    IconButton(focusColor: AppTheme.electricBlue.withOpacity(0.38), onPressed: _zapPrevious, tooltip: AppLocalizations.of(context).t('player_previous_channel'), icon: const Icon(Icons.skip_previous, color: Colors.white)),
                    IconButton(focusColor: AppTheme.electricBlue.withOpacity(0.38), onPressed: _zapNext, tooltip: AppLocalizations.of(context).t('player_next_channel'), icon: const Icon(Icons.skip_next, color: Colors.white)),
                  ],
                  const SizedBox(width: 12),
                  InkWell(
                    focusColor: AppTheme.electricBlue.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(12),
                    focusNode: _historyButtonFocus,
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

  // TV-only diagnostic view: no ADB, external device or background polling.
  // The recorder deliberately excludes stream URLs and account credentials.
  Future<void> _showTvPlaybackDiagnostics() async {
    if (!mounted || !DeviceLayout.isTelevision || !widget.isLive) return;
    final report = _tvDiagnostics.report;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14232C),
        title: const Text('TV-Wiedergabediagnose',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 620,
          height: 340,
          child: SingleChildScrollView(
            child: SelectableText(report,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 13,
                )),
          ),
        ),
        actions: [
          TextButton.icon(
            autofocus: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            icon: const Icon(Icons.copy),
            label: const Text('Kopieren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Schließen'),
          ),
        ],
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
      child: Material(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          focusNode: focusNode,
          focusColor: AppTheme.electricBlue.withOpacity(0.38),
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Icon(icon, color: Colors.white, size: 20),
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

  Widget _navigationBackdrop({required Widget child}) {
    // Blurring a continuously changing video texture is expensive on TV GPUs.
    if (DeviceLayout.isTelevision) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: child,
    );
  }

  Widget _buildHistorySidebar() {
    final library = context.watch<ContentProvider>();
    // Build only the visible tab. Even a per-type index is expensive when
    // thousands of channels and VOD items exist; hidden tabs need no work.
    final selectedType = <RecentPlaybackType>[
      RecentPlaybackType.live,
      RecentPlaybackType.vod,
      RecentPlaybackType.series,
    ][_selectedHistoryTab];
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
    final entries = _historyEntries(selectedType, library)
        .where(_canOpenRecent).take(10).toList(growable: false);
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
        child: _navigationBackdrop(
          child: Container(
            width: MediaQuery.sizeOf(context).width.clamp(0.0, 380.0).toDouble(),
            decoration: BoxDecoration(
              color: DeviceLayout.isTelevision
                ? const Color(0xFF101724) : const Color(0xE6101724),
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
      await _updateHistory(_historyService.clear(type.name));
    }
  }

  Widget _historyImage(String? url, IconData fallback) {
    if (url == null || url.isEmpty) return CircleAvatar(backgroundColor: Colors.white12, child: Icon(fallback, color: Colors.white70));
    return ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(url, width: 44, height: 52, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => CircleAvatar(backgroundColor: Colors.white12, child: Icon(fallback, color: Colors.white70))));
  }

  Future<void> _openRecentEntry(RecentPlaybackEntry entry) async {
    if (!_canOpenRecent(entry)) return;
    setState(() => _showHistory = false);
    if (entry.channel != null) {
      if (widget.isLive) {
        _switchLiveChannel(entry.channel!);
      } else {
        await Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(channel: entry.channel, isLive: true)));
      }
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
    if (_activeChannel == null) return;
    final allowed = _allowedLiveChannels();
    if (allowed.isEmpty) return;
    // Providers may reuse numeric stream IDs across folders or sources.
    // Locate the exact currently authorized stream before D-pad zapping;
    // matching the ID alone could jump from a revoked/stale channel.
    final playing = _activeChannel!;
    final current = allowed.indexWhere((c) =>
        c.id == playing.id &&
        c.streamUrl == playing.streamUrl &&
        c.categoryKey == playing.categoryKey &&
        c.sourceKey == playing.sourceKey);
    if (current < 0 || !_isCurrentStreamAuthorized()) return;
    final next = (current + offset + allowed.length) % allowed.length;
    final channel = allowed[next];
    _switchLiveChannel(channel);
  }

  void _restorePlayerFocus() {
    // Ignore a focus restoration queued before a newer drawer transition.
    // Otherwise Back -> OK within one frame can move focus behind the EPG.
    final navigationEpoch = _navigationScrollEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showDrawer || _showHistory ||
          navigationEpoch != _navigationScrollEpoch) return;
      if (_showControls) {
        _focusFirstPlayerAction();
      } else {
        _playerSurfaceFocus.requestFocus();
      }
    });
  }

  void _toggleHistorySidebar() {
    if (_showHistory) {
      _closeHistorySidebar();
      return;
    }
    _updateHistory(_historyService.refresh());
    _hideTimer?.cancel();
    // Invalidate focus callbacks from a previously opened channel drawer.
    ++_navigationScrollEpoch;
    ++_focusedRowRequest;
    final focusEpoch = _navigationScrollEpoch;
    setState(() {
      _showDrawer = false;
      _selectedHistoryTab = widget.isLive ? 0 : (widget.episodes != null ? 2 : 1);
      _showHistory = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showHistory &&
          focusEpoch == _navigationScrollEpoch) {
        _historyCloseFocus.requestFocus();
      }
    });
  }

  void _closeHistorySidebar() {
    // A queued sidebar-open callback must not steal focus after Back/close.
    ++_navigationScrollEpoch;
    ++_focusedRowRequest;
    setState(() => _showHistory = false);
    _restorePlayerFocus();
  }

  void _expandTvDrawerCategories() {
    if (!_showDrawer || !widget.isLive || !DeviceLayout.isTelevision ||
        _tvDrawerShowCategories) return;
    ++_navigationScrollEpoch;
    ++_focusedRowRequest;
    setState(() => _tvDrawerShowCategories = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showDrawer && _tvDrawerShowCategories) {
        _categoryAllFocus.requestFocus();
      }
    });
  }

  void _closeNavigationDrawer() {
    _tvDrawerPendingIndex = null;
    _tvDrawerPendingChannelId = null;
    _tvDrawerFocusRequest++;
    _navigationScrollEpoch++;
    _focusedRowRequest++;
    setState(() {
      _showDrawer = false;
      _tvDrawerShowCategories = false;
    });
    _restorePlayerFocus();
  }

  void _openNavigationDrawer() {
    if (_showDrawer) return;
    _tvDrawerPendingIndex = null;
    _tvDrawerPendingChannelId = null;
    _tvDrawerFocusRequest++;
    _navigationScrollEpoch++;
    _focusedRowRequest++;
    // On Android TV the channel drawer owns the remote until it closes.
    // Remove the controls/EPG from the widget tree rather than merely
    // excluding their focus: otherwise the 12-hour timeline remains visible
    // beneath the channel drawer and can intercept focus on rebuild.
    _hideTimer?.cancel();
    setState(() {
      _showDrawer = true;
      _tvDrawerShowCategories = false;
      _selectedLiveCategory = null;
      _showHistory = false;
      if (DeviceLayout.isTelevision && widget.isLive) _showControls = false;
    });
    _scrollToCurrentNavigationItem();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showDrawer && widget.isLive && !DeviceLayout.isTelevision) {
        _categoryAllFocus.requestFocus();
      }
    });
  }

  void _zapPrevious() => _zapBy(-1);
  void _zapNext() => _zapBy(1);

  // Android TV has a single channel-only drawer. Never carry the mobile
  // category filter into that drawer: the category column is not available
  // there, so doing so can silently hide channels with no way to recover.
  List<Channel> _visibleLiveChannels(List<Channel> channels) => channels
      .where((c) => matchesFavorite(c.id) &&
          ((DeviceLayout.isTelevision && !_tvDrawerShowCategories) || favoritesOnly ||
              _selectedLiveCategory == null ||
              (c.category ?? '') == _selectedLiveCategory))
      .toList(growable: false);

  Widget _buildLiveNavigationDrawer() {
    context.watch<FamilySessionProvider>();
    context.watch<ContentProvider>();
    final channels = _allowedLiveChannels();
    final categories = channels.map((c) => c.category ?? '')
        .where((c) => c.isNotEmpty).toSet().toList()..sort();
    final visible = _visibleLiveChannels(channels);
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(22)),
        child: _navigationBackdrop(
          child: Container(
            width: DeviceLayout.isTelevision
                ? MediaQuery.sizeOf(context).width * (_tvDrawerShowCategories ? 0.72 : 0.40)
                : MediaQuery.sizeOf(context).width.clamp(0.0, 360.0).toDouble(),
            decoration: BoxDecoration(color: DeviceLayout.isTelevision
                ? const Color(0xFF101724) : const Color(0xE6101724),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.16)))),
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 18, 12, 10), child: Row(children: [
                Expanded(child: Text(DeviceLayout.isTelevision
                    ? 'Live TV'
                    : AppLocalizations.of(context).t('player_channels_folders'),
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
                favoritesButton(),
                IconButton(focusNode: _drawerCloseFocus, tooltip: AppLocalizations.of(context).t('player_close'), focusColor: AppTheme.electricBlue.withOpacity(0.38), onPressed: _closeNavigationDrawer, icon: const Icon(Icons.close, color: Colors.white70)),
              ])),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: FocusTraversalGroup(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!favoritesOnly && (!DeviceLayout.isTelevision || _tvDrawerShowCategories)) SizedBox(
                        width: DeviceLayout.isTelevision
                            ? MediaQuery.sizeOf(context).width * 0.22
                            : (MediaQuery.sizeOf(context).width >= 900 ? 230 : 180),
                        child: ListView(
                          controller: _categoryListScroll,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          children: [
                            _categoryTile(AppLocalizations.of(context).t('player_all'), null, autofocus: !DeviceLayout.isTelevision),
                            ...categories.map((category) => _categoryTile(category, category)),
                          ],
                        ),
                      ),
                      if (!favoritesOnly && (!DeviceLayout.isTelevision || _tvDrawerShowCategories))
                        const VerticalDivider(color: Colors.white24, width: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: _channelListScroll,
                          itemExtent: _navigationRowExtent,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final channel = visible[index];
                            final selected = channel.id == _activeChannel?.id;
                            return Builder(builder: (rowContext) => Focus(
                              onKeyEvent: (node, event) =>
                                  _handleTvDrawerChannelKey(event, visible, index),
                              onFocusChange: (focused) =>
                                  _keepFocusedNavigationRowVisible(rowContext, focused),
                              child: ListTile(
                              // Category navigation owns initial focus; channel rows
                              // gain focus only when the user moves into the list.
                              autofocus: false,
                              focusNode: DeviceLayout.isTelevision
                                  ? _tvDrawerNode(channel) : null,
                              dense: true,
                              selected: selected,
                              selectedTileColor: AppTheme.electricBlue.withOpacity(0.22),
                              leading: channel.logoUrl == null || channel.logoUrl!.isEmpty
                                ? const Icon(Icons.live_tv, color: Colors.white70, size: 20)
                                : SizedBox(width: 34, height: 30, child: Image.network(channel.logoUrl!, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.white70))),
                              title: Text(channel.name, maxLines: DeviceLayout.isTelevision ? 3 : 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                              onTap: () => _activateTvDrawerChannel(visible, index),
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
    final selected = !favoritesOnly && _selectedLiveCategory == category;
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
          title: Text(label, softWrap: true, maxLines: null,
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
        child: _navigationBackdrop(
          child: Container(
            width: MediaQuery.sizeOf(context).width.clamp(0.0, 360.0).toDouble(),
            decoration: BoxDecoration(color: DeviceLayout.isTelevision
                ? const Color(0xFF101724) : const Color(0xE6101724),
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
              onTap: () => _switchEpisode(i, closeDrawer: true),
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
    final profile = _familySession.activeProfile;
    if (profile == null || !_familySession.isReady) return;
    final owner = RecordingService.ownerKey(profile.accountUserId, profile.id);
    final state = await RecordingService.refreshStatus();
    if (!mounted || _familySession.activeProfile?.id != profile.id ||
        !_familySession.isReady) return;

    if (state.isBusy) {
      if (state.ownerKey != owner) return;
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
        if (_familySession.activeProfile?.id != profile.id ||
            !_familySession.isReady || finished.ownerKey != owner) return;
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
    if (_activeChannel == null || !_canPlayChannel(_activeChannel!)) return;
    final accepted = await RecordingService.start(
      _activeChannel?.name ?? _currentTitle,
      streamUrl: url,
      ownerKey: owner,
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
