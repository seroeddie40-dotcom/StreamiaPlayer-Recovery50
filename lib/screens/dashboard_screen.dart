import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'continue_watching_screen.dart';
import 'live_tv_screen.dart';
import 'master_search_screen.dart';
import 'paywall_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'vod_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _label(BuildContext context, String de, String tr, String en) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'tr') return tr;
    if (language == 'de') return de;
    return en;
  }

  void _open(Widget screen) {
    pushWithFocusRestore(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final compact = MediaQuery.sizeOf(context).width < 600;
    final showPurchase = auth.isLoggedIn &&
        auth.accessChecked &&
        !auth.hasAccess &&
        auth.requiresPayment &&
        !auth.deviceBlocked &&
        !auth.devicePending;

    final entries = <_HomeEntry>[
      _HomeEntry(Icons.live_tv_rounded, l10n.t('nav_live'),
          () => _open(const LiveTvScreen())),
      _HomeEntry(Icons.movie_creation_outlined, l10n.t('nav_vod'),
          () => _open(const VodScreen())),
      _HomeEntry(Icons.video_library_outlined, l10n.t('nav_series'),
          () => _open(const SeriesScreen())),
      _HomeEntry(Icons.play_circle_outline_rounded,
          l10n.t('nav_continue_watching'),
          () => _open(const ContinueWatchingScreen())),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 36, 12, compact ? 16 : 36, 8),
              child: Row(
                children: [
                  Container(
                    width: compact ? 42 : 52,
                    height: compact ? 42 : 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient,
                    ),
                    alignment: Alignment.center,
                    child: const Text('S', style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    )),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.t('app_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 17 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (showPurchase) ...[
                    _ProButton(
                      label: l10n.t('nav_pro'),
                      onTap: () => _open(const PaywallScreen()),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: _label(context, 'Suche', 'Ara', 'Search'),
                    onPressed: () => _open(const MasterSearchScreen()),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    tooltip: _label(context, 'Design wechseln',
                        'Temayı değiştir', 'Change theme'),
                    onPressed: () =>
                        context.read<ThemeProvider>().toggleTheme(),
                    icon: Icon(isDark ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                  ),
                  IconButton(
                    tooltip: _label(context, 'Einstellungen',
                        'Ayarlar', 'Settings'),
                    onPressed: () async {
                      await pushWithFocusRestore(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final horizontal = width < 600 ? 16.0 : 36.0;
                final columns = width >= 600 ? 4 : 2;
                return FocusTraversalGroup(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            horizontal, 18, horizontal, 12),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _label(context, 'Deine Mediathek',
                                    'Medya kütüphanen', 'Your library'),
                                style: TextStyle(
                                  fontSize: compact ? 23 : 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _label(context,
                                    'Live-TV, Filme und Serien an einem Ort',
                                    'Canlı TV, filmler ve diziler tek yerde',
                                    'Live TV, movies and series in one place'),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme.onSurface.withOpacity(0.65),
                                  fontSize: compact ? 13 : 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            horizontal, 8, horizontal, 28),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _PremiumTile(
                              entry: entries[index],
                              autofocus: index == 0,
                            ),
                            childCount: entries.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: compact ? 1.35 : (width < 850 ? 1.25 : 1.65),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEntry {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _HomeEntry(this.icon, this.title, this.onTap);
}

class _ProButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ProButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        focusColor: AppTheme.electricBlue.withOpacity(0.25),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _PremiumTile extends StatelessWidget {
  final _HomeEntry entry;
  final bool autofocus;
  const _PremiumTile({required this.entry, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        autofocus: autofocus,
        onTap: entry.onTap,
        focusColor: AppTheme.electricBlue.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: dark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.electricBlue.withOpacity(0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.electricBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(entry.icon,
                      size: 24, color: AppTheme.electricBlue),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
