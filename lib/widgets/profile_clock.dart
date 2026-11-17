import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/family_session_provider.dart';
import '../core/localization/app_localizations.dart';
import '../services/profile_preference_outbox.dart';

/// Profile-wide display preference, independent of playlist and sync clock.
class ProfileClock extends StatefulWidget {
  const ProfileClock({super.key, this.dashboard = false, this.settings = false, this.onVideo = false});
  final bool dashboard, settings, onVideo;
  @override
  State<ProfileClock> createState() => _ProfileClockState();
}

class _ProfileClockState extends State<ProfileClock> with WidgetsBindingObserver {
  static const source = '__streamia_display_v1__';
  static const name = 'clock_display';
  static final changes = ValueNotifier<int>(0);
  Timer? _timer;
  String? _key;
  int _revision = 0, _seen = -1;
  bool _twelve = false, _date = true, _visible = true;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    changes.addListener(_changed);
    if (!widget.settings) _tick();
  }
  void _tick() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _timer = Timer(Duration(milliseconds: 60000 - _now.second * 1000 - _now.millisecond), _tick);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.settings) return;
    if (state == AppLifecycleState.resumed) { _tick(); } else { _timer?.cancel(); }
  }
  @override
  void dispose() {
    _timer?.cancel();
    changes.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  void _changed() { if (mounted) _reload(); }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final family = context.watch<FamilySessionProvider>();
    final p = family.activeProfile;
    final key = p == null || !family.isReady ? null : 'streamia_clock_v1:${p.accountUserId}:${p.id}';
    if (key != _key) {
      _key = key;
      _twelve = false; _date = true; _visible = true;
      _seen = -1;
      ++_revision;
    }
    if (key != null && _seen != family.profileSyncRevision) {
      _seen = family.profileSyncRevision;
      _reload();
    }
  }
  Map<String, bool> get _value => {'twelve': _twelve, 'date': _date, 'visible': _visible};
  void _apply(dynamic value) {
    if (value is! Map) return;
    setState(() {
      _twelve = value['twelve'] == true;
      _date = value['date'] != false;
      _visible = value['visible'] != false;
    });
  }
  Future<void> _reload() async {
    final family = context.read<FamilySessionProvider>();
    final p = family.activeProfile, key = _key;
    if (p == null || key == null) return;
    final token = family.parentAccessToken;
    final revision = ++_revision;
    bool current() => mounted && _key == key && _revision == revision && family.activeProfile?.id == p.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      final cached = prefs.getString(key);
      if (cached != null) _apply(jsonDecode(cached));
      final pending = await ProfilePreferenceOutbox.pending(p.accountUserId, p.id);
      final queued = pending[jsonEncode([source, 'live', name])];
      if (!current()) return;
      if (queued != null) { _apply(queued); return; }
      final rows = await Supabase.instance.client.rpc('read_profile_preferences', params: {
        'p_profile_id': p.id, 'p_parent_token': token, 'p_source_key': source,
      }).eq('content_type', 'live').eq('preference_key', name);
      if (!current() || rows.isEmpty) return;
      final value = rows.first['preference_value'];
      final latest = await ProfilePreferenceOutbox.pending(p.accountUserId, p.id);
      if (!current() || latest.containsKey(jsonEncode([source, 'live', name]))) return;
      await prefs.setString(key, jsonEncode(value));
      if (current()) _apply(value);
    } catch (_) { /* Keep local display while offline. */ }
  }
  Future<void> _save({bool? twelve, bool? date, bool? visible}) async {
    final family = context.read<FamilySessionProvider>();
    final p = family.activeProfile, key = _key;
    if (p == null || key == null) return;
    ++_revision;
    setState(() { _twelve = twelve ?? _twelve; _date = date ?? _date; _visible = visible ?? _visible; });
    final value = _value;
    try {
      await ProfilePreferenceOutbox.enqueue(p.accountUserId, p.id, source, 'live', name, value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
      changes.value++;
      await ProfilePreferenceOutbox.flush(Supabase.instance.client, p.accountUserId, p.id, family.parentAccessToken,
        () => mounted && _key == key && family.activeProfile?.id == p.id);
      if (mounted && _key == key) await _reload();
    } catch (_) { /* Existing outbox retries queued changes. */ }
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.settings) {
      return Column(children: [
        SwitchListTile(title: Text(l10n.t('clock_show')), value: _visible, onChanged: _key == null ? null : (v) => _save(visible: v)),
        SwitchListTile(title: Text(l10n.t('clock_date')), value: _date, onChanged: _key == null ? null : (v) => _save(date: v)),
        ListTile(title: Text(l10n.t('clock_format')), trailing: DropdownButton<bool>(
          value: _twelve, onChanged: _key == null ? null : (v) { if (v != null) _save(twelve: v); },
          items: [DropdownMenuItem(value: false, child: Text(l10n.t('clock_24'))), DropdownMenuItem(value: true, child: Text(l10n.t('clock_12')))],
        )),
      ]);
    }
    if (!_visible || _key == null) return const SizedBox.shrink();
    final loc = MaterialLocalizations.of(context);
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final minute = loc.formatDecimal(_now.minute).padLeft(2, '0');
    final time = _twelve
        ? '${loc.formatDecimal(hour)}:$minute ${_now.hour < 12 ? loc.anteMeridiemAbbreviation : loc.postMeridiemAbbreviation}'
        : loc.formatTimeOfDay(TimeOfDay.fromDateTime(_now), alwaysUse24HourFormat: true);
    final color = widget.onVideo ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(
      mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
      children: [Text(time, style: TextStyle(color: color, fontSize: widget.dashboard ? 26 : 15, fontWeight: FontWeight.w700)),
        if (widget.dashboard && _date) Text(loc.formatFullDate(_now), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color.withOpacity(.7), fontSize: 12))],
    ));
  }
}
