import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../widgets/playlist_source_navigation.dart';
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
  int _sourceNavigationRevision = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, isDark, l10n),
            PlaylistSourceNavigation(
              key: ValueKey(_sourceNavigationRevision),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 600;
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : (compact ? 1 : 2);

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 48,
                    ),
                    child: FocusTraversalGroup(
                      child: GridView.count(
                        crossAxisCount: columns,
                        mainAxisSpacing: compact ? 12 : 24,
                        crossAxisSpacing: compact ? 12 : 24,
                        childAspectRatio: compact ? 2.7 : 1.6,
                        children: [
                          _DashboardTile(
                            autofocus: true,
                            icon: Icons.live_tv,
                            label: l10n.t('nav_live'),
                            onTap: () => pushWithFocusRestore(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LiveTvScreen(),
                              ),
                            ),
                          ),
                          _DashboardTile(
                            icon: Icons.movie,
                            label: l10n.t('nav_vod'),
                            onTap: () => pushWithFocusRestore(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VodScreen(),
                              ),
                            ),
                          ),
                          _DashboardTile(
                            icon: Icons.video_library,
                            label: l10n.t('nav_series'),
                            onTap: () => pushWithFocusRestore(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SeriesScreen(),
                              ),
                            ),
                          ),
                          _DashboardTile(
                            icon: Icons.grid_view,
                            label: l10n.t('nav_multi'),
                            onTap: () {},
                          ),
                          _DashboardTile(
                            icon: Icons.replay,
                            label: l10n.t('nav_catchup'),
                            onTap: () {},
                          ),
                          _DashboardTile(
                            icon: Icons.search,
                            label: l10n.t('nav_search'),
                            onTap: () => pushWithFocusRestore(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MasterSearchScreen(),
                              ),
                            ),
                          ),
                          _DashboardTile(
                            icon: Icons.play_circle_outline,
                            label: l10n.t('nav_continue_watching'),
                            onTap: () => pushWithFocusRestore(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ContinueWatchingScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 48,
        vertical: compact ? 10 : 16,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 48,
            height: compact ? 40 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.accentGradient,
            ),
            child: const Center(
              child: Text(
                'S',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              l10n.t('app_name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            focusColor: AppTheme.electricBlue.withOpacity(0.22),
            onTap: () => pushWithFocusRestore(
              context,
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.t('nav_pro'),
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: isDark ? 'Helles Design' : 'Dunkles Design',
            focusColor: AppTheme.electricBlue.withOpacity(0.22),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              size: compact ? 24 : 28,
            ),
          ),
          IconButton(
            tooltip: 'Einstellungen',
            focusColor: AppTheme.electricBlue.withOpacity(0.22),
            onPressed: () async {
              await pushWithFocusRestore(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (mounted) {
                setState(() => _sourceNavigationRevision++);
              }
            },
            icon: Icon(Icons.settings, size: compact ? 24 : 28),
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      autofocus: autofocus,
      focusColor: AppTheme.electricBlue.withOpacity(0.22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.electricBlue.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.electricBlue),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
