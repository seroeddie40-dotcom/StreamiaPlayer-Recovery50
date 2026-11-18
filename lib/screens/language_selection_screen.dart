
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../core/platform/device_layout.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _focusedLanguage;
  late final Map<String, FocusNode> _nodes = {
    for (final language in _languages) language.$1: FocusNode(debugLabel: language.$1),
  };

  @override
  void dispose() {
    for (final node in _nodes.values) { node.dispose(); }
    super.dispose();
  }

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

  Widget _buildTelevision(String selectedLanguage) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF091425), Color(0xFF15425C)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 400;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.04,
                  vertical: compact ? 8 : 20,
                ),
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Column(
                    children: [
                      Text(
                        'Choose your language',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 22 : 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Sprache wählen',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                      SizedBox(height: compact ? 8 : 20),
                      for (var row = 0; row < 2; row++) ...[
                        if (row > 0) const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var col = 0; col < 4; col++) ...[
                                if (col > 0) const SizedBox(width: 12),
                                Expanded(child: _televisionTile(
                                  _languages[row * 4 + col], selectedLanguage)),
                              ],
                            ],
                          ),
                        ),
                      ],
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

  Widget _televisionTile((String, String, String) language, String selected) {
    final (code, name, flag) = language;
    final focused = _focusedLanguage == code;
    return Material(
      color: focused ? const Color(0xFF215C76) : const Color(0xFF18364D),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        focusNode: _nodes[code],
        autofocus: code == selected,
        onFocusChange: (value) {
          if (!mounted) return;
          setState(() {
            if (value) {
              _focusedLanguage = code;
            } else if (_focusedLanguage == code) {
              _focusedLanguage = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.read<LocaleProvider>().setLocale(code),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused ? const Color(0xFF39E8FF) : const Color(0xFF416579),
              width: focused ? 3 : 1,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(name, style: const TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    final selectedLanguage =
        localeProvider.locale.languageCode;

    if (DeviceLayout.isTelevision) {
      return _buildTelevision(selectedLanguage);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF101A2B), Color(0xFF12344A)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tv = DeviceLayout.isTelevision;
              final shortTv = tv && constraints.maxHeight < 440;
              final horizontalPadding =
                  tv ? 56.0 : (isCompact ? 16.0 : 24.0);

              final availableWidth =
                  constraints.maxWidth -
                  (horizontalPadding * 2);

              final itemSpacing =
                  isCompact ? 10.0 : 14.0;

              final columns = tv && availableWidth >= 520 ? 4 : 2;
              final itemWidth =
                  (availableWidth - itemSpacing * (columns - 1)) / columns;

              return FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: shortTv ? 12 : 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - (shortTv ? 24 : 40)).clamp(0.0, double.infinity).toDouble(),
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.language,
                        size: shortTv ? 32 : 56,
                        color: Colors.white,
                      ),

                      SizedBox(height: shortTv ? 6 : 16),

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

                      SizedBox(height: shortTv ? 12 : 30),

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
                                focusNode: _nodes[languageCode],
                                autofocus: DeviceLayout.isTelevision && languageCode == selectedLanguage,
                                onFocusChange: (focused) {
                                  if (!DeviceLayout.isTelevision || !mounted) return;
                                  setState(() {
                                    if (focused) {
                                      _focusedLanguage = languageCode;
                                    } else if (_focusedLanguage == languageCode) {
                                      _focusedLanguage = null;
                                    }
                                  });
                                },
                                focusColor: Colors.white24,
                                borderRadius:
                                    BorderRadius.circular(16),
                                onTap: () {
                                  context
                                      .read<LocaleProvider>()
                                      .setLocale(languageCode);
                                },
                                child: Container(
                                  constraints:
                                      BoxConstraints(
                                    minHeight: shortTv ? 70 : 88,
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
                                      color: DeviceLayout.isTelevision && _focusedLanguage == languageCode
                                          ? const Color(0xFF00E5FF)
                                          : Colors.white.withOpacity(isSelected ? 1 : 0.4),
                                      width: DeviceLayout.isTelevision ? 3 : (isSelected ? 2 : 1),
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

                      SizedBox(height: shortTv ? 8 : 20),
                    ],
                  ),
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
