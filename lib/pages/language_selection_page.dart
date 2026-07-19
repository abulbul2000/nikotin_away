import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../main.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'trial_info_page.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _selectedCode = 'en';

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final code = await LanguageService.loadSelectedLanguageCode();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCode = code;
    });
  }

  Future<void> _continue(BuildContext context, String languageCode) async {
    // Dili kaydet
    await LanguageService.saveSelectedLanguageCode(languageCode);
    await AppTexts.ensureLanguageLoaded(languageCode);
    await NotificationService.refreshLocalizedResources();
    if (!context.mounted) return;
    
    // Locale'i set et
    NoSmokeApp.setLocale(
      context,
      LanguageService.supportedLanguages[languageCode] ?? const Locale('en'),
    );
    
    // Locale güncellemesinin uygulanması için kısa bir bekleme
    await Future.delayed(const Duration(milliseconds: 150));
    if (!context.mounted) return;

    // Sonra TrialInfoPage'e git
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TrialInfoPage()),
    );
  }

  void _showLanguageModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LanguageSelectionModal(
        selectedCode: _selectedCode,
        onLanguageSelected: (code) {
          setState(() {
            _selectedCode = code;
          });
          _continue(context, code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NoSmokeLogo(
                    size: 156,
                    showLabel: true,
                    iconColor: Color(0xE6FFFFFF),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.t('selectLanguage'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 48),
                  GestureDetector(
                    onTap: () => _showLanguageModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.t('selectLanguage'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white70,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    LanguageService.languageNames[_selectedCode] ?? 'English',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LanguageSelectionModal extends StatefulWidget {
  final String selectedCode;
  final Function(String) onLanguageSelected;

  const LanguageSelectionModal({
    super.key,
    required this.selectedCode,
    required this.onLanguageSelected,
  });

  @override
  State<LanguageSelectionModal> createState() => _LanguageSelectionModalState();
}

class _LanguageSelectionModalState extends State<LanguageSelectionModal> {
  String _searchQuery = '';
  bool _showOtherLanguages = false;

  List<String> _getFilteredLanguages() {
    final query = _searchQuery.toLowerCase();
    final langs = _showOtherLanguages
        ? LanguageService.supportedLanguages.keys
            .where((code) => !LanguageService.primaryLanguages.contains(code))
            .toList()
        : LanguageService.primaryLanguages.toList();

    if (query.isEmpty) {
      return langs;
    }

    return langs.where((code) {
      final name = LanguageService.languageNames[code] ?? '';
      return name.toLowerCase().contains(query) || code.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLangs = _getFilteredLanguages();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E2A3A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _showOtherLanguages
                          ? context.t('otherLanguages')
                          : context.t('selectLanguage'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Search box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: context.t('searchLanguages'),
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            child: Icon(Icons.clear, color: Colors.white54),
                          )
                        : null,
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              // Language list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredLangs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemBuilder: (context, index) {
                    final code = filteredLangs[index];
                    final name = LanguageService.languageNames[code] ?? code;
                    final isSelected = code == widget.selectedCode;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onLanguageSelected(code);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green.withAlpha(80)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.green,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.87),
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Other languages button (nur wenn nicht in other languages)
              if (!_showOtherLanguages)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _showOtherLanguages = true;
                          _searchQuery = '';
                        });
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.language),
                          const SizedBox(width: 8),
                          Text(
                            '${context.t('otherLanguages')} →',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Back button (wenn in other languages)
              if (_showOtherLanguages)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showOtherLanguages = false;
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.t('backToMain')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.white30),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
