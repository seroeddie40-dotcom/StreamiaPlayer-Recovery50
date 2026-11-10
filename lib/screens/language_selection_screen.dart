
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../core/theme/app_theme.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  static const _languages = [
    ('de', 'Deutsch', '🇩🇪'),
    ('tr', 'Türkçe', '🇹🇷'),
    ('en', 'English', '🇬🇧'),
    ('ru', 'Русский', '🇷🇺'),
    ('ar', 'العربية', '🇸🇦'),
    ('pl', 'Polski', '🇵🇱'),
    ('es', 'Español', '🇪🇸'),
    ('fr', 'Français', '🇫🇷'),
  ];

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final selectedLanguage =
        localeProvider.locale.languageCode;

    final screenWidth = MediaQuery.sizeOf(context).width;

    final isCompact = screenWidth < 380;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.accentGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  isCompact ? 16.0 : 24.0;

              final availableWidth =
                  constraints.maxWidth -
                  (horizontalPadding * 2);

              final itemSpacing =
                  isCompact ? 10.0 : 14.0;

              final itemWidth =
                  (availableWidth - itemSpacing) / 2;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - 40,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.language,
                        size: 56,
                        color: Colors.white,
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Choose your language',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'Sprache wählen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Wrap(
                        spacing: itemSpacing,
                        runSpacing: itemSpacing,
                        children: _languages.map((lang) {
                          final languageCode = lang.$1;
                          final languageName = lang.$2;
                          final flag = lang.$3;

                          final isSelected =
                              languageCode ==
                              selectedLanguage;

                          return SizedBox(
                            width: itemWidth,
                            child: Material(
                              color: Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(16),
                                onTap: () {
                                  context
                                      .read<LocaleProvider>()
                                      .setLocale(languageCode);
                                },
                                child: Container(
                                  constraints:
                                      const BoxConstraints(
                                    minHeight: 88,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(
                                      isSelected ? 0.25 : 0.13,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(
                                        isSelected ? 1 : 0.4,
                                      ),
                                      width:
                                          isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        flag,
                                        style: const TextStyle(
                                          fontSize: 26,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          languageName,
                                          maxLines: 1,
                                          textAlign:
                                              TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
