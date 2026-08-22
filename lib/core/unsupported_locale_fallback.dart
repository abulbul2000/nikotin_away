import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Kurdish (`ku`, Kurmancî/Latin script, and `ku-arab`, Soranî/Arabic
/// script — both entries in LanguageService.supportedLanguages) has no
/// translation in Flutter's own flutter_localizations package:
/// GlobalMaterialLocalizations and GlobalCupertinoLocalizations both report
/// `isSupported == false` for it (GlobalWidgetsLocalizations' own inner
/// delegate actually supports every locale, always handing back English
/// text — same problem, no exception thrown). Left alone, that makes every
/// page with an AppBar (or any other widget that asks for
/// MaterialLocalizations) throw "No MaterialLocalizations found" for a user
/// who picked Kurdish — the framework never falls back on its own once a
/// locale is in supportedLocales but unsupported by a delegate.
///
/// This app's own strings never depend on this: `context.t()` reads
/// AppTexts' own translation tables, independent of these delegates. What's
/// missing is purely the *framework's* own built-in strings — the
/// back-button tooltip, the time/date-picker's "OK"/"Cancel", the
/// text-selection toolbar's "Copy"/"Paste", and so on.
///
/// Per-project rule: no supported language stands in with another
/// language's text for anything a user can actually see, including these
/// framework-level strings — see memory/feedback_no_locale_fallback.md.
/// So this is a real (if partial) Kurdish translation, not a stand-in: every
/// member below is one this app's own widget usage can actually surface
/// (TextField selection toolbar, AppBar back button, dialogs/bottom
/// sheets/drawer, showTimePicker, showDatePicker, RefreshIndicator — see the
/// per-file survey behind this change). Members neither this app nor its
/// dependencies ever reach (PaginatedDataTable, LicensePage, TabBar,
/// SliverReorderableList, PopupMenuButton — none of which this app uses)
/// are left inherited from the framework's own locale-agnostic base classes
/// (`DefaultMaterialLocalizations` et al., not another language's
/// translation), since a user of this app can never actually see them.
///
/// [Localizations] picks the first delegate of a given type whose
/// `isSupported` returns true (see _loadAll in the framework), so these must
/// be listed ahead of the Global*Localizations delegates in
/// MaterialApp.localizationsDelegates.
bool _isKurdish(Locale locale) => locale.languageCode == 'ku';

bool _isSorani(Locale locale) => locale.languageCode == 'ku' && locale.scriptCode == 'Arab';

/// Kurmancî (Latin-script Kurdish) translations for the subset of
/// MaterialLocalizations this app's widget usage can actually surface.
/// Everything else — PaginatedDataTable, LicensePage, TabBar, and other
/// members this app never renders — is inherited from
/// DefaultMaterialLocalizations (English), which a user can never see.
class _KurmanciMaterialLocalizations extends DefaultMaterialLocalizations {
  const _KurmanciMaterialLocalizations();

  // Ordered to match DateTime.monday=1 .. DateTime.sunday=7.
  static const _weekdays = [
    'Duşem',
    'Sêşem',
    'Çarşem',
    'Pêncşem',
    'În',
    'Şemî',
    'Yekşem',
  ];
  static const _shortWeekdays = ['Duş', 'Sêş', 'Çar', 'Pên', 'În', 'Şem', 'Yek'];
  static const _narrowWeekdays = ['D', 'S', 'Ç', 'P', 'Î', 'Ş', 'Y'];
  static const _months = [
    'Rêbendan',
    'Sibat',
    'Adar',
    'Nîsan',
    'Gulan',
    'Hezîran',
    'Tîrmeh',
    'Tebax',
    'Îlon',
    'Cotmeh',
    'Mijdar',
    'Berfanbar',
  ];
  static const _shortMonths = [
    'Rêb',
    'Sib',
    'Ada',
    'Nîs',
    'Gul',
    'Hez',
    'Tîr',
    'Teb',
    'Îlo',
    'Cot',
    'Mij',
    'Ber',
  ];

  @override
  String get openAppDrawerTooltip => 'Pêşeka gerînendeyê veke';

  @override
  String get backButtonTooltip => 'Vegere';

  @override
  String get closeButtonTooltip => 'Bigire';

  @override
  String get clearButtonTooltip => 'Nivîsê paqij bike';

  @override
  String get deleteButtonTooltip => 'Jê bibe';

  @override
  String get refreshIndicatorSemanticLabel => 'Nûve bike';

  @override
  String get drawerLabel => 'Pêşeka gerînendeyê';

  @override
  String get dialogLabel => 'Diyalog';

  @override
  String get alertDialogLabel => 'Hişyarî';

  @override
  String get bottomSheetLabel => 'Rûpela binî';

  @override
  String get scrimLabel => 'Perde';

  @override
  String scrimOnTapHint(String modalRouteContentName) => 'Bigire $modalRouteContentName';

  @override
  String get modalBarrierDismissLabel => 'Bigire';

  @override
  String get cancelButtonLabel => 'Betal ke';

  @override
  String get closeButtonLabel => 'Bigire';

  @override
  String get continueButtonLabel => 'Berdewam';

  @override
  String get copyButtonLabel => 'Ji ber bigire';

  @override
  String get cutButtonLabel => 'Jê bike';

  @override
  String get okButtonLabel => 'Baş e';

  @override
  String get pasteButtonLabel => 'Pêve bike';

  @override
  String get selectAllButtonLabel => 'Hemûyan hilbijêre';

  @override
  String get anteMeridiemAbbreviation => 'BN';

  @override
  String get postMeridiemAbbreviation => 'PN';

  @override
  String get timePickerHourModeAnnouncement => 'Saetê hilbijêre';

  @override
  String get timePickerMinuteModeAnnouncement => 'Deqîqeyê hilbijêre';

  @override
  String get timePickerDialHelpText => 'Demjimêrê hilbijêre';

  @override
  String get timePickerInputHelpText => 'Demjimêrê binivîse';

  @override
  String get timePickerHourLabel => 'Saet';

  @override
  String get timePickerMinuteLabel => 'Deqîqe';

  @override
  String get invalidTimeLabel => 'Demek derbasdar binivîse';

  @override
  String get dialModeButtonLabel => 'Derbasî moda çerxê bibe';

  @override
  String get inputTimeModeButtonLabel => 'Derbasî moda nivîsê bibe';

  @override
  String get datePickerHelpText => 'Rojê hilbijêre';

  @override
  String get dateRangePickerHelpText => 'Navberê hilbijêre';

  @override
  String get calendarModeButtonLabel => 'Derbasî salnameyê bibe';

  @override
  String get inputDateModeButtonLabel => 'Derbasî nivîsê bibe';

  @override
  String get currentDateLabel => 'Îro';

  @override
  String get selectedDateLabel => 'Hilbijartî';

  @override
  String get selectYearSemanticsLabel => 'Salê hilbijêre';

  @override
  String get unspecifiedDate => 'Roj';

  @override
  String get unspecifiedDateRange => 'Navbera rojan';

  @override
  String get dateInputLabel => 'Rojê binivîse';

  @override
  String get dateRangeStartLabel => 'Roja destpêkê';

  @override
  String get dateRangeEndLabel => 'Roja dawî';

  @override
  String dateRangeStartDateSemanticLabel(String formattedDate) => 'Roja destpêkê $formattedDate';

  @override
  String dateRangeEndDateSemanticLabel(String formattedDate) => 'Roja dawî $formattedDate';

  @override
  String get invalidDateFormatLabel => 'Şêwaz nederbasdar e.';

  @override
  String get invalidDateRangeLabel => 'Navber nederbasdar e.';

  @override
  String get dateOutOfRangeLabel => 'Ji navberê derve ye.';

  @override
  String get saveButtonLabel => 'Tomar bike';

  @override
  String get nextMonthTooltip => 'Meha bê';

  @override
  String get previousMonthTooltip => 'Meha borî';

  @override
  String get dateSeparator => '/';

  @override
  String get dateHelpText => 'rr/mm/ssss';

  @override
  List<String> get narrowWeekdays => _narrowWeekdays;

  @override
  String formatYear(DateTime date) => date.year.toString();

  @override
  String formatMonthYear(DateTime date) {
    final month = _months[date.month - DateTime.january];
    return '$month ${date.year}';
  }

  @override
  String formatShortDate(DateTime date) {
    final month = _shortMonths[date.month - DateTime.january];
    return '${date.day} $month ${date.year}';
  }

  @override
  String formatMediumDate(DateTime date) {
    final weekday = _shortWeekdays[date.weekday - DateTime.monday];
    final month = _shortMonths[date.month - DateTime.january];
    return '$weekday, ${date.day} $month';
  }

  @override
  String formatFullDate(DateTime date) {
    final weekday = _weekdays[date.weekday - DateTime.monday];
    final month = _months[date.month - DateTime.january];
    return '$weekday, ${date.day} $month ${date.year}';
  }

  @override
  String formatShortMonthDay(DateTime date) {
    final month = _shortMonths[date.month - DateTime.january];
    return '${date.day} $month';
  }
}

/// Soranî (Arabic-script Kurdish, LanguageService's 'ku-arab' entry) shares
/// Kurmancî's translations below — both are Kurdish, differing mainly in
/// script — but reports RTL, matching main.dart's own Directionality choice
/// for this script.
class _SoraniMaterialLocalizations extends _KurmanciMaterialLocalizations {
  const _SoraniMaterialLocalizations();
}

class KurdishMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const KurdishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdish(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final localizations = _isSorani(locale)
        ? const _SoraniMaterialLocalizations()
        : const _KurmanciMaterialLocalizations();
    return SynchronousFuture<MaterialLocalizations>(localizations);
  }

  @override
  bool shouldReload(KurdishMaterialLocalizationsDelegate old) => false;
}

/// This app never renders a Cupertino widget (no CupertinoButton, -Dialog,
/// -Switch, -ActivityIndicator, etc. anywhere in lib/), so no user can ever
/// see this class's text — it exists only to satisfy
/// Localizations._debugCheckLocalizations, which otherwise logs an
/// "unsupported locale" warning for every Kurdish screen even though nothing
/// on screen actually needs CupertinoLocalizations.
class KurdishCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const KurdishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdish(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(const DefaultCupertinoLocalizations());

  @override
  bool shouldReload(KurdishCupertinoLocalizationsDelegate old) => false;
}

/// Kurmancî translations for the WidgetsLocalizations members this app can
/// surface — the TextField selection toolbar (copy/cut/paste/select all)
/// and text direction. reorderItem*/searchResultsFound/noResultsFound/
/// radioButtonUnselectedLabel are inherited from DefaultWidgetsLocalizations
/// (English) since this app uses no SliverReorderableList, RawAutocomplete,
/// or standalone radio button relying on the framework's own semantic label.
class _KurmanciWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _KurmanciWidgetsLocalizations();

  @override
  String get copyButtonLabel => 'Ji ber bigire';

  @override
  String get cutButtonLabel => 'Jê bike';

  @override
  String get pasteButtonLabel => 'Pêve bike';

  @override
  String get selectAllButtonLabel => 'Hemûyan hilbijêre';

  @override
  TextDirection get textDirection => TextDirection.ltr;
}

class _SoraniWidgetsLocalizations extends _KurmanciWidgetsLocalizations {
  const _SoraniWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;
}

class KurdishWidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const KurdishWidgetsLocalizationsDelegate();

  // DefaultWidgetsLocalizations' own inner delegate (auto-added by
  // WidgetsApp) reports true for every locale already, so this must claim
  // Kurdish too or the framework one wins and hands back its English text.
  @override
  bool isSupported(Locale locale) => _isKurdish(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    final localizations = _isSorani(locale)
        ? const _SoraniWidgetsLocalizations()
        : const _KurmanciWidgetsLocalizations();
    return SynchronousFuture<WidgetsLocalizations>(localizations);
  }

  @override
  bool shouldReload(KurdishWidgetsLocalizationsDelegate old) => false;
}
