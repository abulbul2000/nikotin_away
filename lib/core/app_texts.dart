import 'package:flutter/material.dart';

import 'generated_language_data.dart';
import 'mentor_command_codes.dart';

class AppTexts {
  // Turkish - Full translation
  static const Map<String, String> _tr = {
    'appName': 'NIKOTIN AWAY',
    'appTagline': 'Kişisel Sigara Bırakma Rehberin',
    'watchdogForegroundBody': 'Görev yanıtı bekleniyor',
    'watchdogViolationTitle': 'Nikotin Away Hatırlatma',
    'watchdogViolationBody':
        '10 dakika yanıt alamadık. {taskTitle} görevini kaçırmış olabilirsin, sorun değil.',
    'watchdogForegroundChannel': 'Arka plan servisi',
    'watchdogViolationChannel': 'Nikotin Away Hatırlatmaları',
    'selectLanguage': 'Dil Seç',
    'continue': 'Devam Et',
    'back': 'Geri',
    'yes': 'Evet',
    'no': 'Hayır',
    'save': 'Kaydet',
    'home': 'Ana Sayfa',
    'tabTests': 'Testler',
    'tabTracking': 'Takip',
    'weeklySurvey': 'Haftalık Anket',
    'riskAnalysis': 'Risk Analizi',
    'retry': 'Tekrar dene',
    'iBreathed': 'Nefes Aldım',
    'start': 'Başla',
    'test': 'Test',
    'good': 'İyi',
    'bad': 'Kötü',
    'risk': 'Risk',
    'name': 'Ad',
    'age': 'Yaş',
    'gender': 'Cinsiyet',
    'male': 'Erkek',
    'female': 'Kadın',
    'selectOption': 'Seçiniz',
    'breathTest': 'Nefes Egzersizi',
    'breathTestPageTitle': 'Nefes Testi',
    'riskLevel': 'Risk seviyesi',
    'smokeFreeDaysWidgetLabel': 'gün sigarasız',
    'riskScore': 'Risk skoru',
    'initialSurvey': 'Başlangıç Anketi',
    'taskResultTitle': 'Görev Sonucu',
    'smokingInfo': 'Sigara Bilgileri',
    'lifeRoutine': 'Yaşam Düzeni',
    'professionLabel': 'Meslek',
    'healthStatus': 'Sağlık Durumu',
    'triggerTitle': 'Sigara Tetikleyicileri',
    'stressTitle': 'Stres Seviyesi',
    'quitReasonTitle': 'Bırakma Sebebi',
    'heartDisease': 'Kalp Hastalığı',
    'otherHealthCondition': 'Diğer',
    'otherHealthConditionHint': 'Hastalığınızı yazin',
    'usesMedicationQuestion': 'Düzenli ilaç kullanıyorum',
    'addMedicationButton': 'İlaç ekle',
    'medicationNameHint': 'İlaç adı',
    'addMedicationTimeButton': 'Saat ekle',
    'medicationsSettingsRow': 'İlaçlarım',
    'medicationsSettingsRowSubtitle': 'İlaç ekle, düzenle veya sil',
    'medicationsPageTitle': 'İlaçlarım',
    'medicationsEmptyState': 'Henüz ilaç eklemediniz.',
    'medicationDeleteConfirmTitle': 'İlacı sil',
    'medicationDeleteConfirmMessage':
        'Bu ilacı ve hatırlatmalarını silmek istediğinize emin misiniz?',
    'medicationSavedConfirmation': 'İlaç kaydedildi',
    'medicationReminderTitle': 'İlaç hatırlatması',
    'medicationReminderBody': '{name} ilacınızı alma vakti geldi.',
    'overlayPermissionTitle': 'Görev ekranını göster',
    'overlayPermissionMessage':
        'Görev ekranının, telefon kilitli olmasa bile diğer uygulamaların üstünde açılabilmesi için "diğer uygulamaların üstünde göster" iznine ihtiyacımız var. Şimdi ayar ekranını açalım mi?',
    'smokedLogButtonRow': 'Sigara İçtim butonu',
    'smokedLogButtonTitle': 'Sigara İçtim Butonu',
    'smokedLogButtonDescription':
        'Ekranda küçük, şeffaf bir buton belirir. Sigara içtiğinizde 1 saniye basılı tutun; seçenekler açılır ve kayıt alınır. Yanlışlıkla dokunmaniz durumunda kayıt alınmaz.',
    'smokedLogButtonPurpose':
        'Uygulama böylece hangi saatlerde ve hangi yerlerde sigara içme eğiliminiz olduğunu öğrenir, görevleri tam o riskli anlara denk getirir. Konum bilgisi yalnızca daha önce tanımlanmış sık gittiğiniz yerlerle eşleştirilir; adres veya hareket geçmişiniz saklanmaz. Tüm kayıtlar yalnızca cihazınızda tutulur.',
    'smokedLogButtonEnabled': 'Sigara İçtim butonu açıldı.',
    'smokedLogButtonDisabled': 'Sigara İçtim butonu kapatıldı.',
    'smokedLogButtonNeedsOverlay':
        'Bu buton için "diğer uygulamaların üstünde göster" izni gerekiyor.',
    'smokedLogButtonNotificationTitle': 'Nikotin Away',
    'smokedLogButtonNotificationBody':
        'Yüzen butona 1 saniye başılı tutun, seçenekler açılsın',
    'smokedLogButtonAction': 'Sigara İçtim',
    'smokedLogMenuTitle': 'Ne yapmak istiyorsun?',
    'smokedLogMenuSos': 'SOS — Krizdeyim',
    'smokedLogMenuOpen': 'Uygulamayı Aç',
    'smokedLogMenuCancel': 'Vazgeç',
    'dailyBreathPromptContent':
        'Nefes testini şimdi yapmak ister misin? Günde bir kez yeterli.',
    'dailyBreathOverdueContent':
        '24 saattir nefes testi yapmadın. Bu ölçüm sonradan tamamlanamıyor — '
        'atlanan gün grafikte boşluk olarak kalıyor.',
    'dailyBreathLater': 'Sonra',
    'dailyBreathOverdueNotificationTitle': 'Bugünkü nefes testin bekliyor',
    'dailyBreathOverdueNotificationBody':
        '24 saattir ölçüm yapılmadı. Uygulamayı açıp testi tamamla.',
    'smokedLogRecordedWithUndo': 'Sigara kaydedildi.',
    'smokedLogUndoBody': 'Yanlışlıkla mi bastın? Geri alabilirsin.',
    'smokedLogUndoAction': 'Geri Al',
    'channelNameSmokedLogUndo': 'Sigara kaydı geri alma',
    'smokedLogConsentHeading': 'Sigara İçtim butonunu açalım mi?',
    'smokedLogConsentDataTitle': 'Neler kaydedilir',
    'smokedLogConsentDataBody':
        'Sadece butona bastığınız an ve — Konum Zekası açıksa — o an sık gittiğiniz yerlerden hangisine yakın olduğunuz. Adresiniz, koordinatlarınız veya hareket geçmişiniz kaydedilmez. Konum alınamazsa sigara yine kaydedilir, yer bilgisi boş kalır.',
    'smokedLogConsentStorageTitle': 'Nerede tutulur',
    'smokedLogConsentStorageBody':
        'Yalnızca bu cihazda. Hiçbir kayıt dışarı gönderilmez. Butonu ve geçmiş kayıtları istediğiniz zaman Ayarlar bölümünden kaldırabilirsiniz.',
    'smokedLogConsentAccept': 'Butonu ac',
    'smokedLogConsentDecline': 'Şimdilik istemiyorum',
    'permissionSetupTitle': 'Gerekli izinler',
    'permissionSetupIntro':
        'Görevlerin doğru zamanda ve görünür şekilde ulaşabilmesi için aşağıdaki izinler gerekiyor. Ayarlardan dönünce durum kendiliğinden güncellenir.',
    'permissionOverlayDescription':
        'Görev ekranının başka uygulamaların üstünde açılabilmesi için gerekli. Verilmezse görev yine gelir, ama sadece bildirim olarak.',
    'permissionOemDescription':
        'Bu telefonda bazı bildirim ayarları üreticinin kendi izin ekranında duruyor. Oradan "arka planda çalışma" ve "kilit ekranında göster" seçeneklerini açabilirsiniz.',
    'notifKindsSectionTitle': 'Bildirim Türleri',
    'notifKindsTitle': 'Hangi bildirimleri almak istersin?',
    'notifKindsHint':
        'Görev bildirimleri ve kendi seçtiğin ilaç saatleri her zaman gelir. Aşağıdakiler isteğe bağlı — kapatmak günlük ilerlemeni etkilemez.',
    'notifKindBreathTest': 'Nefes testi hatırlatıcısı',
    'notifKindWeeklySurvey': 'Haftalık anket hatırlatıcısı',
    'notifKindHealthTip': 'Sağlık ipuçları',
    'dailyHealthTipCountLabel': 'Günde kaç sağlık ipucu?',
    'notifKindCoachCommand': 'Mentör önerileri',
    'notifKindSedentary': 'Hareketsizlik hatırlatıcısı',
    'permissionSetupOptionalHeading': 'İsteğe bağlı özellikler için izinler',
    'permissionSetupOptionalHint':
        'Bunlar olmadan da uygulama çalışır. Vermek, ilgili özelliği otomatik açmaz — yalnızca Ayarlar\'dan açtığında izin sormasına gerek kalmaz.',
    'permissionHealthTitle': 'Sağlık Verisi (Health Connect)',
    'permissionHealthDescription':
        'Giyilebilir Zekası açıksa, saatinin/bilekliğinin nabız ve uyku verisini okur. Yalnızca cihazında kalır, hiçbir yere gönderilmez.',
    'permissionUsageAccessTitle': 'Uygulama Kullanım Erişimi',
    'permissionUsageAccessDescription':
        'Hangi uygulamanın ekranda olduğunu (yalnızca isim, içerik değil) okuyarak sağlık tavsiyesi ve görev pencerelerinin telefon görüşmesi, oyun, video ya da sosyal medya sırasında açılmasını engeller.',
    'permissionUsageAccessPurpose':
        'Neden: Bu izin verilmezse uygulama yine de ekranın açık kalma süresi ve ses çalma durumu gibi ipuçlarıyla tahmin yapmaya çalışır, ama bu izinle çok daha isabetli olur.',
    'permissionSetupContinueAnyway': 'Şimdilik devam et',
    'permissionSetupOptionalNote':
        'İzinleri daha sonra Ayarlar bölümünden de düzenleyebilirsiniz.',
    'packsPerDayQuestion': 'Günde kaç paket sigara içiyorsunuz?',
    'firstCigaretteWhen':
        'İlk sigarayı uyandıktan ne kadar süre sonra içiyorsunuz?',
    'firstCigarette10to30': 'Uyandıktan 10-30 dk sonra',
    'maxSmokeFreeDuration': 'Sigarasız kalabildiğin maksimum süre',
    'smokeFree30to60': '30-60 dakika',
    'smokingYears': 'Kaç yıldır içiyorsun?',
    'cigarettesPerPackLabel': 'Bir pakette kaç sigara var?',
    'triggerCoffee': 'Kahve',
    'triggerMeal': 'Yemek sonrası',
    'triggerDriving': 'Araç kullanırken',
    'triggerStress': 'Stresliyken',
    'triggerPhone': 'Telefonda',
    'triggerSocial': 'Sosyal ortam',
    'triggerWork': 'Is molası',
    'triggerBoredom': 'Can sıkıntısı',
    'triggerHabit': 'Alışkanlık',
    'triggerUnknown': 'Bilmiyorum',
    'triggerAlcohol': 'Alkol',
    'stressMedium': 'Orta',
    'quitReason': 'Bırakma sebebi',
    'quitHealth': 'Sağlığım için',
    'riskCritical': 'KRİTİK',
    'riskHigh': 'YÜKSEK',
    'riskMedium': 'ORTA',
    'riskLow': 'DÜŞÜK',
    'validationNameRequired': 'Lütfen ad alanını doldurun.',
    'validationAgeRequired': 'Lütfen yaş alanını doldurun.',
    'validationGenderRequired': 'Lütfen cinsiyet seçin.',
    'hello': 'Merhaba',
    'weeklySavePrompt': 'Bu haftaki durumunuzu kaydedin.',
    'weeklySurveyPromptAsk': 'Haftalık anketi şimdi doldurmak ister misiniz?',
    'shareProgressTitle': 'İlerlemeni paylaş',
    'shareProgressMessage':
        'Haftalık değerlendirmeni tamamladın. İlerlemeni arkadaşlarınla paylaşmak ister misin?',
    'shareProgressSkip': 'Geç',
    'shareProgressAction': 'Paylaş',
    'shareProgressText':
        'Nikotin Away ile sigarayı bırakma sürecimi takip ediyorum. Güncel risk skorum: {score}/100 ({level}).',
    'shareAppTitle': 'Sosyal Medyada Paylaş',
    'shareAppMessage':
        'Nikotin Away uygulamasını keşfet: sigarayı bırakma sürecini takip et, tetikleyicilerini tanı ve kişisel koçluğundan yararlan.\n\n{url}',
    'saveErrorRetry': 'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.',
    'loadErrorRetry':
        'Veriler yüklenirken bir hata oluştu. Lütfen tekrar deneyin.',
    'smokeFreeStreak': 'Sigara İçmeme Serisi',
    'reductionCardTitle': 'Azaltma İlerlemen',
    'reductionStreakLabel': 'Hedefi tutturduğun gün',
    'reductionAvoidedLabel': 'İçmediğin sigara',
    'reductionIntervalLabel': 'Sigara arası süre',
    'reductionTargetToday': 'Bugünkü hedef: en fazla {target} sigara',
    'reductionLoggedToday': 'Bugün {count} kayıt girdin',
    'reductionNoDataTitle': 'Henüz ölçecek bir şey yok',
    'reductionNoDataBody':
        'Sigara içtiğinde butona baş ya da görevleri yanıtla — ilerlemeni '
        'ancak gerçek kayıtlardan çıkarabiliriz.',
    'reductionIntervalDetail': 'Eskiden {natural} dk, şimdi {barrier} dk',
    'reductionIntervalGain': '%{percent} daha uzun',
    'reductionBaselineNote': 'Başlangıçta günde {baseline} sigara içiyordun',
    'healthMetrics': 'Sağlık Metrikleri',
    'noBreathTestsYet': 'Henüz nefes testi kaydı yok.',
    'longitudinalAnalysis': 'Zaman Serisine Dayalı Analiz',
    'statistics': 'İstatistikler',
    'recentTests': 'Son Testler',
    'workDaysLabel': 'Çalıştığın günler',
    'dayMonShort': 'Pzt',
    'dayTueShort': 'Sal',
    'dayWedShort': 'Çar',
    'dayThuShort': 'Per',
    'dayFriShort': 'Cum',
    'daySatShort': 'Cmt',
    'daySunShort': 'Paz',
    'weekendPatternLabel': 'Hafta sonu içim paterni',
    'weekendPatternSame': 'Hafta içi ile aynı',
    'weekendPatternMore': 'Hafta sonu daha fazla',
    'weekendPatternLess': 'Hafta sonu daha az',
    'smokingBreakExists': 'İş yerinde sigara molası var mı?',
    'break1Start': '1. mola başlangıç',
    'break1End': '1. mola bitiş',
    'break2Exists': '2. mola var',
    'break2Start': '2. mola başlangıç',
    'break2End': '2. mola bitiş',
    'updatedWorkStart': 'Yeni mesai başlangıç saati',
    'updatedWorkEnd': 'Yeni mesai bitiş saati',
    'updatedWorkplaceRule': 'İş yerinde sigara kuralı',
    'searchLanguages': 'Dilleri ara...',
    'otherLanguages': 'Diğer diller',
    'backToMain': 'Ana listeye dön',
    'notSpecified': 'Belirtilmedi',
    'unknownValue': 'Bilinmiyor',
    'breathRestInstruction':
        'Kısa dinlenme: Normal nefes alın.\nSonraki denemeye hazırlanın.',
    'breathActiveInstruction':
        '1. Dik oturun ve rahatlayın.\n2. Daireye dokunup burnunuzdan ciğerlerinizi tamamen dolduracak şekilde derin bir nefes alın, kısa bir süre tutun.\n3. Nefesinizi ANİDEN ve olabildiğince güçlü, tek seferde verin.\n4. Verme işlemi bitince daireye tekrar dokunun.\n\n3 deneme yapılacak, en iyi skor kaydedilir.',
    'breathExerciseDisclaimer':
        'Bu bir spirometre değildir. Kendi ilerlemeni takip etmen için bir ölçüm.',
    'breathSpirometryResultTitle': 'Nefes Testi Sonucu',
    'breathScoreLabel': 'Nefes Skoru',
    'breathScoreDisclaimer':
        'Bu skor kendi geçmişine göre bir karşılaştırmadır; tıbbi bir ölçüm değildir.',
    'breathSpirometryEstimateDisclaimer':
        'Bu bir tıbbi tanı araçı değildir. Sağlıkla ilgili bir endişeniz varsa doktorunuza danışın.',
    'micRationaleTitle': 'Mikrofon izni',
    'micRationaleMessage':
        'Nefes verme süresini otomatik ölçmek için mikrofonu kullanabiliriz. Ses hiçbir zaman kaydedilmez veya saklanmaz; yalnızca anlık ses seviyesi ölçülür. İzin vermezsen testi elle (dokunarak) bitirebilirsin.',
    'restingLabel': 'Dinlenme',
    'secondsLeftLabel': 'saniye kaldı',
    'tapCircleToFinish': 'Bitirince daireye dokunun',
    'breathListeningHint':
        'Dinleniyor... nefesinizi verin, otomatik algılanacak',
    'breathStepSitRelax': 'Dik oturun ve rahatlayın.',
    'breathStepDeepBreath':
        'Ciğerlerinizi tamamen doldurana kadar derin nefes alın.',
    'breathStepHold': 'Kısa bir süre nefesinizi tutun.',
    'breathStepExhale':
        'Mikrofona doğru ANİDEN ve olabildiğince güçlü üfleyin nefesiniz bitene kadar — yavaş değil, tek seferde.',
    'breathStepExhaleFinishHint': 'Nefesiniz otomatik olarak algılanacak.',
    'breathStepOkAction': 'Devam',
    'breathAutoNextAttemptInstruction':
        'Dik oturun ve rahatlayın. Ciğerlerinizi tamamen doldurana kadar derin nefes alın. Kısa bir süre tutun. Mikrofona doğru aniden ve olabildiğince güçlü üfleyin. Nefesiniz otomatik olarak algılanacak.',
    'breathNoiseCheckListening': 'Ortam dinleniyor...',
    'breathNoiseWarningTitle': 'Ortam gürültülü olabilir',
    'breathNoiseWarningMessage':
        'Ortamda biraz gürültü var. Sonuç yine de kaydedilir ama daha sessiz bir yerde daha güvenilir olur. Nasıl devam etmek istersin?',
    'breathNoiseLoudTitle': 'Ortam çok gürültülü',
    'breathNoiseLoudMessage':
        'Ortam gürültüsü test için oldukça yüksek. Devam edebilirsin ama sonuç "gürültülü ortamda alındı" olarak işaretlenecek ve ilerleme grafiğinde ayrıca gösterilecek. Sessiz bir yere geçmeni öneririz.',
    'breathNoiseContinueAnyway': 'Devam Et',
    'breathNoiseRetry': 'Tekrar Dene',
    'breathNoiseDuringAttemptWarning':
        'Test sırasında ortam sesi arttı — bu deneme gürültülü olarak işaretlendi.',
    'coughInsufficientSignalTitle': 'Mikrofon ses algılamadı',
    'coughInsufficientSignalMessage':
        'Bu denemede mikrofon neredeyse hiç ses kaydetmedi — uygulama arka plana alınmış ya da mikrofon başka bir uygulama tarafından kullanılıyor olabilir. Sonuç kaydedilmedi, lütfen tekrar dene.',
    'breathFeedbackTooShort': 'Ciğerlerini tam boşaltmayı dene.',
    'breathFeedbackLowStability': 'Sabit bir güçle üflemeye çalış.',
    'breathFeedbackWeakSignal': 'Telefonu ağzına biraz daha yaklaştır.',
    'breathFeedbackBetterThanBefore': 'Bu denemen öncekinden daha güçlüydü!',
    'breathFeedbackGoodAttempt': 'İyi bir deneme oldu.',
    'breathAnalysisPageTitle': 'Nefes Analizi',
    'breathAnalysisEmptyTitle': 'Henüz veri yok',
    'breathAnalysisEmptyBody':
        'İlk nefes testini tamamladığında burada ilerlemeni gösteren bir grafik ve özet göreceksin.',
    'breathAnalysisEmptyCta': 'Nefes testini başlat',
    'breathAnalysisNotEnoughDataTitle': 'Trend için birkaç test daha gerekiyor',
    'breathAnalysisScoreChartTitle': 'Nefes Skoru — Son 30 Gün',
    'breathAnalysisChartRawLabel': 'Test',
    'breathAnalysisChartAverageLabel': '7 günlük ortalama',
    'breathAnalysisWeeklyAverageTitle': 'Haftalık Ortalama',
    'breathAnalysisSummaryProgressLabel': 'İlerleme',
    'breathAnalysisSummaryBestScoreLabel': 'En İyi Skor',
    'breathAnalysisSummaryConsistencyLabel': 'Tutarlılık',
    'breathAnalysisSummaryTestCountLabel': 'Test Sayısı',
    'breathAnalysisBadgesTitle': 'Rozetler',
    'breathAnalysisNoisyLegend': 'Gürültülü ortamda alındı',
    'breathBadgeFirstTestTitle': 'İlk Adım',
    'breathBadgeFirstTestDesc': 'İlk nefes testini tamamladın.',
    'breathBadgeStreak7Title': '7 Gün Üst Üste',
    'breathBadgeStreak7Desc': '7 gün üst üste nefes testi yaptın.',
    'breathBadgeTotal30Title': '30 Test',
    'breathBadgeTotal30Desc': 'Toplam 30 nefes testi tamamladın.',
    'breathBadgePersonalRecordTitle': 'Kişisel Rekor',
    'breathBadgePersonalRecordDesc': 'Kendi en iyi skorunu geçtin.',
    'disciplineDisclosureTitle': 'Nasıl destek oluyoruz?',
    'disciplineDisclosureMessage':
        'Nikotin Away, seni sigarayı bırakma sürecinde desteklemek için bazı arka plan mekanizmaları kullanır:\n\n'
        '- Bir görev hatırlatmasina zamanında yanit vermezsen, bunu cihazında bir uyum kaydı olarak not ederiz.\n'
        '- Aktif bir görev sırasında, telefon hareketi ve kullanım oruntülerinden (hareket sensörleri ve mikrofon aracılığıyla) olası riskli anları tahmin etmeye çalışırız. Ses kaydedilmez veya saklanmaz; yalnızca ortam ses seviyesi ölçülür.\n'
        '- Bazı görev hatırlatmaları dikkatini çekmek için tam ekran uyarı olarak görünebilir.\n'
        '- Görevlendirme bildirimleri seni gerçek bir telefon görüşmesi sırasında rahatsız etmesin diye, o an görüşme yapip yapmadığını kontrol ederiz; içeriği veya numarayi hiçbir zaman okumayız.\n\n'
        'Bu veriler varsayılan olarak yalnızca cihazında saklanır ve seni desteklemek dışında bir amaçla kullanılmaz. Ayarlar > Bulut Yedekleme üzerinden kendi belirlediğin bir şifreyle isteğe bağlı, şifreli bir yedekleme açabilirsin; bu şifreyi biz de göremeyiz, sadece sen bilirsin. Devam ederek bunu onaylamış olursun; mikrofon, hareket ve telefon durumu izinlerini bir sonraki adımda ayrica onaylayabilir ya da reddedebilirsin.',
    'disciplineDisclosureAcknowledge': 'Anladim, devam et',
    'cravingSosButton': 'Krizdeyim',
    'quickActionSmokedNow': 'Sigara İçtim',
    'quickActionSmokedNowConfirmed': 'Kaydedildi.',
    'quickActionSelfChallenge': 'Meydan Oku',
    'quickActionOpenApp': 'Uygulamayı Ac',
    'selfChallengeTitle': 'Kendi Meydan Okuman',
    'selfChallengeDurationPrompt': 'Ne kadar süreyle sigara içmeyeceksin?',
    'selfChallengeDurationOption': '{minutes} dakika',
    'selfChallengeInProgress': 'Sigara içmeden devam ediyorsun.',
    'selfChallengeDone': 'Süren doldu, tebrikler!',
    'selfChallengeCloseButton': 'Kapat',
    'selfChallengeGiveUpButton': 'Şimdilik bırak',
    'surveyDraftFoundTitle': 'Kaldıgın yerden devam et',
    'surveyDraftFoundMessage':
        'Daha önce yarım bıraktıgın bir anket bulduk. Kaldıgın yerden devam etmek ister misin?',
    'surveyDraftResume': 'Devam et',
    'surveyDraftDiscard': 'Baştan başla',
    'breathAttemptImplausible':
        'Bu deneme geçerli görünmüyor (çok kısa ya da çok uzun). Lütfen tekrar deneyin.',
    'breathAttemptDiscardedBackgrounded':
        'Uygulama arka plana alındığı için bu deneme iptal edildi. Lütfen tekrar deneyin.',
    'completeRegistrationError':
        'Kaydı tamamlanırken bir hata oluştu. Lütfen tekrar deneyin.',
    'cigaretteUnit': 'sigara',
    'dayUnit': 'gün',
    'exhaleCapacity': 'Nefes Verme Kapasitesi (Exhale)',
    'inhaleCapacity': 'Nefes Alma Kapasitesi (Inhale)',
    'trendLabel': 'Trend',
    'levelLabel': 'Seviye',
    'totalTestCount': 'Toplam Test Sayısı',
    'firstTestDate': 'İlk test',
    'averageExhale': 'Ortalama Exhale',
    'averageInhale': 'Ortalama Inhale',
    'minLabel': 'Min',
    'maxLabel': 'Max',
    'exhaleLabel': 'Exhale',
    'inhaleLabel': 'Inhale',
    'few': 'Az',
    'veryHigh': 'Çok',
    'weeklyAvgDailyCigarettes': 'Ortalama günlük sigara',
    'asthma': 'Astım',
    'chainSmokingAsk': 'Arka arkaya sigara içer misin?',
    'chainSmokingCountAsk': 'Genelde kaç adet arka arkaya içiyorsun?',
    'chainSmokingSituation': 'Ardışık içim durumu',
    'continueWithoutPermission': 'Izinsiz devam et',
    'copd': 'KOAH',
    'diabetes': 'Diyabet',
    'firstCigarette0to5': 'Uyandıktan 0-5 dk sonra',
    'firstCigarette5to10': 'Uyandıktan 5-10 dk sonra',
    'firstCigarette30to60': 'Uyandıktan 30-60 dk sonra',
    'firstCigarette60plus': 'Uyandıktan 60+ dk sonra',
    'fivePack': '5 paket',
    'fivePlusCig': '5+ adet',
    'fourCig': '4 adet',
    'fourPack': '4 paket',
    'hypertension': 'Hipertansiyon',
    'initialRecordTitle': 'Başlangıç Kaydı',
    'lessThanOnePack': '1 paketten az',
    'notificationPermissionRequired':
        'Bildirim izni olmadan hatırlatıcılar çalışmayabilir.',
    'onePack': '1 paket',
    'onlyBreaks': 'Sadece mola saatlerinde',
    'onlyBreaksBetweenLectures': 'Sadece ders aralarında',
    'openAlarmReminderSettings': 'Alarm/Hatırlatıcı Ayarları',
    'openSettings': 'Ayarları Ac',
    'packsApproxQuestion': 'Yaklaşık kaç paket?',
    'permissionsRetryMessage':
        'Gerekli izinler olmadan uygulama özellikleri sınırlı çalışır.',
    'permissionsRetryTitle': 'İzinleri tekrar dene',
    'professionEngineer': 'Mühendis',
    'professionFreelance': 'Serbest',
    'professionHealthcare': 'Sağlık Çalışanı',
    'professionOfficer': 'Memur',
    'professionOther': 'Diğer',
    'professionRetired': 'Emekli',
    'professionSalaried': 'Ücretli',
    'professionStudent': 'Öğrenci',
    'professionTeacher': 'Öğretmen',
    'professionTradesman': 'Esnaf',
    'professionWorker': 'İşçi',
    'quitChildren': 'Çocuklarım için',
    'quitFamily': 'Ailem için',
    'quitMoney': 'Maddi nedenler',
    'quitPerformance': 'Performansımı artırmak',
    'campusSmoking': 'Kampüste sigara serbest mi?',
    'firstLectureStart': 'İlk ders başlangıcı',
    'lastLectureEnd': 'Son ders bitişi',
    'schoolEnd': 'Okul bitiş',
    'schoolSmoking': 'Okulda sigara serbest mi?',
    'schoolStart': 'Okul başlangıç',
    'schoolTypeHighSchool': 'Lise',
    'schoolTypeLabel': 'Okul türü',
    'schoolTypeUniversity': 'Üniversite',
    'sensorPermissionRecommended':
        'Daha doğru takip için hareket/sensor izni önerilir.',
    'sevenPlusPack': '7+ paket',
    'sixPack': '6 paket',
    'sleepTime': 'Uyku saati',
    'smokeFree0to15': '0-15 dakika',
    'smokeFree15to30': '15-30 dakika',
    'smokeFree60to120': '60-120 dakika',
    'smokeFree120to240': '120-240 dakika',
    'smokeFree240plus': '240+ dakika',
    'stressHigh': 'Yüksek',
    'interventionIntensityTitle': 'Müdahale şiddeti',
    'interventionIntensityHint':
        'Uygulamanın seni gün içinde ne sıklıkla uyarıp görevlendireceğini seçer.',
    'triggerTitleHint': 'Bunlardan hangileri seni sigara içmeye tetikliyor?',
    'interventionIntensityGentle': 'Nazik',
    'interventionIntensityBalanced': 'Dengeli',
    'interventionIntensityStrict': 'Sıkı',
    'stressLow': 'Düşük',
    'threeCig': '3 adet',
    'threePack': '3 paket',
    'threePlusPack': '3+ paket',
    'twoCig': '2 adet',
    'twoPack': '2 paket',
    'validationChainCountRequired': 'Lütfen ardışık içim adedini seçin.',
    'validationChainHabitRequired': 'Lütfen ardışık içim durumunu seçin.',
    'validationFirstCigaretteRequired':
        'Lütfen ilk sigarayı ne zaman içtiğinizi seçin.',
    'validationFixHighlightedFields': 'Lütfen işaretli alanları düzeltin.',
    'validationSleepTimeRequired': 'Lütfen uyku saatini seçin.',
    'validationSmokeYearsRange':
        'Sigara süresi 0 ile 90 yıl arasında olmalıdır.',
    'validationWakeTimeRequired': 'Lütfen uyanış saatini seçin.',
    'wakeTime': 'Uyanış saati',
    'workEnd': 'Mesai bitiş',
    'workplaceSmoking': 'Is yerinde sigara içiliyor mu?',
    'workStart': 'Mesai başlangıç',
    'weeklyComparedLastWeek': 'Geçen haftaya göre',
    'weeklyDecrease': 'Azaldı',
    'weeklySame': 'Aynı',
    'weeklyIncrease': 'Arttı',
    'surveySummaryTitle': 'Cevapların ne değiştirdi',
    'surveySummaryFirstScore':
        'İlk haftalık kaydın alındı. Risk skorun: {score}/100. '
        'Önümüzdeki hafta bunun nasıl değiştiğini göreceksin.',
    'surveySummaryScoreDown':
        'Risk skorun {previous} → {score} ({delta} puan düştü).',
    'surveySummaryScoreUp':
        'Risk skorun {previous} → {score} ({delta} puan yükseldi).',
    'surveySummaryScoreSame': 'Risk skorun {score}/100, geçen haftayla aynı.',
    'surveySummaryTriggers':
        'Zorlandığını söylediğin durumlar: {triggers}. Görevler bu saatlere '
        'göre ayarlanacak.',
    'surveySummaryRiskyHours': 'En riskli saatlerin: {hours}.',
    'surveySummaryPlan':
        'Yarınki plan: sigara arası hedef {minutes} dakika, {mode} tempo.',
    'surveyMode_aggressive': 'sıkı',
    'surveyMode_balanced': 'dengeli',
    'surveyMode_protective': 'rahat',
    'weeklyLapseCount': 'Bu hafta kaç kez hedefini aştın?',
    'weeklyCravingPeak': 'En zorlandığın an ne kadar zorluydu? (0-10)',
    'weeklyWithdrawalHint':
        'Bu hafta yaşadıklarını işaretle. Hiçbiri yoksa boş bırak.',
    'weeklyWithdrawal_irritability': 'Sinirlilik',
    'weeklyWithdrawal_anxiety': 'Huzursuzluk',
    'weeklyWithdrawal_sleepProblem': 'Uyku sorunu',
    'weeklyWithdrawal_concentrationProblem': 'Odaklanamama',
    'weeklyWithdrawal_appetiteIncrease': 'İştah artışı',
    'weeklyTriggerHint':
        'Bu hafta hangi durumlarda sigara isteği geldi? Hepsini işaretleyebilirsin.',
    'weeklyTrigger_coffee': 'Kahve / çay',
    'weeklyTrigger_meal': 'Yemek sonrası',
    'weeklyTrigger_driving': 'Araba kullanırken',
    'weeklyTrigger_stress': 'Stres / gerginlik',
    'weeklyTrigger_phone': 'Telefonla konuşurken',
    'weeklyTrigger_social': 'Arkadaş ortamı',
    'weeklyTrigger_alcohol': 'Alkol',
    'weeklyOutlookTitle': 'Bu Haftaki Bakışın',
    'weeklySurveyGeneralStatus': 'Genel Durum',
    'copdDisclaimerNotDiagnostic':
        'Bu bölüm tanı testi değildir. KOAH tanısı için spirometri ve doktor değerlendirmesi gerekir. Sonuçlar takip amaçlıdır.',
    'breathInsightNotEnoughTests':
        'İlerlemeni görmek için birkaç test daha yap.',
    'breathInsightNotEnoughSpan':
        'İlerlemeni karşılaştırmak için biraz daha zamana yayılmış testler gerekiyor.',
    'breathInsightSignificantImprovement':
        'Belirgin iyileşme — üfleme skorun %{percent} arttı.',
    'breathInsightGradualImprovement':
        'Yavaş ama istikrarlı bir ilerleme var — %{percent} artış.',
    'breathInsightStable': 'Sabit seyrediyor, önemli bir değişim yok.',
    'breathInsightDecline':
        'Bu hafta biraz düşük görünüyor — hasta veya yorgunsan bu normal olabilir. Solunum şikayetin varsa doktoruna danış.',
    'channelNamePostponeChoice': 'Görev erteleme seçimi',
    'channelNameTaskConfirm': 'Görev sonu onayı',
    'channelNameHealthTip': 'Sağlık tavsiyesi',
    'channelNameMedicationReminder': 'İlaç hatırlatması',
    'channelNameTaskUpdateReminder': 'Görev güncelleme hatırlatıcı',
    'channelNameFirstTaskTrigger': 'İlk görev tetikleme',
    'channelNameBreathTestReminder': 'Nefes testi hatırlatıcı',
    'channelNameTaskFollowUpReminder': 'Görev takip hatırlatıcı',
    'channelNameWeeklySurveyReminder': 'Haftalık anket hatırlatıcı',
    'channelNameTaskTimerStart': 'Görev zamanlayıcı başlangıcı',
    'channelNameDurationBarrierCall': 'Süre engeli araması',
    'channelNameMovementReminder': 'Hareket hatırlatıcı',
    'channelNameCoachSuggestion': 'Koç önerisi',
    'channelNameLocationReminder': 'Nikotin Away Konum Hatırlatıcı',
    'channelDescriptionLocationReminder':
        'Sık gidilen bir yere varıldığında gösterilen hatırlatma',
    'taskOverlayChannelName': 'Nikotin Away Görev Ekranı',
    'taskOverlayChannelDescription': 'Odak ekranı gösterilirken aktif',
    'taskOverlayForegroundBody': 'Görev ekranı gösteriliyor',
    'snoringCaptureChannelName': 'Nikotin Away Uyku Zekası',
    'snoringCaptureNotificationTitle': 'Nikotin Away',
    'snoringCaptureNotificationBody':
        'Horlama tespiti için kısa bir ses örneği alınıyor',
    'channelNameSmokedLogQuickAction': 'Nikotin Away Hızlı Kayıt',
    'channelDescriptionSmokedLogQuickAction':
        'Sigara içtim butonu ekranda dururken aktif',
    'registrationMissingFields': 'Lütfen eksik alanları doldurun.',
    'registrationProfileCreationFailed':
        'Profil oluşturulamadı. Lütfen tekrar deneyin.',
    'registrationRiskAnalysisFailed':
        'Risk analizi oluşturulamadı. Lütfen tekrar deneyin.',
    'registrationFlagSaveFailed':
        'Kayıt bayrağı kaydedilemedi. Lütfen tekrar deneyin.',
    'breathTestSaveFailed':
        'Nefes testi sonucu kaydedilemedi. Lütfen tekrar deneyin.',
    'barrierStartedInstruction':
        'Lütfen önümüzdeki {duration} boyunca sigara içmeyin. Elinizde sigara varsa hemen söndürün.',
    'severityLevel0': 'Hiç yok',
    'severityLevel1': 'Çok az',
    'severityLevel2': 'Az',
    'severityLevel3': 'Orta',
    'severityLevel4': 'Fazla',
    'severityLevel5': 'Çok fazla',
    'frequencyNever': 'Hiç olmadı',
    'frequencyOneOrTwoNights': 'Bir iki gece',
    'frequencyMostNights': 'Çoğu gece',
    'frequencyEveryNight': 'Neredeyse her gece',
    'weeklyRespTitle': 'Solunum Kontrolü',
    'weeklyRespHint':
        'Son bir haftayı düşünerek yanıtla. Bu bir tanı testi değil, '
        'zaman içindeki değişimi görmek için.',
    'weeklyCoughExample': 'Sabah kalkınca ya da gün içinde öksürüyor musun?',
    'weeklyBreathlessnessStairsExample':
        'Bir kat merdiven çıkınca durup nefeslenmen gerekiyor mu?',
    'weeklySleepImpact': 'Uykuna etkisi',
    'weeklySleepImpactExample':
        'Öksürük ya da nefes darlığı yüzünden gece uyanıyor musun?',
    'weeklyEnergyImpact': 'Enerjine etkisi',
    'weeklyEnergyImpactExample':
        'Gün içinde eskisine göre daha çabuk yoruluyor musun?',
    'mmrcPlain0': 'Nefes darlığı yaşamıyorum.',
    'mmrcPlain1':
        'Sadece hızlı yürürken ya da hafif yokuşta nefesim daralıyor.',
    'mmrcPlain2':
        'Düz yolda kendi hızımda yürürken yaşıtlarımdan geride kalıyorum.',
    'mmrcPlain3':
        'Düz yolda yaklaşık 100 metre yürüyünce durup nefeslenmem gerekiyor.',
    'mmrcPlain4':
        'Evden çıkamayacak kadar ya da giyinirken bile nefesim daralıyor.',
    'weeklyCravingAvg': 'Craving ortalama (0-10)',
    'weeklyCravingMax': 'Craving maksimum (0-10)',
    'weeklyWithdrawalSymptoms': 'Yoksunluk belirtileri (0-3)',
    'weeklyIrritability': 'Sinirlilik',
    'weeklyAnxiety': 'Anksiyete',
    'weeklySleepIssue': 'Uyku problemi',
    'weeklyConcentrationIssue': 'Konsantrasyon problemi',
    'weeklyAppetiteIncrease': 'İştah artışı',
    'weeklyTriggerExposure': 'Tetikleyici maruziyeti (gün/saat 0-7)',
    'weeklyVehicleUse': 'Araç kullanımı',
    'weeklyAlcoholTrigger': 'Alkol tetiği',
    'weeklyAlcoholDays': 'Alkol kullanılan gün',
    'weeklySocialSmokingDays': 'Sigaralı sosyal ortam günü',
    'weeklyMedicationUse': 'Tedavi/NRT kullanımı',
    'weeklyNone': 'Yok',
    'weeklyIrregular': 'Düzenli değil',
    'weeklyRegular': 'Düzenli',
    'weeklySideEffectsExperienced': 'İlaç/NRT yan etkisi yaşandı',
    'weeklyUsedCounseling': 'Danışmanlık/quitline kullanıldı',
    'weeklyMedicationAdherence': 'Tedavi uyumu (0-10)',
    'weeklyFamilySupport': 'Aile/sosyal destek (0-10)',
    'weeklySelfEfficacy': 'Öz yeterlilik (0-10)',
    'weeklyMotivation': 'Motivasyon (0-10)',
    'weeklyTaskCompletion': 'Haftalık görev tamamlama (0-10)',
    'weeklyTaskAdherence': 'Günlük görevlere ne kadar uydun?',
    'weeklyCommandBurden': 'Komutlar seni rahatsız etti mi?',
    'weeklyDailyBreathTarget': 'Günlük nefes testi sayısı tercihin (min 1)',
    'weeklyBreathOnceMandatory': '1 kez (zorunlu minimum)',
    'weeklyBreathTwice': '2 kez',
    'weeklyBreathThree': '3 kez',
    'weeklyBreathFour': '4 kez',
    'weeklyMmrcGrade': 'Nefes darlığı derecesi (mMRC benzeri 1-5)',
    'weeklyMmrc1': '1 - Sadece hızlı yürüyüşte/yokuşta zorlanma',
    'weeklyMmrc2': '2 - Düz yolda yaşıtlara göre daha yavaş',
    'weeklyMmrc3': '3 - Düz yolda bir süre sonra durma ihtiyacı',
    'weeklyMmrc4': '4 - 100 metre civarı yürüyüşte durma',
    'weeklyMmrc5': '5 - Ev içinde belirgin nefes darlığı',
    'weeklyRespiratoryBurden': 'Solunum semptom yükü (CAT benzeri 0-5)',
    'weeklyCough': 'Öksürük',
    'weeklyPhlegm': 'Balgam',
    'weeklyChestTightness': 'Göğüste sıkışma',
    'weeklyBreathlessnessStairs': 'Merdiven/yokuş nefes darlığı',
    'weeklyActivityLimitation': 'Günlük aktivite kısıtlanması',
    'weeklyConfidenceLeavingHome': 'Dışarı çıkma güveni düşüklüğü',
    'weeklySleepQualityResp': 'Solunuma bağlı uyku bozulması',
    'weeklyEnergyLevelResp': 'Solunuma bağlı enerji düşüklüğü',
    'weeklyWarningSigns': 'Uyarı işaretleri (haftalık gün 0-7)',
    'weeklyNightBreathlessness': 'Gece artan nefes darlığı',
    'weeklySputumIncrease': 'Balgam artışı',
    'weeklySputumColorChange': 'Balgam renginde değişim',
    'weeklyWheeze': 'Hırıltı/wheeze',
    'weeklyLunchTime': 'Tahmini öğle yemeği saati',
    'weeklyDinnerTime': 'Tahmini akşam yemeği saati',
    'weeklyProfileChanged':
        'İlk profile göre iş/uyku/çalışma düzeni değişti mi?',
    'weeklyQuickModeInfo':
        'Hızlı mod seçili. Temel sorulara göre risk otomatik hesaplanır. İstersen Detaylı moda geçip tüm parametreleri düzenleyebilirsin.',
    'durationBarrierNeutral': 'Farketmez',
    'durationBarrierEnabledTitle': 'Sigara içmeme süresi bariyeri',
    'durationBarrierEnabledDescription':
        'Kapatırsan sigaralar arası süreyi uzatmanı isteyen görevler gelmez.',
    'durationBarrierFrequencyHow': 'Sigara içmeme süresi sıklığı nasıl olmalı?',
    'respClinicalReview': 'Klinik değerlendirme önerilir',
    'respMonitorCloser': 'Yakın izlem',
    'respStable': 'Stabil',
    'dailyBreathMandatoryTitle': 'Günlük nefes testi gerekli',
    'dailyBreathMandatoryContent':
        'Gelişimi doğru takip etmek için her gün en az 1 profesyonel nefes testi yapılmalı. Şimdi testi başlatalım.',
    'dailyBreathMandatoryStart': 'Testi Başlat',
    'weeklyMandatoryTitle': 'Haftalık anket zorunlu',
    'weeklyMandatoryContent':
        'Risk skorunun güncel kalması için en az 7 günde bir haftalık anket doldurmalısın.',
    'weeklyMandatoryGo': 'Ankete git',
    'commandSaved': 'Komut tamamlandı olarak kaydedildi.',
    'barrierStartedTitle': 'Sigara içmeme süresi başladı',
    'barrierStartedBody': 'Sigara içmeme sayaçı çalışıyor.',
    'barrierStartedDuration': 'Sayaç süresi',
    'smokeFreeCounterTitle': 'Sigara içmeme sayaçı',
    'smokeFreeCounterRemaining': 'Kalan süre',
    'weeklyRiskLine': 'Haftalık anket riski',
    'respiratoryStatusLine': 'Respiratuar durum',
    'weeklyTopDriversLine': 'Haftalık üst risk etkenleri',
    'commandModeLabel': 'Komut modu',
    'advancedSectionTitle': 'Gelişmiş',
    'learnedWeightsLabel': 'Öğrenilen ağırlıklar',
    'personalCommandsTitle': 'Kişisel komutlar',
    'durationBarriersTitle': 'Sigara içmeme süreleri (ayrı çalışır)',
    'doneShort': 'Tamam',
    'defer10m': 'Ertele 10 dk',
    'commandScoreLabel': 'Komut başarı puanları',
    'categoryInsightLabel': 'Kategori başarı içgörüsü',
    'riskScoreExplanationTitle': 'Risk skoru açıklaması',
    'riskExplanationBaseTemplate': 'Baz skor: {score}',
    'riskExplanationBehaviorDeltaTemplate': 'Davranış/trend etkisi: {score}',
    'riskExplanationPersonalizedDeltaTemplate':
        'Nefes + anket kişisel etki: {score}',
    'riskExplanationProfileDeltaTemplate': 'Profil etkisi: {score}',
    'riskExplanationTaskDeltaTemplate': 'Görev performans etkisi: {score}',
    'riskExplanationFinalTemplate': 'Sonuç risk skoru: {score}',
    'quickMenuTitle': 'Hızlı menu',
    'menuSectionTestsAndSurveys': 'Testler ve Anketler',
    'menuSectionTrackingAndReports': 'Takip ve Raporlar',
    'menuBreathTest': 'Nefes Egzersizi',
    'menuWeeklySurvey': 'Haftalık Anket',
    'menuPersonalProgress': 'Kişisel Takip',
    'menuViolationReport': 'Zorlandığın Anlar',
    'menuSurveyHistory': 'Anket Geçmişi',
    'menuLogSmokingNow': 'Şimdi içtim',
    'menuDailyCheckIn': 'Günlük Değerlendirme',
    'mentorCardTitle': 'Mentorunden',
    'aiMentorButton': 'Yapay Zeka Mentoru',
    'aiChatTitle': 'Yapay Zeka Mentoru',
    'aiChatHistory': 'Sohbet geçmişi',
    'aiChatMenuPin': 'Sabitle',
    'aiChatMenuUnpin': 'Sabitlemeyi kaldır',
    'aiChatMenuRename': 'Yeniden adlandır',
    'aiChatMenuInvite': 'Davet et',
    'aiChatMenuCopy': 'Kopyasını gönder',
    'aiChatMenuSummary': 'Bir sayfada özetle',
    'aiChatMenuMove': 'Projelere taşı',
    'aiChatMenuReport': 'Endişe bildir',
    'aiChatMenuDelete': 'Sil',
    'aiChatMenuCancel': 'İptal',
    'aiChatRenameTitle': 'Sohbeti yeniden adlandır',
    'aiChatProjectTitle': 'Projeye taşı',
    'aiChatProjectHint': 'Proje adı',
    'aiChatReportTitle': 'Endişe bildir',
    'aiChatReportHint': 'Neyi bildirmek istiyorsunuz?',
    'aiChatSummaryTitle': 'Sohbet özeti',
    'aiChatSummaryEmpty': 'Bu sohbette henüz özetlenecek mesaj yok.',
    'aiChatDeleteConfirm': 'Bu sohbet silinsin mi?',
    'aiChatNewConversation': 'Yeni sohbet',
    'aiChatNoConversations': 'Henüz sohbet yok',
    'aiChatMessageCount': '{count} mesaj',
    'aiChatHint': 'Mesaj yaz...',
    'aiChatSend': 'Gönder',
    'aiChatError': 'Mesaj gönderilemedi, tekrar deneyin.',
    'aiChatDailyLimitReached':
        'Bugünlük mesaj hakkın doldu, yarın tekrar yazabilirsin.',
    'aiChatAuthNotReady': 'Kimlik doğrulanamadı, birazdan tekrar dene.',
    'aiChatDisclaimer':
        'Bu bir yapay zeka asistanıdır, tıbbi tavsiye vermez. Sağlık konularinda doktorunuza danışın.',
    'aiChatActionApply': 'Uygula',
    'aiChatActionDismiss': 'Vazgeç',
    'aiChatActionFailed': 'Bu değişiklik uygulanamadı.',
    'aiChatActionAppliedCoachMode': 'Koç Modu ayarı güncellendi.',
    'aiChatActionAppliedMedication': 'İlaç hatırlatma saatleri güncellendi.',
    'aiChatActionAppliedPermission': 'İzin isteği açıldı.',
    'aiChatMicTooltip': 'Dokunup konuşun',
    'aiChatListening': 'Dinliyorum...',
    'aiChatMicPermissionDenied': 'Sesli giriş için mikrofon izni gerekiyor.',
    'aiChatMicUnavailable': 'Bu cihazda sesli giriş kullanılamıyor.',
    'mentorReplySentPrefix': 'Yanitin',
    'miuiPermissionTitle': 'Bir izin daha gerekiyor',
    'miuiPermissionMessage':
        'Telefonun görevlendirme ekranını kilitli ekranda da gösterebilmesi için {brand} telefonlarda ek bir izin gerekiyor. Şimdi ayar ekranını açalım mi?',
    'miuiPermissionOpen': 'Ayarları Ac',
    'miuiPermissionSkip': 'Daha Sonra',
    'settingsTitle': 'Ayarlar',
    'settingsSectionGeneral': 'Genel',
    'settingsSectionPrivacy': 'Gizlilik & Izinler',
    'settingsSectionData': 'Veri',
    'settingsLanguageRow': 'Dil',
    'cloudBackupRow': 'Bulut Yedekleme',
    'cloudBackupRowSubtitle': 'Verilerini şifreli olarak buluta yedekle',
    'cloudBackupPhoneChangeWarning':
        'Telefonunu değiştirirsen veya uygulamayı silersen, verilerini geri alman için tek yol önceden buradan bir yedek almış olman. Bulut Yedekleme kapalıysa telefon değişiminde tüm veriler kalıcı olarak kaybolur.',
    'cloudRestoreRow': 'Bulut Yedeğinden Geri Yükle',
    'cloudRestoreRowSubtitle':
        'Daha önce yedeklediğiniz verileri bu cihaza geri getir',
    'cloudBackupPassphraseHint':
        'Şimdi yeni bir şifre belirle. Bu şifre yalnızca sende saklanır, biz hiçbir zaman göremeyiz. Şifreyi unutursan yedeğini geri getiremeyiz, güvenli bir yere not al.',
    'cloudBackupPassphraseLabel': 'Yeni şifre (en az 6 karakter)',
    'cloudRestorePassphraseHint':
        'Daha önce yedeklerken belirlediğin şifreyi gir. Yanlış şifre girersen yedeğin bulunamaz.',
    'cloudRestorePassphrase': 'Yedekleme parolası',
    'cloudRestorePassphraseLabel': 'Yedekleme şifren',
    'cloudBackupPassphraseTooShort': 'Şifre en az 6 karakter olmalı.',
    'cloudBackupInProgress': 'İşleniyor, lütfen bekleyin...',
    'cloudBackupSuccess': 'Yedekleme tamamlandı.',
    'cloudBackupFailed': 'Yedekleme başarısız oldu. Lütfen tekrar deneyin.',
    'cloudRestoreConfirmMessage':
        'Bu cihazdaki mevcut verilerin yerine yedekteki veriler yazılacak. Devam etmek istiyor musun?',
    'cloudRestoreSuccess':
        'Geri yükleme tamamlandı. Uygulamayı yeniden başlat.',
    'cloudRestoreNotFound': 'Bu şifreyle eşleşen bir yedek bulunamadı.',
    'cloudRestoreFailed': 'Geri yükleme başarısız oldu. Şifreni kontrol et.',
    'settingsPermissionsRow': 'İzin Merkezi',
    'settingsPermissionsRowSubtitle':
        'Hangi izinleri neden kullandığımızı görün',
    'settingsResetDataRow': 'Verilerimi Sıfırla',
    'settingsResetDataSubtitle': 'Tüm kayıtlarını kalıcı olarak siler',
    'settingsResetDataConfirmTitle': 'Emin misin?',
    'settingsResetDataConfirmMessage':
        'Tüm sigara kayıtların, anket sonuçların ve ilerlemen kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    'settingsResetDataConfirmAction': 'Evet, Sil',
    'settingsResetDataDone': 'Verilerin silindi.',
    'accountDeleteRow': 'Hesabımı ve bulut verilerimi sil',
    'accountDeleteSubtitle':
        'Hesabını ve Firebase bulut verilerini kalıcı olarak siler',
    'accountDeleteTitle': 'Hesabı sil?',
    'accountDeleteMessage':
        'Hesabın, bulut verilerin ve bu cihazdaki kayıtların kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    'accountDeleteAction': 'Hesabı ve verileri sil',
    'accountDeleteDone': 'Hesabın ve bulut verilerin silindi.',
    'accountDeleteFailed': 'Hesap silinemedi. Lütfen tekrar dene.',
    'accountDeleteRecentLogin':
        'Güvenlik nedeniyle önce yeniden giriş yapman gerekiyor.',
    'accountDeleteRequiresLogin':
        'Hesap silmek için önce Google veya e-posta hesabınla giriş yapmalısın.',
    'permissionsCenterTitle': 'İzin Merkezi',
    'permissionsCenterIntro':
        'Bu izinleri neden istediğimizi ve nasıl kullandığımızı aşağıda bulabilirsin. Hepsi opsiyoneldir, istediğin zaman kapatabilirsin.',
    'permissionStatusGranted': 'Verildi',
    'permissionStatusDenied': 'Verilmedi',
    'permissionActionRequest': 'İzin Ver',
    'permissionActionOpenSettings': 'Ayarları Ac',
    'permissionActionManage': 'Ayarlardan Yönet',
    'permissionNotificationsTitle': 'Bildirimler',
    'permissionNotificationsDescription':
        'Görev hatırlatmaları, nefes testi ve mentorundan gelen mesajlar için kullanılır.',
    'permissionNotificationsPurpose':
        'Neden: Sana doğru zamanda destek olabilmemiz için gerekli.',
    'permissionMicrophoneTitle': 'Mikrofon',
    'permissionMicrophoneDescription':
        'Günlük nefes testinde akciğerlerinin durumunu ölçmek için kullanılır.',
    'permissionMicrophonePurpose':
        'Neden: Ses sadece cihazında işlenir, kaydedilmez veya paylaşılmaz.',
    'permissionActivityTitle': 'Fiziksel Aktivite',
    'permissionActivityDescription':
        'Hareketlerini anlayarak sana daha uygun zamanlarda destek önerileri sunmak ve günlük adım sayını takip etmek için kullanılır.',
    'permissionActivityPurpose':
        'Neden: Aktivite ve adım verilerin cihazından dışarı çıkmaz.',
    'permissionPhoneTitle': 'Telefon Durumu',
    'permissionPhoneDescription':
        'Sahte destek aramasının gerçek bir arama ile çakışmaması için kullanılır.',
    'permissionPhonePurpose':
        'Neden: Arama numaralarını veya içeriğini asla okumayız.',
    'permissionExactAlarmTitle': 'Kesin Zamanlama',
    'permissionExactAlarmDescription':
        'Hatırlatmaların ve mentör mesajlarının tam zamanında gelmesini sağlar.',
    'permissionExactAlarmPurpose':
        'Neden: Android bu izni sistem ayarlarından yönetir.',
    'permissionExactAlarmAlreadyGranted': 'Bu izin zaten verilmiş.',
    'permissionMiuiTitle': 'Xiaomi Ek Izni',
    'permissionMiuiDescription':
        'Sahte destek aramasının kilitli ekranda da görünebilmesi için Xiaomi telefonlarda gereklidir.',
    'permissionMiuiPurpose':
        'Neden: MIUI, diğer Android telefonlardan farklı bir izin sistemi kullanır.',
    'permissionLocationTitle': 'Konum',
    'permissionLocationDescription':
        'Sık gittiğin yerleri öğrenip vardığında kısa bir hatırlatma göstermek için kullanılır (Konum Zekası özelliği, varsayılan kapalı).',
    'permissionLocationPurpose':
        'Neden: Ham konum geçmişi hiçbir zaman kaydedilmez. Detaylar ve açma/kapama için dokunun.',
    'permissionBackgroundTitle': 'Arka Planda Çalışma',
    'permissionBackgroundDescription':
        'Bazı telefon üreticileri pil tasarrufu için arka plan uygulamalarını kısıtlar. Bu, hatırlatmaların, uyku/konum/adım takibinin ve destek aramalarının zamanında çalışmasını engelleyebilir.',
    'permissionBackgroundPurpose':
        'Neden: Uygulamanın pil optimizasyonundan muaf tutulması, arka plan özelliklerinin güvenilir çalışmasını sağlar.',
    'permissionBackgroundOpenSettingsAction': 'Arka Plan Ayarlarını Ac',
    'settingsCoachModeRow': 'Koçluk Modu',
    'settingsCoachModeRowSubtitle':
        'Sana ne kadar sık ve ne kadar zorlayıcı destek olsun',
    'coachModeTitle': 'Koçluk Modu',
    'coachModeIntro':
        'Uygulamanın seni ne sıklıkta ve ne kadar zorlayıcı şekilde destekleyeceğini seç. İstediğin zaman değiştirebilirsin.',
    'coachModeEasyTitle': 'Kolay',
    'coachModeEasyDescription':
        'Az sayıda, yumuşak hatırlatma. Kendi hızında ilerlemek isteyenler için.',
    'coachModeNormalTitle': 'Normal',
    'coachModeNormalDescription':
        'Dengeli sıklıkta destek. Çoğu kullanıcı için önerilen mod.',
    'coachModeHardTitle': 'Zor',
    'coachModeHardDescription':
        'Sık ve kararlı hatırlatmalar. Daha fazla disiplin isteyenler için.',
    'coachModeCustomLabel': 'Özel',
    'coachModeCustomDescription':
        'Gelişmiş ayarlardan kendin belirlediğin bir kombinasyon.',
    'coachModeAdvancedToggle': 'Gelişmiş Ayarlar',
    'coachModeSavedConfirmation': 'Koçluk modu güncellendi.',
    'settingsSleepIntelligenceRow': 'Uyku Zekası',
    'sleepIntelligenceTitle': 'Uyku Zekası',
    'sleepIntelligenceDescription':
        'Açık olduğunda, telefonun ekran ve şarj durumunu gece boyunca birkaç kez kontrol ederek uyku saatlerini tahmin etmeye çalışır. Bu tahmin, risk değerlendirmeni daha doğru hale getirmek için kullanılır.',
    'sleepIntelligencePurpose':
        'Neden: Sadece ekran açık/kapalı ve şarjda olup olmadığın kontrol edilir, başka hiçbir şey okunmaz. Yeterli veri yoksa anket sırasında verdiğin uyku saatlerine geri dönülür.',
    'sleepIntelligenceSnoringIncluded':
        'Horlama analizi de aynı gece takibine otomatik olarak dahildir; ayrı bir horlama testi yoktur.',
    'sleepIntelligenceEnabledConfirmation': 'Uyku zekası açıldı.',
    'sleepIntelligenceDisabledConfirmation': 'Uyku zekası kapatıldı.',
    'settingsSnoringDetectionRow': 'Horlama Testi (Deneysel)',
    'snoringDetectionTitle': 'Horlama Testi (Deneysel)',
    'snoringDetectionDescription':
        'Açık olduğunda, uyku saatlerinde birkaç saniyelik kısa ses örnekleri alınıp cihaz üzerinde analiz edilir; horlamaya benzer ritmik bir ses paterni olup olmadığına bakılır. Bu kısa örnekleme sırasında telefonun bildirim çubuğunda mikrofonun açık olduğunu belirten sessiz bir bildirim görürsün -- bu, Android\'in mikrofon kullanan arka plan servisleri için zorunlu tuttuğu bir şeffaflık önlemidir. Ses kaydı hiçbir zaman diske yazılmaz veya dışarıya gönderilmez, sadece sonuç (evet/hayır) kaydedilir.',
    'snoringDetectionPurpose':
        'Neden: Horlama, uyku kalitesini ve dolayısıyla ertesi günkü sigara riskini etkileyebilir. Bu özellik için önce Uyku Zekası özelliği açık olmalıdır, çünkü aynı gece döngüsünü kullanır.',
    'snoringDetectionEnabledConfirmation': 'Horlama testi açıldı.',
    'snoringDetectionDisabledConfirmation': 'Horlama testi kapatıldı.',
    'snoringDetectionRequiresSleepIntelligence':
        'Önce Uyku Zekasını açmalısın, horlama testi onun üzerine çalışır.',
    'snoringDetectionLastNightCount': 'Son gece horlama paterni sayısı',
    'snoringResultNotificationTitle': 'Dün geceki horlama testi',
    'snoringResultNotificationBodyDetected':
        'Dün gece {count} kez horlamaya benzer bir ses paterni tespit edildi. Detaylar için Ayarlar > Horlama Testi\'ne bakabilirsin.',
    'snoringResultNotificationBodyClear':
        'Dün gece horlamaya benzer bir ses paterni tespit edilmedi.',
    'snoringSeverityNone': 'Horlama tespit edilmedi.',
    'snoringSeverityMild': 'Hafif düzeyde horlama tespit edildi.',
    'snoringSeverityModerate': 'Orta düzeyde horlama tespit edildi.',
    'snoringSeveritySevere': 'Belirgin düzeyde horlama tespit edildi.',
    'snoringAdviceMild':
        'Hafif horlama genelde geçicidir. Yan yatarak uyumak ve alkolden kaçınmak faydalı olabilir.',
    'snoringAdviceModerate':
        'Orta düzeyde horlama birkaç gecedir sürmesi halinde, kilo ve uyku pozisyonu gibi yaşam tarzı önlemlerinin yanında bir doktora danışmanı öneririz.',
    'snoringAdviceSevere':
        'Belirgin düzeyde horlama tespit edildi. Bu durum devam ederse lütfen bir doktora danış; bu uygulama tıbbi tanı veya tedavi önerisi vermez.',
    'snoringHomeSummaryCardTitle': 'Dün geceki horlama',
    'snoringHomeSummaryCardBodyDetected':
        'Dün gece {count} kez horlamaya benzer bir ses paterni tespit edildi.',
    'snoringHomeSummaryCardBodyClear':
        'Dün gece horlamaya benzer bir ses paterni tespit edilmedi.',
    'snoringTestTitle': 'Horlama Testi',
    'snoringTestInstructions':
        '60 saniye boyunca mikrofonu açık tutacağız. Ses hiçbir zaman kaydedilmez veya dışarıya gönderilmez, sadece horlama paterni analiz edilir.',
    'snoringTestStartButton': 'Testi Başlat',
    'snoringTestListening': 'Dinleniyor...',
    'snoringTestResultTitle': 'Test Sonucu',
    'snoringTestDaytimeDisclaimer':
        'Bu, uyanıkken alınan bir ses örneğidir. Uykudaki horlamanı ölçmez ve gece özetine dahil edilmez.',
    'menuSnoringTest': 'Horlama Testi',
    'coughTestTitle': 'Öksürük Testi',
    'coughTestIntro':
        'Mikrofonu 10 saniye açık tutacağız. Bu sürede senden birkaç kez öksürmen istenecek ve sesindeki hırıltı paterni analiz edilecek.',
    'coughTestInstructions':
        'Sessiz bir ortamda başla. Normal nefes al ve senden istendiğinde birkaç kez öksür. Ses kaydedilmez veya dışarıya gönderilmez; yalnızca hırıltı paterni analiz edilir.',

    'coughTestStartButton': 'Testi Başlat',
    'coughTestListening': 'Dinleniyor...',
    'coughTestResultTitle': 'Test Sonucu',
    'coughTestResultCount': '{count} öksürük tespit edildi',
    'wheezeDetectedResult': 'Hırıltı tespit edildi',
    'wheezeNotDetectedResult': 'Hırıltı tespit edilmedi',

    'coughGeneralAdvice':
        'Öksürüğün birkaç gündür sürmesi halinde bir doktora danışmanı öneririz; bu uygulama tıbbi tanı veya tedavi önerisi vermez.',
    'coughTestNotificationTitle': 'Öksürük testi sonucun',
    'wheezeFindingSectionTitle': 'Ses Paterni Notu',
    'breathUnusualSoundDetected':
        'Bu testte olağandışı bir ses paterni duyuldu.',
    'breathUnusualSoundAdvice':
        'Tekrarlarsa bir doktora danışmanı öneririz; bu uygulama tıbbi tanı veya tedavi önerisi vermez.',
    'wheezeTestNotificationTitle': 'Nefes testi notu',
    'breathNotDetectedRetryTitle': 'Nefes algılanamadı',
    'breathNotDetectedRetryMessage':
        'Mikrofon nefesini net algılayamadı. Tekrar denemek ister misin?',
    'coughNotDetectedRetryTitle': 'Öksürük algılanamadı',
    'coughNotDetectedRetryMessage':
        'Mikrofon bir öksürük algılamadı. Tekrar denemek ister misin?',
    'retryAttemptButton': 'Tekrar Dene',
    'keepResultAnywayButton': 'Yine de Devam Et',
    'coughTestRequiredForWeeklySurvey': 'Testi Yap',
    'coughTestRequiredDialogTitle': 'Öksürük testi gerekiyor',
    'coughTestRequiredDialogMessage':
        'Haftalık anketi kaydetmeden önce bu hafta bir öksürük testi yapmış olman gerekiyor. Şimdi yapmak ister misin?',
    'coughTestSkip': 'Vazgeç',
    'menuCoughTest': 'Öksürük Testi',
    'settingsWearableIntelligenceRow': 'Bileklik Verisi (Deneysel)',
    'wearableIntelligenceTitle': 'Bileklik Verisi (Deneysel)',
    'wearableIntelligenceDescription':
        'Açık olduğunda, Health Connect üzerinden -eger bir akıllı saat/bileklik uygulaman varsa- nabız ve uyku verini okumaya çalışır. Uygulama saatinle doğrudan konuşmaz, sadece Health Connect deposunda zaten var olan veriyi okur.',
    'wearableIntelligencePurpose':
        'Neden: Anı nabız yükselmeleri, riskli anları daha erken fark etmemize yardımcı olabilir. Saatin/bilekliğin yoksa veya senkronize veri yoksa bu kart boş görünür, başka hiçbir şey değişmez.',
    'wearableIntelligenceEnabledConfirmation': 'Bileklik verisi açıldı.',
    'wearableIntelligenceDisabledConfirmation': 'Bileklik verisi kapatıldı.',
    'wearableIntelligenceUnavailable':
        'Health Connect bu cihazda bulunamadı. Yüklemek ister misin?',
    'wearableIntelligencePermissionDenied':
        'Health Connect izni verilmedi, özellik açılamadı.',
    'wearableIntelligenceInstallAction': 'Health Connect\'i Yükle',
    'wearableIntelligenceLatestHeartRate': 'Son nabız',
    'wearableIntelligenceLastSleep': 'Son uyku süresi',
    'wearableIntelligenceNoData': 'Henüz okunabilir veri yok.',
    'coachCommandTitle': 'Öneri',
    'sedentaryReminderTitle': 'Biraz hareket vakti',
    'sedentaryReminderBody':
        'Bir süre hareketsiz görünüyorsun. Kısa bir yürüyüş, hem bacaklarına hem de sigara isteklerine iyi gelir.',
    'healthTipTitle': 'Sağlık Tavsiyesi',
    'healthTipGeneral1': 'Bugün su içmeyi ve kısa bir yürüyüşü ihmal etme.',
    'healthTipGeneral2':
        'Düzenli uyku, bedenin ve zihnin toparlanmasina yardım eder.',
    'healthTipGeneral3':
        'Stres geldiğinde nefesini yavaşlat ve omuzlarını gevşet.',
    'healthTipGeneral4':
        'Mümkün olduğunca taze hava al ve uzun süre hareketsiz kalma.',
    'healthTipGeneral5':
        'Küçük ve tutarlı sağlık adımları uzun vadede büyük fark yaratır.',
    'healthTipSmoking1':
        'Sigara isteği dalga gibidir; birkaç dakika beklemek onu azaltır.',
    'healthTipSmoking2':
        'Bir sigarayı ertelemek bile kontrolun sende olduğunu hatırlatır.',
    'healthTipSmoking3':
        'Kahve, stres veya mola geldiğinde sigara yerine suyu dene.',
    'healthTipSmoking4':
        'Ellerini meşgul etmek sigara isteğinin geçmesine yardım eder.',
    'healthTipSmoking5':
        'Bugün içmediğin her sigara kalbin ve akciğerlerin için kazanç.',
    'healthTipSmoking6': 'Sigara molası yerine kısa bir yürüyüş yapmayi dene.',
    'healthTipSmoking7':
        'İstek geldiğinde dört sayıda nefes al, altı sayıda ver.',
    'healthTipSmoking8':
        'Sigara dumanından uzaklaşmak isteğinin daha çabuk azalmasını sağlar.',
    'healthTipSmoking9':
        'Bir arkadaşına hedefini söylemek kararını güçlendirebilir.',
    'healthTipSmoking10':
        'Bugün daha az içmek, yarınki kararın için somut bir başlangıçtır.',
    'healthTipSmoking11':
        'Alkol ve sigara isteği birlikte artabilir; ikisini ayırmayı dene.',
    'healthTipSmoking12':
        'Yemekten sonra hemen sigaraya uzanmak yerine sofradan kalkıp yürü.',
    'healthTipSmoking13':
        'Uykusuzluk isteği büyütebilir; bu gece dinlenmeye öncelik ver.',
    'healthTipSmoking14':
        'Sigara isteğini bastırmak yerine onu uc dakika gözlemle.',
    'healthTipSmoking15':
        'Her erteleme, beynine sigarasız da baş edebildiğini öğretir.',
    'healthTipGeneralDisease1':
        'Belirtilerin artarsa doktorunun önerilerine uy ve gecikmeden destek al.',
    'healthTipGeneralDisease2':
        'İlaçlarını doktorunun söylediği şekilde kullanmak düzenli takip kadar önemlidir.',
    'healthTipGeneralDisease3':
        'Sigara, birçok kronik hastalığın kontrolünü zorlaştırabilir.',
    'healthTipGeneralDisease4':
        'Nefes darlığı veya göğüs ağrısı varsa acil yardım gerekip gerekmediğini değerlendir.',
    'healthTipGeneralDisease5':
        'Bugün bir sigarayı atlamak, vücudunun iyileşme yükünü azaltır.',
    'healthTipGeneralDisease6':
        'Tansiyon, şeker veya nefes ölçümlerini doktorunun planına göre takip et.',
    'healthTipGeneralDisease7':
        'Kısa ve düzenli hareket, dolaşım ve enerji için yararlıdır.',
    'healthTipGeneralDisease8':
        'Dumanlı ortamlardan uzak durmak hastalık belirtilerini hafifletmeye yardım eder.',
    'healthTipGeneralDisease9':
        'Yeni veya şiddetlenen bir belirtiyi kendi kendine yorumlamak yerine sağlık uzmanına sor.',
    'healthTipGeneralDisease10':
        'Kendine uygun küçük bir hedef seç ve bugün onu gerçekleştir.',
    'healthTipHypertension1':
        'Sigara, kan basıncını anında yükseltir. Su an biraz derin nefes almak tansiyonuna iyi gelir.',
    'healthTipHypertension2':
        'Tuzu azaltmak ve sigarasız kalmak, tansiyonun için birlikte çalışır. Bugün bir sigarayı daha erteleyebilirsin.',
    'healthTipAsthma1':
        'Sigara dumanı, hava yollarını daraltarak astım ataklarını tetikleyebilir. Temiz hava alabileceğin bir yere cik.',
    'healthTipAsthma2':
        'Nefesin daraldığında sigaraya değil, yavaş ve derin nefes egzersizine yönel.',
    'healthTipDiabetes1':
        'Sigara, kan şekerini dengelemeyi zorlaştırır. Bir bardak su içip birkaç dakika beklemeyi dene.',
    'healthTipDiabetes2':
        'Sigarasız geçen her saat, dolaşımındaki kan şekeri kontrolune küçük bir katki.',
    'healthTipCopd1':
        'KOAH ile sigara bir arada gitmez. Şu anki isteğin, birkaç dakika içinde azalacak.',
    'healthTipCopd2':
        'Kısa bir nefes egzersizi, akciğerlerine sigaradan çok daha fazla iyilik yapar.',
    'healthTipHeartDisease1':
        'Sigara, kalbini gereksiz yere hızlandırır. Sakin bir nefes molası kalbin için daha iyi bir seçim.',
    'healthTipHeartDisease2':
        'Kalp sağlığın için attığın en değerli adım, şu anki sigarayı içmemek.',
    'healthTipHypertension3':
        'Sigara içtiğin her an damarların büzülür. Şimdi ayağa kalkıp birkaç adım atmak tam tersini yapar.',
    'healthTipHypertension4':
        'Tansiyonun sabahları en oynak olduğu saatte. Bugünün ilk sigarasını geciktirmek en çok bu saatte işe yarar.',
    'healthTipHypertension5':
        'Bir bardak su iç ve iki dakika bekle. İstek genelde bu süre içinde geçer, tansiyonun işe sakin kalır.',
    'healthTipHypertension6':
        'Yürüyüş, tansiyon için sigaranın vaat ettiği rahatlamayı gerçekten verir. On dakika yeter.',
    'healthTipHypertension7':
        'Öfkelendiğinde tansiyon da sigara isteği de birlikte yükselir. Önce nefesini yavaşlat, karar sonra gelsin.',
    'healthTipHypertension8':
        'Kahveyle sigarayı birlikte içmek tansiyonuna iki yönlü yüklenir. Bugün kahveyi sigarasız dene.',
    'healthTipHypertension9':
        'Tuzlu atıştırmalık, sigara isteğini de tansiyonu da tetikler. Elin uzanırken bunu hatırla.',
    'healthTipHypertension10':
        'Sigarasız geçen her saat, kalbinin aynı kanı daha az zorlanarak pompaladığı bir saattir.',
    'healthTipHypertension11':
        'Tansiyon ilaçını düzenli almak önemli, ama sigara onun işini zorlaştırır. İkişi aynı yöne çalışsın.',
    'healthTipHypertension12':
        'Şu an istek geldiyse, üç dakika sonra tekrar sor kendine. Çoğu zaman cevap değişir.',
    'healthTipHypertension13':
        'Merdiveni asansöre tercih etmek, tansiyonun için sigarayı bırakmanın küçük kardeşidir.',
    'healthTipHypertension14':
        'Stresli bir görüşmeden sonra sigara arıyorsan, aslında aradığın şey nefeslenmek.',
    'healthTipHypertension15':
        'Sıcak duş, sigaranın verdiği gevşemenin aynısını tansiyonunu yükseltmeden verir.',
    'healthTipHypertension16':
        'Akşam sigarası uykunu böler, bölünen uyku da tansiyonu yükseltir. Zincir buradan kırılıyor.',
    'healthTipHypertension17':
        'Bugün hedefinin altında kaldıysan, damarların bunu zaten fark etti.',
    'healthTipHypertension18':
        'Sigara istediğinde ellerini meşgul et. Tansiyonun bu birkaç dakikayı sana borçlu.',
    'healthTipHypertension19':
        'Yemekten sonraki sigara alışkanlığın en güçlü olduğu an. Sofradan kalkıp yürümeyi dene.',
    'healthTipHypertension20':
        'Bir kişiye bugünkü hedefini söyle. Söylenen hedef, tutulan hedef olur.',
    'healthTipHypertension21':
        'Tansiyonun için en iyi haber: bıraktığın gün değil, azalttığın her gün sayılıyor.',
    'healthTipHypertension22':
        'Nefesini dörde kadar sayarak al, altıya kadar say vererek. Bunu üç kez yap.',
    'healthTipHypertension23':
        'Sigara molası yerine pencere molası ver. Aynı ara, farklı sonuç.',
    'healthTipHypertension24':
        'Kolundaki tansiyon aleti sigarayı görmez ama etkisini ölçer.',
    'healthTipHypertension25':
        'Bugün içmediğin sigara, yarınki ölçümünde görünecek.',
    'healthTipHypertension26':
        'Alkolle birlikte sigara isteği katlanır, tansiyon da öyle. İkisini ayır.',
    'healthTipHypertension27':
        'Yorgunluk sigara isteği gibi hissettirir. Önce on dakika otur, sonra karar ver.',
    'healthTipHypertension28':
        'Sabah kalkınca bir bardak su, günün ilk sigarasını geciktirmenin en kolay yolu.',
    'healthTipHypertension29':
        'Tansiyonunu düşüren şey tek bir büyük karar değil, üst üste gelen küçük ertelemeler.',
    'healthTipHypertension30':
        'Bugünün hedefini tutturduysan, bunu yarın da yapabilirsin. Kanıtı sensin.',
    'healthTipHypertension31':
        'Tansiyon ilaçını sabah aç karnına almadan önce sigarayı ertelemek, ikisinin birlikte çalışmasına yardım eder.',
    'healthTipHypertension32':
        'Baş ağrısı ve baş dönmesi bazen yüksek tansiyonun habercisidir; sigara bunu daha da kötüleştirir. Şimdi dinlen.',
    'healthTipHypertension33':
        'Gece geç saatte sigara, sabah tansiyon ölçümünü yükseltir. Bu akşamki sigarayı atlamak yarın fark yaratır.',
    'healthTipAsthma3':
        'Duman, hava yollarını saatlerce hassas bırakır. Şimdi içmezsen gece daha rahat nefes alırsın.',
    'healthTipAsthma4':
        'Göğsün sıkıştığında sigara onu açmaz, daraltır. Nefes egzersizi tam tersini yapar.',
    'healthTipAsthma5':
        'Soğuk havada sigara, hava yollarına iki kat yüklenir. Bugün içeride kal ve ertele.',
    'healthTipAsthma6':
        'Astım için en kötü kombinasyon: duman ve toz. Bulunduğun yeri havalandır.',
    'healthTipAsthma7':
        'Öksürüğün sabah artıyorsa, gece içilen sigarayla ilgili olabilir. Bir gece dene, farkı gör.',
    'healthTipAsthma8':
        'Nefes darlığında panik isteği büyütür. Omuzlarını gevşet, nefesini uzat.',
    'healthTipAsthma9':
        'Egzersiz astımını tetikliyorsa sigara bu eşiği daha da düşürür. Bugün bir sigara az.',
    'healthTipAsthma10':
        'Sigarasız geçen her gün, kurtarıcı ilaçına daha az ihtiyaç duyduğun bir gündür.',
    'healthTipAsthma11':
        'Duman kokusu kıyafetinde kalır ve seni tekrar tetikler. Üstünü değiştir, isteği kes.',
    'healthTipAsthma12': 'Hırıltı duyduğunda sigara değil, temiz hava ara.',
    'healthTipAsthma13':
        'Polen mevsiminde hava yolların zaten yüklü. Bu hafta ertelemeler daha çok işe yarar.',
    'healthTipAsthma14':
        'Sigara isteği geldiğinde ağzından değil, burnundan yavaşça nefes al.',
    'healthTipAsthma15':
        'Astımlı biri için en değerli kazanç, gece kesintisiz uyumak. Akşam sigarası onu çalıyor.',
    'healthTipAsthma16':
        'Bugün içmediğin sigara, merdivende bir basamak fazla demek.',
    'healthTipAsthma17':
        'Kapalı alanda içilen sigara, hava yollarına açık alandakinden çok daha ağır gelir.',
    'healthTipAsthma18':
        'Nefesin daraldığında oturup öne eğil ve yavaş nefes ver. Bu his geçecek.',
    'healthTipAsthma19':
        'Sigara isteği ortalama üç dakika sürer. Astım atağı işe saatler. Hangisini beklemek daha kolay?',
    'healthTipAsthma20':
        'Yatak odanı dumandan uzak tut. Uyurken hava yolların dinlenmeli.',
    'healthTipAsthma21':
        'Bir sigarayı ertelediğinde sadece istek geçmez, nefesin de yerine gelir.',
    'healthTipAsthma22':
        'Stres astımı da tetikler, sigarayı da. Kaynağı aynı, çözümü de aynı: yavaş nefes.',
    'healthTipAsthma23':
        'Bugün öksürüğün az mı? Bu tesadüf değil, dünkü kararların.',
    'healthTipAsthma24':
        'Sigara dumanı, ilaçının etkisini de zayıflatır. İkisini yarıştırma.',
    'healthTipAsthma25':
        'Nefes testinde bir saniyelik artış bile hava yollarının açıldığını gösterir.',
    'healthTipAsthma26':
        'Yürürken nefesin yetmiyorsa yavaşla, dur, nefeslen. Sigara bu sıralamayı bozar.',
    'healthTipAsthma27':
        'Evde biri sigara içiyorsa senin hava yolların da içiyor. Bunu konuşmaya değer.',
    'healthTipAsthma28':
        'Sıcak buhar, göğsündeki sıkışmayı sigaradan çok daha iyi açar.',
    'healthTipAsthma29':
        'Bugünkü hedefin altında kalmak, bu gece daha az uyanmak demek.',
    'healthTipAsthma30':
        'Hava yolların iyileşmeyi hemen başlatır. Bir günün bile karşılığı var.',
    'healthTipAsthma31':
        'Soğuk hava ve sigara dumanı birlikte hava yollarını daha çok daraltır. Kalın bir eşarpla nefes al, sigarayı erteleyebilirsin.',
    'healthTipAsthma32':
        'Öksürük krizinden hemen sonra sigara istemek yaygındır ama tam da o an akciğerlerinin en çok dinlenmeye ihtiyacı olan an.',
    'healthTipAsthma33':
        'Nefes darlığı geceleri artıyorsa, akşamki son sigarayı atlamak uyku kalitesini doğrudan etkiler.',
    'healthTipDiabetes3':
        'Sigara, insülinin işini zorlaştırır. Şimdi içmemek, bugünkü şekerini daha öngörülebilir kılar.',
    'healthTipDiabetes4':
        'Yemekten sonraki sigara, şeker yükselmesinin üstüne binen ikinci bir yüktür.',
    'healthTipDiabetes5':
        'Ayaklarındaki dolaşım en çok sigaradan etkilenir. Bugün bir sigara az, bir adım fazla.',
    'healthTipDiabetes6':
        'Kan şekerin düştüğünde sigara isteği artar. Önce bir şeyler ye, sonra tekrar düşün.',
    'healthTipDiabetes7':
        'Sigarasız geçen her hafta, vücudunun kendi insülinini daha iyi kullandığı bir haftadır.',
    'healthTipDiabetes8':
        'Yürüyüş hem şekerini hem sigara isteğini aynı anda düşürür. İki iş, tek çaba.',
    'healthTipDiabetes9':
        'Yaraların geç iyileşiyorsa sigara bunun büyük bir payı. Azaltmak fark ediyor.',
    'healthTipDiabetes10':
        'Şekerli içecekle sigara birlikte gelir. Birini bıraktığında diğeri de zayıflar.',
    'healthTipDiabetes11':
        'Sabah şekerin yüksekse, dünkü akşam sigarasına da bakmaya değer.',
    'healthTipDiabetes12':
        'Sigara, göz damarlarını da zorlar. Bugün ertelediğin her sigara oraya da yazılıyor.',
    'healthTipDiabetes13':
        'İstek geldiğinde bir bardak su iç. Susuzluk da şeker de isteği büyütür.',
    'healthTipDiabetes14':
        'Stres şekerini yükseltir, sigara stresi geçirmez sadece erteler.',
    'healthTipDiabetes15':
        'Ayak kontrolünü yaparken şunu düşün: dolaşımına en çok yardım eden şey azaltmak.',
    'healthTipDiabetes16':
        'Sigara isteği üç dakika sürer. Şeker dalgalanması saatler. Kısa olanı bekle.',
    'healthTipDiabetes17':
        'Bugün hedefini tutturduysan, pankreasın da bunu fark etti.',
    'healthTipDiabetes18':
        'Böbreklerin sigaradan da şekerden de yorulur. İkisini birden azaltmak en iyi hediye.',
    'healthTipDiabetes19':
        'Öğün atlamak isteği büyütür. Düzenli yemek, sigarayı ertelemeyi kolaylaştırır.',
    'healthTipDiabetes20':
        'Akşam yürüyüşü, hem gece şekerini hem gece sigarasını devre dışı bırakır.',
    'healthTipDiabetes21':
        'Sigarayı azaltmak, ilaçlarının aynı işi daha az çabayla yapması demek.',
    'healthTipDiabetes22':
        'Ellerini meşgul et: bir şey soy, bir şey karıştır. İstek geçecek.',
    'healthTipDiabetes23':
        'Tatlı isteği ve sigara isteği aynı anda gelirse, önce su ve on dakika.',
    'healthTipDiabetes24':
        'Uykusuzluk hem şekerini hem isteğini bozar. Bu gece erken yat.',
    'healthTipDiabetes25':
        'Bugün içilmeyen sigara, damarlarında hemen etkisini gösteriyor.',
    'healthTipDiabetes26':
        'Kahvaltıyı atlayıp sigara içmek, güne şekerini iki kez zorlayarak başlamak demek.',
    'healthTipDiabetes27':
        'Arkadaş ortamında hem tatlı hem sigara gelir. Bir tanesine hazırlıklı git.',
    'healthTipDiabetes28':
        'Şekerini ölçerken sigara sayını da düşün. İkişi aynı grafiğin parçası.',
    'healthTipDiabetes29':
        'Azaltmak, bırakmanın küçük hâli değil; kendi başına kazanç.',
    'healthTipDiabetes30':
        'Bir haftadır hedefinin altındaysan, bunu vücudun çoktan hissediyor.',
    'healthTipDiabetes31':
        'Sigara, ayaklarındaki küçük damarları daraltır; diyabette bu iyileşmeyi zaten yavaşlatıyor. Bir sigara daha eksiltmek yardımcı olur.',
    'healthTipDiabetes32':
        'Kan şekerin düşükken sigara isteği artabilir. Önce bir şeyler ye, istek genelde onunla birlikte azalır.',
    'healthTipDiabetes33':
        'Düzenli ölçüm yapıyorsan, sigarasız geçen günlerdeki farkı zamanla kendin göreceksin.',
    'healthTipCopd3':
        'KOAH\'ta her sigara, kaybedilen kapasitenin üstüne biner. Bugünkü erteleme kalıcı bir kazanç.',
    'healthTipCopd4':
        'Nefesin daraldığında öne eğilip dudak büzerek nefes ver. Sigaradan hızlı rahatlatır.',
    'healthTipCopd5':
        'Sabah balgamı fazlaysa, gece içilen sigarayla ilgisi var. Bir gece dene.',
    'healthTipCopd6':
        'Alevlenmelerin çoğu sigarayla başlar. Bugün içmemek, bu ayı hastanesiz geçirmene yardım eder.',
    'healthTipCopd7':
        'Merdiven çıkarken durup nefeslenmek zayıflık değil, doğru teknik. Sigara bu tekniği bozar.',
    'healthTipCopd8':
        'Akciğerlerin iyileşmeyi bugün başlatabilir. Yaşın ya da süren fark etmez.',
    'healthTipCopd9':
        'Soğuk hava hava yollarını daraltır. Sigarayla birleşince iki kat zorlar. Bugün içeride kal.',
    'healthTipCopd10':
        'Sigara isteği üç dakika sürer. Nefes darlığı işe günü alır. Üç dakikayı bekle.',
    'healthTipCopd11':
        'Balgamının rengi değişiyorsa doktoruna söyle. Bu arada bir sigara az iç.',
    'healthTipCopd12':
        'Kısa yürüyüşler akciğer kapasiteni korur. Sigara molası yerine yürüyüş molası ver.',
    'healthTipCopd13':
        'Gece nefes darlığıyla uyanıyorsan, akşam sigarası bunun en kolay değiştirilebilir sebebi.',
    'healthTipCopd14':
        'Nefes egzersizini yaparken sayı tut. Ölçülen ilerleme, hissedilenden daha inandırıcı.',
    'healthTipCopd15':
        'Sigarasız geçen her gün, öksürüğünün biraz daha azaldığı bir gündür.',
    'healthTipCopd16':
        'Evi havalandırmak, akciğerlerine bugün verebileceğin en kolay iyilik.',
    'healthTipCopd17':
        'Konuşurken nefesin yetmiyorsa, bu geri kazanılabilir bir şey. Azaltmakla başlıyor.',
    'healthTipCopd18':
        'Ağır yemek sonrası nefesin daralır. Sigarayı da ekleme, biraz yürü.',
    'healthTipCopd19':
        'Bugün hedefinin altında kaldıysan, akciğerlerin bunu bir hafta boyunca hatırlayacak.',
    'healthTipCopd20':
        'Duman, hava yollarındaki temizleyici tüycükleri felç eder. Onlar birkaç saatte toparlanır.',
    'healthTipCopd21':
        'Nefes testinde bir saniye artış küçük görünür ama merdivende hissedilir.',
    'healthTipCopd22':
        'Kalabalık ve dumanlı yerlerden uzak dur. Hava yolların bugün zaten çalışıyor.',
    'healthTipCopd23':
        'Sigara isteği panikle büyür. Otur, dudak büzerek ver, tekrar değerlendir.',
    'healthTipCopd24':
        'Grip aşını yaptırdıysan iyi. Sigarayı azaltmak onun etkisini destekler.',
    'healthTipCopd25':
        'Su içmek balgamı inceltir ve öksürmeyi kolaylaştırır. Sigara tam tersini yapar.',
    'healthTipCopd26':
        'Bugün bir sigara az içtiysen, bu gece bir kez az uyanabilirsin.',
    'healthTipCopd27':
        'Ev işlerini parçalara böl ve aralarda nefeslen. Bu, sigara molasının yerini alabilir.',
    'healthTipCopd28':
        'Akciğer kapasiten yavaş iyileşir ama geri gider de. Yön senin elinde.',
    'healthTipCopd29':
        'Nefes darlığı arttığında ilk yapılacak şey durmak, ikinci şey yavaş nefes vermek.',
    'healthTipCopd30':
        'Azaltarak gitmek de bir yol. Akciğerlerin her adımı sayıyor.',
    'healthTipCopd31':
        'Sabah balgam söktürme zorluğu genelde gece içilen son sigaralardan gelir. Onları erteleyerek başla.',
    'healthTipCopd32':
        'Merdiven çıkarken nefesin daraldıysa, şu an sigara değil dinlenme zamanı.',
    'healthTipCopd33':
        'KOAH ilaçların sigarayla birlikte daha az işe yarar. İlacı aldığın saatte sigarayı atlamak, ilaçın gerçekten çalışmasını sağlar.',
    'healthTipHeartDisease3':
        'Sigara, kalbinin oksijen ihtiyacını artırırken damarları daraltır. Şu an içmemek ikisini de düzeltir.',
    'healthTipHeartDisease4':
        'Göğsünde baskı hissedersen dur ve dinlen. Bu bir sigara zamanı değil.',
    'healthTipHeartDisease5':
        'Sigarasız geçen ilk gün bile kalp krizi riskini düşürmeye başlar.',
    'healthTipHeartDisease6':
        'Nabzın hızlandığında sigara onu daha da hızlandırır. Nefesini yavaşlat.',
    'healthTipHeartDisease7':
        'Yürüyüş kalbini güçlendirir, sigara yorar. Bugün hangisini seçeceğin belli.',
    'healthTipHeartDisease8':
        'Sabah saatleri kalp için en riskli zaman. Günün ilk sigarasını geciktir.',
    'healthTipHeartDisease9':
        'Merdiven çıkarken zorlanıyorsan bu geri kazanılabilir. Azaltmakla başlar.',
    'healthTipHeartDisease10':
        'Sigara kanı koyulaştırır ve pıhtı riskini artırır. Bugün içmediğin her sigara sayılıyor.',
    'healthTipHeartDisease11':
        'Stres kalbini de sigara isteğini de tetikler. Kaynağı çözmek ikisini birden çözer.',
    'healthTipHeartDisease12':
        'Kalp ilaçların sigarayla yarışmak zorunda kalmasın.',
    'healthTipHeartDisease13':
        'Bacaklarında yürürken ağrı oluyorsa damarların konuşuyor. Dinle.',
    'healthTipHeartDisease14':
        'Ağır yemek sonrası kalp zaten çalışıyor. Üstüne sigara ekleme.',
    'healthTipHeartDisease15':
        'Sigara isteği geldiğinde iki dakika ayakta yürü. Kalbin bu takası kabul eder.',
    'healthTipHeartDisease16':
        'Kolesterol ve sigara birlikte damar duvarına yüklenir. Birini azaltmak diğerini hafifletir.',
    'healthTipHeartDisease17':
        'Bugün hedefinin altında kaldıysan, kalbin bugün daha az attı.',
    'healthTipHeartDisease18':
        'Uyku kalbini onarır. Akşam sigarası o onarımı böler.',
    'healthTipHeartDisease19':
        'Nefes egzersizi nabzını düşürür, sigara yükseltir. Aynı üç dakika, zıt sonuç.',
    'healthTipHeartDisease20':
        'Tuz ve sigara birlikte tansiyonu iter. Bugün ikisinden birini geri çek.',
    'healthTipHeartDisease21':
        'Kalp için en iyi haber: hasar durduğu anda onarım başlar.',
    'healthTipHeartDisease22':
        'Soğukta yürürken kalp daha çok çalışır. Sigarayı buna ekleme.',
    'healthTipHeartDisease23':
        'Bir sigarayı ertelediğinde kalbin o dakikalarda daha rahat kan pompalıyor.',
    'healthTipHeartDisease24':
        'Alkolle sigara birlikte nabzı iki yönden zorlar. Ayrı tut.',
    'healthTipHeartDisease25':
        'Bugünkü yürüyüşün, bu haftanın en iyi kalp kararı olabilir.',
    'healthTipHeartDisease26':
        'Sigara isteği geldiğinde nabzını say. Sayarken istek genelde geçer.',
    'healthTipHeartDisease27':
        'Kalp sağlığı için azaltmak, bırakmaya giden yolun tamamı kadar değerli.',
    'healthTipHeartDisease28':
        'Göğüs ağrın değişiyorsa doktoruna söyle. Bu arada bir sigara az.',
    'healthTipHeartDisease29':
        'Damarların esnekliğini geri kazanabilir. Bu, azalttığın her gün biraz daha olur.',
    'healthTipHeartDisease30':
        'Kalbin bugüne kadar durmadan çalıştı. Bugün ona bir sigara borcun yok.',
    'healthTipHeartDisease31':
        'Göğsünde baskı hissettiğinde sigara değil, oturup yavaş nefes almak kalbini rahatlatır.',
    'healthTipHeartDisease32':
        'Sigara sonrası kalp atışındaki hızlanma dakikalarca sürer. O dakikaları hiç yaşamamayı seçebilirsin.',
    'healthTipHeartDisease33':
        'Kalp ilaçlarını düzenli alıyorsan, sigarayı azaltmak onların etkisini güçlendirir, zayıflatmaz.',
    'reportsAvertedCigarettes': 'İçilmediği tahmin edilen sigara',
    'reportsSmokingTimePattern': 'Sigara zaman dağılımı',
    'reportsNoDataYet': 'Henüz yeterli veri yok',
    'reportsPartMorning': 'Sabah (05-10)',
    'reportsPartMidday': 'Öğle (10-13)',
    'reportsPartAfternoon': 'Öğleden sonra (13-17)',
    'reportsPartEvening': 'Akşam (17-22)',
    'reportsPartNight': 'Gece (22-05)',
    'reportsDisclaimer':
        'Bu rapor kayıtlarına dayalı tahmini bilgiler içerir; tıbbi değerlendirme veya tanı değildir. Kişisel sağlık kararların için doktoruna dans.',
    'menuReports': 'Raporlar',
    'reportsTitle': 'Raporlar',
    'reportsWeeklyTab': 'Haftalık',
    'reportsMonthlyTab': 'Aylık',
    'reportsPreviewButton': 'Önizle / Yazdır',
    'reportsShareButton': 'PDF Olarak Paylaş',
    'reportsPdfTitle': 'Nikotin Away Raporu',
    'reportsCigarettesLogged': 'Kaydedilen sigara sayısı',
    'reportsAvgPerDay': 'Günlük ortalama',
    'reportsRiskScore': 'Risk skoru',
    'reportsRiskTrend': 'Risk eğilimi',
    'reportsBreathTrend': 'Nefes eğilimi',
    'reportsSmokingTrend': 'Sigara eğilimi',
    'reportsTaskSuccess': 'Tamamlanan görevler',
    'reportsTaskCompletionRate': 'Görev başarı oranı',
    'reportsWeeklySurveys': 'Tamamlanan haftalık anketler',
    'reportsBreathTests': 'Tamamlanan nefes testleri',
    'reportsDaysSinceQuit': 'Programa başlayalı geçen gün',
    'reportsTotalSteps': 'Toplam adım',
    'reportsAvgStepsPerDay': 'Günlük ortalama adım',
    'settingsLocationIntelligenceRow': 'Konum Zekası',
    'settingsLocationIntelligenceRowSubtitle':
        'Sık gittiğin yerleri öğrenerek destek ol',
    'locationIntelligenceTitle': 'Konum Zekası',
    'locationIntelligenceIntro':
        'Açık olduğunda, uygulama zamanla en fazla 8 sık gittiğin yeri öğrenir (örneğin ev, is). Bu yerlerden birine vardığında kısa bir hatırlatma gösterilir. Ham konum geçmişi hiçbir zaman kaydedilmez, sadece bu az sayıdaki yerin kabaca konumu tutulur.',
    'locationIntelligencePurpose':
        'Neden: Bildirim göstermek ve risk değerlendirmene katki sağlamak için. Ayarlar > Verilerimi Sıfırla ile bu veriler de silinir.',
    'locationIntelligenceBackgroundWarning':
        'Ana izin verildi ama arka plan izni verilmedi. Uygulama kapalıyken vardığın yerler algılanamaz. Ayarlar > Uygulamalar > Nikotin Away > Izinler > Konum bölümünden "Her zaman izin ver" seçebilirsin.',
    'locationIntelligenceEnabledConfirmation': 'Konum zekası açıldı.',
    'locationIntelligenceDisabledConfirmation': 'Konum zekası kapatıldı.',
    'locationIntelligencePlacesTitle': 'Öğrenilen Yerler',
    'locationIntelligenceNoPlacesYet': 'Henüz bir yer öğrenilmedi.',
    'locationIntelligencePlaceRow': 'Yer',
    'locationIntelligenceVisitCount': 'ziyaret',
    'locationArrivalNotificationTitle': 'Buradasın',
    'locationArrivalNotificationBody':
        'Sık gittiğin bir yerdesin. Kendine iyi bak.',
    'smokingLoggedConfirmation':
        'Kaydedildi. Bu, ne zaman zorlandığını daha iyi anlamamıza yardımcı olur.',
    'undo': 'Geri al',
    'dailyCheckInTitle': 'Günlük Değerlendirme',
    'dailyCheckInIntro':
        'Günü kapatmadan önce kısa bir değerlendirme yapalım. Bu, seni gereksiz yere gün boyu rahatsız etmeden en doğru desteği vermemizi sağlar.',
    'breathExerciseCardTitle': 'Nefes Egzersizi',
    'dailyCheckInHoursQuestion': 'Bugün yaklaşık hangi saatlerde sigara içtin?',
    'dailyCheckInDidNotSmoke': 'Bugün hiç içmedim',
    'dailyCheckInSaved': 'Teşekkürler, kaydedildi. Yarın görüşürüz.',
    'notificationContextReasonLabel': 'Bildirim bağlam nedeni',
    'smokingYearsHintExample': 'örn: 5',
    'dataLoadFailed': 'Veri yüklenemedi.',
    'progressSummaryTitle': 'Genel Özet',
    'totalRecords': 'Toplam kayıt',
    'latestRiskScore': 'Son risk skoru',
    'breathProgressTitle': 'Nefes Gelişimi',
    'dailyAverageLabel': 'Günlük ortalama',
    'weeklyAverageLabel': 'Haftalık ortalama',
    'monthlyAverageLabel': 'Aylık ortalama',
    'firstToLastAverageDiff': 'İlk -> Son ortalama fark',
    'latestVsPrevious': 'Son test vs önceki',
    'bestConsecutiveDay': 'En iyi ardışık gün',
    'respFollowUpTitle': 'Respiratuar Izlem (KOAH-benzeri, tanisal değil)',
    'latestRespBurden': 'Son respiratuar yük',
    'latestStatus': 'Son durum',
    'mmrcLikeGrade': 'mMRC benzeri derece',
    'catLikeTotal': 'CAT-benzeri toplam',
    'warningDaysTotal': 'Uyarı günleri toplamı',
    'respFollowUpNote':
        'Not: Bu izlem tanı koymaz; belirti kötüleşirse klinik değerlendirme alın.',
    'trendChartsTitle': 'Trend Grafikler',
    'weeklyRiskTrendTitle': 'Haftalık risk trendi (son 12 ölçüm)',
    'noWeeklyDataForChart': 'Grafik için yeterli haftalık veri yok.',
    'breathTrendTitle': 'Nefes ortalama trendi (günlük son 14 veri)',
    'noBreathDataForChart': 'Grafik için yeterli nefes testi verisi yok.',
    'respiratoryTrendTitle': 'Respiratuar yük trendi (haftalık son 12)',
    'noRespDataForChart': 'Grafik için yeterli respiratuar veri yok.',
    'taskBarrierComplianceTitle': 'Görev ve Bariyer Uyum',
    'last10Successful': 'Son 10 başarılı',
    'last10Failed': 'Son 10 başarısız',
    'achievementsSinceStartTitle': 'Başlangıçtan Bugüne Başarılar',
    'achievementsPageTitle': 'Rozetler',
    'achievementsEarnedCount': '{earned} / {total} rozet kazanıldı',
    'achievementStreak1Title': 'İlk Gün',
    'achievementStreak1Desc': 'Bir gün boyunca hedefinin altında kaldın.',
    'achievementStreak3Title': 'Üç Gün Üst Üste',
    'achievementStreak3Desc': 'Üç gün arka arkaya hedefini tutturdun.',
    'achievementStreak7Title': 'Bir Hafta',
    'achievementStreak7Desc': 'Yedi gün boyunca hedefinin altında kaldın.',
    'achievementStreak30Title': 'Bir Ay',
    'achievementStreak30Desc': 'Otuz gün arka arkaya hedefini tutturdun.',
    'achievementStreak90Title': 'Üç Ay',
    'achievementStreak90Desc': 'Doksan gün boyunca hedefini tutturdun.',
    'achievementAvoided20Title': 'İlk Yirmi',
    'achievementAvoided20Desc': 'Yirmi sigara içmedin — neredeyse bir paket.',
    'achievementAvoided100Title': 'Yüz Sigara',
    'achievementAvoided100Desc': 'Yüz sigara içmedin.',
    'achievementAvoided500Title': 'Beş Yüz Sigara',
    'achievementAvoided500Desc': 'Beş yüz sigara içmedin.',
    'achievementAvoided1000Title': 'Bin Sigara',
    'achievementAvoided1000Desc': 'Bin sigara içmedin.',
    'achievementInterval25Title': 'Çeyrek Kadar Uzun',
    'achievementInterval25Desc':
        'Sigaralar arası süreni eskisinden %25 uzattın.',
    'achievementInterval50Title': 'Yarı Yarıya Uzun',
    'achievementInterval50Desc':
        'Sigaralar arası süreni eskisinden %50 uzattın.',
    'achievementInterval100Title': 'İki Katı',
    'achievementInterval100Desc':
        'Sigaralar arası süren eskisinin iki katına çıktı.',
    'achievementLongestBarrier60Title': 'Bir Saat',
    'achievementLongestBarrier60Desc':
        'En uzun sigarasız aralığın 1 saati asti.',
    'achievementLongestBarrier120Title': 'İki Saat',
    'achievementLongestBarrier120Desc':
        'En uzun sigarasız aralığın 2 saati asti.',
    'riskChange': 'Risk değişimi',
    'weeklyImprovementPeriod': 'Haftalık iyileşen dönem',
    'planDayLabel': 'Plan günü',
    'remainingDaysLabel': 'Kalan gün',
    'respAlertHistoryTitle': 'Respiratuar Uyarı Geçmişi',
    'noCriticalRespAlertRecord': 'Kritik respiratuar uyarı kaydı yok.',
    'weeklyHistoryTitle': 'Haftalık Geçmiş',
    'noWeeklyRecordYet': 'Henüz haftalık anket kaydı yok.',
    'breathTestHistoryTitle': 'Nefes Testi Geçmişi',
    'noBreathRecordYet': 'Henüz nefes testi kaydı yok.',
    'surveyModeTitle': 'Anket modu',
    'surveyModeQuick': 'Hızlı (15 sn)',
    'surveyModeDetailed': 'Detaylı',
    'surveyModeAutoDetailedHint':
        'Geçen hafta risk yüksek görünüyor. İstersen Detaylı moda geçerek daha ince ayar yapabilirsin.',
    'weeklyQuickRespTitle': 'Hızlı Solunum Kontrolü',
    'weeklyQuickRespHint':
        'Kısa modda da solunum durumunu daha doğru yansıtmak için 3 alan doldur.',
    'adaptiveSummary': 'Uyarlanabilir özet',
    'addNote': 'Not ekle',
    'backToHome': 'Ana sayfaya dön',
    'breathAverageComparison': 'Ortalama ile karşılaştırma',
    'breathComparedAverageDeclined': 'Ortalamanın altında',
    'breathComparedAverageImproved': 'Ortalamanın üstünde',
    'breathComparedAverageStable': 'Ortalamaya yakın',
    'breathComparedPreviousDeclined': 'Önceki teste göre düşüş',
    'breathComparedPreviousImproved': 'Önceki teste göre artış',
    'breathComparedPreviousStable': 'Önceki teste göre stabil',
    'breathImprovementSummary': 'Nefes gelişim özeti',
    'breathNoReferenceYet': 'Karşılaştırma için yeterli referans yok.',
    'breathPreviousComparison': 'Önceki test ile karşılaştırma',
    'breathTestRecordTitle': 'Nefes Egzersizi Kaydı',
    'breathTrend': 'Nefes trendi',
    'chainSmoking': 'Ardışık içim',
    'chainSmokingLatest': 'Son ardışık içim',
    'chainSmokingTrend': 'Ardışık içim trengi',
    'completeRegistration': 'Kaydı tamamla',
    'daily': 'Günlük',
    'dailyBreathStatus': 'Günlük nefes durumu',
    'days': 'gün',
    'evaluation': 'Değerlendirme',
    'exhaleDelta': 'Exhale farkı',
    'failedTaskCount': 'Başarısız görev',
    'firstEvaluation': 'İlk değerlendirme',
    'firstTaskNoSmoke15': 'İlk görev: 15 dakika sigarasız kal',
    'goal180CadenceLabel': '180 gün hedef temposu',
    'goal180CadenceOneDay': 'Her gün düzenli',
    'goal180CadenceTwoDays': 'Iki günde bir güçlü takip',
    'goal180CadenceWeek': 'Haftalık toparlama planı',
    'goal180GuideEarly': 'Erken dönemde daha sık destek normaldir.',
    'goal180GuideLate': 'İleri dönemde istikrar on planda.',
    'goal180GuideLateHard': 'İleri dönemde zorlanma varsa yük hafifletilir.',
    'goal180GuideMid': 'Orta dönemde ritim yerleşir.',
    'goal180GuideMidHard': 'Orta dönemde tetikleyici odaklı düzenleme yapılır.',
    'goal180ProgressLabel': '180 gün ilerleme',
    'goal180RemainingLabel': '180 güne kalan',
    'inhaleDelta': 'Inhale farkı',
    'lastBreathTest': 'Son nefes testi',
    'lastExhale': 'Son exhale',
    'lastInhale': 'Son inhale',
    'lastSurveyDate': 'Son anket tarihi',
    'mandatoryTaskCommand': 'Zorunlu görev komutu',
    'mandatoryTaskHint': 'Bugünün odağını tamamla.',
    'mandatoryTaskStartButton': 'Kabul Et',
    'mandatoryTaskDeclineButton': 'Ertele',
    'mandatoryTaskTitle': 'Bugünün odağı',
    'monthly': 'Aylık',
    'monthlyImprovement': 'Aylık iyileşme',
    'noRecordYet': 'Henüz kayıt yok.',
    'noSurveyYet': 'Henüz anket yok.',
    'noTaskToday': 'Bugün görev yok.',
    'openTaskFollowUpScreen': 'Görev takibine git',
    'openViolationReportScreen': 'Zorlandığın anları aç',
    'packChangeDaily': 'Günlük paket değişimi',
    'pointShort': 'puan',
    'predictedRiskTime': 'Tahmini risk saati',
    'predictedTrigger': 'Tahmini tetikleyici',
    'predictionConfidence': 'Tahmin güveni',
    'premiumActive': 'Premium aktif',
    'previousRecord': 'Önceki kayıt',
    'progressNegative': 'Gerileme var',
    'progressNegativeDetail': 'Bu hafta risk artışı görüldü.',
    'progressPositive': 'İlerleme var',
    'progressPositiveDetail': 'Bu hafta risk azalışı görüldü.',
    'progressRegression': 'Regresyon',
    'progressSummary': 'İlerleme özeti',
    'registrationCompleted': 'Kayıt tamamlandı',
    'riskDelta': 'Risk farkı',
    'riskyHours': 'Riskli saatler',
    'riskyTriggers': 'Riskli tetikleyiciler',
    'secShort': 'sn',
    'status': 'Durum',
    'subscriptionEnd': 'Abonelik bitiş',
    'subscriptionInfo': 'Abonelik bilgisi',
    'subscriptionStart': 'Abonelik başlangıç',
    'subscriptionType': 'Abonelik tipi',
    'free': 'Ücretsiz',
    'premium': 'Premium',
    'active': 'Aktif',
    'passive': 'Pasif',
    'taskTimerStartedTitle': 'Görev başladı',
    'successfulTaskCount': 'Başarılı görev',
    'surveyHistory': 'Anket geçmişi',
    'taskBreathExercise2': '2 dakikalık nefes egzersizi yap',
    'taskCountToday': 'Bugünkü görev sayısı',
    'taskDeferredTenMinutes': 'Görev 10 dakika ertelendi',
    'taskDelayFirstSmoke10': 'İlk sigarayı 10 dakika ertele',
    'taskDelayFirstSmoke25': 'İlk sigarayı 25 dakika ertele',
    'taskDrinkWater': 'Bir bardak su ic',
    'taskFollowUpEmpty': 'Bekleyen görev takibi yok.',
    'taskFollowUpPendingCount': 'Bekleyen takip sayısı',
    'missedTaskCardBody': 'Bir görevi kaçırdık. Şimdi başlamak ister misin?',
    'missedTaskStartLabel': 'Başlat',
    'missedTaskSkipLabel': 'Geç',
    'undeliveredTaskSummary':
        '{count} görev, telefonun rahatsız etme modu gibi bir durumla denk geldiği için ertelendi.',
    'taskFollowUpScheduledAt': 'Planlanan takip saati',
    'taskFollowUpTitle': 'Görev takipleri',
    'taskFollowUpMarkSuccess': 'Başardım',
    'taskFollowUpMarkSmoked': 'Sigara içtim',
    'taskFollowUpDefer': 'Ertele',
    'taskOutcomeConfirmQuestion': 'Görev başarıldı mi?',
    'taskNoSmoke10': '10 dakika sigarasız kal',
    'taskNoSmoke120': '120 dakika sigarasız kal',
    'taskNoSmoke30': '30 dakika sigarasız kal',
    'taskNoSmoke45': '45 dakika sigarasız kal',
    'taskNoSmoke60': '60 dakika sigarasız kal',
    'taskNoSmoke90': '90 dakika sigarasız kal',
    'adaptiveNoSmokeTaskTemplate':
        'Önümüzdeki {duration} boyunca sigara içmeyin. Elinizde sigara varsa hemen söndürün.',
    'delayFirstCigaretteTemplate': 'İlk sigaranızı {duration} geciktirin.',
    'adaptiveNoSmokeWindowTemplate':
        'Önümüzdeki {duration} boyunca sigara içmeyin, {window} penceresi öncesi hazir ol.',
    'checkInPrompt': 'Devam ediyor musunuz?',
    'coachReductionTier75':
        'Bugün hedef: dünden en az 1 sigara az, ilk sigarayı 90 dakika ertele.',
    'coachReductionTier60':
        'Bugün hedef: dünden en az 2 sigara az, her sigara öncesi 10 dakika bekle.',
    'coachReductionTier40':
        'Bugün hedef: dünden en az 3 sigara az, öğlen sonrası 1 sigarayı atla.',
    'coachReductionTierBase':
        'Bugün hedef: mevcut azalmayi koru, riski saatlerde sigara yerine su + sakız uygula.',
    'coachBreathDeclining':
        'NEFES: Bugün 2 nefes testi yap, her testten sonra 2 dakika yavaş nefes uygula.',
    'coachBreathImproving':
        'NEFES: Kazanımı koru, risk saatinden önce 1 nefes rutini tamamla.',
    'coachBreathStable':
        'NEFES: Kriz anında 2 dakika nefes + 1 bardak su uygula.',
    'coachTrackReduceToday':
        'TAKIP: Bugün toplam adedi dünün en az 2 altında tamamla.',
    'coachTrackCompleteThree':
        'TAKIP: Bugün seçilen görevlerin en az 3 tanesini tamamlandı işaretle.',
    'coachPrepWindowTemplate':
        'HAZIRLIK: {window} öncesinde su + sakız + kısa yürüyüş planını hazırla.',
    'coachTriggerDelayTemplate':
        'TETIKLEYICI: {trigger} anında 3 dakika ertele, sonra yeniden karar ver.',
    'coachFocusRiskHourTemplate':
        'ODAK: En riskli saat {hour} için bildirimleri açık tut.',
    'coachWeeklyTargetTemplate':
        'HEDEF: Haftalık risk hedefini {percent} altına indir.',
    'coachTriggerStressCommand':
        'TETIKLEYICI-STRES: Stres anında 90 saniye nefes + 1 bardak su, sonra yeniden karar ver.',
    'coachTriggerCoffeeCommand':
        'TETIKLEYICI-KAHVE: Kahveyi 30 dakika geciktir, kahve ile sigarayı bağlama.',
    'coachTriggerAlcoholCommand':
        'TETIKLEYICI-ALKOL: Alkol günlerinde ilk teklifte sigaraya hayır de, sakız/su alternatifi kullan.',
    'coachTriggerSocialCommand':
        'TETIKLEYICI-SOSYAL: Sosyal ortama girmeden önce hedefini destek kisina mesajla.',
    'coachCrisisProtocol':
        'KRIZ: İlk istek dalgasında 3 dakika ertele, ikinci dalgada 4D protokolünü uygula.',
    'coachSupportSingleGoal':
        'DESTEK: Bugün tek hedef seç ve tamamlayınca uygulamada işaretle.',
    'coachHintHighRisk':
        'Yüksek risk dönemindesiniz: ilk sigarayı mutlaka erteleyin.',
    'coachHintMedRisk':
        'Orta-yüksek risk: tetikleyici anında nefes + su rutini uygulayın.',
    'coachHintLowRisk':
        'Ritmi koruyun: bugün en az bir görevi tamamlama hedefi koyun.',
    'coachHintWindowTemplate':
        'En riskli pencere: {window}. Bu saatten önce hazırlık yapın.',
    'coachHintTriggerTemplate':
        'Tahmini tetikleyici: {trigger}. Alternatif davranış belirleyin.',
    'coachRiskDaypart_high_morning_0':
        'SABAH: İlk sigarayı 90 dakika ertele, önce 1 bardak su ic.',
    'coachRiskDaypart_high_morning_1':
        'KRIZ: 4D protokolünü uygula (ertele-nefes-su-dikkat dağıt).',
    'coachRiskDaypart_high_day_0':
        'ÖĞLE: Yemek sonrası 7 dakika yürüyüş yap, sonra karar ver.',
    'coachRiskDaypart_high_day_1':
        'TETIK: Kahve ile sigarayı ayır, kahveyi 30 dakika geciktir.',
    'coachRiskDaypart_high_evening_0':
        'AKŞAM: Sosyal ortamda ilk teklife hayır de, 3 dakika ertele.',
    'coachRiskDaypart_high_evening_1':
        'DESTEK: Risk saatinden önce destek kisina tek satır mesaj gönder.',
    'coachRiskDaypart_high_night_0':
        'GECE: Bu saatten sonra sigara yok, acil kriz rutini uygula.',
    'coachRiskDaypart_high_night_1':
        'GEVŞEME: 3 dakika yavaş nefes + su ile günü kapat.',
    'coachRiskDaypart_medium_morning_0':
        'SABAH: İlk sigarayı 45 dakika ertele.',
    'coachRiskDaypart_medium_morning_1':
        'RUTIN: Kahve öncesi 2 dakika nefes egzersizi yap.',
    'coachRiskDaypart_medium_day_0': 'ÖĞLE: Her sigara öncesi 10 dakika bekle.',
    'coachRiskDaypart_medium_day_1':
        'ATLA: Bugün öğleden sonra 1 sigarayı atla.',
    'coachRiskDaypart_medium_evening_0':
        'AKŞAM: Riskli saatte sakız/su alternatifi uygula.',
    'coachRiskDaypart_medium_evening_1':
        'TAKIP: Gün sonu sayımında hedefi kontrol et.',
    'coachRiskDaypart_medium_night_0':
        'GECE: Son sigaradan sonra su ic, tekrar sigara içme.',
    'coachRiskDaypart_medium_night_1':
        'PLAN: Yarın ilk sigara saatini simdiden 15 dakika geciktir.',
    'coachRiskDaypart_low_morning_0':
        'SABAH: İlk sigarayı en az 25 dakika ertele.',
    'coachRiskDaypart_low_morning_1':
        'KORU: Nefes kazancını korumak için su + nefes rutini yap.',
    'coachRiskDaypart_low_day_0':
        'ÖĞLE: Sadece planlı saatlerde karar ver, otomatik yakma yok.',
    'coachRiskDaypart_low_day_1':
        'KORU: Öğlen sonrası 1 sigara yerine 5 dakika yürüyüş yap.',
    'coachRiskDaypart_low_evening_0':
        'AKŞAM: Sosyal tetikleyicilerde 3 dakika erteleme uygula.',
    'coachRiskDaypart_low_evening_1':
        'KORU: Gün sonu notuna bugün işe yarayan yöntemi yaz.',
    'coachRiskDaypart_low_night_0':
        'GECE: Bu saatten sonra sigarayı kapat, kriz olursa nefes uygula.',
    'coachRiskDaypart_low_night_1':
        'KORU: Yarın için risk saatine tek bir önlem yaz.',
    'taskNoteCraving': 'Kriz anını not et',
    'taskNotNowButton': 'Şimdi değil',
    'taskOutcomeNo': 'Hayır',
    'taskOutcomeQuestion': 'Görevi başarıyla tamamladın mi?',
    'taskOutcomeYes': 'Evet',
    'taskPlanOneDayDelayAllCravings':
        '1 gün sigarasız kalma görevi: bugün tüm kriz anlarında sigarayı erteleyin.',
    'taskPlanOneDayDelayFirst90':
        '1 gün sigarasız kalma görevi: ilk sigarayı en az 90 dakika erteleyin.',
    'taskPlanOneWeekCompleteAll':
        '1 hafta sigarasız kalma hedefi: 7 gün boyunca tüm görevleri tamamlayın.',
    'taskPlanTwoDaysBreathAndWater':
        '2 gün sigarasız kalma planı: kriz anında 10 derin nefes + su uygulayın.',
    'taskPlanTwoDaysDelayTriggers':
        '2 gün sigarasız kalma görevi: 48 saat boyunca tetikleyicilerde sigarayı erteleyin.',
    'taskReasonCadence': 'Görev ritmi',
    'taskReasonCardTitle': 'Neden bu görev?',
    'taskReasonCause': 'Neden',
    'taskReasonCauseBalanced': 'Dengeli zorluk seçildi',
    'taskReasonCauseBootstrap': 'Yeni başlangıç modu aktif',
    'taskReasonCauseFailurePressure': 'Sonuç baskısı nedeniyle ayarlandı',
    'taskReasonCauseHighRisk': 'Yüksek risk nedeniyle seçildi',
    'taskReasonCauseLowRisk': 'Düşük riskte koruyucu görev',
    'taskReasonCauseSuccessStability': 'Başarıya göre istikrar görevi',
    'taskReasonCauseTopHour': 'En riskli saate göre seçildi',
    'taskReasonCauseTopTrigger': 'En riskli tetikleyiciye göre seçildi',
    'taskReasonNextNotification': 'Sonraki hatırlatma',
    'taskReasonNoPlanned': 'Planlı görev yok',
    'taskReasonNoRecentData': 'Yeterli güncel veri yok',
    'taskReasonRecentRatio': 'Son performans oranı',
    'taskReasonRiskLine': 'Risk açıklaması',
    'taskSkipOneCig': 'Bugün bir sigarayı atla',
    'taskSmokeTwoLess': 'Bugün 2 sigara eksik ic',
    'taskStartTitle': 'Görev başladı',
    'taskStateCompleted': 'Tamamlandı',
    'taskStateDeferred': 'Ertelendi',
    'taskStateFailed': 'Bu sefer olmadı',
    'taskStateNew': 'Yeni',
    'taskSuspiciousReset': 'Beklenmedik bir durum nedeniyle sıfırlandı',
    'taskUnit': 'görev',
    'taskUseGumAtRiskHour': 'Riskli saatte şeker sakız kullan',
    'todaysTasks': 'Bugünün görevleri',
    'totalUsage': 'Toplam kullanım',
    'trendDeclining': 'Düşüşte',
    'trendImproving': 'İyileşiyor',
    'trendStable': 'Stabil',
    'trialStatus': 'Deneme durumu',
    'unnamedUser': 'Isimsiz kullanıcı',
    'viewAllSurveys': 'Tüm anketleri gör',
    'violationHigh': 'Yüksek',
    'violationLow': 'Düşük',
    'violationMedium': 'Orta',
    'violationReportEmpty': 'Henüz kayıtlı bir an yok.',
    'violationReportTitle': 'Zorlandığın Anlar',
    'violationSource': 'Kaynak',
    'violationTask': 'Görev',
    'violationTime': 'Zaman',
    'weekly': 'Haftalık',
    'weeklyImprovement': 'Haftalık iyileşme',
    'weeklyMood': 'Haftalık ruh hâli',
    'weeklyRecordTitle': 'Haftalık Kayıt',
    'weeklyRiskTarget': 'Haftalık risk hedefi',
    'welcome': 'Hoş geldin',
    'taskActionDone': 'Görevi Başlat',
    'taskActionNotNow': 'Şimdi Uygun Değil',
    'taskActionDoneLabel': 'Kabul Et',
    'taskActionNotNowLabel': 'Ertele',
    'taskActionDeclineLabel': 'Reddet',
    'taskActionSosLabel': 'SOS Krizdeyim',
    'postponeChoiceTitle': 'Ne kadar ertelensin?',
    'postponeChoiceBody': 'Aynı görev seçilen süre sonunda tekrar gelecek.',
    'postpone5Label': '5 dakika',
    'postpone10Label': '10 dakika',
    'postpone15Label': '15 dakika',
    'taskConfirmQuestionTitle': 'Süre doldu',
    'taskConfirmQuestion': 'Bu süre içinde sigara içtiniz mi?',
    'taskConfirmYesLabel': 'İçtim — Başarısız',
    'taskConfirmNoLabel': 'İçmedim — Başarılı',
    'sosPageTitle': 'Su an isteğim var',
    'sosIntro': 'Bu his birkaç dakika içinde geçecek. Birlikte nefes alalım.',
    'sosCyclesCompleted': '{count} tür tamamlandı',
    'sosPhaseInhale': 'Nefes al',
    'sosPhaseHold': 'Tut',
    'sosPhaseExhale': 'Ver',
    'sosReassurance':
        'İstek dalgası genelde 3-5 dakikada zirve yapip azalır. Sigara içmeden de bu anı atlatabilirsin.',
    'sosDismiss': 'Atlattim',
    'sosNeedSuggestion': 'Bana bir şey öner',
    'sosSuggestionTitle': 'Şunu dene',
    'sosSuggestionWater': 'Bir bardak su ic, yavaşça.',
    'sosSuggestionWalk': 'Beş dakika yürü, tercihen dışarıda.',
    'sosSuggestionCall': 'Bugün konuşmadığın birini ara.',
    'sosSuggestionStretch': 'Ayağa kalk ve omuzlarını gevşet.',
    'sosSuggestionWash': 'Yüzünü soğuk suyla yıka.',
    'sosResumeQuestion': 'Görevine ne zaman dönelim?',
    'sosResume30': '30 dakika sonra',
    'sosResume60': '1 saat sonra',
    'sosResume120': '2 saat sonra',
    'sosTaskPostponed': 'Görev ertelendi. Kendine iyi bak.',
    'sosBarrierResumed': 'Bariyer devam ediyor. Başardın.',
    'sosBarrierResumedTitle': 'Krizi atlattin',
    'sosBarrierResumedBody':
        'Bariyeri sıfırlamadık, kaldıgın yerden devam ediyor. Bu tam olarak istediğimiz şey.',
    'sosBarrierResumedAction': 'Devam et',
    'barrierWonFeedback':
        '{minutes} dakika sigarasız. Bu ay toplam {hours} saat sigarasız aralık.',
    'failureTriggerPromptTitle': 'Az önce sigara içmenize ne sebep oldu?',
    'failureTriggerStress': 'Stres veya gerginlik',
    'failureTriggerCoffee': 'Kahve veya çay',
    'failureTriggerMeal': 'Yemek sonrası',
    'failureTriggerAlcohol': 'Alkol',
    'failureTriggerPhone': 'Telefon kullanımı',
    'failureTriggerDriving': 'Araç kullanma',
    'failureTriggerWorkBreak': 'İş molası',
    'failureTriggerSocial': 'Sosyal ortam',
    'failureTriggerBoredom': 'Can sıkıntısı',
    'failureTriggerHabit': 'Alışkanlık / otomatik olarak',
    'failureTriggerNoReason': 'Belirli bir neden yoktu',
    'failureTriggerUnknown': 'Şimdi cevaplamak istemiyorum',
    'medicationTimesPerDay': 'Günde kaç kez alıyorsunuz?',
    'medicationTimesPerDayHint':
        'Saatleri uyanık olduğunuz süreye eşit dağıtıp öneriyoruz; her birini değiştirebilirsiniz.',
    'medicationTimeSlotLabel': '{index}. doz',
    'medicationAdviceDisclaimer':
        'Bu bilgi genel niteliktedir; tedavinizle ilgili kararlar için doktorunuza danışın.',
    'taskFollowUpActionYes': 'Evet',
    'taskFollowUpActionNo': 'Hayır',
    'disciplineCommand': 'Şu andan itibaren sigara içme',
    'disciplineCommandBody':
        'Protokol aktif. Bildirim kapanması için görevi başlat.',
    'breathReminderTitle': 'Nefes Testi',
    'breathReminderBody': 'Günlük nefes testi zamanı geldi.',
    'breathReminderDriving':
        'Sürüşte güvenliğiniz için hatırlatma kısa süre ertelendi.',
    'breathReminderWorkout':
        'Aktivite tamamlanınca hatırlatma tekrar gönderilecek.',
    'breathReminderPostMeal':
        'Yemek sonrası sigarayı ertelemek için nefes rutinini şimdi uygula.',
    'taskFollowUpTitlePush': 'Görev Takibi',
    'taskFollowUpQuestion': 'Görevi başarıyla tamamladınız mi?',
    'taskFollowUpQuestionDriving':
        'Sürüş sonrası cevaplayın: Görevi başarıyla tamamladınız mi?',
    'taskFollowUpQuestionWorkout':
        'Aktivite sonrası cevaplayın: Görevi başarıyla tamamladınız mi?',
    'taskFollowUpQuestionPostMeal':
        'Yemek sonrası sigara isteğini yönetebildiniz mi?',
    'postMealShieldCommand':
        'Yemek sonrası 10 dakika ertele + su + sakız rutini uygula.',
    'contextReasonDriving': 'Bildirim sürüş/ulaşım durumu nedeniyle ertelendi',
    'contextReasonWorkout': 'Bildirim kosu/egzersiz durumu nedeniyle ertelendi',
    'contextReasonEating':
        'Bildirim yemek penceresi nedeniyle yemek sonrasına kaydırıldı',
    'contextReasonNormal': 'Bildirim normal plana göre ayarlandı',
    'taskEscalationTitle': 'Hâlâ bekliyorum',
    'taskEscalationBodyPrefix':
        'Henüz cevap vermedin. {minutes} dakika sonra tekrar soracağım:',
    'taskTimerStartedBody': 'Görev başladı:',
    'taskTimerDuration': 'Sayaç',
    'minutesShort': 'dakika',
    'oneHourLabel': '1 saat',
    'postponeReminderPromptTitle': 'Ne zaman hatırlatayım?',
    'postponeReminderPromptMessage':
        'Görevi erteliyorsunuz. Size ne zaman tekrar hatırlatmamı istersiniz?',
    'sleepActivityAdvisoryTitle': 'Hâlâ ayakta misin?',
    'sleepActivityAdvisoryBody':
        'Uyku saatinde uyanık olduğunu fark ettik. Bugünkü görevlerini zaten tamamladın, sadece dinlenmeyi unutma.',
    'weeklySurveyReminderTitle': 'Haftalık anket zamanı',
    'weeklySurveyReminderBody':
        'Risk skorunu güncellemek için haftalık anketi doldurman gerekiyor.',
    'trialInfoTitle': '14 Günlük Ücretsiz Deneme',
    'trialInfoMessage':
        'Nikotin Away uygulamasını 14 gün boyunca, Yapay Zeka Mentoru dahil tüm özellikleriyle ücretsiz deneyebilirsin. 14 gün sonunda devam etmek için abonelik gerekir.',
    'subscriptionGateTitle': 'Deneme Süresi Doldu',
    'subscriptionGateMessage':
        '14 günlük ücretsiz deneme süren sona erdi. Yapay Zeka Mentoru, görev sistemi, nefes/öksürük testleri ve konum/uyku zekası gibi özellikler için abonelik gerekir; temel özelliklerle ücretsiz devam edebilirsin.',
    'subscriptionMonthlyTitle': 'Aylık',
    'subscriptionYearlyTitle': 'Yıllık',
    'subscriptionPurchaseButton': 'Satın Al',
    'subscriptionRestoreButton': 'Satın Alımı Geri Yükle',
    'subscriptionContinueFreeButton': 'Ücretsiz Devam Et',
    'subscriptionNeedsConnection':
        'Abonelik durumunu doğrulamak için internet bağlantısı gerekiyor. Bağlanınca otomatik olarak tekrar denenecek.',
    'subscriptionRetryButton': 'Tekrar Dene',
    'subscriptionPurchasePending': 'İşleniyor...',
    'subscriptionPurchaseFailed': 'Satın alma tamamlanamadı, tekrar dene.',
    'subscriptionRestoreNotFound': 'Geri yüklenecek bir satın alma bulunamadı.',
    'subscriptionStoreUnavailable':
        'Mağaza şu anda ulaşılamaz durumda. Lütfen daha sonra tekrar dene.',
    'premiumUpsellTitle': 'Premium Özellik',
    'premiumUpsellDismiss': 'Vazgeç',
    'premiumUpsellUpgrade': 'Yükselt',
    'premiumUpsellAiMentor':
        'Yapay Zeka Mentoru bir abonelik veya deneme süresi gerektirir.',
    'premiumUpsellBreathTests':
        'Nefes ve öksürük testleri bir abonelik veya deneme süresi gerektirir.',
    'premiumUpsellLocationIntelligence':
        'Konum Zekası bir abonelik veya deneme süresi gerektirir.',
    'savingsPageTitle': 'Tasarruf',
    'savingsMoneySaved': 'Biriken para',
    'savingsCigarettesNotSmoked': 'İçilmeyen sigara',
    'savingsLifeTimeRegained': 'Kazanılan yaşam süresi',
    'savingsHoursUnit': '{hours} saat',
    'savingsPackPriceLabel': 'Paket fiyatı (₺)',
    'savingsPackPriceHint': 'Örn: 80',
    'savingsSaveButton': 'Kaydet',
    'healthRecoveryPageTitle': 'Sağlık İyileşme Süreci',
    'recoveryMin20Title': '20 dakika',
    'recoveryHour12Title': '12 saat',
    'recoveryDay1Title': '24 saat',
    'recoveryDay2Title': '48 saat',
    'recoveryDay3Title': '72 saat',
    'recoveryWeek2Title': '2 hafta',
    'recoveryMonth1Title': '1 ay',
    'recoveryMonth9Title': '9 ay',
    'recoveryYear1Title': '1 yıl',
    'recoveryYear5Title': '5 yıl',
    'recoveryYear10Title': '10 yıl',
    'recoveryMin20Desc': 'Nabız ve kan başıncı normale dönmeye başlar.',
    'recoveryHour12Desc': 'Kandaki karbonmonoksit seviyesi normale düşer.',
    'recoveryDay1Desc': 'Kalp krizi riski azalmaya başlar.',
    'recoveryDay2Desc': 'Tat ve koku alma duyusu belirgin şekilde iyileşir.',
    'recoveryDay3Desc': 'Nefes almak kolaylaşır, enerji seviyesi artar.',
    'recoveryWeek2Desc': 'Kan dolaşımı ve akciğer fonksiyonu iyileşir.',
    'recoveryMonth1Desc': 'Öksürük ve nefes darlığı belirgin azalır.',
    'recoveryMonth9Desc': 'Akciğerlerdeki silyalar yeniden işlev kazanır.',
    'recoveryYear1Desc': 'Koroner kalp hastalığı riski yarı yarıya azalır.',
    'recoveryYear5Desc': 'İnme riski, hiç içmemiş biri seviyesine yaklaşır.',
    'recoveryYear10Desc': 'Akciğer kanseri riski yaklaşık yarıya iner.',

    'mentorDailyCoachHourTemplate':
        'Bu ara gerçekten iyi gidiyorsun. Bugün özellikle {hour} aralığına dikkat et, gerisini zaten götürüyorsun.',
    'mentorDailyCoachNoHour':
        'Bu ara gerçekten iyi gidiyorsun. Bu tempoyu koruyalım.',
    'mentorDailySupportive':
        'Son günler senin için kolay geçmiyor gibi görünüyor, bunu görüyorum. Bugün mükemmel olması gerekmiyor — sadece bir sonraki anı atlatmaya odaklan.',
    'mentorDailyNeutralHourTemplate':
        'Bugün nasıl gidiyor? {hour} aralığında yanındayım.',
    'mentorDailyNeutralNoHour': 'Bugün nasıl gidiyor? ',
    'mentorBreathImprovingNote':
        'Son nefes testlerin de iyiye gidiyor, bunu fark ettim — devam et.',
    'mentorWeeklyCoachTemplate':
        'Bu hafta gerçekten güçlüydün — {count} görevi tamamladın. Bu ivmeyi haftaya da taşıyalım.',
    'mentorWeeklySupportive':
        'Bu hafta zorlu geçti, farkındayım. Sayılar önemli değil şu an — önemli olan hâlâ burada olman.',
    'mentorWeeklyNeutralTemplate':
        'Bu haftaki risk seviyen: {level}. Detaylı bir haftalık anketle daha net bir resim çıkarabiliriz.',
    'mentorHistImprovedTemplate':
        'Geçen hafta {daypart} zorlanmıştın — bu hafta o saatlerde hiç kayıt yok, harika gidiyor.',
    'mentorHistWorseningTemplate':
        'Geçen hafta {daypart} zorlanmıştın, bu hafta da benzer görünüyor. Birlikte bu saatlere özel bir plan yapalım mı?',
    'mentorHistSimilarTemplate':
        'Geçen hafta {daypart} zorlanmıştın, bu hafta biraz daha iyi görünüyorsun.',
    'mentorDayPartMorning': 'sabahları',
    'mentorDayPartAfternoon': 'öğleden sonraları',
    'mentorDayPartEvening': 'akşamları',
    'mentorDayPartNight': 'geceleri',
    'mentorReframeSuspiciousWithTitleTemplate':
        'Az önce bir şeyler ters gitmiş gibi göründü ("{title}" sırasında). İyi misin? İstersen birlikte kısa bir nefes molası verelim.',
    'mentorReframeSuspiciousNoTitle':
        'Az önce bir şeyler ters gitmiş gibi göründü. İyi misin? İstersen birlikte kısa bir nefes molası verelim.',
    'mentorReframeWillpower':
        'Bu sefer olmadı, sorun değil — bu bir başarısızlık değil, sürecin bir parçası. Yarın yeniden deneriz.',
    'mentorReframeDeferredStart':
        'Şimdi uygun değilse anlıyorum, 10 dakika sonra tekrar hatırlatacağım.',
    'mentorReframeFollowupDeferred': 'Tamam, biraz sonra tekrar soracağım.',
    'mentorReframeDurationBarrier':
        'Bu hedef sana göre biraz uzun geldi sanırım. Bir dahaki sefere daha kısa bir süreyle başlayalım — küçük adımlar da ilerlemedir.',
    'quickReplyOk': 'İyiyim',
    'quickReplyStruggling': 'Zorlanıyorum',
    'quickReplyNoTalk': 'Konuşmak istemiyorum',
    'quickReplyFillWeeklySurvey': 'Haftalık anketi doldur',
    'quickReplyLater': 'Daha sonra',
    'quickReplyThanks': 'Teşekkürler',
    'quickReplyLetsTalk': 'Konuşalım',
    'quickReplyOkAck': 'Tamam',
    'mentorFollowupStrugglingQ': 'Ne tür yardım istersin?',
    'quickReplyReduceTasks': 'Görevleri azalt',
    'quickReplyEaseBarrier': 'Bariyeri gevşet',
    'quickReplyJustTalking': 'Sadece konuşmak istedim',
    'mentorFollowupAckReduceTasks':
        'Yarından itibaren bir hafta boyunca görevlerini azalttım, kendine iyi bak.',
    'mentorFollowupAckEaseBarrier': 'Yarın için bariyeri biraz gevşettim.',
    'mentorFollowupAckJustTalking':
        'Buradayım, ne zaman istersen yazabilirsin.',
    'sleepRoutineTitle': 'Uyku Öncesi Rutin',
    'sleepRoutineIntro': 'Uyumadan önce 4 kısa adım',
    'sleepRoutineStepIndicator': 'Adım {current} / {total}',
    'sleepRoutineDiscrepancyQuestionTitle': 'Bugün kaç sigara içtin?',
    'sleepRoutineDiscrepancyQuestionBody':
        'Kayıtlarda {count} eksik görünüyor, unuttuğun var mı?',
    'sleepRoutineDiscrepancyNoneButton': 'Hayır, doğru logladım',
    'sleepRoutineDiscrepancyConfirmButton': 'Eklediklerimi kaydet',
    'sleepRoutineReportTitle': 'Bugünkü İlerleme',
    'sleepRoutineReportCloseButton': 'Kapat',
    'sleepRoutineReportNoEvidence': 'Bugün için henüz yeterli veri yok',
    'sleepRoutineReportTaskSuccessLabel': 'Görev Başarısı',
    'sleepRoutineCommand': 'Uyku öncesi rutin zamanı',
    'loginTitle': 'Hoş Geldin',
    'loginSubtitle': 'Verilerini bulutta sakla, yeniden kurunca geri yükle',
    'loginGoogleButton': 'Google ile Giriş Yap',
    'loginEmailButton': 'E-posta hesabıyla giriş yap',
    'loginEmailCreate': 'Yeni hesap oluştür',
    'loginEmailAddress': 'E-posta adresi',
    'loginEmailPassword': 'Şifre',
    'loginEmailInvalid': 'E-posta hesabı işlemi başarısız oldu.',
    'loginGoogleFailed':
        'Google ile giriş yapılamadı. Tekrar deneyin veya geçin.',
    'cancel': 'İptal',
    'loginFirstUserButton': 'İlk kez kullanıyorum',
    'loginSkipButton': 'Şimdilik Geç',
    'loginSkipSubtitle': 'Hesap bağlantısız devam edebilirsin',
    'loginRestoring': 'Verilerin geri yükleniyor...',
    'loginNoCloudData': 'Bulutta kayıtlı verin bulunamadı.',
    'loginRestoreSuccess': '{count} kayıt geri yüklendi.',
    'notificationsPageTitle': 'Bildirimler',
    'notificationsEmpty': 'Son 6 saat içinde bildirim yok',
    'settingsNotificationsRow': 'Bildirim Geçmişi',
    'settingsNotificationsRowSubtitle': 'Son bildirimlerini görüntüle',
  };

  // English - Full translation
  static const Map<String, String> _en = {
    'appName': 'NIKOTIN AWAY',
    'appTagline': 'Your Personal Quit Smoking Mentor',
    'watchdogForegroundBody': 'Waiting for task response',
    'watchdogViolationTitle': 'Nikotin Away Reminder',
    'watchdogViolationBody':
        'No response for 10 minutes. You may have missed the {taskTitle} task — that\'s okay.',
    'watchdogForegroundChannel': 'Background service',
    'watchdogViolationChannel': 'Nikotin Away Reminders',
    'selectLanguage': 'Select language',
    'continue': 'Continue',
    'back': 'Back',
    'yes': 'Yes',
    'no': 'No',
    'save': 'Save',
    'home': 'Home',
    'tabTests': 'Tests',
    'tabTracking': 'Tracking',
    'weeklySurvey': 'Weekly Survey',
    'riskAnalysis': 'Risk Analysis',
    'retry': 'Retry',
    'iBreathed': 'I Breathed',
    'start': 'Start',
    'test': 'Test',
    'good': 'Good',
    'bad': 'Bad',
    'risk': 'Risk',
    'name': 'Name',
    'age': 'Age',
    'gender': 'Gender',
    'male': 'Male',
    'female': 'Female',
    'selectOption': 'Select',
    'breathTest': 'Breathing Exercise',
    'breathTestPageTitle': 'Breath Test',
    'riskLevel': 'Risk level',
    'smokeFreeDaysWidgetLabel': 'smoke-free days',
    'riskScore': 'Risk score',
    'initialSurvey': 'Initial Survey',
    'taskResultTitle': 'Task Result',
    'reportsAvertedCigarettes': 'Estimated cigarettes not smoked',
    'reportsDisclaimer':
        'This report contains estimates based on your records; it is not a medical evaluation or diagnosis. Consult your doctor for personal health decisions.',
    'reportsNoDataYet': 'Not enough data yet',
    'reportsPartAfternoon': 'Afternoon (13:00–17:00)',
    'reportsPartEvening': 'Evening (17:00–22:00)',
    'reportsPartMidday': 'Midday (10:00–13:00)',
    'reportsPartMorning': 'Morning (05:00–10:00)',
    'reportsPartNight': 'Night (22:00–05:00)',
    'reportsSmokingTimePattern': 'Smoking time distribution',
    'smokingInfo': 'Smoking Information',
    'lifeRoutine': 'Daily Routine',
    'professionLabel': 'Profession',
    'healthStatus': 'Health Status',
    'triggerTitle': 'Smoking Triggers',
    'stressTitle': 'Stress Level',
    'quitReasonTitle': 'Quit Reason',
    'heartDisease': 'Heart Disease',
    'otherHealthCondition': 'Other',
    'otherHealthConditionHint': 'Enter your condition',
    'usesMedicationQuestion': 'I take medication regularly',
    'addMedicationButton': 'Add medication',
    'medicationNameHint': 'Medication name',
    'addMedicationTimeButton': 'Add time',
    'medicationsSettingsRow': 'My Medications',
    'medicationsSettingsRowSubtitle': 'Add, edit, or remove medications',
    'medicationsPageTitle': 'My Medications',
    'medicationsEmptyState': 'You haven\'t added any medications yet.',
    'medicationDeleteConfirmTitle': 'Delete medication',
    'medicationDeleteConfirmMessage':
        'Are you sure you want to delete this medication and its reminders?',
    'medicationSavedConfirmation': 'Medication saved',
    'medicationReminderTitle': 'Medication reminder',
    'medicationReminderBody': 'It\'s time to take your {name}.',
    'overlayPermissionTitle': 'Show the task screen',
    'overlayPermissionMessage':
        'For the task screen to open over other apps even when the phone isn\'t locked, we need the "display over other apps" permission. Open the settings screen now?',
    'smokedLogButtonRow': 'I Smoked button',
    'smokedLogButtonTitle': 'I Smoked Button',
    'smokedLogButtonDescription':
        'A small, translucent button appears on screen. When you smoke, press and hold it for 1 second to open the options and record the moment. A stray tap records nothing.',
    'smokedLogButtonPurpose':
        'This is how the app learns which hours and which places you tend to smoke in, so it can aim tasks at exactly those moments. Location is only matched against the handful of places you already visit often; no address or movement history is stored. Everything stays on your device.',
    'smokedLogButtonEnabled': 'I Smoked button is on.',
    'smokedLogButtonDisabled': 'I Smoked button is off.',
    'smokedLogButtonNeedsOverlay':
        'This button needs the "display over other apps" permission.',
    'smokedLogButtonNotificationTitle': 'Nikotin Away',
    'smokedLogButtonNotificationBody':
        'Hold the floating button for 1 second to open the options',
    'smokedLogButtonAction': 'I Smoked',
    'smokedLogMenuTitle': 'What do you need?',
    'smokedLogMenuSos': 'SOS — Craving',
    'smokedLogMenuOpen': 'Open the app',
    'smokedLogMenuCancel': 'Cancel',
    'dailyBreathPromptContent':
        'Take the breathing test now? Once a day is enough.',
    'dailyBreathOverdueContent':
        'There has been no breathing test for 24 hours. This reading cannot '
        'be filled in later — a skipped day stays a gap in the chart.',
    'dailyBreathLater': 'Later',
    'dailyBreathOverdueNotificationTitle': 'Your breathing test is waiting',
    'dailyBreathOverdueNotificationBody':
        'No reading for 24 hours. Open the app and complete the test.',
    'smokedLogRecordedWithUndo': 'Cigarette recorded.',
    'smokedLogUndoBody': 'Tapped by accident? You can undo it.',
    'smokedLogUndoAction': 'Undo',
    'channelNameSmokedLogUndo': 'Smoking log undo',
    'smokedLogConsentHeading': 'Turn on the I Smoked button?',
    'smokedLogConsentDataTitle': 'What gets recorded',
    'smokedLogConsentDataBody':
        'Only the moment you press the button and — if Location Intelligence is on — which of your frequent places you were near at the time. No address, no coordinates, no movement history. If location isn\'t available the cigarette is still recorded, just without a place.',
    'smokedLogConsentStorageTitle': 'Where it is kept',
    'smokedLogConsentStorageBody':
        'On this device only. Nothing is sent anywhere. You can remove the button and your past records from Settings at any time.',
    'smokedLogConsentAccept': 'Turn on the button',
    'smokedLogConsentDecline': 'Not right now',
    'permissionSetupTitle': 'Permissions needed',
    'permissionSetupIntro':
        'These permissions let tasks reach you at the right moment, and visibly. Each row updates on its own when you come back from Settings.',
    'permissionOverlayDescription':
        'Lets the task screen open over other apps. Without it tasks still arrive, just as a notification.',
    'permissionOemDescription':
        'This phone keeps some notification settings in the manufacturer\'s own permission screen. That\'s where "run in background" and "show on lock screen" live.',
    'notifKindsSectionTitle': 'Notification Types',
    'notifKindsTitle': 'Which notifications do you want?',
    'notifKindsHint':
        'Task alerts and the medication times you set yourself always '
        'arrive. The ones below are optional — turning them off does not '
        'affect your daily progress.',
    'notifKindBreathTest': 'Breath test reminder',
    'notifKindWeeklySurvey': 'Weekly survey reminder',
    'notifKindHealthTip': 'Health tips',
    'dailyHealthTipCountLabel': 'How many health tips per day?',
    'notifKindCoachCommand': 'Coaching suggestions',
    'notifKindSedentary': 'Sedentary reminder',
    'permissionSetupOptionalHeading': 'Permissions for optional features',
    'permissionSetupOptionalHint':
        'The app works without these. Granting one does not switch the '
        'feature on by itself — it just means Settings won\'t need to ask '
        'again when you do.',
    'permissionHealthTitle': 'Health Data (Health Connect)',
    'permissionHealthDescription':
        'If Wearable Intelligence is on, reads heart rate and sleep data '
        'from your watch or band. Stays on your device, never sent '
        'anywhere.',
    'permissionUsageAccessTitle': 'App Usage Access',
    'permissionUsageAccessDescription':
        'Reads which app is on screen (name only, never its content) so '
        'health-tip and task overlays skip a moment when you\'re on a call, '
        'gaming, watching a video or on social media instead of '
        'interrupting it.',
    'permissionUsageAccessPurpose':
        'Why: without this the app still guesses using free signals like '
        'how long the screen has been on and whether audio is playing, but '
        'this permission makes that guess far more accurate.',
    'permissionSetupContinueAnyway': 'Continue for now',
    'permissionSetupOptionalNote': 'You can change these later from Settings.',
    'packsPerDayQuestion': 'How many packs of cigarettes do you smoke per day?',
    'firstCigaretteWhen':
        'How long after waking up do you smoke your first cigarette?',
    'firstCigarette10to30': '10-30 minutes after waking',
    'maxSmokeFreeDuration': 'Longest smoke-free duration',
    'smokeFree30to60': '30-60 minutes',
    'smokingYears': 'Smoking years',
    'cigarettesPerPackLabel': 'How many cigarettes are in a pack?',
    'triggerCoffee': 'Coffee',
    'triggerMeal': 'After meals',
    'triggerDriving': 'While driving',
    'triggerStress': 'When stressed',
    'triggerPhone': 'On phone calls',
    'triggerSocial': 'Social situations',
    'triggerWork': 'Work break',
    'triggerBoredom': 'Boredom',
    'triggerHabit': 'Habit',
    'triggerUnknown': 'I do not know',
    'triggerAlcohol': 'Alcohol',
    'stressMedium': 'Medium',
    'quitReason': 'Quit reason',
    'quitHealth': 'For my health',
    'riskCritical': 'CRITICAL',
    'riskHigh': 'HIGH',
    'riskMedium': 'MEDIUM',
    'riskLow': 'LOW',
    'validationNameRequired': 'Please fill in the name field.',
    'validationAgeRequired': 'Please fill in the age field.',
    'validationGenderRequired': 'Please select a gender.',
    'hello': 'Hello',
    'weeklySavePrompt': 'Save your status for this week.',
    'weeklySurveyPromptAsk':
        'Would you like to complete the weekly survey now?',
    'shareProgressTitle': 'Share your progress',
    'shareProgressMessage':
        'You just completed your weekly check-in. Want to share your progress with friends?',
    'shareProgressSkip': 'Skip',
    'shareProgressAction': 'Share',
    'shareProgressText':
        'I\'m tracking my quit-smoking journey with Nikotin Away. My current risk score: {score}/100 ({level}).',
    'shareAppTitle': 'Share on Social Media',
    'shareAppMessage':
        'Discover Nikotin Away: track your quit-smoking journey, understand your triggers, and get personal coaching.\n\n{url}',
    'saveErrorRetry': 'An error occurred while saving. Please try again.',
    'loadErrorRetry':
        'Something went wrong loading this data. Please try again.',
    'smokeFreeStreak': 'Smoke-Free Streak',
    'reductionCardTitle': 'Your Reduction Progress',
    'reductionStreakLabel': 'Days on target',
    'reductionAvoidedLabel': 'Cigarettes not smoked',
    'reductionIntervalLabel': 'Gap between cigarettes',
    'reductionTargetToday': "Today's target: {target} cigarettes at most",
    'reductionLoggedToday': 'You logged {count} today',
    'reductionNoDataTitle': 'Nothing to measure yet',
    'reductionNoDataBody':
        'Press the button when you smoke, or answer your tasks — progress '
        'can only come from what actually happened.',
    'reductionIntervalDetail': 'Was {natural} min, now {barrier} min',
    'reductionIntervalGain': '{percent}% longer',
    'reductionBaselineNote': 'You started at {baseline} a day',
    'healthMetrics': 'Health Metrics',
    'noBreathTestsYet': 'No breath test records yet.',
    'longitudinalAnalysis': 'Longitudinal Analysis',
    'statistics': 'Statistics',
    'recentTests': 'Recent Tests',
    'workDaysLabel': 'Working days',
    'dayMonShort': 'Mon',
    'dayTueShort': 'Tue',
    'dayWedShort': 'Wed',
    'dayThuShort': 'Thu',
    'dayFriShort': 'Fri',
    'daySatShort': 'Sat',
    'daySunShort': 'Sun',
    'weekendPatternLabel': 'Weekend smoking pattern',
    'weekendPatternSame': 'Same as weekdays',
    'weekendPatternMore': 'More on weekends',
    'weekendPatternLess': 'Less on weekends',
    'smokingBreakExists': 'Are smoking breaks available at work?',
    'break1Start': 'Break 1 start',
    'break1End': 'Break 1 end',
    'break2Exists': 'Second break available',
    'break2Start': 'Break 2 start',
    'break2End': 'Break 2 end',
    'updatedWorkStart': 'Updated work start time',
    'updatedWorkEnd': 'Updated work end time',
    'updatedWorkplaceRule': 'Workplace smoking rule',
    'searchLanguages': 'Search languages...',
    'otherLanguages': 'Other languages',
    'backToMain': 'Back to main',
    'notSpecified': 'Not specified',
    'unknownValue': 'Unknown',
    'breathRestInstruction':
        'Short rest: Breathe normally.\nPrepare for the next attempt.',
    'breathActiveInstruction':
        '1. Sit upright and relax.\n2. Tap the circle, breathe in deeply through your nose until your lungs are full, and hold briefly.\n3. Blow out SUDDENLY and as hard as you can, in one burst.\n4. Tap the circle again when you\'re done.\n\n3 attempts will be performed, best score is saved.',
    'breathExerciseDisclaimer':
        'This is not a spirometer. It\'s a measurement to help you track your own progress.',
    'breathSpirometryResultTitle': 'Breath Test Result',
    'breathScoreLabel': 'Breath Score',
    'breathScoreDisclaimer':
        'This score is a comparison against your own history; it is not a medical measurement.',
    'breathSpirometryEstimateDisclaimer':
        'This is not a medical diagnostic tool. If you have a health concern, consult your doctor.',
    'micRationaleTitle': 'Microphone permission',
    'micRationaleMessage':
        'We can use the microphone to automatically time your exhale. Audio is never recorded or stored — only the momentary sound level is measured. If you decline, you can still finish the test manually by tapping.',
    'restingLabel': 'Resting',
    'secondsLeftLabel': 'seconds left',
    'tapCircleToFinish': 'Tap the circle when you\'re done',
    'breathListeningHint':
        'Listening... exhale, it will be detected automatically',
    'breathStepSitRelax': 'Sit upright and relax.',
    'breathStepDeepBreath':
        'Breathe in deeply until your lungs are completely full.',
    'breathStepHold': 'Hold your breath briefly.',
    'breathStepExhale':
        'Blow into the microphone SUDDENLY and as hard as you can until your breath is done — not slow, all at once.',
    'breathStepExhaleFinishHint': 'Your breath will be detected automatically.',
    'breathStepOkAction': 'Continue',
    'breathAutoNextAttemptInstruction':
        'Sit upright and relax. Breathe in deeply until your lungs are completely full. Hold briefly. Blow into the microphone suddenly and as hard as you can. Your breath will be detected automatically.',
    'breathNoiseCheckListening': 'Listening to your surroundings...',
    'breathNoiseWarningTitle': 'It might be noisy',
    'breathNoiseWarningMessage':
        "There's some background noise. The result will still be saved, but it will be more reliable in a quieter spot. How would you like to continue?",
    'breathNoiseLoudTitle': "It's quite noisy",
    'breathNoiseLoudMessage':
        'The background noise is fairly high for this test. You can continue, but the result will be marked as "recorded in a noisy environment" and shown separately on your progress chart. We recommend moving somewhere quieter.',
    'breathNoiseContinueAnyway': 'Continue Anyway',
    'breathNoiseRetry': 'Try Again',
    'breathNoiseDuringAttemptWarning':
        'Background noise increased during the test — this attempt was marked as noisy.',
    'coughInsufficientSignalTitle': "Microphone didn't pick up any sound",
    'coughInsufficientSignalMessage':
        'This attempt captured almost no audio — the app may have been backgrounded, or the microphone may be in use by another app. The result was not saved; please try again.',
    'breathFeedbackTooShort': 'Try to empty your lungs completely.',
    'breathFeedbackLowStability': 'Try blowing with a steady, even force.',
    'breathFeedbackWeakSignal': 'Bring the phone a bit closer to your mouth.',
    'breathFeedbackBetterThanBefore':
        'That attempt was stronger than your last one!',
    'breathFeedbackGoodAttempt': 'Good attempt.',
    'breathAnalysisPageTitle': 'Breath Analysis',
    'breathAnalysisEmptyTitle': 'No data yet',
    'breathAnalysisEmptyBody':
        "Once you complete your first breath test, you'll see a chart and summary of your progress here.",
    'breathAnalysisEmptyCta': 'Start a breath test',
    'breathAnalysisNotEnoughDataTitle':
        'A few more tests are needed for a trend',
    'breathAnalysisScoreChartTitle': 'Breath Score — Last 30 Days',
    'breathAnalysisChartRawLabel': 'Test',
    'breathAnalysisChartAverageLabel': '7-day average',
    'breathAnalysisWeeklyAverageTitle': 'Weekly Average',
    'breathAnalysisSummaryProgressLabel': 'Progress',
    'breathAnalysisSummaryBestScoreLabel': 'Best Score',
    'breathAnalysisSummaryConsistencyLabel': 'Consistency',
    'breathAnalysisSummaryTestCountLabel': 'Test Count',
    'breathAnalysisBadgesTitle': 'Badges',
    'breathAnalysisNoisyLegend': 'Recorded in a noisy environment',
    'breathBadgeFirstTestTitle': 'First Step',
    'breathBadgeFirstTestDesc': 'Completed your first breath test.',
    'breathBadgeStreak7Title': '7-Day Streak',
    'breathBadgeStreak7Desc': 'Took a breath test 7 days in a row.',
    'breathBadgeTotal30Title': '30 Tests',
    'breathBadgeTotal30Desc': 'Completed 30 breath tests in total.',
    'breathBadgePersonalRecordTitle': 'Personal Record',
    'breathBadgePersonalRecordDesc': 'Beat your own best score.',
    'disciplineDisclosureTitle': 'How do we support you?',
    'disciplineDisclosureMessage':
        'Nikotin Away uses a few background mechanisms to support you through quitting:\n\n'
        '- If you don\'t respond to a task reminder in time, we note it on your device as a compliance record.\n'
        '- During an active task, we try to estimate possible risky moments from phone motion and usage patterns (via motion sensors and the microphone). Audio is never recorded or stored — only the ambient sound level is measured.\n'
        '- Some task reminders may appear as full-screen alerts to get your attention.\n'
        '- So task notifications don\'t interrupt a real phone call, we check whether you\'re currently on one; we never read call content or numbers.\n\n'
        'By default, this data stays only on your device and is never used for anything other than supporting you. In Settings > Cloud Backup you can optionally turn on an encrypted backup protected by a passphrase you choose — we can never read that passphrase either, only you know it. Continuing means you acknowledge this; you can still separately allow or deny the microphone, motion, and phone-state permissions in the next step.',
    'disciplineDisclosureAcknowledge': 'I understand, continue',
    'cravingSosButton': 'Craving now',
    'quickActionSmokedNow': 'I Smoked',
    'quickActionSmokedNowConfirmed': 'Logged.',
    'quickActionSelfChallenge': 'Challenge Myself',
    'quickActionOpenApp': 'Open App',
    'selfChallengeTitle': 'Your Own Challenge',
    'selfChallengeDurationPrompt': 'How long will you go without smoking?',
    'selfChallengeDurationOption': '{minutes} minutes',
    'selfChallengeInProgress': 'Staying smoke-free.',
    'selfChallengeDone': 'Time\'s up, well done!',
    'selfChallengeCloseButton': 'Close',
    'selfChallengeGiveUpButton': 'Give up for now',
    'surveyDraftFoundTitle': 'Continue where you left off',
    'surveyDraftFoundMessage':
        'We found a survey you didn\'t finish earlier. Would you like to continue from where you left off?',
    'surveyDraftResume': 'Continue',
    'surveyDraftDiscard': 'Start over',
    'breathAttemptImplausible':
        'That attempt doesn\'t look valid (too short or too long). Please try again.',
    'breathAttemptDiscardedBackgrounded':
        'This attempt was discarded because the app was backgrounded. Please try again.',
    'completeRegistrationError':
        'An error occurred while completing registration. Please try again.',
    'cigaretteUnit': 'cigarettes',
    'dayUnit': 'day',
    'exhaleCapacity': 'Exhale Capacity',
    'inhaleCapacity': 'Inhale Capacity',
    'trendLabel': 'Trend',
    'levelLabel': 'Level',
    'totalTestCount': 'Total Test Count',
    'firstTestDate': 'First test',
    'averageExhale': 'Average Exhale',
    'averageInhale': 'Average Inhale',
    'minLabel': 'Min',
    'maxLabel': 'Max',
    'exhaleLabel': 'Exhale',
    'inhaleLabel': 'Inhale',
    'few': 'Low',
    'veryHigh': 'High',
    'weeklyAvgDailyCigarettes': 'Average daily cigarettes',
    'weeklyComparedLastWeek': 'Compared to last week',
    'weeklyDecrease': 'Decreased',
    'weeklySame': 'Same',
    'weeklyIncrease': 'Increased',
    'surveySummaryTitle': 'What your answers changed',
    'surveySummaryFirstScore':
        'Your first weekly check-in is saved. Risk score: {score}/100. '
        'Next week you will see how it moved.',
    'surveySummaryScoreDown':
        'Your risk score went {previous} → {score} (down {delta}).',
    'surveySummaryScoreUp':
        'Your risk score went {previous} → {score} (up {delta}).',
    'surveySummaryScoreSame':
        'Your risk score is {score}/100 — same as last week.',
    'surveySummaryTriggers':
        'What you said sets you off: {triggers}. Tasks will be timed around '
        'these.',
    'surveySummaryRiskyHours': 'Your riskiest hours: {hours}.',
    'surveySummaryPlan':
        "Tomorrow's plan: {minutes} minutes between cigarettes, {mode} pace.",
    'surveyMode_aggressive': 'firm',
    'surveyMode_balanced': 'balanced',
    'surveyMode_protective': 'easy',
    'weeklyLapseCount': 'How many times did you go over your target this week?',
    'weeklyCravingPeak': 'How hard was the toughest moment? (0-10)',
    'weeklyWithdrawalHint':
        'Tick anything you had this week. Leave it empty if none.',
    'weeklyWithdrawal_irritability': 'Irritability',
    'weeklyWithdrawal_anxiety': 'Restlessness',
    'weeklyWithdrawal_sleepProblem': 'Trouble sleeping',
    'weeklyWithdrawal_concentrationProblem': 'Trouble concentrating',
    'weeklyWithdrawal_appetiteIncrease': 'Bigger appetite',
    'weeklyTriggerHint':
        'What made you want a cigarette this week? Tick all that apply.',
    'weeklyTrigger_coffee': 'Coffee or tea',
    'weeklyTrigger_meal': 'After a meal',
    'weeklyTrigger_driving': 'Driving',
    'weeklyTrigger_stress': 'Stress',
    'weeklyTrigger_phone': 'On the phone',
    'weeklyTrigger_social': 'With friends',
    'weeklyTrigger_alcohol': 'Alcohol',
    'weeklyOutlookTitle': 'Where You Stand This Week',
    'weeklySurveyGeneralStatus': 'General Status',
    'copdDisclaimerNotDiagnostic':
        'This section is not a diagnostic test. A COPD diagnosis requires spirometry and a doctor\'s evaluation. Results are for tracking purposes only.',
    'breathInsightNotEnoughTests':
        'Take a few more tests to see your progress.',
    'breathInsightNotEnoughSpan':
        'You need tests spread over a bit more time to compare your progress.',
    'breathInsightSignificantImprovement':
        'Significant improvement — your blow score rose {percent}%.',
    'breathInsightGradualImprovement':
        'Slow but steady progress — {percent}% higher.',
    'breathInsightStable': 'Holding steady, no significant change.',
    'breathInsightDecline':
        'This week looks a bit lower — that can be normal if you\'re sick or tired. Talk to your doctor if you have breathing complaints.',
    'channelNamePostponeChoice': 'Task postpone choice',
    'channelNameTaskConfirm': 'Task completion confirmation',
    'channelNameHealthTip': 'Health tip',
    'channelNameMedicationReminder': 'Medication reminder',
    'channelNameTaskUpdateReminder': 'Task update reminder',
    'channelNameFirstTaskTrigger': 'First task trigger',
    'channelNameBreathTestReminder': 'Breath test reminder',
    'channelNameTaskFollowUpReminder': 'Task follow-up reminder',
    'channelNameWeeklySurveyReminder': 'Weekly survey reminder',
    'channelNameTaskTimerStart': 'Task timer start',
    'channelNameDurationBarrierCall': 'Duration barrier call',
    'channelNameMovementReminder': 'Movement reminder',
    'channelNameCoachSuggestion': 'Coach suggestion',
    'channelNameLocationReminder': 'Nikotin Away Location Reminder',
    'channelDescriptionLocationReminder':
        'Reminder shown on arrival at a frequently visited place',
    'taskOverlayChannelName': 'Nikotin Away Task Screen',
    'taskOverlayChannelDescription': 'Active while the focus screen is showing',
    'taskOverlayForegroundBody': 'Task screen showing',
    'snoringCaptureChannelName': 'Nikotin Away Sleep Intelligence',
    'snoringCaptureNotificationTitle': 'Nikotin Away',
    'snoringCaptureNotificationBody':
        'Taking a brief sound sample to check for snoring',
    'channelNameSmokedLogQuickAction': 'Nikotin Away Quick Log',
    'channelDescriptionSmokedLogQuickAction':
        'Active while the "I Smoked" button is on screen',
    'registrationMissingFields': 'Please fill in the missing fields.',
    'registrationProfileCreationFailed':
        'Could not create profile. Please try again.',
    'registrationRiskAnalysisFailed':
        'Could not create risk analysis. Please try again.',
    'registrationFlagSaveFailed':
        'Could not save registration flag. Please try again.',
    'breathTestSaveFailed':
        'Could not save breath test result. Please try again.',
    'barrierStartedInstruction':
        'Please do not smoke for the next {duration}. If you have a cigarette in your hand, put it out now.',
    'severityLevel0': 'Not at all',
    'severityLevel1': 'Barely',
    'severityLevel2': 'A little',
    'severityLevel3': 'Moderately',
    'severityLevel4': 'A lot',
    'severityLevel5': 'Severely',
    'frequencyNever': 'Never',
    'frequencyOneOrTwoNights': 'A night or two',
    'frequencyMostNights': 'Most nights',
    'frequencyEveryNight': 'Almost every night',
    'weeklyRespTitle': 'Breathing Check',
    'weeklyRespHint':
        'Answer for the past week. This is not a diagnosis — it is here to '
        'show how things change over time.',
    'weeklyCoughExample': 'Do you cough in the morning or during the day?',
    'weeklyBreathlessnessStairsExample':
        'Do you have to stop for breath after one flight of stairs?',
    'weeklySleepImpact': 'Effect on your sleep',
    'weeklySleepImpactExample':
        'Do coughing or breathlessness wake you at night?',
    'weeklyEnergyImpact': 'Effect on your energy',
    'weeklyEnergyImpactExample': 'Do you tire more easily than you used to?',
    'mmrcPlain0': 'I am not short of breath.',
    'mmrcPlain1':
        'I get short of breath hurrying on the flat or up a slight hill.',
    'mmrcPlain2':
        'I walk slower than people my age on the flat, or have to stop.',
    'mmrcPlain3': 'I stop for breath after about 100 metres on the flat.',
    'mmrcPlain4':
        'I am too breathless to leave the house, or breathless dressing.',
    'weeklyCravingAvg': 'Average craving (0-10)',
    'weeklyCravingMax': 'Maximum craving (0-10)',
    'weeklyWithdrawalSymptoms': 'Withdrawal symptoms (0-3)',
    'weeklyIrritability': 'Irritability',
    'weeklyAnxiety': 'Anxiety',
    'weeklySleepIssue': 'Sleep issues',
    'weeklyConcentrationIssue': 'Concentration issues',
    'weeklyAppetiteIncrease': 'Increased appetite',
    'weeklyTriggerExposure': 'Trigger exposure (days 0-7)',
    'weeklyVehicleUse': 'Driving',
    'weeklyAlcoholTrigger': 'Alcohol trigger',
    'weeklyAlcoholDays': 'Days with alcohol',
    'weeklySocialSmokingDays': 'Days in smoking social settings',
    'weeklyMedicationUse': 'Medication/NRT usage',
    'weeklyNone': 'None',
    'weeklyIrregular': 'Irregular',
    'weeklyRegular': 'Regular',
    'weeklySideEffectsExperienced': 'Medication/NRT side effects experienced',
    'weeklyUsedCounseling': 'Counseling/quitline used',
    'weeklyMedicationAdherence': 'Treatment adherence (0-10)',
    'weeklyFamilySupport': 'Family/social support (0-10)',
    'weeklySelfEfficacy': 'Self-efficacy (0-10)',
    'weeklyMotivation': 'Motivation (0-10)',
    'weeklyTaskCompletion': 'Weekly task completion (0-10)',
    'weeklyTaskAdherence': 'How much did you follow daily tasks?',
    'weeklyCommandBurden': 'Did commands bother you?',
    'weeklyDailyBreathTarget': 'Preferred daily breath test count (min 1)',
    'weeklyBreathOnceMandatory': '1 time (required minimum)',
    'weeklyBreathTwice': '2 times',
    'weeklyBreathThree': '3 times',
    'weeklyBreathFour': '4 times',
    'weeklyMmrcGrade': 'Breathlessness grade (mMRC-like 1-5)',
    'weeklyMmrc1': '1 - Shortness of breath only on fast walk/uphill',
    'weeklyMmrc2': '2 - Walks slower than peers on flat ground',
    'weeklyMmrc3': '3 - Needs to stop after a while on flat ground',
    'weeklyMmrc4': '4 - Stops after around 100 meters',
    'weeklyMmrc5': '5 - Marked breathlessness indoors',
    'weeklyRespiratoryBurden': 'Respiratory symptom burden (CAT-like 0-5)',
    'weeklyCough': 'Cough',
    'weeklyPhlegm': 'Phlegm',
    'weeklyChestTightness': 'Chest tightness',
    'weeklyBreathlessnessStairs': 'Breathlessness on stairs/hills',
    'weeklyActivityLimitation': 'Daily activity limitation',
    'weeklyConfidenceLeavingHome': 'Low confidence leaving home',
    'weeklySleepQualityResp': 'Respiratory-related sleep disturbance',
    'weeklyEnergyLevelResp': 'Respiratory-related low energy',
    'weeklyWarningSigns': 'Warning signs (weekly days 0-7)',
    'weeklyNightBreathlessness': 'Nighttime breathlessness',
    'weeklySputumIncrease': 'Increased sputum',
    'weeklySputumColorChange': 'Change in sputum color',
    'weeklyWheeze': 'Wheeze',
    'weeklyLunchTime': 'Estimated lunch time',
    'weeklyDinnerTime': 'Estimated dinner time',
    'weeklyProfileChanged':
        'Has work/sleep/routine changed since the initial profile?',
    'weeklyQuickModeInfo':
        'Quick mode selected. Risk is computed from core answers. You can switch to Detailed mode to adjust all parameters.',
    'durationBarrierNeutral': 'Neutral',
    'durationBarrierEnabledTitle': 'Smoke-free duration barrier',
    'durationBarrierEnabledDescription':
        "Turn this off and you won't get tasks asking you to stretch the gap between cigarettes.",
    'durationBarrierFrequencyHow':
        'How often should smoke-free durations appear?',
    'respClinicalReview': 'Clinical review recommended',
    'respMonitorCloser': 'Monitor closer',
    'respStable': 'Stable',
    'dailyBreathMandatoryTitle': 'Daily breath test required',
    'dailyBreathMandatoryContent':
        'To track progress accurately, at least one professional breath test should be done daily. Let us start now.',
    'dailyBreathMandatoryStart': 'Start Test',
    'weeklyMandatoryTitle': 'Weekly survey required',
    'weeklyMandatoryContent':
        'To keep your risk score up to date, complete the weekly survey at least once every 7 days.',
    'weeklyMandatoryGo': 'Go to survey',
    'commandSaved': 'Command marked as completed.',
    'weeklyRiskLine': 'Weekly survey risk',
    'respiratoryStatusLine': 'Respiratory status',
    'weeklyTopDriversLine': 'Top weekly risk drivers',
    'commandModeLabel': 'Command mode',
    'advancedSectionTitle': 'Advanced',
    'learnedWeightsLabel': 'Learned weights',
    'personalCommandsTitle': 'Personal commands',
    'durationBarriersTitle': 'Smoke-free durations (separate flow)',
    'doneShort': 'Done',
    'defer10m': 'Defer 10 min',
    'commandScoreLabel': 'Command success scores',
    'categoryInsightLabel': 'Category success insight',
    'riskScoreExplanationTitle': 'Risk score explanation',
    'riskExplanationBaseTemplate': 'Base score: {score}',
    'riskExplanationBehaviorDeltaTemplate': 'Behavior/trend effect: {score}',
    'riskExplanationPersonalizedDeltaTemplate':
        'Breath + survey personal effect: {score}',
    'riskExplanationProfileDeltaTemplate': 'Profile effect: {score}',
    'riskExplanationTaskDeltaTemplate': 'Task performance effect: {score}',
    'riskExplanationFinalTemplate': 'Final risk score: {score}',
    'quickMenuTitle': 'Quick menu',
    'menuSectionTestsAndSurveys': 'Tests & Surveys',
    'menuSectionTrackingAndReports': 'Tracking & Reports',
    'menuBreathTest': 'Breathing Exercise',
    'menuWeeklySurvey': 'Weekly Survey',
    'menuPersonalProgress': 'Personal Progress',
    'menuViolationReport': 'Moments You Struggled',
    'menuSurveyHistory': 'Survey History',
    'menuLogSmokingNow': 'I smoked now',
    'menuDailyCheckIn': 'Daily Check-in',
    'mentorCardTitle': 'From your mentor',
    'aiMentorButton': 'AI Mentor',
    'aiChatTitle': 'AI Mentor',
    'aiChatHistory': 'Chat history',
    'aiChatMenuPin': 'Pin',
    'aiChatMenuUnpin': 'Unpin',
    'aiChatMenuRename': 'Rename',
    'aiChatMenuInvite': 'Invite',
    'aiChatMenuCopy': 'Send a copy',
    'aiChatMenuSummary': 'Summarize on one page',
    'aiChatMenuMove': 'Move to projects',
    'aiChatMenuReport': 'Report a concern',
    'aiChatMenuDelete': 'Delete',
    'aiChatMenuCancel': 'Cancel',
    'aiChatRenameTitle': 'Rename chat',
    'aiChatProjectTitle': 'Move to project',
    'aiChatProjectHint': 'Project name',
    'aiChatReportTitle': 'Report a concern',
    'aiChatReportHint': 'What would you like to report?',
    'aiChatSummaryTitle': 'Chat summary',
    'aiChatSummaryEmpty': 'There are no messages to summarize yet.',
    'aiChatDeleteConfirm': 'Delete this chat?',
    'aiChatNewConversation': 'New chat',
    'aiChatNoConversations': 'No chats yet',
    'aiChatMessageCount': '{count} messages',
    'aiChatHint': 'Type a message...',
    'aiChatSend': 'Send',
    'aiChatActionAppliedPermission': 'Permission request opened.',
    'aiChatMicTooltip': 'Tap to speak',
    'aiChatListening': 'Listening...',
    'aiChatMicPermissionDenied':
        'Microphone permission is required for voice input.',
    'aiChatMicUnavailable': 'Voice input is not available on this device.',
    'aiChatError': 'Could not send message, try again.',
    'aiChatDailyLimitReached':
        'You\'ve reached today\'s message limit, try again tomorrow.',
    'aiChatAuthNotReady': 'Could not verify your identity, try again shortly.',
    'aiChatDisclaimer':
        'This is an AI assistant, not medical advice. Consult your doctor for health matters.',
    'aiChatActionApply': 'Apply',
    'aiChatActionDismiss': 'Dismiss',
    'aiChatActionFailed': 'This change could not be applied.',
    'aiChatActionAppliedCoachMode': 'Coach Mode setting updated.',
    'aiChatActionAppliedMedication': 'Medication reminder times updated.',
    'mentorReplySentPrefix': 'Your reply',
    'miuiPermissionTitle': 'One more permission needed',
    'miuiPermissionMessage':
        '{brand} phones need an extra permission for the task screen to show up over a locked screen. Open the settings screen now?',
    'miuiPermissionOpen': 'Open Settings',
    'miuiPermissionSkip': 'Later',
    'settingsTitle': 'Settings',
    'settingsSectionGeneral': 'General',
    'settingsSectionPrivacy': 'Privacy & Permissions',
    'settingsSectionData': 'Data',
    'settingsLanguageRow': 'Language',
    'cloudBackupRow': 'Cloud Backup',
    'cloudBackupRowSubtitle': 'Back up your data to the cloud, encrypted',
    'cloudBackupPhoneChangeWarning':
        'If you change phones or uninstall the app, the only way to get your data back is having made a backup here beforehand. If Cloud Backup is off, changing phones means losing all your data permanently.',
    'cloudRestoreRow': 'Restore From Cloud Backup',
    'cloudRestoreRowSubtitle':
        'Bring your previously backed-up data to this device',
    'cloudBackupPassphraseHint':
        'Choose a new passphrase now. It is stored only on your device -- we can never see it. If you forget it, we cannot restore your backup, so write it down somewhere safe.',
    'cloudBackupPassphraseLabel': 'New passphrase (at least 6 characters)',
    'cloudRestorePassphraseHint':
        'Enter the passphrase you chose when you backed up. The wrong passphrase means your backup cannot be found.',
    'cloudRestorePassphrase': 'Backup passphrase',
    'cloudRestorePassphraseLabel': 'Your backup passphrase',
    'cloudBackupPassphraseTooShort':
        'Passphrase must be at least 6 characters.',
    'cloudBackupInProgress': 'Working, please wait...',
    'cloudBackupSuccess': 'Backup complete.',
    'cloudBackupFailed': 'Backup failed. Please try again.',
    'cloudRestoreConfirmMessage':
        'The data currently on this device will be replaced with the backup. Do you want to continue?',
    'cloudRestoreSuccess': 'Restore complete. Please restart the app.',
    'cloudRestoreNotFound': 'No backup matches this passphrase.',
    'cloudRestoreFailed': 'Restore failed. Please check your passphrase.',
    'settingsPermissionsRow': 'Permissions Center',
    'settingsPermissionsRowSubtitle': 'See which permissions we use and why',
    'settingsResetDataRow': 'Reset My Data',
    'settingsResetDataSubtitle': 'Permanently deletes all your records',
    'settingsResetDataConfirmTitle': 'Are you sure?',
    'settingsResetDataConfirmMessage':
        'All your smoking logs, survey results and progress will be permanently deleted. This cannot be undone.',
    'settingsResetDataConfirmAction': 'Yes, Delete',
    'settingsResetDataDone': 'Your data has been deleted.',
    'accountDeleteRow': 'Delete my account and cloud data',
    'accountDeleteSubtitle':
        'Permanently deletes your account and Firebase cloud data',
    'accountDeleteTitle': 'Delete account?',
    'accountDeleteMessage':
        'Your account, cloud data and records on this device will be permanently deleted. This cannot be undone.',
    'accountDeleteAction': 'Delete account and data',
    'accountDeleteDone': 'Your account and cloud data were deleted.',
    'accountDeleteFailed':
        'The account could not be deleted. Please try again.',
    'accountDeleteRecentLogin':
        'For security, please sign in again before deleting your account.',
    'accountDeleteRequiresLogin':
        'Please sign in with Google or email before deleting an account.',
    'permissionsCenterTitle': 'Permissions Center',
    'permissionsCenterIntro':
        'Here\'s why we ask for each permission and how we use it. All of them are optional and can be turned off anytime.',
    'permissionStatusGranted': 'Granted',
    'permissionStatusDenied': 'Not granted',
    'permissionActionRequest': 'Grant',
    'permissionActionOpenSettings': 'Open Settings',
    'permissionActionManage': 'Manage in Settings',
    'permissionNotificationsTitle': 'Notifications',
    'permissionNotificationsDescription':
        'Used for task reminders, breath tests, and messages from your mentor.',
    'permissionNotificationsPurpose':
        'Why: needed so we can support you at the right moment.',
    'permissionMicrophoneTitle': 'Microphone',
    'permissionMicrophoneDescription':
        'Used in the daily breath test to measure your lung condition.',
    'permissionMicrophonePurpose':
        'Why: audio is processed only on your device, never recorded or shared.',
    'permissionActivityTitle': 'Physical Activity',
    'permissionActivityDescription':
        'Used to understand your movement so we can suggest support at better times, and to track your daily step count.',
    'permissionActivityPurpose':
        'Why: your activity and step data never leave your device.',
    'permissionPhoneTitle': 'Phone State',
    'permissionPhoneDescription':
        'Used to keep the fake support call from colliding with a real call.',
    'permissionPhonePurpose': 'Why: we never read call numbers or content.',
    'permissionExactAlarmTitle': 'Exact Timing',
    'permissionExactAlarmDescription':
        'Makes sure reminders and mentor messages arrive exactly on time.',
    'permissionExactAlarmPurpose':
        'Why: Android manages this permission from system settings.',
    'permissionExactAlarmAlreadyGranted': 'This permission is already granted.',
    'permissionMiuiTitle': 'Xiaomi Extra Permission',
    'permissionMiuiDescription':
        'Required on Xiaomi phones so the fake support call can show over the lock screen.',
    'permissionMiuiPurpose':
        'Why: MIUI uses a different permission system than other Android phones.',
    'permissionLocationTitle': 'Location',
    'permissionLocationDescription':
        'Used to learn places you visit often and show a short reminder when you arrive (Location Intelligence feature, off by default).',
    'permissionLocationPurpose':
        'Why: your raw location history is never recorded. Tap for details and to turn it on/off.',
    'permissionBackgroundTitle': 'Background Operation',
    'permissionBackgroundDescription':
        'Some phone manufacturers restrict background apps to save battery. This can stop reminders, sleep/location/step tracking, and support calls from working on time.',
    'permissionBackgroundPurpose':
        'Why: exempting the app from battery optimization keeps background features working reliably.',
    'permissionBackgroundOpenSettingsAction': 'Open Background Settings',
    'settingsCoachModeRow': 'Coach Mode',
    'settingsCoachModeRowSubtitle':
        'How often and how firmly the app should push you',
    'coachModeTitle': 'Coach Mode',
    'coachModeIntro':
        'Choose how often and how firmly the app should support you. You can change this anytime.',
    'coachModeEasyTitle': 'Easy',
    'coachModeEasyDescription':
        'Few, gentle reminders. For going at your own pace.',
    'coachModeNormalTitle': 'Normal',
    'coachModeNormalDescription':
        'Balanced support frequency. Recommended for most users.',
    'coachModeHardTitle': 'Hard',
    'coachModeHardDescription':
        'Frequent, firm reminders. For extra discipline.',
    'coachModeCustomLabel': 'Custom',
    'coachModeCustomDescription':
        'A combination you set yourself in Advanced Settings.',
    'coachModeAdvancedToggle': 'Advanced Settings',
    'coachModeSavedConfirmation': 'Coach mode updated.',
    'settingsSleepIntelligenceRow': 'Sleep Intelligence',
    'sleepIntelligenceTitle': 'Sleep Intelligence',
    'sleepIntelligenceDescription':
        'When on, the app checks your phone\'s screen and charging state a few times overnight to estimate your sleep hours. This estimate is used to make your risk assessment more accurate.',
    'sleepIntelligencePurpose':
        'Why: only whether the screen is on/off and charging is checked, nothing else is read. If there isn\'t enough data, it falls back to the sleep time you gave in the survey.',
    'sleepIntelligenceSnoringIncluded':
        'Snoring analysis is automatically included in the same overnight tracking; there is no separate snoring test.',
    'sleepIntelligenceEnabledConfirmation': 'Sleep intelligence turned on.',
    'sleepIntelligenceDisabledConfirmation': 'Sleep intelligence turned off.',
    'settingsSnoringDetectionRow': 'Snoring Test (Experimental)',
    'snoringDetectionTitle': 'Snoring Test (Experimental)',
    'snoringDetectionDescription':
        'When on, a few seconds of audio are sampled during your sleep hours and analyzed on-device for a rhythmic, snore-like sound pattern. During that brief sampling you\'ll see a silent notification in the status bar showing the microphone is active -- this is a transparency measure Android requires for any background service that uses the microphone. The recording is never written to disk or sent anywhere -- only the result (yes/no) is stored.',
    'snoringDetectionPurpose':
        'Why: snoring can affect sleep quality and, in turn, next-day smoking risk. Sleep Intelligence must be on first for this feature, since it runs on the same overnight cycle.',
    'snoringDetectionEnabledConfirmation': 'Snoring test turned on.',
    'snoringDetectionDisabledConfirmation': 'Snoring test turned off.',
    'snoringDetectionRequiresSleepIntelligence':
        'Turn on Sleep Intelligence first -- the snoring test runs on top of it.',
    'snoringDetectionLastNightCount': 'Snore-like patterns detected last night',
    'snoringResultNotificationTitle': 'Last night\'s snoring test',
    'snoringResultNotificationBodyDetected':
        'A snore-like sound pattern was detected {count} times last night. See Settings > Snoring Test for details.',
    'snoringResultNotificationBodyClear':
        'No snore-like sound pattern was detected last night.',
    'snoringSeverityNone': 'No snoring detected.',
    'snoringSeverityMild': 'A mild level of snoring was detected.',
    'snoringSeverityModerate': 'A moderate level of snoring was detected.',
    'snoringSeveritySevere': 'A pronounced level of snoring was detected.',
    'snoringAdviceMild':
        'Mild snoring is usually temporary. Sleeping on your side and avoiding alcohol can help.',
    'snoringAdviceModerate':
        'If moderate snoring has lasted several nights, alongside lifestyle steps like weight and sleep position, we recommend seeing a doctor.',
    'snoringAdviceSevere':
        'A pronounced level of snoring was detected. If this continues, please see a doctor -- this app does not provide a medical diagnosis or treatment recommendation.',
    'snoringHomeSummaryCardTitle': 'Last night\'s snoring',
    'snoringHomeSummaryCardBodyDetected':
        'A snore-like sound pattern was detected {count} times last night.',
    'snoringHomeSummaryCardBodyClear':
        'No snore-like sound pattern was detected last night.',
    'snoringTestTitle': 'Snoring Test',
    'snoringTestInstructions':
        'We\'ll keep the microphone on for 60 seconds. Sound is never recorded or sent anywhere, only the snoring pattern is analyzed.',
    'snoringTestStartButton': 'Start Test',
    'snoringTestListening': 'Listening...',
    'snoringTestResultTitle': 'Test Result',
    'snoringTestDaytimeDisclaimer':
        'This is a sample taken while you\'re awake. It doesn\'t measure snoring during sleep and isn\'t included in your nightly summary.',
    'menuSnoringTest': 'Snoring Test',
    'coughTestTitle': 'Cough Test',
    'coughTestIntro':
        'We\'ll keep the microphone on for 10 seconds. You\'ll be asked to cough a few times while the sound is checked for wheeze patterns.',
    'coughTestInstructions':
        'Start somewhere quiet. Breathe normally and cough a few times when prompted. Audio is not recorded or sent anywhere; only the wheeze pattern is analysed.',

    'coughTestStartButton': 'Start Test',
    'coughTestListening': 'Listening...',
    'coughTestResultTitle': 'Test Result',
    'coughTestResultCount': '{count} coughs detected',
    'wheezeDetectedResult': 'Wheeze detected',
    'wheezeNotDetectedResult': 'No wheeze detected',

    'coughGeneralAdvice':
        'If the cough has lasted several days, we recommend seeing a doctor -- this app does not provide a medical diagnosis or treatment recommendation.',
    'coughTestNotificationTitle': 'Your cough test result',
    'wheezeFindingSectionTitle': 'Sound Pattern Note',
    'breathUnusualSoundDetected':
        'An unusual sound pattern was heard in this test.',
    'breathUnusualSoundAdvice':
        'If it recurs, we recommend seeing a doctor -- this app does not provide a medical diagnosis or treatment recommendation.',
    'wheezeTestNotificationTitle': 'Breath test note',
    'breathNotDetectedRetryTitle': 'Breath not detected',
    'breathNotDetectedRetryMessage':
        "The microphone couldn't clearly detect your breath. Want to try again?",
    'coughNotDetectedRetryTitle': 'Cough not detected',
    'coughNotDetectedRetryMessage':
        "The microphone didn't detect a cough. Want to try again?",
    'retryAttemptButton': 'Try Again',
    'keepResultAnywayButton': 'Continue Anyway',
    'coughTestRequiredForWeeklySurvey': 'Take the Test',
    'coughTestRequiredDialogTitle': 'Cough test required',
    'coughTestRequiredDialogMessage':
        'You need to take a cough test this week before saving the weekly survey. Take it now?',
    'coughTestSkip': 'Skip',
    'menuCoughTest': 'Cough Test',
    'settingsWearableIntelligenceRow': 'Wearable Data (Experimental)',
    'wearableIntelligenceTitle': 'Wearable Data (Experimental)',
    'wearableIntelligenceDescription':
        'When on, the app tries to read heart-rate and sleep data through Health Connect — if you have a smartwatch/wearable app syncing to it. The app never talks to your watch directly, it only reads what\'s already in Health Connect.',
    'wearableIntelligencePurpose':
        'Why: a sudden heart-rate spike can help catch a risky moment earlier. If you have no wearable or no synced data, this card just stays empty — nothing else changes.',
    'wearableIntelligenceEnabledConfirmation': 'Wearable data turned on.',
    'wearableIntelligenceDisabledConfirmation': 'Wearable data turned off.',
    'wearableIntelligenceUnavailable':
        'Health Connect wasn\'t found on this device. Install it?',
    'wearableIntelligencePermissionDenied':
        'Health Connect permission was not granted, feature could not be turned on.',
    'wearableIntelligenceInstallAction': 'Install Health Connect',
    'wearableIntelligenceLatestHeartRate': 'Latest heart rate',
    'wearableIntelligenceLastSleep': 'Last sleep duration',
    'wearableIntelligenceNoData': 'No readable data yet.',
    'coachCommandTitle': 'A suggestion',
    'sedentaryReminderTitle': 'Time to move a bit',
    'sedentaryReminderBody':
        'You\'ve been still for a while. A short walk is good for your legs and for cravings alike.',
    'healthTipTitle': 'Health Tip',
    'healthTipGeneral1': 'Drink water today and do not skip a short walk.',
    'healthTipGeneral2': 'Regular sleep helps your body and mind recover.',
    'healthTipGeneral3':
        'When stress arrives, slow your breathing and relax your shoulders.',
    'healthTipGeneral4':
        'Get fresh air when possible and avoid sitting still for too long.',
    'healthTipGeneral5':
        'Small, consistent health steps create a meaningful long-term difference.',
    'healthTipSmoking1':
        'A cigarette urge is a wave; waiting a few minutes can reduce it.',
    'healthTipSmoking2':
        'Delaying one cigarette reminds you that you are still in control.',
    'healthTipSmoking3':
        'When coffee, stress or a break triggers you, try water instead.',
    'healthTipSmoking4': 'Keeping your hands busy can help the urge pass.',
    'healthTipSmoking5':
        'Every cigarette you skip today is a gain for your heart and lungs.',
    'healthTipSmoking6':
        'Try taking a short walk instead of taking a smoking break.',
    'healthTipSmoking7':
        'When an urge arrives, breathe in for four counts and out for six.',
    'healthTipSmoking8':
        'Moving away from smoke can help the urge fade faster.',
    'healthTipSmoking9':
        'Telling a friend about your goal can strengthen your decision.',
    'healthTipSmoking10':
        'Smoking less today is a concrete start for tomorrow’s decision.',
    'healthTipSmoking11':
        'Alcohol and smoking urges can rise together; try separating them.',
    'healthTipSmoking12':
        'After a meal, stand up and walk before reaching for a cigarette.',
    'healthTipSmoking13':
        'Poor sleep can amplify urges; give rest priority tonight.',
    'healthTipSmoking14':
        'Instead of fighting an urge, observe it for three minutes.',
    'healthTipSmoking15':
        'Every delay teaches your brain that you can cope without smoking.',
    'healthTipGeneralDisease1':
        'If symptoms worsen, follow your clinician’s advice and seek help promptly.',
    'healthTipGeneralDisease2':
        'Taking medicines as prescribed matters as much as regular follow-up.',
    'healthTipGeneralDisease3':
        'Smoking can make many chronic conditions harder to control.',
    'healthTipGeneralDisease4':
        'If you have breathlessness or chest pain, consider whether urgent help is needed.',
    'healthTipGeneralDisease5':
        'Skipping one cigarette today reduces the load on your body’s recovery.',
    'healthTipGeneralDisease6':
        'Track blood pressure, glucose or breathing as your clinician recommends.',
    'healthTipGeneralDisease7':
        'Short, regular movement can support circulation and energy.',
    'healthTipGeneralDisease8':
        'Avoiding smoky places can help ease disease-related symptoms.',
    'healthTipGeneralDisease9':
        'Ask a health professional about new or worsening symptoms instead of self-diagnosing.',
    'healthTipGeneralDisease10':
        'Choose one small goal that fits you and complete it today.',
    'healthTipHypertension1':
        'Smoking raises your blood pressure instantly. A few deep breaths right now will help it more.',
    'healthTipHypertension2':
        'Less salt and no cigarette work together for your blood pressure. You can put off one more today.',
    'healthTipAsthma1':
        'Cigarette smoke narrows your airways and can trigger an asthma attack. Step somewhere with fresh air.',
    'healthTipAsthma2':
        'When your breathing feels tight, reach for a slow deep-breathing exercise instead of a cigarette.',
    'healthTipDiabetes1':
        'Smoking makes blood sugar harder to keep steady. Try a glass of water and a few minutes\' wait instead.',
    'healthTipDiabetes2':
        'Every smoke-free hour is a small win for your blood sugar control.',
    'healthTipCopd1':
        'COPD and smoking don\'t mix. This urge will fade on its own within a few minutes.',
    'healthTipCopd2':
        'A short breathing exercise does your lungs far more good than a cigarette ever could.',
    'healthTipHeartDisease1':
        'Smoking speeds up your heart for no reason. A calm breathing break is the better choice for it.',
    'healthTipHeartDisease2':
        'The most valuable thing you can do for your heart right now is skip this cigarette.',
    'healthTipHypertension3':
        'Every cigarette tightens your blood vessels. Standing up and walking a few steps does the opposite.',
    'healthTipHypertension4':
        'Blood pressure swings most in the morning. Delaying today\'s first cigarette matters most right now.',
    'healthTipHypertension5':
        'Drink a glass of water and wait two minutes. The urge usually passes in that time; your blood pressure stays calm.',
    'healthTipHypertension6':
        'A walk actually delivers the relief a cigarette only promises. Ten minutes is enough.',
    'healthTipHypertension7':
        'Anger raises your blood pressure and your craving together. Slow your breathing first; decide after.',
    'healthTipHypertension8':
        'Coffee and a cigarette together push your blood pressure from two directions. Try the coffee alone today.',
    'healthTipHypertension9':
        'Salty snacks trigger both the craving and your blood pressure. Remember that as you reach out.',
    'healthTipHypertension10':
        'Every smoke-free hour is an hour your heart moves the same blood with less strain.',
    'healthTipHypertension11':
        'Taking your blood pressure medicine regularly matters, but smoking works against it. Let them pull the same way.',
    'healthTipHypertension12':
        'If the urge just hit, ask yourself again in three minutes. The answer usually changes.',
    'healthTipHypertension13':
        'Choosing the stairs over the lift is the little sibling of quitting, for your blood pressure.',
    'healthTipHypertension14':
        'If you want a cigarette after a tense meeting, what you actually want is to catch your breath.',
    'healthTipHypertension15':
        'A warm shower gives the same loosening a cigarette does, without raising your blood pressure.',
    'healthTipHypertension16':
        'An evening cigarette breaks your sleep, and broken sleep raises blood pressure. This is where the chain breaks.',
    'healthTipHypertension17':
        'If you stayed under your target today, your blood vessels have already noticed.',
    'healthTipHypertension18':
        'Keep your hands busy when the urge comes. Your blood pressure owes you these few minutes.',
    'healthTipHypertension19':
        'The after-meal cigarette is where habit is strongest. Try getting up and walking instead.',
    'healthTipHypertension20':
        'Tell one person today\'s target. A target spoken out loud is a target kept.',
    'healthTipHypertension21':
        'The good news for your blood pressure: it isn\'t only the day you quit that counts, but every day you cut down.',
    'healthTipHypertension22':
        'Breathe in for a count of four, out for a count of six. Do it three times.',
    'healthTipHypertension23':
        'Take a window break instead of a smoke break. Same pause, different outcome.',
    'healthTipHypertension24':
        'The cuff on your arm can\'t see the cigarette, but it measures what it did.',
    'healthTipHypertension25':
        'The cigarette you skip today shows up in tomorrow\'s reading.',
    'healthTipHypertension26':
        'Alcohol multiplies the craving, and your blood pressure with it. Keep them apart.',
    'healthTipHypertension27':
        'Tiredness disguises itself as a craving. Sit for ten minutes first, then decide.',
    'healthTipHypertension28':
        'A glass of water on waking is the easiest way to push back the day\'s first cigarette.',
    'healthTipHypertension29':
        'What lowers your blood pressure isn\'t one big decision but small delays stacked together.',
    'healthTipHypertension30':
        'If you hit today\'s target, you can do it tomorrow too. You\'re the proof.',
    'healthTipHypertension31':
        'Delaying a cigarette before your morning blood-pressure pill on an empty stomach helps them work together.',
    'healthTipHypertension32':
        'A headache or dizziness can be a sign your pressure is running high — smoking makes it worse. Rest first.',
    'healthTipHypertension33':
        'A late-night cigarette shows up in tomorrow morning\'s reading. Skipping tonight\'s makes a difference by morning.',
    'healthTipAsthma3':
        'Smoke leaves your airways irritable for hours. Skipping this one means easier breathing tonight.',
    'healthTipAsthma4':
        'When your chest tightens, a cigarette narrows it further. A breathing exercise does the opposite.',
    'healthTipAsthma5':
        'In cold air a cigarette hits your airways twice as hard. Stay in and put it off today.',
    'healthTipAsthma6':
        'Smoke and dust are the worst pairing for asthma. Air out the room you\'re in.',
    'healthTipAsthma7':
        'If your cough is worse in the morning, the night-time cigarette may be why. Try one night without and see.',
    'healthTipAsthma8':
        'Panic makes breathlessness feel bigger. Drop your shoulders and lengthen your breath.',
    'healthTipAsthma9':
        'If exercise sets off your asthma, smoking lowers that threshold further. One cigarette fewer today.',
    'healthTipAsthma10':
        'Every smoke-free day is a day you reach for your reliever less.',
    'healthTipAsthma11':
        'Smoke clings to your clothes and re-triggers you. Change your top and cut the loop.',
    'healthTipAsthma12':
        'When you hear a wheeze, look for fresh air, not a cigarette.',
    'healthTipAsthma13':
        'In pollen season your airways are already loaded. Delaying pays off more this week.',
    'healthTipAsthma14':
        'When the urge comes, breathe slowly through your nose rather than your mouth.',
    'healthTipAsthma15':
        'For someone with asthma the best win is a night without waking. The evening cigarette steals it.',
    'healthTipAsthma16':
        'The cigarette you skipped today is one more stair you\'ll manage.',
    'healthTipAsthma17':
        'Smoking indoors is far heavier on your airways than outdoors.',
    'healthTipAsthma18':
        'When breathing tightens, sit, lean forward, and breathe out slowly. It will pass.',
    'healthTipAsthma19':
        'A craving lasts about three minutes. An asthma flare lasts hours. Which is easier to wait out?',
    'healthTipAsthma20':
        'Keep your bedroom smoke-free. Your airways need the night off.',
    'healthTipAsthma21':
        'When you put off a cigarette, the urge isn\'t the only thing that passes — your breath comes back too.',
    'healthTipAsthma22':
        'Stress triggers both asthma and the urge. Same source, same answer: slow breathing.',
    'healthTipAsthma23':
        'Coughing less today? That isn\'t chance — it\'s yesterday\'s decisions.',
    'healthTipAsthma24':
        'Cigarette smoke weakens what your medicine does. Don\'t make them compete.',
    'healthTipAsthma25':
        'Even a one-second gain on the breathing test means your airways are opening.',
    'healthTipAsthma26':
        'If you run out of breath walking, slow down, stop, recover. A cigarette breaks that sequence.',
    'healthTipAsthma27':
        'If someone smokes at home, your airways smoke too. That\'s worth a conversation.',
    'healthTipAsthma28':
        'Warm steam opens the tightness in your chest far better than a cigarette.',
    'healthTipAsthma29':
        'Staying under today\'s target means waking less tonight.',
    'healthTipAsthma30':
        'Your airways start recovering immediately. Even one day pays back.',
    'healthTipAsthma31':
        'Cold air and smoke together narrow your airways more than either alone. Wrap up warm and let this one pass.',
    'healthTipAsthma32':
        'Wanting a cigarette right after a coughing fit is common — but that\'s exactly when your lungs need rest most.',
    'healthTipAsthma33':
        'If breathlessness gets worse at night, skipping the last evening cigarette directly improves your sleep.',
    'healthTipDiabetes3':
        'Smoking makes insulin\'s job harder. Skipping this one keeps today\'s numbers more predictable.',
    'healthTipDiabetes4':
        'The after-meal cigarette lands on top of a rise your body is already handling.',
    'healthTipDiabetes5':
        'Circulation in your feet suffers most from smoking. One cigarette fewer, one step more today.',
    'healthTipDiabetes6':
        'Cravings get stronger when your blood sugar drops. Eat something first, then reconsider.',
    'healthTipDiabetes7':
        'Every smoke-free week is a week your body uses its own insulin better.',
    'healthTipDiabetes8':
        'A walk lowers your blood sugar and your craving at once. Two jobs, one effort.',
    'healthTipDiabetes9':
        'If cuts heal slowly, smoking is a big part of why. Cutting down changes it.',
    'healthTipDiabetes10':
        'The sugary drink and the cigarette travel together. Drop one and the other weakens.',
    'healthTipDiabetes11':
        'If your morning number is high, last night\'s cigarette is worth looking at too.',
    'healthTipDiabetes12':
        'Smoking strains the vessels in your eyes too. Every cigarette you skip counts there as well.',
    'healthTipDiabetes13':
        'Drink water when the urge comes. Thirst and blood sugar both make it feel bigger.',
    'healthTipDiabetes14':
        'Stress raises your blood sugar, and a cigarette doesn\'t resolve stress — it postpones it.',
    'healthTipDiabetes15':
        'While you check your feet, remember: cutting down is what helps that circulation most.',
    'healthTipDiabetes16':
        'A craving lasts three minutes. A blood sugar swing lasts hours. Wait out the short one.',
    'healthTipDiabetes17':
        'If you hit today\'s target, your pancreas noticed too.',
    'healthTipDiabetes18':
        'Your kidneys tire from both smoking and blood sugar. Easing both is the best gift.',
    'healthTipDiabetes19':
        'Skipping meals makes the urge bigger. Eating regularly makes delaying easier.',
    'healthTipDiabetes20':
        'An evening walk takes out both the night-time number and the night-time cigarette.',
    'healthTipDiabetes21':
        'Cutting down means your medicines do the same work with less effort.',
    'healthTipDiabetes22':
        'Keep your hands busy — peel something, stir something. The urge will pass.',
    'healthTipDiabetes23':
        'If a sweet craving and a cigarette craving arrive together, water and ten minutes first.',
    'healthTipDiabetes24':
        'Poor sleep worsens both your numbers and your cravings. Turn in early tonight.',
    'healthTipDiabetes25':
        'The cigarette not smoked today shows up in your vessels right away.',
    'healthTipDiabetes26':
        'Skipping breakfast for a cigarette starts your day by straining your blood sugar twice.',
    'healthTipDiabetes27':
        'Sweets and cigarettes both show up in company. Go in with a plan for one of them.',
    'healthTipDiabetes28':
        'When you check your sugar, think about your cigarette count too. They\'re on the same chart.',
    'healthTipDiabetes29':
        'Cutting down isn\'t a lesser version of quitting — it\'s a gain in itself.',
    'healthTipDiabetes30':
        'If you\'ve been under target for a week, your body already feels it.',
    'healthTipDiabetes31':
        'Smoking narrows the small vessels in your feet, and diabetes already slows healing there. One fewer cigarette helps.',
    'healthTipDiabetes32':
        'Low blood sugar can make cravings feel stronger. Eat something first — the urge usually settles with it.',
    'healthTipDiabetes33':
        'If you track your readings regularly, you\'ll see the difference smoke-free days make over time.',
    'healthTipCopd3':
        'With COPD every cigarette adds to capacity already lost. Today\'s delay is a lasting gain.',
    'healthTipCopd4':
        'When breathing tightens, lean forward and breathe out through pursed lips. It works faster than a cigarette.',
    'healthTipCopd5':
        'More phlegm in the morning is linked to the night-time cigarette. Try one night without.',
    'healthTipCopd6':
        'Most flare-ups start with a cigarette. Skipping today helps you get through the month without one.',
    'healthTipCopd7':
        'Stopping to catch your breath on stairs is technique, not weakness. Smoking undoes it.',
    'healthTipCopd8':
        'Your lungs can start recovering today. Your age and history don\'t change that.',
    'healthTipCopd9':
        'Cold air narrows your airways; a cigarette doubles it. Stay in today.',
    'healthTipCopd10':
        'A craving lasts three minutes. Breathlessness takes the day. Wait out the three minutes.',
    'healthTipCopd11':
        'If your phlegm changes colour, tell your doctor. In the meantime, one cigarette fewer.',
    'healthTipCopd12':
        'Short walks protect your lung capacity. Take a walking break instead of a smoke break.',
    'healthTipCopd13':
        'If breathlessness wakes you at night, the evening cigarette is the easiest cause to change.',
    'healthTipCopd14':
        'Count while you do your breathing exercise. Measured progress convinces more than felt progress.',
    'healthTipCopd15':
        'Every smoke-free day is a day your cough eases a little further.',
    'healthTipCopd16':
        'Airing out the house is the easiest kindness you can do your lungs today.',
    'healthTipCopd17':
        'If you run short of breath while talking, that\'s recoverable. It starts with cutting down.',
    'healthTipCopd18':
        'Breathing gets harder after a heavy meal. Don\'t add a cigarette — walk a little.',
    'healthTipCopd19':
        'If you stayed under target today, your lungs will remember it for a week.',
    'healthTipCopd20':
        'Smoke paralyses the tiny hairs that clean your airways. They recover within hours.',
    'healthTipCopd21':
        'One extra second on the breathing test looks small but shows up on the stairs.',
    'healthTipCopd22':
        'Stay away from crowded, smoky places. Your airways are working hard enough today.',
    'healthTipCopd23':
        'Panic inflates a craving. Sit, breathe out through pursed lips, then reassess.',
    'healthTipCopd24':
        'Good that you\'ve had your flu jab. Cutting down supports what it does.',
    'healthTipCopd25':
        'Water thins phlegm and makes clearing it easier. Smoking does the opposite.',
    'healthTipCopd26':
        'One cigarette fewer today can mean one fewer waking tonight.',
    'healthTipCopd27':
        'Break chores into pieces and rest between them. That can replace the smoke break.',
    'healthTipCopd28':
        'Lung capacity recovers slowly, but it also declines. The direction is yours.',
    'healthTipCopd29':
        'When breathlessness rises, the first thing is to stop and the second is to breathe out slowly.',
    'healthTipCopd30':
        'Cutting down is a route too. Your lungs count every step of it.',
    'healthTipCopd31':
        'Morning difficulty clearing phlegm usually traces back to the last cigarettes the night before. Start by skipping those.',
    'healthTipCopd32':
        'Breathless on the stairs? That\'s a signal to rest, not to smoke.',
    'healthTipCopd33':
        'Your COPD medicine works less well alongside smoking. Skipping a cigarette around your dose lets it actually work.',
    'healthTipHeartDisease3':
        'Smoking raises your heart\'s oxygen demand while narrowing the vessels. Skipping this fixes both.',
    'healthTipHeartDisease4':
        'If you feel pressure in your chest, stop and rest. This is not a moment for a cigarette.',
    'healthTipHeartDisease5':
        'Even the first smoke-free day starts lowering your heart attack risk.',
    'healthTipHeartDisease6':
        'When your pulse climbs, a cigarette pushes it higher. Slow your breathing instead.',
    'healthTipHeartDisease7':
        'Walking strengthens your heart; smoking tires it. Today\'s choice is clear.',
    'healthTipHeartDisease8':
        'Mornings are the riskiest hours for your heart. Push back the day\'s first cigarette.',
    'healthTipHeartDisease9':
        'If stairs are getting harder, that\'s recoverable. It starts with cutting down.',
    'healthTipHeartDisease10':
        'Smoking thickens your blood and raises clot risk. Every cigarette you skip today counts.',
    'healthTipHeartDisease11':
        'Stress triggers your heart and your craving alike. Addressing the source addresses both.',
    'healthTipHeartDisease12':
        'Don\'t make your heart medicines compete with a cigarette.',
    'healthTipHeartDisease13':
        'Pain in your legs when walking is your arteries talking. Listen.',
    'healthTipHeartDisease14':
        'Your heart is already working after a heavy meal. Don\'t add a cigarette.',
    'healthTipHeartDisease15':
        'When the urge comes, walk for two minutes. Your heart accepts that trade.',
    'healthTipHeartDisease16':
        'Cholesterol and smoking press on the artery wall together. Easing one lightens the other.',
    'healthTipHeartDisease17':
        'If you stayed under target today, your heart beat fewer times for it.',
    'healthTipHeartDisease18':
        'Sleep repairs your heart. The evening cigarette interrupts the repair.',
    'healthTipHeartDisease19':
        'A breathing exercise lowers your pulse; a cigarette raises it. Same three minutes, opposite result.',
    'healthTipHeartDisease20':
        'Salt and smoking push your blood pressure together. Pull back on one today.',
    'healthTipHeartDisease21':
        'The best news for your heart: repair starts the moment the damage stops.',
    'healthTipHeartDisease22':
        'Your heart works harder walking in the cold. Don\'t add a cigarette.',
    'healthTipHeartDisease23':
        'When you put off a cigarette, your heart pumps easier for those minutes.',
    'healthTipHeartDisease24':
        'Alcohol and cigarettes strain your pulse from two directions. Keep them apart.',
    'healthTipHeartDisease25':
        'Today\'s walk might be the best decision your heart gets this week.',
    'healthTipHeartDisease26':
        'Count your pulse when the urge comes. It usually passes while you count.',
    'healthTipHeartDisease27':
        'For your heart, cutting down is as valuable as the whole road to quitting.',
    'healthTipHeartDisease28':
        'If your chest pain changes, tell your doctor. In the meantime, one cigarette fewer.',
    'healthTipHeartDisease29':
        'Your arteries can regain flexibility. It happens a little more with every day you cut down.',
    'healthTipHeartDisease30':
        'Your heart hasn\'t stopped once. You don\'t owe it a cigarette today.',
    'healthTipHeartDisease31':
        'Feeling pressure in your chest calls for sitting down and resting, not a cigarette.',
    'healthTipHeartDisease32':
        'The jump in heart rate after smoking lasts several minutes. You can choose to skip that entirely.',
    'healthTipHeartDisease33':
        'If you take heart medication regularly, cutting down makes it work harder for you, not against it.',
    'menuReports': 'Reports',
    'reportsTitle': 'Reports',
    'reportsWeeklyTab': 'Weekly',
    'reportsMonthlyTab': 'Monthly',
    'reportsPreviewButton': 'Preview / Print',
    'reportsShareButton': 'Share as PDF',
    'reportsPdfTitle': 'Nikotin Away Report',
    'reportsCigarettesLogged': 'Cigarettes logged',
    'reportsAvgPerDay': 'Daily average',
    'reportsRiskScore': 'Risk score',
    'reportsRiskTrend': 'Risk trend',
    'reportsBreathTrend': 'Breath trend',
    'reportsSmokingTrend': 'Smoking trend',
    'reportsTaskSuccess': 'Tasks completed',
    'reportsTaskCompletionRate': 'Task success rate',
    'reportsWeeklySurveys': 'Weekly surveys completed',
    'reportsBreathTests': 'Breath tests completed',
    'reportsDaysSinceQuit': 'Days since you started',
    'reportsTotalSteps': 'Total steps',
    'reportsAvgStepsPerDay': 'Daily average steps',
    'settingsLocationIntelligenceRow': 'Location Intelligence',
    'settingsLocationIntelligenceRowSubtitle':
        'Learn your frequent places to support you better',
    'locationIntelligenceTitle': 'Location Intelligence',
    'locationIntelligenceIntro':
        'When on, the app gradually learns up to 8 places you visit often (e.g. home, work). A short reminder is shown when you arrive at one of them. Your raw location history is never recorded — only the rough location of this small set of places is kept.',
    'locationIntelligencePurpose':
        'Why: to show the reminder and contribute to your risk assessment. Settings > Reset My Data also clears this data.',
    'locationIntelligenceBackgroundWarning':
        'The main permission was granted but background permission was not. Arrivals can\'t be detected while the app is closed. You can choose "Allow all the time" from Settings > Apps > Nikotin Away > Permissions > Location.',
    'locationIntelligenceEnabledConfirmation':
        'Location intelligence turned on.',
    'locationIntelligenceDisabledConfirmation':
        'Location intelligence turned off.',
    'locationIntelligencePlacesTitle': 'Learned Places',
    'locationIntelligenceNoPlacesYet': 'No place learned yet.',
    'locationIntelligencePlaceRow': 'Place',
    'locationIntelligenceVisitCount': 'visits',
    'locationArrivalNotificationTitle': 'You\'re here',
    'locationArrivalNotificationBody':
        'You\'re at a place you visit often. Take care of yourself.',
    'smokingLoggedConfirmation':
        'Logged. This helps us understand when things are hardest for you.',
    'undo': 'Undo',
    'dailyCheckInTitle': 'Daily Check-in',
    'dailyCheckInIntro':
        'Before you wind down, let\'s do a quick check-in. This lets us support you well without interrupting your day.',
    'breathExerciseCardTitle': 'Breathing Exercise',
    'dailyCheckInHoursQuestion': 'Roughly when did you smoke today?',
    'dailyCheckInDidNotSmoke': 'I didn\'t smoke today',
    'dailyCheckInSaved': 'Thanks, saved. See you tomorrow.',
    'notificationContextReasonLabel': 'Notification context reason',
    'smokingYearsHintExample': 'e.g.: 5',
    'dataLoadFailed': 'Failed to load data.',
    'progressSummaryTitle': 'General Summary',
    'totalRecords': 'Total records',
    'latestRiskScore': 'Latest risk score',
    'breathProgressTitle': 'Breath Progress',
    'dailyAverageLabel': 'Daily average',
    'weeklyAverageLabel': 'Weekly average',
    'monthlyAverageLabel': 'Monthly average',
    'firstToLastAverageDiff': 'First -> Last average difference',
    'latestVsPrevious': 'Latest test vs previous',
    'bestConsecutiveDay': 'Best consecutive days',
    'respFollowUpTitle': 'Respiratory Follow-up (COPD-like, non-diagnostic)',
    'latestRespBurden': 'Latest respiratory burden',
    'latestStatus': 'Latest status',
    'mmrcLikeGrade': 'mMRC-like grade',
    'catLikeTotal': 'CAT-like total',
    'warningDaysTotal': 'Total warning days',
    'respFollowUpNote':
        'Note: This follow-up does not diagnose; seek clinical evaluation if symptoms worsen.',
    'trendChartsTitle': 'Trend Charts',
    'weeklyRiskTrendTitle': 'Weekly risk trend (last 12 points)',
    'noWeeklyDataForChart': 'Not enough weekly data for chart.',
    'breathTrendTitle': 'Breath average trend (daily last 14 points)',
    'noBreathDataForChart': 'Not enough breath test data for chart.',
    'respiratoryTrendTitle': 'Respiratory burden trend (weekly last 12)',
    'noRespDataForChart': 'Not enough respiratory data for chart.',
    'taskBarrierComplianceTitle': 'Task and Barrier Compliance',
    'last10Successful': 'Last 10 successful',
    'last10Failed': 'Last 10 failed',
    'achievementsSinceStartTitle': 'Achievements Since Start',
    'achievementsPageTitle': 'Badges',
    'achievementsEarnedCount': '{earned} / {total} badges earned',
    'achievementStreak1Title': 'First Day',
    'achievementStreak1Desc': 'You stayed under your target for a day.',
    'achievementStreak3Title': 'Three in a Row',
    'achievementStreak3Desc': 'Three days running at or under target.',
    'achievementStreak7Title': 'One Week',
    'achievementStreak7Desc': 'Seven days under your target.',
    'achievementStreak30Title': 'One Month',
    'achievementStreak30Desc': 'Thirty days running at or under target.',
    'achievementStreak90Title': 'Three Months',
    'achievementStreak90Desc': 'Ninety days at or under target.',
    'achievementAvoided20Title': 'First Twenty',
    'achievementAvoided20Desc': "Twenty cigarettes not smoked — nearly a pack.",
    'achievementAvoided100Title': 'One Hundred',
    'achievementAvoided100Desc': 'A hundred cigarettes not smoked.',
    'achievementAvoided500Title': 'Five Hundred',
    'achievementAvoided500Desc': 'Five hundred cigarettes not smoked.',
    'achievementAvoided1000Title': 'One Thousand',
    'achievementAvoided1000Desc': 'A thousand cigarettes not smoked.',
    'achievementInterval25Title': 'A Quarter Longer',
    'achievementInterval25Desc':
        'Your gap between cigarettes is 25% longer than it was.',
    'achievementInterval50Title': 'Half Again',
    'achievementInterval50Desc':
        'Your gap between cigarettes is 50% longer than it was.',
    'achievementInterval100Title': 'Twice as Long',
    'achievementInterval100Desc': 'Your gap between cigarettes has doubled.',
    'achievementLongestBarrier60Title': 'One Hour',
    'achievementLongestBarrier60Desc':
        'Your longest smoke-free stretch passed 1 hour.',
    'achievementLongestBarrier120Title': 'Two Hours',
    'achievementLongestBarrier120Desc':
        'Your longest smoke-free stretch passed 2 hours.',
    'riskChange': 'Risk change',
    'weeklyImprovementPeriod': 'Weekly improvement period',
    'planDayLabel': 'Plan day',
    'remainingDaysLabel': 'Remaining day',
    'respAlertHistoryTitle': 'Respiratory Alert History',
    'noCriticalRespAlertRecord': 'No critical respiratory alert record.',
    'weeklyHistoryTitle': 'Weekly History',
    'noWeeklyRecordYet': 'No weekly survey record yet.',
    'breathTestHistoryTitle': 'Breath Test History',
    'noBreathRecordYet': 'No breath test record yet.',
    'surveyModeTitle': 'Survey mode',
    'surveyModeQuick': 'Quick (15 sec)',
    'surveyModeDetailed': 'Detailed',
    'surveyModeAutoDetailedHint':
        'Last week looks high-risk. You can switch to Detailed mode for finer adjustment.',
    'weeklyQuickRespTitle': 'Quick Respiratory Check',
    'weeklyQuickRespHint':
        'Fill 3 fields in quick mode to better reflect your respiratory status.',
    'adaptiveSummary': 'Adaptive summary',
    'addNote': 'Add note',
    'asthma': 'Asthma',
    'backToHome': 'Back to home',
    'breathAverageComparison': 'Average comparison',
    'breathComparedAverageDeclined': 'Below average',
    'breathComparedAverageImproved': 'Above average',
    'breathComparedAverageStable': 'Close to average',
    'breathComparedPreviousDeclined': 'Declined vs previous test',
    'breathComparedPreviousImproved': 'Improved vs previous test',
    'breathComparedPreviousStable': 'Stable vs previous test',
    'breathImprovementSummary': 'Breath improvement summary',
    'breathNoReferenceYet': 'Not enough reference data yet.',
    'breathPreviousComparison': 'Previous test comparison',
    'breathTestRecordTitle': 'Breathing Exercise Record',
    'breathTrend': 'Breath trend',
    'chainSmoking': 'Chain smoking',
    'chainSmokingAsk': 'Do you smoke consecutively?',
    'chainSmokingCountAsk': 'How many do you smoke consecutively?',
    'chainSmokingLatest': 'Latest chain smoking status',
    'chainSmokingSituation': 'Chain smoking status',
    'chainSmokingTrend': 'Chain smoking trend',
    'completeRegistration': 'Complete registration',
    'continueWithoutPermission': 'Continue without permission',
    'copd': 'COPD',
    'daily': 'Daily',
    'dailyBreathStatus': 'Daily breath status',
    'days': 'days',
    'diabetes': 'Diabetes',
    'evaluation': 'Evaluation',
    'exhaleDelta': 'Exhale delta',
    'failedTaskCount': 'Failed tasks',
    'firstCigarette0to5': '0-5 minutes after waking',
    'firstCigarette30to60': '30-60 minutes after waking',
    'firstCigarette5to10': '5-10 minutes after waking',
    'firstCigarette60plus': '60+ minutes after waking',
    'firstEvaluation': 'First evaluation',
    'firstTaskNoSmoke15': 'First task: Stay smoke-free for 15 minutes',
    'fivePack': '5 packs',
    'fivePlusCig': '5+ cigarettes',
    'fourCig': '4 cigarettes',
    'fourPack': '4 packs',
    'goal180CadenceLabel': '180-day goal cadence',
    'goal180CadenceOneDay': 'Steady daily cadence',
    'goal180CadenceTwoDays': 'Strong every-two-days cadence',
    'goal180CadenceWeek': 'Weekly recovery cadence',
    'goal180GuideEarly': 'Frequent support is normal in early phase.',
    'goal180GuideLate': 'Stability is prioritized in late phase.',
    'goal180GuideLateHard': 'If hard in late phase, burden is reduced.',
    'goal180GuideMid': 'Rhythm settles in mid phase.',
    'goal180GuideMidHard': 'Trigger-focused tuning in mid phase.',
    'goal180ProgressLabel': '180-day progress',
    'goal180RemainingLabel': 'Remaining to 180 days',
    'hypertension': 'Hypertension',
    'inhaleDelta': 'Inhale delta',
    'initialRecordTitle': 'Initial Record',
    'lastBreathTest': 'Last breath test',
    'lastExhale': 'Last exhale',
    'lastInhale': 'Last inhale',
    'lastSurveyDate': 'Last survey date',
    'lessThanOnePack': 'Less than 1 pack',
    'mandatoryTaskCommand': 'Mandatory task command',
    'mandatoryTaskHint': 'Complete today\'s focus.',
    'mandatoryTaskStartButton': 'Accept',
    'mandatoryTaskDeclineButton': 'Postpone',
    'mandatoryTaskTitle': 'Today\'s focus',
    'monthly': 'Monthly',
    'monthlyImprovement': 'Monthly improvement',
    'noRecordYet': 'No record yet.',
    'noSurveyYet': 'No survey yet.',
    'noTaskToday': 'No task today.',
    'notificationPermissionRequired':
        'Reminders may not work without notification permission.',
    'onePack': '1 pack',
    'onlyBreaks': 'Only during breaks',
    'onlyBreaksBetweenLectures': 'Only between lectures',
    'openAlarmReminderSettings': 'Open Alarm/Reminder Settings',
    'openSettings': 'Open Settings',
    'openTaskFollowUpScreen': 'Open task follow-up screen',
    'openViolationReportScreen': 'Open moments you struggled',
    'packChangeDaily': 'Daily pack change',
    'packsApproxQuestion': 'Approximately how many packs?',
    'permissionsRetryMessage':
        'App features are limited without required permissions.',
    'permissionsRetryTitle': 'Retry permissions',
    'pointShort': 'pts',
    'predictedRiskTime': 'Predicted risk time',
    'predictedTrigger': 'Predicted trigger',
    'predictionConfidence': 'Prediction confidence',
    'premiumActive': 'Premium active',
    'previousRecord': 'Previous record',
    'professionEngineer': 'Engineer',
    'professionFreelance': 'Freelance',
    'professionHealthcare': 'Healthcare worker',
    'professionOfficer': 'Officer',
    'professionOther': 'Other',
    'professionRetired': 'Retired',
    'professionSalaried': 'Employed',
    'professionStudent': 'Student',
    'professionTeacher': 'Teacher',
    'professionTradesman': 'Tradesman',
    'professionWorker': 'Worker',
    'progressNegative': 'Negative progress',
    'progressNegativeDetail': 'Risk increased this week.',
    'progressPositive': 'Positive progress',
    'progressPositiveDetail': 'Risk decreased this week.',
    'progressRegression': 'Regression',
    'progressSummary': 'Progress summary',
    'quitChildren': 'For my children',
    'quitFamily': 'For my family',
    'quitMoney': 'Financial reasons',
    'quitPerformance': 'To improve my performance',
    'campusSmoking': 'Is smoking allowed on campus?',
    'firstLectureStart': 'First lecture start',
    'lastLectureEnd': 'Last lecture end',
    'schoolEnd': 'School end',
    'schoolSmoking': 'Is smoking allowed at school?',
    'schoolStart': 'School start',
    'schoolTypeHighSchool': 'High school',
    'schoolTypeLabel': 'School type',
    'schoolTypeUniversity': 'University',
    'registrationCompleted': 'Registration completed',
    'riskDelta': 'Risk delta',
    'riskyHours': 'Risky hours',
    'riskyTriggers': 'Risky triggers',
    'secShort': 'sec',
    'sensorPermissionRecommended':
        'Motion/sensor permission is recommended for better tracking.',
    'sevenPlusPack': '7+ packs',
    'sixPack': '6 packs',
    'sleepTime': 'Sleep time',
    'smokeFree0to15': '0-15 minutes',
    'smokeFree120to240': '120-240 minutes',
    'smokeFree15to30': '15-30 minutes',
    'smokeFree240plus': '240+ minutes',
    'smokeFree60to120': '60-120 minutes',
    'status': 'Status',
    'stressHigh': 'High',
    'interventionIntensityTitle': 'Intervention intensity',
    'interventionIntensityHint':
        'Chooses how often the app interrupts and assigns you tasks during the day.',
    'triggerTitleHint': 'Which of these make you want to smoke?',
    'interventionIntensityGentle': 'Gentle',
    'interventionIntensityBalanced': 'Balanced',
    'interventionIntensityStrict': 'Strict',
    'stressLow': 'Low',
    'subscriptionEnd': 'Subscription end',
    'subscriptionInfo': 'Subscription info',
    'subscriptionStart': 'Subscription start',
    'subscriptionType': 'Subscription type',
    'free': 'Free',
    'premium': 'Premium',
    'active': 'Active',
    'passive': 'Passive',
    'taskTimerStartedTitle': 'Task started',
    'successfulTaskCount': 'Successful tasks',
    'surveyHistory': 'Survey history',
    'taskBreathExercise2': 'Do a 2-minute breathing exercise',
    'taskCountToday': 'Today\'s task count',
    'taskDeferredTenMinutes': 'Task deferred by 10 minutes',
    'taskDelayFirstSmoke10': 'Delay first cigarette by 10 minutes',
    'taskDelayFirstSmoke25': 'Delay first cigarette by 25 minutes',
    'taskDrinkWater': 'Drink a glass of water',
    'taskFollowUpEmpty': 'No pending task follow-up.',
    'taskFollowUpPendingCount': 'Pending follow-up count',
    'missedTaskCardBody': 'We missed a task. Want to start it now?',
    'missedTaskStartLabel': 'Start',
    'missedTaskSkipLabel': 'Skip',
    'undeliveredTaskSummary':
        '{count} task(s) were postponed because your phone was in a state like Do Not Disturb.',
    'taskFollowUpScheduledAt': 'Scheduled follow-up time',
    'taskFollowUpTitle': 'Task follow-ups',
    'taskFollowUpMarkSuccess': 'I did it',
    'taskFollowUpMarkSmoked': 'I smoked',
    'taskFollowUpDefer': 'Postpone',
    'taskOutcomeConfirmQuestion': 'Was the task completed?',
    'taskNoSmoke10': 'Stay smoke-free for 10 minutes',
    'taskNoSmoke120': 'Stay smoke-free for 120 minutes',
    'taskNoSmoke30': 'Stay smoke-free for 30 minutes',
    'taskNoSmoke45': 'Stay smoke-free for 45 minutes',
    'taskNoSmoke60': 'Stay smoke-free for 60 minutes',
    'taskNoSmoke90': 'Stay smoke-free for 90 minutes',
    'adaptiveNoSmokeTaskTemplate':
        'Do not smoke for the next {duration}. If you have a cigarette in your hand, put it out now.',
    'delayFirstCigaretteTemplate': 'Delay your first cigarette by {duration}.',
    'adaptiveNoSmokeWindowTemplate':
        'Do not smoke for the next {duration}, get ready before the {window} window.',
    'checkInPrompt': 'Are you still holding on?',
    'coachReductionTier75':
        "Today's goal: at least 1 fewer cigarette than yesterday, delay the first one by 90 minutes.",
    'coachReductionTier60':
        "Today's goal: at least 2 fewer cigarettes than yesterday, wait 10 minutes before each one.",
    'coachReductionTier40':
        "Today's goal: at least 3 fewer cigarettes than yesterday, skip one after midday.",
    'coachReductionTierBase':
        "Today's goal: keep the current reduction, use water + gum instead of smoking during risky hours.",
    'coachBreathDeclining':
        'BREATHING: Do 2 breath tests today, follow each with 2 minutes of slow breathing.',
    'coachBreathImproving':
        'BREATHING: Keep your gains, finish one breathing routine before your risk hour.',
    'coachBreathStable':
        'BREATHING: During a crisis, do 2 minutes of breathing + 1 glass of water.',
    'coachTrackReduceToday':
        'TRACK: Finish today at least 2 below yesterday\'s total count.',
    'coachTrackCompleteThree':
        'TRACK: Mark at least 3 of today\'s chosen tasks as done.',
    'coachPrepWindowTemplate':
        'PREPARE: Before {window}, prepare water + gum + a short walk plan.',
    'coachTriggerDelayTemplate':
        'TRIGGER: Delay 3 minutes when {trigger} hits, then decide again.',
    'coachFocusRiskHourTemplate':
        'FOCUS: Keep notifications on for your riskiest hour, {hour}.',
    'coachWeeklyTargetTemplate':
        'GOAL: Bring your weekly risk target below {percent}.',
    'coachTriggerStressCommand':
        'TRIGGER-STRESS: When stressed, do 90 seconds of breathing + 1 glass of water, then decide again.',
    'coachTriggerCoffeeCommand':
        'TRIGGER-COFFEE: Delay coffee by 30 minutes, don\'t pair coffee with smoking.',
    'coachTriggerAlcoholCommand':
        'TRIGGER-ALCOHOL: On drinking days, say no to the first cigarette offer, use gum/water instead.',
    'coachTriggerSocialCommand':
        'TRIGGER-SOCIAL: Before entering a social setting, message your support person about your goal.',
    'coachCrisisProtocol':
        'CRISIS: Delay 3 minutes on the first craving wave, apply the 4D protocol on the second.',
    'coachSupportSingleGoal':
        'SUPPORT: Pick a single goal today and mark it done in the app when finished.',
    'coachHintHighRisk':
        'You are in a high-risk period: be sure to delay your first cigarette.',
    'coachHintMedRisk':
        'Medium-high risk: use the breathing + water routine the moment a trigger hits.',
    'coachHintLowRisk':
        'Keep the rhythm: set a goal to complete at least one task today.',
    'coachHintWindowTemplate':
        'Riskiest window: {window}. Prepare before this time.',
    'coachHintTriggerTemplate':
        'Predicted trigger: {trigger}. Decide on an alternative behavior.',
    'coachRiskDaypart_high_morning_0':
        'MORNING: Delay your first cigarette by 90 minutes, drink a glass of water first.',
    'coachRiskDaypart_high_morning_1':
        'CRISIS: Apply the 4D protocol (delay-breathe-water-distract).',
    'coachRiskDaypart_high_day_0':
        'MIDDAY: Take a 7-minute walk after eating, then decide.',
    'coachRiskDaypart_high_day_1':
        'TRIGGER: Separate coffee from smoking, delay coffee by 30 minutes.',
    'coachRiskDaypart_high_evening_0':
        'EVENING: Say no to the first offer in a social setting, delay 3 minutes.',
    'coachRiskDaypart_high_evening_1':
        'SUPPORT: Send your support person a one-line message before your risk hour.',
    'coachRiskDaypart_high_night_0':
        'NIGHT: No smoking after this hour, apply the emergency crisis routine.',
    'coachRiskDaypart_high_night_1':
        'UNWIND: Close the day with 3 minutes of slow breathing + water.',
    'coachRiskDaypart_medium_morning_0':
        'MORNING: Delay your first cigarette by 45 minutes.',
    'coachRiskDaypart_medium_morning_1':
        'ROUTINE: Do a 2-minute breathing exercise before coffee.',
    'coachRiskDaypart_medium_day_0':
        'MIDDAY: Wait 10 minutes before each cigarette.',
    'coachRiskDaypart_medium_day_1': 'SKIP: Skip one cigarette this afternoon.',
    'coachRiskDaypart_medium_evening_0':
        'EVENING: Use gum/water as an alternative during your risk hour.',
    'coachRiskDaypart_medium_evening_1':
        'TRACK: Check your goal in the end-of-day count.',
    'coachRiskDaypart_medium_night_0':
        'NIGHT: Drink water after your last cigarette, don\'t smoke again.',
    'coachRiskDaypart_medium_night_1':
        'PLAN: Push tomorrow\'s first-cigarette time back by 15 minutes, starting now.',
    'coachRiskDaypart_low_morning_0':
        'MORNING: Delay your first cigarette by at least 25 minutes.',
    'coachRiskDaypart_low_morning_1':
        'PROTECT: Do a water + breathing routine to protect your breathing gains.',
    'coachRiskDaypart_low_day_0':
        'MIDDAY: Only decide at planned times, no automatic lighting up.',
    'coachRiskDaypart_low_day_1':
        'PROTECT: Take a 5-minute walk instead of a cigarette after midday.',
    'coachRiskDaypart_low_evening_0':
        'EVENING: Apply a 3-minute delay for social triggers.',
    'coachRiskDaypart_low_evening_1':
        'PROTECT: Write down what worked today in your end-of-day note.',
    'coachRiskDaypart_low_night_0':
        'NIGHT: Stop smoking after this hour, use breathing if a crisis hits.',
    'coachRiskDaypart_low_night_1':
        'PROTECT: Write down one measure for tomorrow\'s risk hour.',
    'taskNoteCraving': 'Take a note of the craving moment',
    'taskNotNowButton': 'Not now',
    'taskOutcomeNo': 'No',
    'taskOutcomeQuestion': 'Did you complete the task successfully?',
    'taskOutcomeYes': 'Yes',
    'taskPlanOneDayDelayAllCravings':
        '1-day smoke-free task: delay cigarettes during all craving moments today.',
    'taskPlanOneDayDelayFirst90':
        '1-day smoke-free task: delay first cigarette by at least 90 minutes.',
    'taskPlanOneWeekCompleteAll':
        '1-week smoke-free goal: complete all tasks for 7 days.',
    'taskPlanTwoDaysBreathAndWater':
        '2-day smoke-free plan: 10 deep breaths + water during cravings.',
    'taskPlanTwoDaysDelayTriggers':
        '2-day smoke-free task: delay smoking in triggers for 48 hours.',
    'taskReasonCadence': 'Task cadence',
    'taskReasonCardTitle': 'Why this task?',
    'taskReasonCause': 'Reason',
    'taskReasonCauseBalanced': 'Balanced difficulty selected',
    'taskReasonCauseBootstrap': 'Bootstrap mode is active',
    'taskReasonCauseFailurePressure': 'Adjusted due to failure pressure',
    'taskReasonCauseHighRisk': 'Selected due to high risk',
    'taskReasonCauseLowRisk': 'Protective task in low risk',
    'taskReasonCauseSuccessStability': 'Stability task based on success',
    'taskReasonCauseTopHour': 'Selected by highest-risk hour',
    'taskReasonCauseTopTrigger': 'Selected by top trigger',
    'taskReasonNextNotification': 'Next reminder',
    'taskReasonNoPlanned': 'No planned task',
    'taskReasonNoRecentData': 'No sufficient recent data',
    'taskReasonRecentRatio': 'Recent performance ratio',
    'taskReasonRiskLine': 'Risk line',
    'taskSkipOneCig': 'Skip one cigarette today',
    'taskSmokeTwoLess': 'Smoke two fewer cigarettes today',
    'taskStartTitle': 'Task started',
    'taskStateCompleted': 'Completed',
    'taskStateDeferred': 'Deferred',
    'taskStateFailed': 'Not this time',
    'taskStateNew': 'New',
    'taskSuspiciousReset': 'Reset due to an unexpected condition',
    'taskUnit': 'task',
    'taskUseGumAtRiskHour': 'Use sugar-free gum at risky hour',
    'threeCig': '3 cigarettes',
    'threePack': '3 packs',
    'threePlusPack': '3+ packs',
    'todaysTasks': 'Today\'s tasks',
    'totalUsage': 'Total usage',
    'trendDeclining': 'Declining',
    'trendImproving': 'Improving',
    'trendStable': 'Stable',
    'trialStatus': 'Trial status',
    'twoCig': '2 cigarettes',
    'twoPack': '2 packs',
    'unnamedUser': 'Unnamed user',
    'validationChainCountRequired': 'Please select consecutive smoking count.',
    'validationChainHabitRequired': 'Please select consecutive smoking habit.',
    'validationFirstCigaretteRequired':
        'Please select how soon after waking you smoke your first cigarette.',
    'validationFixHighlightedFields': 'Please fix the highlighted fields.',
    'validationSleepTimeRequired': 'Please select sleep time.',
    'validationSmokeYearsRange':
        'Smoking duration must be between 0 and 90 years.',
    'validationWakeTimeRequired': 'Please select wake-up time.',
    'viewAllSurveys': 'View all surveys',
    'violationHigh': 'High',
    'violationLow': 'Low',
    'violationMedium': 'Medium',
    'violationReportEmpty': 'No moments recorded yet.',
    'violationReportTitle': 'Moments You Struggled',
    'violationSource': 'Source',
    'violationTask': 'Task',
    'violationTime': 'Time',
    'wakeTime': 'Wake-up time',
    'weekly': 'Weekly',
    'weeklyImprovement': 'Weekly improvement',
    'weeklyMood': 'Weekly mood',
    'weeklyRecordTitle': 'Weekly Record',
    'weeklyRiskTarget': 'Weekly risk target',
    'welcome': 'Welcome',
    'workEnd': 'Work end',
    'workplaceSmoking': 'Is smoking allowed at your workplace?',
    'workStart': 'Work start',
    'taskActionDone': 'Start Task',
    'taskActionNotNow': 'Not now',
    'taskActionDoneLabel': 'Accept',
    'taskActionDeclineLabel': 'Decline',
    'taskActionSosLabel': 'SOS, I\'m struggling',
    'postponeChoiceTitle': 'Postpone for how long?',
    'postponeChoiceBody': 'The same task returns after the time you pick.',
    'postpone5Label': '5 minutes',
    'postpone10Label': '10 minutes',
    'postpone15Label': '15 minutes',
    'taskConfirmQuestionTitle': 'Time is up',
    'taskConfirmQuestion': 'Did you smoke during this time?',
    'taskConfirmYesLabel': 'I smoked — Failed',
    'taskConfirmNoLabel': 'I did not smoke — Successful',
    'sosPageTitle': 'I want one right now',
    'sosIntro': 'This will pass in a few minutes. Let\'s breathe together.',
    'sosCyclesCompleted': '{count} rounds done',
    'sosPhaseInhale': 'Breathe in',
    'sosPhaseHold': 'Hold',
    'sosPhaseExhale': 'Breathe out',
    'sosReassurance':
        'A craving usually peaks within 3-5 minutes and then fades. You can get through this one without smoking.',
    'sosDismiss': 'I\'m through it',
    'sosNeedSuggestion': 'Suggest something',
    'sosSuggestionTitle': 'Try this',
    'sosSuggestionWater': 'Drink a glass of water, slowly.',
    'sosSuggestionWalk': 'Walk for five minutes, outside if you can.',
    'sosSuggestionCall': 'Call someone you haven\'t spoken to today.',
    'sosSuggestionStretch': 'Stand up and loosen your shoulders.',
    'sosSuggestionWash': 'Splash cold water on your face.',
    'sosResumeQuestion': 'When should we return to your task?',
    'sosResume30': 'In 30 minutes',
    'sosResume60': 'In 1 hour',
    'sosResume120': 'In 2 hours',
    'sosTaskPostponed': 'Task postponed. Take care of yourself.',
    'sosBarrierResumed': "The barrier is still going. You did it.",
    'sosBarrierResumedTitle': 'You got through it',
    'sosBarrierResumedBody':
        "We didn't reset the barrier — it's resuming right where it left off. That's exactly what we want.",
    'sosBarrierResumedAction': 'Continue',
    'barrierWonFeedback':
        '{minutes} minutes smoke-free. {hours} total hours smoke-free this month.',
    'failureTriggerPromptTitle': 'What made you smoke just now?',
    'failureTriggerStress': 'Stress or tension',
    'failureTriggerCoffee': 'Coffee or tea',
    'failureTriggerMeal': 'After a meal',
    'failureTriggerAlcohol': 'Alcohol',
    'failureTriggerPhone': 'Using your phone',
    'failureTriggerDriving': 'Driving',
    'failureTriggerWorkBreak': 'Work break',
    'failureTriggerSocial': 'Social setting',
    'failureTriggerBoredom': 'Boredom',
    'failureTriggerHabit': 'Habit / automatically',
    'failureTriggerNoReason': 'No specific reason',
    'failureTriggerUnknown': 'I do not want to answer now',
    'medicationTimesPerDay': 'How many times a day do you take it?',
    'medicationTimesPerDayHint':
        'We spread the times evenly across your waking hours; you can change any of them.',
    'medicationTimeSlotLabel': 'Dose {index}',
    'medicationAdviceDisclaimer':
        'This is general information; talk to your doctor about anything concerning your treatment.',
    'taskActionNotNowLabel': 'Not now',
    'taskFollowUpActionYes': 'Yes',
    'taskFollowUpActionNo': 'No',
    'disciplineCommand': 'Do not smoke from this moment',
    'disciplineCommandBody':
        'Protocol is active. Start the task to clear this alert.',
    'breathReminderTitle': 'Breath Test',
    'breathReminderBody': 'Time for your daily breath test.',
    'breathReminderDriving': 'Reminder delayed briefly for driving safety.',
    'breathReminderWorkout':
        'Reminder deferred until your activity cool-down window.',
    'breathReminderPostMeal':
        'Use a post-meal breathing routine now to avoid smoking.',
    'taskFollowUpTitlePush': 'Task Follow-up',
    'taskFollowUpQuestion': 'Did you complete the task successfully?',
    'taskFollowUpQuestionDriving':
        'Answer after driving: Did you complete the task successfully?',
    'taskFollowUpQuestionWorkout':
        'Answer after your activity: Did you complete the task successfully?',
    'taskFollowUpQuestionPostMeal':
        'After the meal window, did you manage the urge without smoking?',
    'postMealShieldCommand':
        'After meal: delay 10 minutes, drink water, and use gum.',
    'contextReasonDriving':
        'Notification deferred due to driving/transport context',
    'contextReasonWorkout':
        'Notification deferred due to running/workout context',
    'contextReasonEating':
        'Notification shifted to post-meal anti-smoking window',
    'contextReasonNormal': 'Notification scheduled in normal mode',
    'taskEscalationTitle': 'Still waiting',
    'taskEscalationBodyPrefix':
        "You haven't answered yet. I'll ask again in {minutes} minutes:",
    'taskTimerStartedBody': 'Task started:',
    'taskTimerDuration': 'Timer',
    'minutesShort': 'minutes',
    'oneHourLabel': '1 hour',
    'postponeReminderPromptTitle': 'When should I remind you?',
    'postponeReminderPromptMessage':
        'You are postponing the task. When would you like to be reminded again?',
    'sleepActivityAdvisoryTitle': 'Still awake?',
    'sleepActivityAdvisoryBody':
        'We noticed you\'re awake during your sleep hours. You\'ve already completed today\'s tasks -- just remember to rest.',
    'barrierStartedTitle': 'Duration barrier started',
    'barrierStartedBody': 'Smoke-free timer is running.',
    'barrierStartedDuration': 'Timer duration',
    'smokeFreeCounterTitle': 'Smoke-free timer',
    'smokeFreeCounterRemaining': 'Remaining time',
    'weeklySurveyReminderTitle': 'Weekly survey due',
    'weeklySurveyReminderBody':
        'Please complete the weekly survey to refresh your risk score.',
    'trialInfoTitle': '14-Day Free Trial',
    'trialInfoMessage':
        'You can use Nikotin Away free for 14 days, including the AI Mentor and every other feature. A subscription is required to continue after that.',
    'subscriptionGateTitle': 'Your Trial Has Ended',
    'subscriptionGateMessage':
        'Your 14-day free trial is over. Features like the AI Mentor, the task system, breath/cough tests, and location/sleep intelligence need a subscription; you can keep using the core features for free.',
    'subscriptionMonthlyTitle': 'Monthly',
    'subscriptionYearlyTitle': 'Yearly',
    'subscriptionPurchaseButton': 'Subscribe',
    'subscriptionRestoreButton': 'Restore Purchase',
    'subscriptionContinueFreeButton': 'Continue for Free',
    'subscriptionNeedsConnection':
        'An internet connection is needed to verify your subscription. This will retry automatically once connected.',
    'subscriptionRetryButton': 'Retry',
    'subscriptionPurchasePending': 'Processing...',
    'subscriptionPurchaseFailed': 'Purchase could not be completed, try again.',
    'subscriptionRestoreNotFound': 'No purchase was found to restore.',
    'subscriptionStoreUnavailable':
        'The store is currently unavailable. Please try again later.',
    'premiumUpsellTitle': 'Premium Feature',
    'premiumUpsellDismiss': 'Dismiss',
    'premiumUpsellUpgrade': 'Upgrade',
    'premiumUpsellAiMentor':
        'The AI Mentor requires a subscription or trial period.',
    'premiumUpsellBreathTests':
        'Breath and cough tests require a subscription or trial period.',
    'premiumUpsellLocationIntelligence':
        'Location Intelligence requires a subscription or trial period.',
    'savingsPageTitle': 'Savings',
    'savingsMoneySaved': 'Money saved',
    'savingsCigarettesNotSmoked': 'Cigarettes not smoked',
    'savingsLifeTimeRegained': 'Lifetime regained',
    'savingsHoursUnit': '{hours} hours',
    'savingsPackPriceLabel': 'Pack price',
    'savingsPackPriceHint': 'e.g. 80',
    'savingsSaveButton': 'Save',
    'healthRecoveryPageTitle': 'Health Recovery Timeline',
    'recoveryMin20Title': '20 minutes',
    'recoveryHour12Title': '12 hours',
    'recoveryDay1Title': '24 hours',
    'recoveryDay2Title': '48 hours',
    'recoveryDay3Title': '72 hours',
    'recoveryWeek2Title': '2 weeks',
    'recoveryMonth1Title': '1 month',
    'recoveryMonth9Title': '9 months',
    'recoveryYear1Title': '1 year',
    'recoveryYear5Title': '5 years',
    'recoveryYear10Title': '10 years',
    'recoveryMin20Desc':
        'Heart rate and blood pressure start returning to normal.',
    'recoveryHour12Desc':
        'Carbon monoxide level in your blood drops to normal.',
    'recoveryDay1Desc': 'Your risk of heart attack begins to decrease.',
    'recoveryDay2Desc': 'Your sense of taste and smell noticeably improves.',
    'recoveryDay3Desc': 'Breathing gets easier and energy levels rise.',
    'recoveryWeek2Desc': 'Circulation and lung function improve.',
    'recoveryMonth1Desc':
        'Coughing and shortness of breath noticeably decrease.',
    'recoveryMonth9Desc': 'Cilia in your lungs regain normal function.',
    'recoveryYear1Desc': 'Risk of coronary heart disease is cut in half.',
    'recoveryYear5Desc': 'Stroke risk approaches that of a non-smoker.',
    'recoveryYear10Desc':
        'Lung cancer death rate is about half that of a smoker.',

    'mentorDailyCoachHourTemplate':
        "You've really been doing well lately. Pay extra attention to {hour} today — you've got the rest handled.",
    'mentorDailyCoachNoHour':
        "You've really been doing well lately. Let's keep this pace up.",
    'mentorDailySupportive':
        "The last few days haven't been easy for you, I can see that. Today doesn't need to be perfect — just focus on getting through the next moment.",
    'mentorDailyNeutralHourTemplate':
        "How's today going? I'm with you during {hour}.",
    'mentorDailyNeutralNoHour': "How's today going? ",
    'mentorBreathImprovingNote':
        "I noticed your recent breath tests are improving too — keep it up.",
    'mentorWeeklyCoachTemplate':
        "You were really strong this week — you completed {count} tasks. Let's carry this momentum into next week.",
    'mentorWeeklySupportive':
        "This week was tough, I know. The numbers don't matter right now — what matters is that you're still here.",
    'mentorWeeklyNeutralTemplate':
        "Your risk level this week: {level}. A detailed weekly survey can give us a clearer picture.",
    'mentorHistImprovedTemplate':
        "You were struggling {daypart} last week — there's no record at all this week during that time, that's great.",
    'mentorHistWorseningTemplate':
        "You were struggling {daypart} last week, and it looks similar this week. Should we make a plan together for that time?",
    'mentorHistSimilarTemplate':
        "You were struggling {daypart} last week, and you look a bit better this week.",
    'mentorDayPartMorning': 'in the mornings',
    'mentorDayPartAfternoon': 'in the afternoons',
    'mentorDayPartEvening': 'in the evenings',
    'mentorDayPartNight': 'at night',
    'mentorReframeSuspiciousWithTitleTemplate':
        'Something seemed to go wrong just now (during "{title}"). Are you okay? We can take a short breathing break together if you want.',
    'mentorReframeSuspiciousNoTitle':
        'Something seemed to go wrong just now. Are you okay? We can take a short breathing break together if you want.',
    'mentorReframeWillpower':
        "It didn't work out this time, that's okay — this isn't a failure, it's part of the process. We'll try again tomorrow.",
    'mentorReframeDeferredStart':
        "I understand if now isn't a good time, I'll remind you again in 10 minutes.",
    'mentorReframeFollowupDeferred': "Okay, I'll ask again in a bit.",
    'mentorReframeDurationBarrier':
        "I think this goal was a bit long for you. Let's start with a shorter duration next time — small steps are still progress.",
    'quickReplyOk': "I'm okay",
    'quickReplyStruggling': "I'm struggling",
    'quickReplyNoTalk': "I don't want to talk",
    'quickReplyFillWeeklySurvey': 'Fill weekly survey',
    'quickReplyLater': 'Later',
    'quickReplyThanks': 'Thanks',
    'quickReplyLetsTalk': "Let's talk",
    'quickReplyOkAck': 'Okay',
    'mentorFollowupStrugglingQ': 'What kind of help would you like?',
    'quickReplyReduceTasks': 'Reduce tasks',
    'quickReplyEaseBarrier': 'Ease the barrier',
    'quickReplyJustTalking': 'I just wanted to talk',
    'mentorFollowupAckReduceTasks':
        "Starting tomorrow, I've eased your tasks for a week — take care of yourself.",
    'mentorFollowupAckEaseBarrier': "I've eased tomorrow's barrier a bit.",
    'mentorFollowupAckJustTalking': "I'm here, write whenever you'd like.",
    'sleepRoutineTitle': 'Pre-Sleep Routine',
    'sleepRoutineIntro': '4 short steps before you sleep',
    'sleepRoutineStepIndicator': 'Step {current} of {total}',
    'sleepRoutineDiscrepancyQuestionTitle': 'How many cigarettes today?',
    'sleepRoutineDiscrepancyQuestionBody':
        "We're missing {count} — did you forget to log any?",
    'sleepRoutineDiscrepancyNoneButton': 'No, my log is correct',
    'sleepRoutineDiscrepancyConfirmButton': 'Save what I added',
    'sleepRoutineReportTitle': "Today's Progress",
    'sleepRoutineReportCloseButton': 'Close',
    'sleepRoutineReportNoEvidence': 'Not enough data for today yet',
    'sleepRoutineReportTaskSuccessLabel': 'Task Success',
    'sleepRoutineCommand': 'Time for your pre-sleep routine',
    'loginTitle': 'Welcome',
    'loginSubtitle': 'Save your data to the cloud — restore on reinstall',
    'loginGoogleButton': 'Sign in with Google',
    'loginEmailButton': 'Sign in with email account',
    'loginEmailCreate': 'Create a new account',
    'loginEmailAddress': 'Email address',
    'loginEmailPassword': 'Password',
    'loginEmailInvalid': 'The email account operation failed.',
    'loginGoogleFailed': 'Google sign-in failed. Try again or skip.',
    'cancel': 'Cancel',
    'loginFirstUserButton': "I'm a first-time user",
    'loginSkipButton': 'Skip for Now',
    'loginSkipSubtitle': 'Continue without linking an account',
    'loginRestoring': 'Restoring your data...',
    'loginNoCloudData': 'No saved data found in the cloud.',
    'loginRestoreSuccess': '{count} records restored.',
    'notificationsPageTitle': 'Notifications',
    'notificationsEmpty': 'No notifications in the last 6 hours',
    'settingsNotificationsRow': 'Notification History',
    'settingsNotificationsRowSubtitle': 'View your recent notifications',
  };

  static String textForCode(String code, String key) {
    if (code == 'tr') return _tr[key] ?? key;
    if (code == 'en') return _en[key] ?? key;

    // Every supported language is bundled in generatedLanguageData. Never
    // silently substitute English or Turkish: a missing entry must remain
    // visible as its key so validation catches it before release.
    return generatedLanguageData[code]?[key] ?? key;
  }

  /// The canonical set of translatable keys — English is the language
  /// every key is guaranteed to be written in first (see this file's own
  /// `_en` map), so it is the only trustworthy reference for "every
  /// generated language should have this key" checks. Picking any other
  /// language for that role (e.g. the first entry in
  /// `generatedLanguageData`, whatever that happens to be after Dart's map
  /// literal insertion order) inherits that language's own gaps as if
  /// they were the target instead of the problem.
  static Set<String> get referenceKeys => _en.keys.toSet();

  /// Kept so callers do not have to know whether a language needs loading.
  ///
  /// It used to fetch the whole string table from translate.googleapis.com
  /// on first use of any language without bundled data — an undocumented
  /// endpoint, and a network call in an app whose data-safety declaration
  /// says nothing leaves the device. Every language now resolves from the
  /// bundle. Missing entries are intentionally not replaced by another
  /// language; validation must expose them before release.
  static Future<void> ensureLanguageLoaded(String code) async {}

  static String text(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode;
    return textForCode(code, key);
  }

  /// Turns a duration-barrier task's raw minute count into a natural
  /// phrase in whatever unit actually reads naturally at that scale — the
  /// tier system in DisciplineProtocolService can now produce anything
  /// from 30 minutes up to a fixed "this month" commitment (43200
  /// minutes), and showing the user "43200 dakika" instead of "bu ay" would
  /// defeat the point of the escalation. Only TR/EN are hand-formatted here
  /// (matching the existing precedent in NotificationService's
  /// _formatBarrierDuration, which is TR/EN-only too) — every other
  /// language falls back to the English phrasing.
  static String formatAdaptiveDurationPhrase(String code, int minutes) {
    final isTr = code == 'tr';
    if (minutes >= 28 * 24 * 60) {
      return isTr ? 'bu ay' : 'this month';
    }
    if (minutes >= 24 * 60) {
      final days = (minutes / (24 * 60)).round();
      return isTr ? '$days gün' : '$days day${days == 1 ? '' : 's'}';
    }
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remaining = minutes % 60;
      if (remaining == 0) {
        return isTr ? '$hours saat' : '$hours hour${hours == 1 ? '' : 's'}';
      }
      return isTr
          ? '$hours saat $remaining dakika'
          : '$hours hour${hours == 1 ? '' : 's'} $remaining minute${remaining == 1 ? '' : 's'}';
    }
    return isTr
        ? '$minutes dakika'
        : '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  /// Resolves a [MentorMessageBuilder]-produced canonical `text` value (a
  /// [MentorMessageCodes.segmentSeparator]-joined list of segments, each
  /// either a plain code or a `CODE:param` pair) into the user's language,
  /// joining resolved segments with a blank line the same way the old
  /// hardcoded-Turkish builder used to join its sentences with `\n\n`.
  static String localizeMentorMessage(String code, String rawText) {
    return rawText
        .split(MentorMessageCodes.segmentSeparator)
        .map((segment) => _localizeMentorSegment(code, segment))
        .join('\n\n');
  }

  static String _localizeMentorSegment(String code, String segment) {
    final colonIndex = segment.indexOf(':');
    final prefix = colonIndex == -1
        ? segment
        : segment.substring(0, colonIndex);
    final param = colonIndex == -1 ? null : segment.substring(colonIndex + 1);

    switch (prefix) {
      case MentorMessageCodes.dailyCoachWithHour:
        return textForCode(
          code,
          'mentorDailyCoachHourTemplate',
        ).replaceAll('{hour}', param ?? '');
      case MentorMessageCodes.dailyCoachNoHour:
        return textForCode(code, 'mentorDailyCoachNoHour');
      case MentorMessageCodes.dailySupportive:
        return textForCode(code, 'mentorDailySupportive');
      case MentorMessageCodes.dailyNeutralWithHour:
        return textForCode(
          code,
          'mentorDailyNeutralHourTemplate',
        ).replaceAll('{hour}', param ?? '');
      case MentorMessageCodes.dailyNeutralNoHour:
        return textForCode(code, 'mentorDailyNeutralNoHour');
      case MentorMessageCodes.breathImprovingNote:
        return textForCode(code, 'mentorBreathImprovingNote');
      case MentorMessageCodes.weeklyCoachPrefix:
        return textForCode(
          code,
          'mentorWeeklyCoachTemplate',
        ).replaceAll('{count}', param ?? '');
      case MentorMessageCodes.weeklySupportive:
        return textForCode(code, 'mentorWeeklySupportive');
      case MentorMessageCodes.weeklyNeutralPrefix:
        return textForCode(code, 'mentorWeeklyNeutralTemplate').replaceAll(
          '{level}',
          localizeCanonicalTextForCode(code, param ?? ''),
        );
      case MentorMessageCodes.histImprovedPrefix:
        return textForCode(
          code,
          'mentorHistImprovedTemplate',
        ).replaceAll('{daypart}', _dayPartLabel(code, param));
      case MentorMessageCodes.histWorseningPrefix:
        return textForCode(
          code,
          'mentorHistWorseningTemplate',
        ).replaceAll('{daypart}', _dayPartLabel(code, param));
      case MentorMessageCodes.histSimilarPrefix:
        return textForCode(
          code,
          'mentorHistSimilarTemplate',
        ).replaceAll('{daypart}', _dayPartLabel(code, param));
      case MentorMessageCodes.reframeSuspiciousWithTitle:
        return textForCode(
          code,
          'mentorReframeSuspiciousWithTitleTemplate',
        ).replaceAll('{title}', param ?? '');
      case MentorMessageCodes.reframeSuspiciousNoTitle:
        return textForCode(code, 'mentorReframeSuspiciousNoTitle');
      case MentorMessageCodes.reframeWillpower:
        return textForCode(code, 'mentorReframeWillpower');
      case MentorMessageCodes.reframeDeferredStart:
        return textForCode(code, 'mentorReframeDeferredStart');
      case MentorMessageCodes.reframeFollowupDeferred:
        return textForCode(code, 'mentorReframeFollowupDeferred');
      case MentorMessageCodes.reframeDurationBarrier:
        return textForCode(code, 'mentorReframeDurationBarrier');
      case MentorMessageCodes.followUpStrugglingQuestion:
        return textForCode(code, 'mentorFollowupStrugglingQ');
      case MentorMessageCodes.followUpAckReduceTasks:
        return textForCode(code, 'mentorFollowupAckReduceTasks');
      case MentorMessageCodes.followUpAckEaseBarrier:
        return textForCode(code, 'mentorFollowupAckEaseBarrier');
      case MentorMessageCodes.followUpAckJustTalking:
        return textForCode(code, 'mentorFollowupAckJustTalking');
      default:
        return segment;
    }
  }

  static String _dayPartLabel(String code, String? dayPart) {
    switch (dayPart) {
      case 'morning':
        return textForCode(code, 'mentorDayPartMorning');
      case 'afternoon':
        return textForCode(code, 'mentorDayPartAfternoon');
      case 'evening':
        return textForCode(code, 'mentorDayPartEvening');
      case 'night':
        return textForCode(code, 'mentorDayPartNight');
      default:
        return dayPart ?? '';
    }
  }

  /// Resolves a [MentorMessageBuilder] quick-reply or reframed-violation
  /// `userReply` code (e.g. [MentorMessageCodes.quickReplyOk]) into the
  /// user's language. Falls back to returning the code itself for anything
  /// unrecognized, so a stale/legacy literal reply still displays as-is.
  static String localizeMentorReplyCode(String code, String replyCode) {
    switch (replyCode) {
      case MentorMessageCodes.quickReplyOk:
        return textForCode(code, 'quickReplyOk');
      case MentorMessageCodes.quickReplyStruggling:
        return textForCode(code, 'quickReplyStruggling');
      case MentorMessageCodes.quickReplyNoTalk:
        return textForCode(code, 'quickReplyNoTalk');
      case MentorMessageCodes.quickReplyFillWeeklySurvey:
        return textForCode(code, 'quickReplyFillWeeklySurvey');
      case MentorMessageCodes.quickReplyLater:
        return textForCode(code, 'quickReplyLater');
      case MentorMessageCodes.quickReplyThanks:
        return textForCode(code, 'quickReplyThanks');
      case MentorMessageCodes.quickReplyLetsTalk:
        return textForCode(code, 'quickReplyLetsTalk');
      case MentorMessageCodes.quickReplyOkAck:
        return textForCode(code, 'quickReplyOkAck');
      case MentorMessageCodes.quickReplyReduceTasks:
        return textForCode(code, 'quickReplyReduceTasks');
      case MentorMessageCodes.quickReplyEaseBarrier:
        return textForCode(code, 'quickReplyEaseBarrier');
      case MentorMessageCodes.quickReplyJustTalking:
        return textForCode(code, 'quickReplyJustTalking');
      default:
        return replyCode;
    }
  }

  static String localizeCanonicalTextForCode(String code, String value) {
    final normalized = value.trim();

    var toneSuffix = '';
    var core = normalized;
    if (core.endsWith(MentorCommandCodes.toneSoftSuffix)) {
      toneSuffix = 'soft';
      core = core.substring(
        0,
        core.length - MentorCommandCodes.toneSoftSuffix.length,
      );
    } else if (core.endsWith(MentorCommandCodes.toneActiveSuffix)) {
      toneSuffix = 'active';
      core = core.substring(
        0,
        core.length - MentorCommandCodes.toneActiveSuffix.length,
      );
    }

    final resolved = _localizeCanonicalCore(code, core);
    return toneSuffix.isEmpty
        ? resolved
        : _applyToneVariant(code, resolved, toneSuffix);
  }

  static String _localizeCanonicalCore(String code, String normalized) {
    final riskDaypart = RegExp(
      r'^RISKDAYPART_(HIGH|MEDIUM|LOW)_(MORNING|DAY|EVENING|NIGHT)_(0|1)$',
    ).firstMatch(normalized);
    if (riskDaypart != null) {
      final key =
          'coachRiskDaypart_'
          '${riskDaypart.group(1)!.toLowerCase()}_'
          '${riskDaypart.group(2)!.toLowerCase()}_'
          '${riskDaypart.group(3)}';
      return textForCode(code, key);
    }

    final adaptiveWindow = RegExp(
      r'^ADAPTIVE_NO_SMOKE_WINDOW:(\d+):(.+)$',
    ).firstMatch(normalized);
    if (adaptiveWindow != null) {
      final minutes = int.tryParse(adaptiveWindow.group(1) ?? '15') ?? 15;
      final window = adaptiveWindow.group(2)!;
      final template = textForCode(code, 'adaptiveNoSmokeWindowTemplate');
      return template
          .replaceAll('{duration}', formatAdaptiveDurationPhrase(code, minutes))
          .replaceAll('{window}', window);
    }

    final prepWindow = RegExp(r'^PREP_WINDOW:(.+)$').firstMatch(normalized);
    if (prepWindow != null) {
      final template = textForCode(code, 'coachPrepWindowTemplate');
      return template.replaceAll('{window}', prepWindow.group(1)!);
    }

    final triggerDelay = RegExp(r'^TRIGGER_DELAY:(.+)$').firstMatch(normalized);
    if (triggerDelay != null) {
      final localizedTrigger = localizeCanonicalTextForCode(
        code,
        triggerDelay.group(1)!,
      );
      final template = textForCode(code, 'coachTriggerDelayTemplate');
      return template.replaceAll('{trigger}', localizedTrigger);
    }

    final focusRiskHour = RegExp(
      r'^FOCUS_RISK_HOUR:(.+)$',
    ).firstMatch(normalized);
    if (focusRiskHour != null) {
      final template = textForCode(code, 'coachFocusRiskHourTemplate');
      return template.replaceAll('{hour}', focusRiskHour.group(1)!);
    }

    final weeklyTarget = RegExp(
      r'^WEEKLY_TARGET:(\d+)$',
    ).firstMatch(normalized);
    if (weeklyTarget != null) {
      final template = textForCode(code, 'coachWeeklyTargetTemplate');
      return template.replaceAll('{percent}', weeklyTarget.group(1)!);
    }

    final hintWindow = RegExp(r'^HINT_WINDOW:(.+)$').firstMatch(normalized);
    if (hintWindow != null) {
      final template = textForCode(code, 'coachHintWindowTemplate');
      return template.replaceAll('{window}', hintWindow.group(1)!);
    }

    final hintTrigger = RegExp(r'^HINT_TRIGGER:(.+)$').firstMatch(normalized);
    if (hintTrigger != null) {
      final localizedTrigger = localizeCanonicalTextForCode(
        code,
        hintTrigger.group(1)!,
      );
      final template = textForCode(code, 'coachHintTriggerTemplate');
      return template.replaceAll('{trigger}', localizedTrigger);
    }

    final delayFirstCigarette = RegExp(
      r'^DELAY_FIRST_CIGARETTE:(\d+)$',
    ).firstMatch(normalized);
    if (delayFirstCigarette != null) {
      final minutes = int.tryParse(delayFirstCigarette.group(1) ?? '10') ?? 10;
      final template = textForCode(code, 'delayFirstCigaretteTemplate');
      return template.replaceAll(
        '{duration}',
        formatAdaptiveDurationPhrase(code, minutes),
      );
    }

    final riskExplanationLine = RegExp(
      r'^(RISK_BASE|RISK_BEHAVIOR_DELTA|RISK_PERSONALIZED_DELTA|'
      r'RISK_PROFILE_DELTA|RISK_TASK_DELTA|RISK_FINAL):([+-]?\d+)$',
    ).firstMatch(normalized);
    if (riskExplanationLine != null) {
      final prefix = riskExplanationLine.group(1)!;
      final score = riskExplanationLine.group(2)!;
      final templateKey = switch (prefix) {
        RiskExplanationCodes.baseScorePrefix => 'riskExplanationBaseTemplate',
        RiskExplanationCodes.behaviorDeltaPrefix =>
          'riskExplanationBehaviorDeltaTemplate',
        RiskExplanationCodes.personalizedDeltaPrefix =>
          'riskExplanationPersonalizedDeltaTemplate',
        RiskExplanationCodes.profileDeltaPrefix =>
          'riskExplanationProfileDeltaTemplate',
        RiskExplanationCodes.taskDeltaPrefix =>
          'riskExplanationTaskDeltaTemplate',
        RiskExplanationCodes.finalScorePrefix => 'riskExplanationFinalTemplate',
        _ => 'riskExplanationBaseTemplate',
      };
      final template = textForCode(code, templateKey);
      return template.replaceAll('{score}', score);
    }

    switch (normalized) {
      case MentorCommandCodes.reductionTier75:
        return textForCode(code, 'coachReductionTier75');
      case MentorCommandCodes.reductionTier60:
        return textForCode(code, 'coachReductionTier60');
      case MentorCommandCodes.reductionTier40:
        return textForCode(code, 'coachReductionTier40');
      case MentorCommandCodes.reductionTierBase:
        return textForCode(code, 'coachReductionTierBase');
      case MentorCommandCodes.breathDeclining:
        return textForCode(code, 'coachBreathDeclining');
      case MentorCommandCodes.breathImproving:
        return textForCode(code, 'coachBreathImproving');
      case MentorCommandCodes.breathStable:
        return textForCode(code, 'coachBreathStable');
      case MentorCommandCodes.trackReduceToday:
        return textForCode(code, 'coachTrackReduceToday');
      case MentorCommandCodes.trackCompleteThree:
        return textForCode(code, 'coachTrackCompleteThree');
      case MentorCommandCodes.triggerStress:
        return textForCode(code, 'coachTriggerStressCommand');
      case MentorCommandCodes.triggerCoffee:
        return textForCode(code, 'coachTriggerCoffeeCommand');
      case MentorCommandCodes.triggerAlcohol:
        return textForCode(code, 'coachTriggerAlcoholCommand');
      case MentorCommandCodes.triggerSocial:
        return textForCode(code, 'coachTriggerSocialCommand');
      case MentorCommandCodes.crisisProtocol:
        return textForCode(code, 'coachCrisisProtocol');
      case MentorCommandCodes.supportSingleGoal:
        return textForCode(code, 'coachSupportSingleGoal');
      case MentorCommandCodes.hintHighRisk:
        return textForCode(code, 'coachHintHighRisk');
      case MentorCommandCodes.hintMedRisk:
        return textForCode(code, 'coachHintMedRisk');
      case MentorCommandCodes.hintLowRisk:
        return textForCode(code, 'coachHintLowRisk');
    }

    final adaptiveCanonical = RegExp(
      r'^ADAPTIVE_NO_SMOKE:(\d+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (adaptiveCanonical != null) {
      final minutes = int.tryParse(adaptiveCanonical.group(1) ?? '15') ?? 15;
      final template = textForCode(code, 'adaptiveNoSmokeTaskTemplate');
      return template.replaceAll(
        '{duration}',
        formatAdaptiveDurationPhrase(code, minutes),
      );
    }

    if (normalized == 'ADAPTIVE_CHECK_IN') {
      return textForCode(code, 'checkInPrompt');
    }

    if (normalized == 'SLEEP_ROUTINE') {
      return textForCode(code, 'sleepRoutineCommand');
    }

    final adaptiveLegacyTr = RegExp(
      r'^Onumuzdeki\s+(\d+)\s+dakika\s+boyunca\s+sigara\s+icmeyin\.?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (adaptiveLegacyTr != null) {
      final minutes = int.tryParse(adaptiveLegacyTr.group(1) ?? '15') ?? 15;
      final template = textForCode(code, 'adaptiveNoSmokeTaskTemplate');
      return template.replaceAll(
        '{duration}',
        formatAdaptiveDurationPhrase(code, minutes),
      );
    }

    switch (normalized) {
      case 'Evet':
        return textForCode(code, 'yes');
      case 'Hayır':
      case 'Hayir':
        return textForCode(code, 'no');
      case '2 adet':
        return textForCode(code, 'twoCig');
      case '3 adet':
        return textForCode(code, 'threeCig');
      case '4 adet':
        return textForCode(code, 'fourCig');
      case '5+ adet':
        return textForCode(code, 'fivePlusCig');
      case '1 paketten az':
        return textForCode(code, 'lessThanOnePack');
      case '1 paket':
        return textForCode(code, 'onePack');
      case '2 paket':
        return textForCode(code, 'twoPack');
      case '3 paket':
        return textForCode(code, 'threePack');
      case '3+ paket':
        return textForCode(code, 'threePlusPack');
      case '4 paket':
        return textForCode(code, 'fourPack');
      case '5 paket':
        return textForCode(code, 'fivePack');
      case '6 paket':
        return textForCode(code, 'sixPack');
      case '7+ paket':
        return textForCode(code, 'sevenPlusPack');
      case 'Kahve':
        return textForCode(code, 'triggerCoffee');
      case 'Yemek Sonrasi':
        return textForCode(code, 'triggerMeal');
      case 'Arac':
        return textForCode(code, 'triggerDriving');
      case 'Stres':
        return textForCode(code, 'triggerStress');
      case 'Telefon':
        return textForCode(code, 'triggerPhone');
      case 'Sosyal Ortam':
        return textForCode(code, 'triggerSocial');
      case 'Alkol':
        return textForCode(code, 'triggerAlcohol');
      case 'Belirtilmedi':
        return textForCode(code, 'notSpecified');
      case 'unknown':
        return textForCode(code, 'unknownValue');
      case 'Ayni':
        return textForCode(code, 'weekendPatternSame');
      case 'Farketmez':
        return textForCode(code, 'durationBarrierNeutral');
      case 'Orta':
        return textForCode(code, 'stressMedium');
      case 'Sağlık':
      case 'Saglik':
        return textForCode(code, 'quitHealth');
      case 'İyi':
        return textForCode(code, 'good');
      case 'Kötü':
      case 'Kotu':
        return textForCode(code, 'bad');
      case 'KRİTİK':
      case 'KRITIK':
      case 'critical':
        return textForCode(code, 'riskCritical');
      case 'YÜKSEK':
      case 'YUKSEK':
      case 'high':
        return textForCode(code, 'riskHigh');
      case 'ORTA':
      case 'medium':
        return textForCode(code, 'riskMedium');
      case 'DÜŞÜK':
      case 'DUSUK':
      case 'low':
        return textForCode(code, 'riskLow');
      case 'Ilk sigarayi 10 dakika ertele':
        return textForCode(code, 'taskDelayFirstSmoke10');
      case 'Bir bardak su ic':
        return textForCode(code, 'taskDrinkWater');
      case '2 dakikalik nefes egzersizi yap':
        return textForCode(code, 'taskBreathExercise2');
      case '10 dakika sigarasiz kal':
        return textForCode(code, 'taskNoSmoke10');
      case 'Kriz anini not et':
        return textForCode(code, 'taskNoteCraving');
      case 'Ilk sigarayi 25 dakika ertele':
        return textForCode(code, 'taskDelayFirstSmoke25');
      case 'Bugun bir sigarayi atla':
        return textForCode(code, 'taskSkipOneCig');
      case '30 dakika sigarasiz kal':
        return textForCode(code, 'taskNoSmoke30');
      case 'Riskli saatte seker sakiz kullan':
        return textForCode(code, 'taskUseGumAtRiskHour');
      case '45 dakika sigarasiz kal':
        return textForCode(code, 'taskNoSmoke45');
      case '60 dakika sigarasiz kal':
        return textForCode(code, 'taskNoSmoke60');
      case 'Bugun 2 sigara eksik ic':
        return textForCode(code, 'taskSmokeTwoLess');
      case '90 dakika sigarasiz kal':
        return textForCode(code, 'taskNoSmoke90');
      case '120 dakika sigarasiz kal':
        return textForCode(code, 'taskNoSmoke120');
      case 'Aksam saatinde destek kisisiyle iletisim kur':
        return textForCode(code, 'taskContactSupportEvening');
      case '1 gun sigarasiz kalma gorevi: bugun tum kriz anlarinda sigarayi erteleyin.':
        return textForCode(code, 'taskPlanOneDayDelayAllCravings');
      case '1 gun sigarasiz kalma gorevi: ilk sigarayi en az 90 dakika erteleyin.':
        return textForCode(code, 'taskPlanOneDayDelayFirst90');
      case '2 gun sigarasiz kalma gorevi: 48 saat boyunca tetikleyicilerde sigarayi erteleyin.':
        return textForCode(code, 'taskPlanTwoDaysDelayTriggers');
      case '2 gun sigarasiz kalma plani: kriz aninda 10 derin nefes + su uygulayin.':
        return textForCode(code, 'taskPlanTwoDaysBreathAndWater');
      case '1 hafta sigarasiz kalma hedefi: 7 gun boyunca tum gorevleri tamamlayin.':
        return textForCode(code, 'taskPlanOneWeekCompleteAll');
    }

    final parts = normalized.split(' - ');
    if (parts.length == 2) {
      return '${localizeCanonicalTextForCode(code, parts[0])} - ${localizeCanonicalTextForCode(code, parts[1])}';
    }

    return normalized;
  }

  /// Softens or sharpens a coach command's tone after translation -- the
  /// runtime-side counterpart of MentorEngine's old `_softenCommandTone`/
  /// `_activateCommandTone` word-replacement, which had to move here once
  /// the engine stopped producing language-specific sentences.
  ///
  /// Only TR/EN get a real wording change, same precedent as
  /// formatAdaptiveDurationPhrase (see its comment): every other language
  /// silently keeps the neutral phrasing rather than getting a half-correct
  /// tone transform.
  static String _applyToneVariant(String code, String text, String tone) {
    if (code != 'tr' && code != 'en') {
      return text;
    }
    if (tone == 'soft') {
      return code == 'tr' ? _softenTr(text) : _softenEn(text);
    }
    if (tone == 'active') {
      return code == 'tr' ? _activateTr(text) : _activateEn(text);
    }
    return text;
  }

  static String _softenTr(String text) {
    var result = text
        .replaceAll('mutlaka ', '')
        .replaceAll('en az ', '')
        .replaceAll('tamamla', 'dene')
        .replaceAll('uygula', 'dene')
        .replaceAll('kapat', 'azalt');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (result.endsWith('!')) {
      result = '${result.substring(0, result.length - 1)}.';
    }
    return result;
  }

  static String _activateTr(String text) {
    var result = text.replaceAll('dene', 'uygula');
    if (!result.endsWith('!')) {
      if (result.endsWith('.')) {
        result = '${result.substring(0, result.length - 1)}!';
      } else {
        result = '$result!';
      }
    }
    return result;
  }

  static String _softenEn(String text) {
    var result = text
        .replaceAll('be sure to ', '')
        .replaceAll('at least ', '')
        .replaceAll('complete', 'try')
        .replaceAll('apply', 'try')
        .replaceAll('close', 'ease up on');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (result.endsWith('!')) {
      result = '${result.substring(0, result.length - 1)}.';
    }
    return result;
  }

  static String _activateEn(String text) {
    var result = text.replaceAll('try', 'apply');
    if (!result.endsWith('!')) {
      if (result.endsWith('.')) {
        result = '${result.substring(0, result.length - 1)}!';
      } else {
        result = '$result!';
      }
    }
    return result;
  }

  static String localizeCanonicalText(BuildContext context, String value) {
    final code = Localizations.localeOf(context).languageCode;
    return localizeCanonicalTextForCode(code, value);
  }
}

extension AppTextsX on BuildContext {
  String t(String key) => AppTexts.text(this, key);
}
