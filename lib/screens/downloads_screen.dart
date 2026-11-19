import '../widgets/tv_catalog_focus.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../core/focus_navigation.dart';
import '../providers/family_session_provider.dart';
import '../models/family_profile.dart';
import '../services/download_service.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, this.managedChild});
  final FamilyProfile? managedChild;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = DownloadService.initialize();
  }

  String _t(String key) {
    final lang = Localizations.localeOf(context).languageCode;
    const words = <String, Map<String, String>>{
      'de': {'downloads':'Downloads','movies':'Filme','series':'Serien','empty':'Keine Downloads','cancel':'Abbrechen','delete':'Löschen','retry':'Erneut herunterladen','open':'Offline abspielen','loading':'Downloadliste wird geladen','error':'Downloadliste konnte nicht geladen werden','missing':'Datei fehlt','interrupted':'Unterbrochen','failed':'Fehlgeschlagen','cancelled':'Abgebrochen','queued':'Wartend','downloading':'Wird heruntergeladen','completed':'Heruntergeladen','season':'Staffel','episode':'Folge','deleteQuestion':'Download wirklich löschen?'},
      'tr': {'downloads':'İndirilenler','movies':'Filmler','series':'Diziler','empty':'İndirme yok','cancel':'İptal et','delete':'Sil','retry':'Yeniden indir','open':'Çevrimdışı oynat','loading':'İndirmeler yükleniyor','error':'İndirme listesi yüklenemedi','missing':'Dosya bulunamadı','interrupted':'Kesintiye uğradı','failed':'Başarısız','cancelled':'İptal edildi','queued':'Bekliyor','downloading':'İndiriliyor','completed':'İndirildi','season':'Sezon','episode':'Bölüm','deleteQuestion':'İndirme silinsin mi?'},
      'en': {'downloads':'Downloads','movies':'Movies','series':'Series','empty':'No downloads','cancel':'Cancel','delete':'Delete','retry':'Download again','open':'Play offline','loading':'Loading downloads','error':'Could not load downloads','missing':'File missing','interrupted':'Interrupted','failed':'Failed','cancelled':'Cancelled','queued':'Queued','downloading':'Downloading','completed':'Downloaded','season':'Season','episode':'Episode','deleteQuestion':'Delete this download?'},
      'ru': {'downloads':'Загрузки','movies':'Фильмы','series':'Сериалы','empty':'Нет загрузок','cancel':'Отмена','delete':'Удалить','retry':'Скачать снова','open':'Смотреть офлайн','loading':'Загрузка списка','error':'Не удалось загрузить список','missing':'Файл отсутствует','interrupted':'Прервано','failed':'Ошибка','cancelled':'Отменено','queued':'В очереди','downloading':'Загрузка','completed':'Загружено','season':'Сезон','episode':'Серия','deleteQuestion':'Удалить загрузку?'},
      'pl': {'downloads':'Pobrane','movies':'Filmy','series':'Seriale','empty':'Brak pobranych','cancel':'Anuluj','delete':'Usuń','retry':'Pobierz ponownie','open':'Odtwórz offline','loading':'Ładowanie pobranych','error':'Nie można wczytać listy','missing':'Brak pliku','interrupted':'Przerwano','failed':'Błąd','cancelled':'Anulowano','queued':'W kolejce','downloading':'Pobieranie','completed':'Pobrano','season':'Sezon','episode':'Odcinek','deleteQuestion':'Usunąć pobrany plik?'},
      'es': {'downloads':'Descargas','movies':'Películas','series':'Series','empty':'Sin descargas','cancel':'Cancelar','delete':'Eliminar','retry':'Descargar de nuevo','open':'Ver sin conexión','loading':'Cargando descargas','error':'No se pudo cargar la lista','missing':'Archivo no encontrado','interrupted':'Interrumpido','failed':'Error','cancelled':'Cancelado','queued':'En espera','downloading':'Descargando','completed':'Descargado','season':'Temporada','episode':'Episodio','deleteQuestion':'¿Eliminar esta descarga?'},
      'fr': {'downloads':'Téléchargements','movies':'Films','series':'Séries','empty':'Aucun téléchargement','cancel':'Annuler','delete':'Supprimer','retry':'Télécharger à nouveau','open':'Lire hors ligne','loading':'Chargement','error':'Impossible de charger les téléchargements','missing':'Fichier introuvable','interrupted':'Interrompu','failed':'Échec','cancelled':'Annulé','queued':'En attente','downloading':'Téléchargement','completed':'Téléchargé','season':'Saison','episode':'Épisode','deleteQuestion':'Supprimer ce téléchargement ?'},
      'ar': {'downloads':'التنزيلات','movies':'أفلام','series':'مسلسلات','empty':'لا توجد تنزيلات','cancel':'إلغاء','delete':'حذف','retry':'إعادة التنزيل','open':'تشغيل دون اتصال','loading':'جارٍ تحميل التنزيلات','error':'تعذر تحميل قائمة التنزيلات','missing':'الملف غير موجود','interrupted':'انقطع','failed':'فشل','cancelled':'أُلغي','queued':'قيد الانتظار','downloading':'جارٍ التنزيل','completed':'تم التنزيل','season':'الموسم','episode':'الحلقة','deleteQuestion':'هل تريد حذف التنزيل؟'},
    };
    return (words[lang] ?? words['en']!)[key] ?? key;
  }

  String _legacyNotice() {
    const notices = {
      'de': 'Ältere Downloads ohne Profilzuordnung bleiben gespeichert, werden jedoch nicht angezeigt.',
      'tr': 'Profil ataması olmayan eski indirmeler saklanır ancak gösterilmez.',
      'en': 'Older downloads without a profile assignment are retained but not displayed.',
      'fr': 'Les anciens téléchargements sans profil sont conservés mais non affichés.',
      'es': 'Las descargas antiguas sin perfil se conservan, pero no se muestran.',
      'pl': 'Starsze pobrania bez przypisanego profilu są zachowane, ale niewidoczne.',
      'ru': 'Старые загрузки без профиля сохранены, но не отображаются.',
      'ar': 'يتم الاحتفاظ بالتنزيلات القديمة غير المرتبطة بملف شخصي دون عرضها.',
    };
    return notices[Localizations.localeOf(context).languageCode] ?? notices['en']!;
  }

  bool _owns(DownloadEntry entry) {
    final family = context.read<FamilySessionProvider>();
    final active = family.activeProfile;
    final child = widget.managedChild;
    if (child != null && (family.parentAccessToken == null || active?.accountUserId != child.accountUserId || !child.isChild)) return false;
    final profile = child ?? active;
    return family.isReady && profile != null &&
        entry.belongsTo(profile.accountUserId, profile.id);
  }

  Future<void> _play(DownloadEntry entry) async {
    if (widget.managedChild != null || !_owns(entry) || !entry.hasSafeFilename || entry.state != DownloadState.completed) return;
    final root = await getApplicationDocumentsDirectory();
    final file = File('${root.path}/downloads/${entry.filename}');
    if (!mounted || !_owns(entry)) return;
    if (!await file.exists()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('missing'))));
      return;
    }
    if (!mounted || !_owns(entry)) return;
    pushWithFocusRestore(context, MaterialPageRoute<void>(builder: (_) =>
      PlayerScreen(streamUrl: file.uri.toString(), title: entry.title,
        isLive: false, offlineDownloadId: entry.id)));
  }

  Future<void> _confirmDelete(DownloadEntry entry) async {
    if (!_owns(entry)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('deleteQuestion')),
        content: Text(entry.title),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_owns(entry)) return;
    try {
      await DownloadService.remove(entry.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('failed'))),
        );
      }
    }
  }

  Widget _item(DownloadEntry entry) {
    final active = entry.state == DownloadState.downloading || entry.state == DownloadState.queued;
    final status = _t(entry.state.name);
    final subtitle = entry.kind == 'episode'
        ? '${_t('season')} ${entry.season ?? '-'} · ${_t('episode')} ${entry.episode ?? '-'} · $status'
        : status;
    return TvCatalogFocus(child: ListTile(
      leading: Icon(entry.kind == 'episode' ? Icons.tv : Icons.movie_outlined),
      title: Text(entry.title),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(subtitle),
        if (active) ...[
          LinearProgressIndicator(value: entry.progress.isFinite && entry.progress > 0
              ? entry.progress.clamp(0.0, 1.0).toDouble() : null),
          if (entry.progress.isFinite && entry.progress > 0)
            Text('${(entry.progress.clamp(0.0, 1.0) * 100).floor()}%'),
        ],
      ]),
      trailing: Wrap(spacing: 0, children: [
        if (widget.managedChild == null && entry.state == DownloadState.completed)
          IconButton(tooltip: _t('open'), icon: const Icon(Icons.play_arrow), onPressed: () => _play(entry)),
        if (active)
          IconButton(tooltip: _t('cancel'), icon: const Icon(Icons.cancel_outlined), onPressed: () {
            if (_owns(entry)) DownloadService.cancel(entry.id);
          }),
        IconButton(tooltip: _t('delete'), icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(entry)),
      ]),
    ));
  }

  Widget _content(List<DownloadEntry> items) {
    if (items.isEmpty) return Center(child: Text(_t('empty')));
    final movies = items.where((e) => e.kind != 'episode').toList();
    final episodes = items.where((e) => e.kind == 'episode').toList();
    final grouped = <String, List<DownloadEntry>>{};
    for (final episode in episodes) {
      grouped.putIfAbsent(episode.seriesTitle ?? episode.title, () => []).add(episode);
    }
    return ListView(children: [
      ExpansionTile(initiallyExpanded: true, leading: const Icon(Icons.movie), title: Text('${_t('movies')} (${movies.length})'),
        children: movies.map(_item).toList()),
      ExpansionTile(initiallyExpanded: true, leading: const Icon(Icons.video_library), title: Text('${_t('series')} (${episodes.length})'),
        children: grouped.entries.map((group) => ExpansionTile(
          leading: const Icon(Icons.folder_outlined), title: Text(group.key),
          children: group.value.map(_item).toList(),
        )).toList()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilySessionProvider>();
    if (!family.isReady || family.activeProfile == null || (widget.managedChild != null && (family.parentAccessToken == null || family.activeProfile?.accountUserId != widget.managedChild!.accountUserId || !widget.managedChild!.isChild))) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.managedChild == null ? _t('downloads') : '${_t('downloads')} · ${widget.managedChild!.displayName}')),
        body: Center(
          child: Text(_t('loading')),
        ),
      );
    }
    return Scaffold(
    appBar: AppBar(title: Text(widget.managedChild == null ? _t('downloads') : '${_t('downloads')} · ${widget.managedChild!.displayName}')),
    body: FutureBuilder<void>(future: _ready, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(_t('error')));
      if (snapshot.connectionState != ConnectionState.done) return Center(child: Text(_t('loading')));
      return ValueListenableBuilder<List<DownloadEntry>>(
        valueListenable: DownloadService.entries,
        builder: (context, items, _) => Column(children: [
          if (widget.managedChild == null && family.parentAccessToken != null &&
              items.any((entry) => entry.isUnassigned))
            Padding(padding: const EdgeInsets.all(12), child: Text(_legacyNotice())),
          Expanded(child: _content(items.where(_owns).toList())),
        ]),
      );
    }),
  );
  }
}
