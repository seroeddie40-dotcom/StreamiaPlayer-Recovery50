
import 'package:flutter/material.dart';
import '../core/storage/prefs_service.dart';
import '../core/theme/app_theme.dart';

class LegalDisclaimerScreen extends StatefulWidget {
  final PrefsService? prefs;
  final bool requireAcceptance;
  final String? languageCode;

  const LegalDisclaimerScreen({
    super.key,
    this.prefs,
    this.requireAcceptance = false,
    this.languageCode,
  });

  @override
  State<LegalDisclaimerScreen> createState() =>
      _LegalDisclaimerScreenState();
}

class _LegalDisclaimerScreenState
    extends State<LegalDisclaimerScreen> {
  bool _confirmed = false;
  bool _saving = false;

  String get _language =>
      widget.languageCode ??
      Localizations.localeOf(context).languageCode;

  List<String> get _copy {
    const data = {
      'de': [
        'Rechtlicher Hinweis',
        'Streamia Player ist ausschließlich eine Media-Player-Software. Wir stellen keine Playlists, Sender, TV-Kanäle, Live-Streams, Filme, Serien, Videos, Zugangsdaten oder Abonnements bereit, verkaufen, hosten oder vermitteln diese auch nicht.',
        'Du fügst externe Quellen und Inhalte eigenständig hinzu. Du bist dafür verantwortlich, dass du die erforderlichen Rechte und Genehmigungen besitzt und die Gesetze deines Landes sowie die Nutzungsbedingungen der jeweiligen Anbieter einhältst.',
        'Streamia Player ist nicht mit IPTV-Anbietern, Sendern, Rechteinhabern oder Streaming-Plattformen verbunden, sofern dies nicht ausdrücklich angegeben wird. Die App garantiert weder Verfügbarkeit noch Qualität oder Rechtmäßigkeit externer Inhalte.',
        'Bei Fragen zu einer Playlist oder einem Stream wende dich an den jeweiligen Anbieter. Streamia Player kann keine Zugangsdaten bereitstellen oder Beschränkungen fremder Dienste umgehen.',
        'Ich bestätige, dass ich diesen Hinweis gelesen habe und nur Quellen und Inhalte nutze, zu deren Nutzung ich berechtigt bin.',
        'Ich habe den rechtlichen Hinweis gelesen und stimme zu',
        'Bestätigen und fortfahren',
      ],
      'en': [
        'Legal notice',
        'Streamia Player is media-player software only. We do not provide, sell, host, or broker playlists, channels, TV stations, live streams, films, series, videos, credentials, or subscriptions.',
        'You add external sources and content yourself. You are responsible for ensuring that you hold all necessary rights and permissions and comply with the laws in your country and the terms of the relevant providers.',
        'Unless expressly stated, Streamia Player is not affiliated with IPTV providers, broadcasters, rights holders, or streaming platforms. The app does not guarantee the availability, quality, or legality of external content.',
        'For playlist or stream issues, contact the relevant provider. Streamia Player cannot supply credentials or bypass restrictions imposed by third-party services.',
        'I confirm that I have read this notice and will only use sources and content that I am authorized to access.',
        'I have read and agree to the legal notice',
        'Confirm and continue',
      ],
      'tr': [
        'Yasal bilgilendirme',
        'Streamia Player yalnızca bir medya oynatıcı yazılımıdır. Herhangi bir oynatma listesi, kanal, TV yayını, canlı yayın, film, dizi, video, erişim bilgisi veya abonelik sağlamaz, satmaz, barındırmaz ya da aracılık etmez.',
        'Harici kaynakları ve içerikleri kendiniz eklersiniz. Gerekli hak ve izinlere sahip olduğunuzdan, ülkenizdeki yasalara ve ilgili sağlayıcıların kullanım koşullarına uyduğunuzdan siz sorumlusunuz.',
        'Açıkça belirtilmedikçe Streamia Player; IPTV sağlayıcıları, yayıncılar, hak sahipleri veya yayın platformlarıyla bağlantılı değildir. Uygulama harici içeriklerin kullanılabilirliğini, kalitesini veya yasallığını garanti etmez.',
        'Oynatma listesi veya yayın sorunları için ilgili sağlayıcıyla iletişime geçin. Streamia Player erişim bilgisi sağlayamaz veya üçüncü taraf hizmetlerinin kısıtlamalarını aşamaz.',
        'Bu bilgilendirmeyi okuduğumu ve yalnızca kullanmaya yetkili olduğum kaynakları ve içerikleri kullanacağımı onaylıyorum.',
        'Yasal bilgilendirmeyi okudum ve kabul ediyorum',
        'Onayla ve devam et',
      ],
      'ru': [
        'Юридическая информация',
        'Streamia Player — только программное обеспечение для воспроизведения медиа. Мы не предоставляем, не продаём, не размещаем и не распространяем плейлисты, каналы, телеканалы, прямые трансляции, фильмы, сериалы, видео, учётные данные или подписки.',
        'Вы самостоятельно добавляете внешние источники и материалы. Вы несёте ответственность за наличие необходимых прав и разрешений, соблюдение законов вашей страны и условий соответствующих поставщиков.',
        'Если прямо не указано иное, Streamia Player не связан с IPTV-провайдерами, вещателями, правообладателями или стриминговыми платформами. Приложение не гарантирует доступность, качество или законность внешнего контента.',
        'По вопросам плейлистов и трансляций обращайтесь к соответствующему поставщику. Streamia Player не предоставляет учётные данные и не обходит ограничения сторонних сервисов.',
        'Подтверждаю, что прочитал(а) это уведомление и буду использовать только те источники и материалы, к которым имею законный доступ.',
        'Я прочитал(а) и принимаю уведомление',
        'Подтвердить и продолжить',
      ],
      'pl': [
        'Informacja prawna',
        'Streamia Player jest wyłącznie oprogramowaniem do odtwarzania multimediów. Nie udostępniamy, nie sprzedajemy, nie hostujemy ani nie pośredniczymy w dostępie do playlist, kanałów, transmisji na żywo, filmów, seriali, danych logowania ani subskrypcji.',
        'Użytkownik samodzielnie dodaje zewnętrzne źródła i treści. Odpowiada za posiadanie niezbędnych praw i zgód oraz przestrzeganie lokalnego prawa i warunków dostawców.',
        'O ile wyraźnie nie wskazano inaczej, Streamia Player nie jest powiązany z dostawcami IPTV, nadawcami, właścicielami praw ani platformami streamingowymi. Aplikacja nie gwarantuje dostępności, jakości ani legalności treści zewnętrznych.',
        'W sprawach playlist lub transmisji skontaktuj się z odpowiednim dostawcą. Streamia Player nie udostępnia danych dostępowych ani nie omija ograniczeń usług zewnętrznych.',
        'Potwierdzam, że przeczytałem(-am) tę informację i będę korzystać wyłącznie ze źródeł i treści, do których mam uprawnienia.',
        'Przeczytałem(-am) i akceptuję informację prawną',
        'Potwierdź i kontynuuj',
      ],
      'es': [
        'Aviso legal',
        'Streamia Player es únicamente un software reproductor multimedia. No proporcionamos, vendemos, alojamos ni intermediamos en listas de reproducción, canales, emisiones, retransmisiones en directo, películas, series, vídeos, credenciales ni suscripciones.',
        'Usted añade las fuentes y el contenido externos por su cuenta. Es responsable de disponer de los derechos y permisos necesarios y de cumplir las leyes de su país y las condiciones de los proveedores correspondientes.',
        'Salvo que se indique expresamente, Streamia Player no está afiliado a proveedores IPTV, emisoras, titulares de derechos ni plataformas de streaming. La aplicación no garantiza la disponibilidad, calidad ni legalidad del contenido externo.',
        'Para problemas con listas o emisiones, contacte con el proveedor correspondiente. Streamia Player no facilita credenciales ni elude restricciones de servicios de terceros.',
        'Confirmo que he leído este aviso y que solo utilizaré fuentes y contenidos a los que esté autorizado a acceder.',
        'He leído y acepto el aviso legal',
        'Confirmar y continuar',
      ],
      'fr': [
        'Avis juridique',
        'Streamia Player est uniquement un logiciel de lecture multimédia. Nous ne fournissons, ne vendons, n’hébergeons et ne distribuons aucune playlist, chaîne, diffusion TV, flux en direct, film, série, vidéo, identifiant ou abonnement.',
        'Vous ajoutez vous-même les sources et contenus externes. Il vous appartient de disposer des droits et autorisations nécessaires et de respecter les lois de votre pays ainsi que les conditions des fournisseurs concernés.',
        'Sauf indication expresse, Streamia Player n’est affilié ni aux fournisseurs IPTV, ni aux diffuseurs, titulaires de droits ou plateformes de streaming. L’application ne garantit ni la disponibilité, ni la qualité, ni la légalité des contenus externes.',
        'Pour tout problème de playlist ou de flux, contactez le fournisseur concerné. Streamia Player ne fournit aucun identifiant et ne contourne pas les restrictions de services tiers.',
        'Je confirme avoir lu cet avis et n’utiliser que des sources et contenus auxquels je suis autorisé(e) à accéder.',
        'J’ai lu et j’accepte l’avis juridique',
        'Confirmer et continuer',
      ],
      'ar': [
        'إشعار قانوني',
        'Streamia Player هو برنامج لتشغيل الوسائط فقط. نحن لا نوفر أو نبيع أو نستضيف أو نوزع قوائم التشغيل أو القنوات أو البث التلفزيوني أو البث المباشر أو الأفلام أو المسلسلات أو مقاطع الفيديو أو بيانات الدخول أو الاشتراكات.',
        'يقوم المستخدم بإضافة المصادر والمحتويات الخارجية بنفسه. ويتحمل مسؤولية امتلاك الحقوق والأذونات اللازمة والالتزام بقوانين بلده وشروط مزودي الخدمة المعنيين.',
        'ما لم يُذكر خلاف ذلك صراحةً، فإن Streamia Player غير تابع لمزودي IPTV أو جهات البث أو أصحاب الحقوق أو منصات البث. ولا يضمن التطبيق توفر المحتوى الخارجي أو جودته أو قانونيته.',
        'للمشكلات المتعلقة بقائمة تشغيل أو بث، يرجى التواصل مع المزود المعني. لا يوفر Streamia Player بيانات الدخول ولا يتجاوز قيود خدمات الجهات الخارجية.',
        'أؤكد أنني قرأت هذا الإشعار ولن أستخدم إلا المصادر والمحتويات المصرح لي باستخدامها.',
        'قرأت الإشعار القانوني وأوافق عليه',
        'تأكيد ومتابعة',
      ],
    };

    return data[_language] ?? data['en']!;
  }

  Future<void> _accept() async {
    if (!_confirmed || _saving) return;

    setState(() => _saving = true);

    try {
      await widget.prefs?.setLegalDisclaimerAccepted(
        _language,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Die Zustimmung konnte nicht gespeichert werden: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _copy;

    return Scaffold(
      appBar: AppBar(
        title: Text(t[0]),
        automaticallyImplyLeading:
            !widget.requireAcceptance,
      ),
      body: SafeArea(
        child: FocusTraversalGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.gavel_rounded,
                size: 48,
                color: AppTheme.electricBlue,
              ),
              const SizedBox(height: 20),
              for (final paragraph in t.sublist(1, 6)) ...[
                Text(
                  paragraph,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.requireAcceptance) ...[
                const Divider(height: 28),
                CheckboxListTile(
                  value: _confirmed,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _confirmed = value ?? false;
                          });
                        },
                  autofocus: true,
                  activeColor: AppTheme.electricBlue,
                  controlAffinity:
                      ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t[6],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      !_confirmed || _saving ? null : _accept,
                  style: FilledButton.styleFrom(
                    overlayColor: Colors.white24,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(t[7]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
