import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/content_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/family_session_provider.dart';
import '../providers/locale_provider.dart';
import '../services/category_sort_service.dart';
import '../services/profile_preference_outbox.dart';
import 'dart:convert';

mixin CategorySortState<T extends StatefulWidget> on State<T> {
  String get sortArea;
  String? _sortKey;
  CategorySortOrder sortOrder = CategorySortOrder.ascending;
  int _revision = 0;
  int _seenSyncRevision = -1;
  Future<void> _writes = Future<void>.value();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.watch<FamilySessionProvider>().activeProfile;
    final family = context.watch<FamilySessionProvider>();
    final source = context.watch<ContentProvider>().sourceKey;
    final key = profile == null || !family.isReady ? null : 'category_sort_v2:${profile.accountUserId}:${profile.id}:$source:$sortArea';
    final syncRevision = family.profileSyncRevision;
    if (key == _sortKey) {
      if (key != null && profile != null && syncRevision != _seenSyncRevision) {
        _seenSyncRevision = syncRevision;
        _restoreSort(key, ++_revision, profile.id, family.parentAccessToken, source);
      }
      return;
    }
    _seenSyncRevision = syncRevision;
    _sortKey = key;
    sortOrder = CategorySortOrder.ascending;
    final revision = ++_revision;
    if (key != null && profile != null) _restoreSort(key, revision, profile.id, family.parentAccessToken, source);
  }

  Future<void> _restoreSort(String key, int revision, String profileId, String? token, String source) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var saved = prefs.getString(key);
      try {
        await _writes;
        final account = Supabase.instance.client.auth.currentUser?.id;
        if (account == null) return;
        final pending = await ProfilePreferenceOutbox.pending(account, profileId);
        final queued = pending[jsonEncode([source, sortArea, 'sort'])];
        if (queued is String) {
          if (mounted && revision == _revision && key == _sortKey) {
            final matches = CategorySortOrder.values.where((o) => o.name == queued);
            if (matches.isNotEmpty) setState(() => sortOrder = matches.first);
          }
          return;
        }
        final rows = await Supabase.instance.client.rpc('read_profile_preferences', params: {'p_profile_id': profileId, 'p_parent_token': token, 'p_source_key': source}).eq('content_type', sortArea).eq('preference_key', 'sort');
        if (!mounted || revision != _revision || key != _sortKey) return;
        if (rows.isNotEmpty) {
          final remote = rows.first['preference_value'];
          if (remote is String && CategorySortOrder.values.any((o) => o.name == remote)) {
            saved = remote;
            await prefs.setString(key, remote);
          }
        }
      } catch (_) { /* Offline: retain the local cache. */ }
      if (!mounted || revision != _revision || key != _sortKey) return;
      for (final order in CategorySortOrder.values) {
        if (order.name == saved) {
          setState(() => sortOrder = order);
          break;
        }
      }
    } catch (_) { /* Keep the default if storage is unavailable. */ }
  }

  Future<void> _changeSort(CategorySortOrder order) async {
    final key = _sortKey;
    if (key == null || !mounted) return;
    final family = context.read<FamilySessionProvider>();
    final profile = family.activeProfile;
    final source = context.read<ContentProvider>().sourceKey;
    final token = family.parentAccessToken;
    if (profile == null || !family.isReady) return;
    ++_revision;
    setState(() => sortOrder = order);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, order.name);
      _writes = _writes.then((_) async {
        if (Supabase.instance.client.auth.currentUser?.id != profile.accountUserId) return;
        await ProfilePreferenceOutbox.enqueue(profile.accountUserId, profile.id, source, sortArea, 'sort', order.name);
        await ProfilePreferenceOutbox.flush(Supabase.instance.client, profile.accountUserId, profile.id, token,
          () => mounted && _sortKey == key && family.activeProfile?.id == profile.id);
      });
      await _writes;
      if (mounted && key == _sortKey && family.activeProfile?.id == profile.id) {
        await _restoreSort(key, _revision, profile.id, token, source);
      }
    } catch (_) { /* The selection remains usable for this session. */ }
  }

  Widget sortMenu() {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    const labels = <String, List<String>>{
      'de': ['Sortieren', 'Original', 'A–Z', 'Z–A', 'Größte zuerst', 'Kleinste zuerst'],
      'tr': ['Sırala', 'Orijinal', 'A–Z', 'Z–A', 'En büyük önce', 'En küçük önce'],
      'en': ['Sort', 'Original', 'A–Z', 'Z–A', 'Largest first', 'Smallest first'],
      'ru': ['Сортировка', 'Исходный порядок', 'А–Я', 'Я–А', 'Сначала большие', 'Сначала малые'],
      'pl': ['Sortuj', 'Oryginalna', 'A–Z', 'Z–A', 'Największe najpierw', 'Najmniejsze najpierw'],
      'es': ['Ordenar', 'Original', 'A–Z', 'Z–A', 'Mayores primero', 'Menores primero'],
      'fr': ['Trier', 'Original', 'A–Z', 'Z–A', 'Plus grands d’abord', 'Plus petits d’abord'],
      'ar': ['ترتيب', 'الأصلي', 'تصاعدي', 'تنازلي', 'الأكبر أولاً', 'الأصغر أولاً'],
    };
    final text = labels[lang] ?? labels['en']!;
    return Theme(
      data: Theme.of(context).copyWith(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.30)),
      child: PopupMenuButton<CategorySortOrder>(
      enabled: _sortKey != null,
      tooltip: '${text[0]}: ${text[sortOrder.index + 1]}',
      initialValue: sortOrder,
      onSelected: _changeSort,
      icon: const Icon(Icons.sort),
      itemBuilder: (_) => [for (final order in CategorySortOrder.values)
        PopupMenuItem(value: order, child: Text(text[order.index + 1]))],
    ));
  }

  Widget sortHeader(String label, TextStyle? style) => Row(children: [
    Expanded(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
    sortMenu(),
  ]);
}
