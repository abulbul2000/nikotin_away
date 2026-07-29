import 'package:flutter/material.dart';

import 'generated_language_data.dart';

class AppTexts {
  // Turkish - Full translation
  static const Map<String, String> _tr = {
    'appName': 'NIKOTIN AWAY',
    'selectLanguage': 'Dil Sec',
    'continue': 'Devam Et',
    'yes': 'Evet',
    'no': 'Hayır',
    'save': 'Kaydet',
    'home': 'Ana Sayfa',
    'weeklySurvey': 'Haftalık Anket',
    'riskAnalysis': 'Risk Analizi',
    'retry': 'Tekrar dene',
    'iBreathed': 'Nefes Aldim',
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
    'smokeFreeDaysWidgetLabel': 'gun sigarasiz',
    'riskScore': 'Risk skoru',
    'initialSurvey': 'Başlangıç Anketi',
    'smokingInfo': 'Sigara Bilgileri',
    'lifeRoutine': 'Yaşam Düzeni',
    'professionLabel': 'Meslek',
    'healthStatus': 'Sağlık Durumu',
    'triggerTitle': 'Sigara Tetikleyicileri',
    'stressTitle': 'Stres Seviyesi',
    'quitReasonTitle': 'Bırakma Sebebi',
    'heartDisease': 'Kalp Hastaligi',
    'otherHealthCondition': 'Diger',
    'otherHealthConditionHint': 'Hastaliginizi yazin',
    'usesMedicationQuestion': 'Duzenli ilac kullaniyorum',
    'addMedicationButton': 'Ilac ekle',
    'medicationNameHint': 'Ilac adi',
    'addMedicationTimeButton': 'Saat ekle',
    'medicationsSettingsRow': 'Ilaclarim',
    'medicationsSettingsRowSubtitle': 'Ilac ekle, duzenle veya sil',
    'medicationsPageTitle': 'Ilaclarim',
    'medicationsEmptyState': 'Henuz ilac eklemediniz.',
    'medicationDeleteConfirmTitle': 'Ilaci sil',
    'medicationDeleteConfirmMessage': 'Bu ilaci ve hatirlatmalarini silmek istediginize emin misiniz?',
    'medicationSavedConfirmation': 'Ilac kaydedildi',
    'medicationReminderTitle': 'Ilac hatirlatmasi',
    'medicationReminderBody': '{name} ilacinizi alma vakti geldi.',
    'overlayPermissionTitle': 'Gorev ekranini goster',
    'overlayPermissionMessage': 'Gorev ekraninin, telefon kilitli olmasa bile diger uygulamalarin ustunde acilabilmesi icin "diger uygulamalarin ustunde goster" iznine ihtiyacimiz var. Simdi ayar ekranini acalim mi?',
    'smokedLogButtonRow': 'Sigara Ictim butonu',
    'smokedLogButtonTitle': 'Sigara Ictim Butonu',
    'smokedLogButtonDescription':
        'Ekranda kucuk, seffaf bir buton belirir. Sigara ictiginizde 3 saniye basili tutun — cevresindeki halka doldugunda tik isareti cikar ve kayit alinir. Yanlislikla dokunmaniz durumunda kayit alinmaz.',
    'smokedLogButtonPurpose':
        'Uygulama boylece hangi saatlerde ve hangi yerlerde sigara icme egiliminiz oldugunu ogrenir, gorevleri tam o riskli anlara denk getirir. Konum bilgisi yalnizca daha once tanimlanmis sik gittiginiz yerlerle eslestirilir; adres veya hareket gecmisiniz saklanmaz. Tum kayitlar yalnizca cihazinizda tutulur.',
    'smokedLogButtonEnabled': 'Sigara Ictim butonu acildi.',
    'smokedLogButtonDisabled': 'Sigara Ictim butonu kapatildi.',
    'smokedLogButtonNeedsOverlay':
        'Bu buton icin "diger uygulamalarin ustunde goster" izni gerekiyor.',
    'smokedLogButtonNotificationTitle': 'Nikotin Away',
    'smokedLogButtonNotificationBody': 'Sigara ictiyseniz buradan kaydedin',
    'smokedLogButtonAction': 'Sigara Ictim',
    'smokedLogRecordedWithUndo': 'Sigara kaydedildi.',
    'smokedLogConsentHeading': 'Sigara Ictim butonunu acalim mi?',
    'smokedLogConsentDataTitle': 'Neler kaydedilir',
    'smokedLogConsentDataBody':
        'Sadece butona bastiginiz an ve — Konum Zekasi aciksa — o an sik gittiginiz yerlerden hangisine yakin oldugunuz. Adresiniz, koordinatlariniz veya hareket gecmisiniz kaydedilmez. Konum alinamazsa sigara yine kaydedilir, yer bilgisi bos kalir.',
    'smokedLogConsentStorageTitle': 'Nerede tutulur',
    'smokedLogConsentStorageBody':
        'Yalnizca bu cihazda. Hicbir kayit disari gonderilmez. Butonu ve gecmis kayitlari istediginiz zaman Ayarlar bolumunden kaldirabilirsiniz.',
    'smokedLogConsentAccept': 'Butonu ac',
    'smokedLogConsentDecline': 'Simdilik istemiyorum',
    'permissionSetupTitle': 'Gerekli izinler',
    'permissionSetupIntro':
        'Gorevlerin dogru zamanda ve gorunur sekilde ulasabilmesi icin asagidaki izinler gerekiyor. Ayarlardan donunce durum kendiliginden guncellenir.',
    'permissionOverlayDescription':
        'Gorev ekraninin baska uygulamalarin ustunde acilabilmesi icin gerekli. Verilmezse gorev yine gelir, ama sadece bildirim olarak.',
    'permissionOemDescription':
        'Bu telefonda bazi bildirim ayarlari ureticinin kendi izin ekraninda duruyor. Oradan "arka planda calisma" ve "kilit ekraninda goster" seceneklerini acabilirsiniz.',
    'permissionSetupContinueAnyway': 'Simdilik devam et',
    'permissionSetupOptionalNote':
        'Izinleri daha sonra Ayarlar bolumunden de duzenleyebilirsiniz.',
    'packsPerDayQuestion': 'Gunde kac paket sigara iciyorsunuz?',
    'firstCigaretteWhen': 'Ilk sigarayi uyandiktan ne kadar sure sonra iciyorsunuz?',
    'firstCigarette10to30': 'Uyandiktan 10-30 dk sonra',
    'maxSmokeFreeDuration': 'Sigarasiz kalabildigin maksimum sure',
    'smokeFree30to60': '30-60 dakika',
    'smokingYears': 'Kac yildir iciyorsun?',
    'cigarettesPerPackLabel': 'Bir pakette kac sigara var?',
    'triggerCoffee': 'Kahve',
    'triggerMeal': 'Yemek sonrasi',
    'triggerDriving': 'Arac kullanirken',
    'triggerStress': 'Stresliyken',
    'triggerPhone': 'Telefonda',
    'triggerSocial': 'Sosyal ortam',
    'triggerAlcohol': 'Alkol',
    'stressMedium': 'Orta',
    'quitReason': 'Birakma sebebi',
    'quitHealth': 'Sagligim icin',
    'riskCritical': 'KRİTİK',
    'riskHigh': 'YÜKSEK',
    'riskMedium': 'ORTA',
    'riskLow': 'DÜŞÜK',
    'validationNameRequired': 'Lütfen ad alanını doldurun.',
    'validationAgeRequired': 'Lütfen yaş alanını doldurun.',
    'validationGenderRequired': 'Lütfen cinsiyet seçin.',
    'hello': 'Merhaba',
    'weeklySavePrompt': 'Bu haftaki durumunuzu kaydedin.',
    'weeklySurveyPromptAsk': 'Haftalik anketi simdi doldurmak ister misiniz?',
    'shareProgressTitle': 'Ilerlemeni paylas',
    'shareProgressMessage':
      'Haftalik degerlendirmeni tamamladin. Ilerlemeni arkadaslarinla paylasmak ister misin?',
    'shareProgressSkip': 'Gec',
    'shareProgressAction': 'Paylas',
    'shareProgressText':
      'Nikotin Away ile sigarayi birakma surecimi takip ediyorum. Guncel risk skorum: {score}/100 ({level}).',
    'saveErrorRetry': 'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.',
    'loadErrorRetry': 'Veriler yuklenirken bir hata olustu. Lutfen tekrar deneyin.',
    'smokeFreeStreak': 'Sigara İçmeme Serisi',
    'reductionCardTitle': 'Azaltma İlerlemen',
    'reductionStreakLabel': 'Hedefi tutturduğun gün',
    'reductionAvoidedLabel': 'İçmediğin sigara',
    'reductionIntervalLabel': 'Sigara arası süre',
    'reductionTargetToday': 'Bugünkü hedef: en fazla {target} sigara',
    'reductionLoggedToday': 'Bugün {count} kayıt girdin',
    'reductionNoDataTitle': 'Henüz ölçecek bir şey yok',
    'reductionNoDataBody':
        'Sigara içtiğinde butona bas ya da görevleri yanıtla — ilerlemeni '
        'ancak gerçek kayıtlardan çıkarabiliriz.',
    'reductionIntervalDetail': 'Eskiden {natural} dk, şimdi {barrier} dk',
    'reductionIntervalGain': '%{percent} daha uzun',
    'reductionBaselineNote': 'Başlangıçta günde {baseline} sigara içiyordun',
    'healthMetrics': 'Sağlık Metrikleri',
    'noBreathTestsYet': 'Henüz nefes testi kaydı yok.',
    'longitudinalAnalysis': 'Zaman Serisine Dayalı Analiz',
    'statistics': 'İstatistikler',
    'recentTests': 'Son Testler',
    'exportComingSoon': 'PDF dışa aktarma yakında geliyor.',
    'exportPDF': 'PDF Olarak Dışa Aktar',
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
      '1. Dik oturun ve rahatlayın.\n2. Daireye dokunup burnunuzdan derin bir nefes alın, 2 saniye tutun.\n3. Nefesinizi tek seferde, kontrollü şekilde verin.\n4. Verme işlemi bitince daireye tekrar dokunun.\n\n3 deneme yapılacak, en iyi skor kaydedilir.',
    'breathExerciseDisclaimer':
      'Bu bir tibbi tani araci degildir; farkindalik ve rahatlama icin basit bir nefes egzersizidir.',
    'micRationaleTitle': 'Mikrofon izni',
    'micRationaleMessage':
      'Nefes verme suresini otomatik olcmek icin mikrofonu kullanabiliriz. Ses hicbir zaman kaydedilmez veya saklanmaz; yalnizca anlik ses seviyesi olculur. Izin vermezsen testi elle (dokunarak) bitirebilirsin.',
    'restingLabel': 'Dinlenme',
    'secondsLeftLabel': 'saniye kaldi',
    'tapCircleToFinish': 'Bitirince daireye dokunun',
    'breathListeningHint': 'Dinleniyor... nefesinizi verin, otomatik algılanacak',
    'breathStepSitRelax': 'Dik oturun ve rahatlayın.',
    'breathStepDeepBreath': 'Derin bir nefes alın.',
    'breathStepHold': '5 saniye nefesinizi tutun ve başlata basın.',
    'breathStepExhale':
      'Nefesinizi mikrofona doğru güçlüce ve tamamen bitene kadar üfleyin.',
    'breathStepExhaleFinishHint': 'Nefesiniz bitince tamama basın.',
    'breathStepOkAction': 'Tamam',
    'breathStepPressOkVoiceSuffix': 'Tamama basın.',
    'breathAutoNextAttemptInstruction':
      'Dik oturun ve rahatlayın. Derin bir nefes alın. Beş saniye tutun. Sonra nefesinizi mikrofona doğru güçlüce ve tamamen bitene kadar üfleyin. Nefesiniz bitince tamama basın.',
    'disciplineDisclosureTitle': 'Nasil destek oluyoruz?',
    'disciplineDisclosureMessage':
      'Nikotin Away, seni sigarayi birakma surecinde desteklemek icin bazı arka plan mekanizmalari kullanir:\n\n'
      '- Bir gorev hatırlatmasina zamaninda yanit vermezsen, bunu cihazinda bir uyum kaydi olarak not ederiz.\n'
      '- Aktif bir gorev sirasinda, telefon hareketi ve kullanim oruntülerinden (hareket sensorleri ve mikrofon araciligiyla) olasi riskli anlari tahmin etmeye calisiriz. Ses kaydedilmez veya saklanmaz; yalnizca ortam ses seviyesi olculur.\n'
      '- Bazi gorev hatirlatmalari dikkatini cekmek icin tam ekran uyari olarak gorunebilir.\n'
      '- Gorevlendirme bildirimleri seni gercek bir telefon gorusmesi sirasinda rahatsiz etmesin diye, o an gorusme yapip yapmadigini kontrol ederiz; icerigi veya numarayi hicbir zaman okumayiz.\n\n'
      'Bu veriler varsayilan olarak yalnizca cihazinda saklanir ve seni desteklemek disinda bir amacla kullanilmaz. Ayarlar > Bulut Yedekleme uzerinden kendi belirledigin bir sifreyle istege bagli, sifreli bir yedekleme acabilirsin; bu sifreyi biz de goremeyiz, sadece sen bilirsin. Devam ederek bunu onaylamis olursun; mikrofon, hareket ve telefon durumu izinlerini bir sonraki adimda ayrica onaylayabilir ya da reddedebilirsin.',
    'disciplineDisclosureAcknowledge': 'Anladim, devam et',
    'cravingSosButton': 'Krizdeyim',
    'surveyDraftFoundTitle': 'Kaldigin yerden devam et',
    'surveyDraftFoundMessage':
      'Daha once yarım bıraktıgın bir anket bulduk. Kaldıgın yerden devam etmek ister misin?',
    'surveyDraftResume': 'Devam et',
    'surveyDraftDiscard': 'Bastan basla',
    'breathAttemptImplausible':
      'Bu deneme gecerli gorunmuyor (cok kisa ya da cok uzun). Lutfen tekrar deneyin.',
    'breathAttemptDiscardedBackgrounded':
      'Uygulama arka plana alindigi icin bu deneme iptal edildi. Lutfen tekrar deneyin.',
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
    'asthma': 'Astim',
    'chainSmokingAsk': 'Arka arkaya sigara icer misin?',
    'chainSmokingCountAsk': 'Genelde kac adet arka arkaya iciyorsun?',
    'chainSmokingSituation': 'Ardisik icim durumu',
    'continueWithoutPermission': 'Izinsiz devam et',
    'copd': 'KOAH',
    'diabetes': 'Diyabet',
    'firstCigarette0to5': 'Uyandiktan 0-5 dk sonra',
    'firstCigarette5to10': 'Uyandiktan 5-10 dk sonra',
    'firstCigarette30to60': 'Uyandiktan 30-60 dk sonra',
    'firstCigarette60plus': 'Uyandiktan 60+ dk sonra',
    'fivePack': '5 paket',
    'fivePlusCig': '5+ adet',
    'fourCig': '4 adet',
    'fourPack': '4 paket',
    'hypertension': 'Hipertansiyon',
    'initialRecordTitle': 'Baslangic Kaydi',
    'lessThanOnePack': '1 paketten az',
    'notificationPermissionRequired':
      'Bildirim izni olmadan hatirlaticilar calismayabilir.',
    'onePack': '1 paket',
    'onlyBreaks': 'Sadece mola saatlerinde',
    'openAlarmReminderSettings': 'Alarm/Hatirlatici Ayarlari',
    'openSettings': 'Ayarlari Ac',
    'packsApproxQuestion': 'Yaklasik kac paket?',
    'permissionsRetryMessage':
      'Gerekli izinler olmadan uygulama ozellikleri sinirli calisir.',
    'permissionsRetryTitle': 'Izinleri tekrar dene',
    'professionEngineer': 'Muhendis',
    'professionFreelance': 'Serbest',
    'professionHealthcare': 'Saglik Calisani',
    'professionOfficer': 'Memur',
    'professionOther': 'Diger',
    'professionRetired': 'Emekli',
    'professionSalaried': 'Ucretli',
    'professionStudent': 'Ogrenci',
    'professionTeacher': 'Ogretmen',
    'professionTradesman': 'Esnaf',
    'professionWorker': 'Isci',
    'quitChildren': 'Cocuklarim icin',
    'quitFamily': 'Ailem icin',
    'quitMoney': 'Maddi nedenler',
    'quitPerformance': 'Performansimi artirmak',
    'sensorPermissionRecommended':
      'Daha dogru takip icin hareket/sensor izni onerilir.',
    'sevenPlusPack': '7+ paket',
    'sixPack': '6 paket',
    'sleepTime': 'Uyku saati',
    'smokeFree0to15': '0-15 dakika',
    'smokeFree15to30': '15-30 dakika',
    'smokeFree60to120': '60-120 dakika',
    'smokeFree120to240': '120-240 dakika',
    'smokeFree240plus': '240+ dakika',
    'stressHigh': 'Yuksek',
    'interventionIntensityTitle': 'Mudahale siddeti',
    'interventionIntensityHint':
      'Uygulamanin seni gun icinde ne siklikla uyarip gorevlendirecegini secer.',
    'interventionIntensityGentle': 'Nazik',
    'interventionIntensityBalanced': 'Dengeli',
    'interventionIntensityStrict': 'Siki',
    'stressLow': 'Dusuk',
    'threeCig': '3 adet',
    'threePack': '3 paket',
    'threePlusPack': '3+ paket',
    'twoCig': '2 adet',
    'twoPack': '2 paket',
    'validationChainCountRequired':
      'Lutfen ardisik icim adedini secin.',
    'validationChainHabitRequired':
      'Lutfen ardisik icim durumunu secin.',
    'validationFirstCigaretteRequired':
      'Lutfen ilk sigarayi ne zaman ictiginizi secin.',
    'validationFixHighlightedFields':
      'Lutfen isaretli alanlari duzeltin.',
    'validationSleepTimeRequired': 'Lutfen uyku saatini secin.',
    'validationSmokeYearsRange':
      'Sigara suresi 0 ile 90 yil arasinda olmalidir.',
    'validationWakeTimeRequired': 'Lutfen uyanis saatini secin.',
    'wakeTime': 'Uyanis saati',
    'workEnd': 'Mesai bitis',
    'workplaceSmoking': 'Is yerinde sigara iciliyor mu?',
    'workStart': 'Mesai baslangic',
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
    'weeklyWithdrawalHint': 'Bu hafta yaşadıklarını işaretle. Hiçbiri yoksa boş bırak.',
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
    'weeklyCoughExample':
        'Sabah kalkınca ya da gün içinde öksürüyor musun?',
    'weeklyBreathlessnessStairsExample':
        'Bir kat merdiven çıkınca durup nefeslenmen gerekiyor mu?',
    'weeklySleepImpact': 'Uykuna etkisi',
    'weeklySleepImpactExample':
        'Öksürük ya da nefes darlığı yüzünden gece uyanıyor musun?',
    'weeklyEnergyImpact': 'Enerjine etkisi',
    'weeklyEnergyImpactExample':
        'Gün içinde eskisine göre daha çabuk yoruluyor musun?',
    'mmrcPlain0': 'Nefes darlığı yaşamıyorum.',
    'mmrcPlain1': 'Sadece hızlı yürürken ya da hafif yokuşta nefesim daralıyor.',
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
    'weeklyProfileChanged': 'İlk profile göre iş/uyku/çalışma düzeni değişti mi?',
    'weeklyQuickModeInfo':
      'Hızlı mod seçili. Temel sorulara göre risk otomatik hesaplanır. İstersen Detaylı moda geçip tüm parametreleri düzenleyebilirsin.',
    'durationBarrierTitle': 'Sigara İçmeme Süresi Tercihi',
    'durationBarrierHow': 'Sigara içmeme süresini nasıl buluyorsun?',
    'durationBarrierLike': 'Beğeniyorum',
    'durationBarrierNeutral': 'Farketmez',
    'durationBarrierDislike': 'Beğenmiyorum',
    'durationBarrierOff': 'İstemiyorum',
    'durationBarrierFrequencyHow': 'Sigara içmeme süresi sıklığı nasıl olmalı?',
    'respClinicalReview': 'Klinik degerlendirme onerilir',
    'respMonitorCloser': 'Yakin izlem',
    'respStable': 'Stabil',
    'dailyBreathMandatoryTitle': 'Gunluk nefes testi gerekli',
    'dailyBreathMandatoryContent':
      'Gelisimi dogru takip etmek icin her gun en az 1 profesyonel nefes testi yapilmali. Simdi testi baslatalim.',
    'dailyBreathMandatoryStart': 'Testi Baslat',
    'weeklyMandatoryTitle': 'Haftalik anket zorunlu',
    'weeklyMandatoryContent':
      'Risk skorunun guncel kalmasi icin en az 7 gunde bir haftalik anket doldurmalisin.',
    'weeklyMandatoryGo': 'Ankete git',
    'commandSaved': 'Komut tamamlandi olarak kaydedildi.',
    'barrierStartedTitle': 'Sigara içmeme süresi başladı',
    'barrierStartedBody': 'Sigara içmeme sayacı çalışıyor.',
    'barrierStartedDuration': 'Sayaç süresi',
    'smokeFreeCounterTitle': 'Sigara içmeme sayacı',
    'smokeFreeCounterRemaining': 'Kalan sure',
    'barrierEvaluationTitle': 'Sigara içmeme süresi değerlendirme',
    'barrierEvaluationPromptNoMinutes':
      'Sigara içmeme süresi tamamlandı. Başarılı oldun mu?',
    'barrierEvaluationPromptMinutes':
      'dakikalık sigara içmeme süresi bitti. Başarılı oldun mu?',
    'barrierFail': 'Basarisiz',
    'barrierSuccess': 'Basarili',
    'barrierSavedSuccess':
      'Sigara içmeme süresi başarılı kaydedildi. Sonraki süreler buna göre ayarlanacak.',
    'barrierSavedFailure':
      'Sigara içmeme süresi başarısız kaydedildi. Sonraki süreler uyuma göre güncellenecek.',
    'commandDeferred10': 'Komut 10 dakika ertelendi.',
    'barrierDeferred10': 'Sigara içmeme süresi 10 dakika ertelendi.',
    'weeklyRiskLine': 'Haftalik anket riski',
    'respiratoryStatusLine': 'Respiratuar durum',
    'weeklyTopDriversLine': 'Haftalik ust risk etkenleri',
    'commandModeLabel': 'Komut modu',
    'advancedSectionTitle': 'Gelismis',
    'learnedWeightsLabel': 'Ogrenilen agirliklar',
    'personalCommandsTitle': 'Kisisel komutlar',
    'durationBarriersTitle': 'Sigara içmeme süreleri (ayrı çalışır)',
    'doneShort': 'Tamam',
    'defer10m': 'Ertele 10 dk',
    'commandScoreLabel': 'Komut basari puanlari',
    'categoryInsightLabel': 'Kategori basari icgorusu',
    'riskScoreExplanationTitle': 'Risk skoru aciklamasi',
    'quickMenuTitle': 'Hizli menu',
    'menuBreathTest': 'Nefes Egzersizi',
    'menuWeeklySurvey': 'Haftalik Anket',
    'menuPersonalProgress': 'Kisisel Takip',
    'menuViolationReport': 'Ihlal Raporu',
    'menuSurveyHistory': 'Anket Gecmisi',
    'menuLogSmokingNow': 'Simdi ictim',
    'menuDailyCheckIn': 'Gunluk Degerlendirme',
    'mentorCardTitle': 'Mentorunden',
    'mentorReplySentPrefix': 'Yanitin',
    'miuiPermissionTitle': 'Bir izin daha gerekiyor',
    'miuiPermissionMessage':
      'Telefonun görevlendirme ekranini kilitli ekranda da gosterebilmesi icin {brand} telefonlarda ek bir izin gerekiyor. Simdi ayar ekranini acalim mi?',
    'miuiPermissionOpen': 'Ayarlari Ac',
    'miuiPermissionSkip': 'Daha Sonra',
    'settingsTitle': 'Ayarlar',
    'settingsSectionGeneral': 'Genel',
    'settingsSectionPrivacy': 'Gizlilik & Izinler',
    'settingsSectionData': 'Veri',
    'settingsLanguageRow': 'Dil',
    'cloudBackupRow': 'Bulut Yedekleme',
    'cloudBackupRowSubtitle': 'Verilerini sifreli olarak buluta yedekle',
    'cloudRestoreRow': 'Bulut Yedeginden Geri Yukle',
    'cloudRestoreRowSubtitle': 'Daha once yedeklediginiz verileri bu cihaza geri getir',
    'cloudBackupPassphraseHint':
      'Bu sifre yaln izca sende saklanir, biz hicbir zaman goremeyiz. Sifreyi unutursan yedegini geri getiremeyiz, guvenli bir yere not al.',
    'cloudBackupPassphraseLabel': 'Sifre (en az 6 karakter)',
    'cloudBackupPassphraseTooShort': 'Sifre en az 6 karakter olmali.',
    'cloudBackupInProgress': 'Isleniyor, lutfen bekleyin...',
    'cloudBackupSuccess': 'Yedekleme tamamlandi.',
    'cloudBackupFailed': 'Yedekleme basarisiz oldu. Lutfen tekrar deneyin.',
    'cloudRestoreConfirmMessage':
      'Bu cihazdaki mevcut verilerin yerine yedekteki veriler yazilacak. Devam etmek istiyor musun?',
    'cloudRestoreSuccess': 'Geri yukleme tamamlandi. Uygulamayi yeniden baslat.',
    'cloudRestoreNotFound': 'Bu sifreyle eslesen bir yedek bulunamadi.',
    'cloudRestoreFailed': 'Geri yukleme basarisiz oldu. Sifreni kontrol et.',
    'settingsPermissionsRow': 'Izin Merkezi',
    'settingsPermissionsRowSubtitle': 'Hangi izinleri neden kullandigimizi gorun',
    'settingsResetDataRow': 'Verilerimi Sifirla',
    'settingsResetDataSubtitle': 'Tum kayitlarini kalici olarak siler',
    'settingsResetDataConfirmTitle': 'Emin misin?',
    'settingsResetDataConfirmMessage':
      'Tum sigara kayitlarin, anket sonuclarin ve ilerlemen kalici olarak silinecek. Bu islem geri alinamaz.',
    'settingsResetDataConfirmAction': 'Evet, Sil',
    'settingsResetDataDone': 'Verilerin silindi.',
    'permissionsCenterTitle': 'Izin Merkezi',
    'permissionsCenterIntro':
      'Bu izinleri neden istedigimizi ve nasil kullandigimizi asagida bulabilirsin. Hepsi opsiyoneldir, istedigin zaman kapatabilirsin.',
    'permissionStatusGranted': 'Verildi',
    'permissionStatusDenied': 'Verilmedi',
    'permissionActionRequest': 'Izin Ver',
    'permissionActionOpenSettings': 'Ayarlari Ac',
    'permissionNotificationsTitle': 'Bildirimler',
    'permissionNotificationsDescription':
      'Gorev hatirlatmalari, nefes testi ve mentorundan gelen mesajlar icin kullanilir.',
    'permissionNotificationsPurpose':
      'Neden: Sana dogru zamanda destek olabilmemiz icin gerekli.',
    'permissionMicrophoneTitle': 'Mikrofon',
    'permissionMicrophoneDescription':
      'Gunluk nefes testinde akcigerlerinin durumunu olcmek icin kullanilir.',
    'permissionMicrophonePurpose':
      'Neden: Ses sadece cihazinda islenir, kaydedilmez veya paylasilmaz.',
    'permissionActivityTitle': 'Fiziksel Aktivite',
    'permissionActivityDescription':
      'Hareketlerini anlayarak sana daha uygun zamanlarda destek onerileri sunmak ve gunluk adim sayini takip etmek icin kullanilir.',
    'permissionActivityPurpose':
      'Neden: Aktivite ve adim verilerin cihazindan disari cikmaz.',
    'permissionPhoneTitle': 'Telefon Durumu',
    'permissionPhoneDescription':
      'Sahte destek aramasinin gercek bir arama ile cakismamasi icin kullanilir.',
    'permissionPhonePurpose':
      'Neden: Arama numaralarini veya icerigini asla okumayiz.',
    'permissionExactAlarmTitle': 'Kesin Zamanlama',
    'permissionExactAlarmDescription':
      'Hatirlatmalarin ve mentor mesajlarinin tam zamaninda gelmesini saglar.',
    'permissionExactAlarmPurpose':
      'Neden: Android bu izni sistem ayarlarindan yonetir.',
    'permissionMiuiTitle': 'Xiaomi Ek Izni',
    'permissionMiuiDescription':
      'Sahte destek aramasinin kilitli ekranda da gorunebilmesi icin Xiaomi telefonlarda gereklidir.',
    'permissionMiuiPurpose':
      'Neden: MIUI, diger Android telefonlardan farkli bir izin sistemi kullanir.',
    'permissionLocationTitle': 'Konum',
    'permissionLocationDescription':
      'Sik gittigin yerleri ogrenip vardiginda kisa bir hatirlatma gostermek icin kullanilir (Konum Zekasi ozelligi, varsayilan kapali).',
    'permissionLocationPurpose':
      'Neden: Ham konum gecmisi hicbir zaman kaydedilmez. Detaylar ve acma/kapama icin dokunun.',
    'permissionBackgroundTitle': 'Arka Planda Calisma',
    'permissionBackgroundDescription':
      'Bazi telefon ureticileri pil tasarrufu icin arka plan uygulamalarini kisitlar. Bu, hatirlatmalarin, uyku/konum/adim takibinin ve destek aramalarinin zamaninda calismasini engelleyebilir.',
    'permissionBackgroundPurpose':
      'Neden: Uygulamanin pil optimizasyonundan muaf tutulmasi, arka plan ozelliklerinin guvenilir calismasini saglar.',
    'permissionBackgroundOpenSettingsAction': 'Arka Plan Ayarlarini Ac',
    'settingsCoachModeRow': 'Kocluk Modu',
    'settingsCoachModeRowSubtitle': 'Sana ne kadar sik ve ne kadar zorlayici destek olsun',
    'coachModeTitle': 'Kocluk Modu',
    'coachModeIntro':
      'Uygulamanin seni ne siklikta ve ne kadar zorlayici sekilde destekleyecegini sec. Istedigin zaman degistirebilirsin.',
    'coachModeEasyTitle': 'Kolay',
    'coachModeEasyDescription': 'Az sayida, yumusak hatirlatma. Kendi hizinda ilerlemek isteyenler icin.',
    'coachModeNormalTitle': 'Normal',
    'coachModeNormalDescription': 'Dengeli siklikta destek. Cogu kullanici icin onerilen mod.',
    'coachModeHardTitle': 'Zor',
    'coachModeHardDescription': 'Sik ve kararli hatirlatmalar. Daha fazla disiplin isteyenler icin.',
    'coachModeCustomLabel': 'Ozel',
    'coachModeCustomDescription': 'Gelismis ayarlardan kendin belirledigin bir kombinasyon.',
    'coachModeAdvancedToggle': 'Gelismis Ayarlar',
    'coachModeSavedConfirmation': 'Kocluk modu guncellendi.',
    'settingsSleepIntelligenceRow': 'Uyku Zekasi',
    'sleepIntelligenceTitle': 'Uyku Zekasi',
    'sleepIntelligenceDescription':
      'Acik oldugunda, telefonun ekran ve sarj durumunu gece boyunca birkac kez kontrol ederek uyku saatlerini tahmin etmeye calisir. Bu tahmin, risk degerlendirmeni daha dogru hale getirmek icin kullanilir.',
    'sleepIntelligencePurpose':
      'Neden: Sadece ekran acik/kapali ve sarjda olup olmadigin kontrol edilir, baska hicbir sey okunmaz. Yeterli veri yoksa anket sirasinda verdigin uyku saatlerine geri donulur.',
    'sleepIntelligenceEnabledConfirmation': 'Uyku zekasi acildi.',
    'sleepIntelligenceDisabledConfirmation': 'Uyku zekasi kapatildi.',
    'settingsSnoringDetectionRow': 'Horlama Testi (Deneysel)',
    'snoringDetectionTitle': 'Horlama Testi (Deneysel)',
    'snoringDetectionDescription':
      'Acik oldugunda, uyku saatlerinde birkac saniyelik kisa ses ornekleri alinip cihaz uzerinde analiz edilir; horlamaya benzer ritmik bir ses paterni olup olmadigina bakilir. Ses kaydi hicbir zaman diske yazilmaz veya disariya gonderilmez, sadece sonuc (evet/hayir) kaydedilir.',
    'snoringDetectionPurpose':
      'Neden: Horlama, uyku kalitesini ve dolayisiyla ertesi gunku sigara riskini etkileyebilir. Bu ozellik icin once Uyku Zekasi ozelligi acik olmalidir, cunku ayni gece dongusunu kullanir.',
    'snoringDetectionEnabledConfirmation': 'Horlama testi acildi.',
    'snoringDetectionDisabledConfirmation': 'Horlama testi kapatildi.',
    'snoringDetectionRequiresSleepIntelligence':
      'Once Uyku Zekasini acmalisin, horlama testi onun uzerine calisir.',
    'snoringDetectionLastNightCount': 'Son gece horlama paterni sayisi',
    'settingsWearableIntelligenceRow': 'Bileklik Verisi (Deneysel)',
    'wearableIntelligenceTitle': 'Bileklik Verisi (Deneysel)',
    'wearableIntelligenceDescription':
      'Acik oldugunda, Health Connect uzerinden -eger bir akilli saat/bileklik uygulaman varsa- nabiz ve uyku verini okumaya calisir. Uygulama saatinle dogrudan konusmaz, sadece Health Connect deposunda zaten var olan veriyi okur.',
    'wearableIntelligencePurpose':
      'Neden: Ani nabiz yukselmeleri, riskli anlari daha erken fark etmemize yardimci olabilir. Saatin/bilekligin yoksa veya senkronize veri yoksa bu kart bos gorunur, baska hicbir sey degismez.',
    'wearableIntelligenceEnabledConfirmation': 'Bileklik verisi acildi.',
    'wearableIntelligenceDisabledConfirmation': 'Bileklik verisi kapatildi.',
    'wearableIntelligenceUnavailable':
      'Health Connect bu cihazda bulunamadi. Yuklemek ister misin?',
    'wearableIntelligencePermissionDenied':
      'Health Connect izni verilmedi, ozellik acilamadi.',
    'wearableIntelligenceInstallAction': 'Health Connect\'i Yukle',
    'wearableIntelligenceLatestHeartRate': 'Son nabiz',
    'wearableIntelligenceLastSleep': 'Son uyku suresi',
    'wearableIntelligenceNoData': 'Henuz okunabilir veri yok.',
    'sedentaryReminderTitle': 'Biraz hareket vakti',
    'sedentaryReminderBody':
      'Bir sure hareketsiz gorunuyorsun. Kisa bir yuruyus, hem bacaklarina hem de sigara isteklerine iyi gelir.',
    'healthTipTitle': 'Saglik Tavsiyesi',
    'healthTipHypertension1':
      'Sigara, kan basincini aninda yukseltir. Su an biraz derin nefes almak tansiyonuna iyi gelir.',
    'healthTipHypertension2':
      'Tuzu azaltmak ve sigarasiz kalmak, tansiyonun icin birlikte calisir. Bugun bir sigarayi daha erteleyebilirsin.',
    'healthTipAsthma1':
      'Sigara dumani, hava yollarini daraltarak astim ataklarini tetikleyebilir. Temiz hava alabilecegin bir yere cik.',
    'healthTipAsthma2':
      'Nefesin daraldiginda sigaraya degil, yavas ve derin nefes egzersizine yonel.',
    'healthTipDiabetes1':
      'Sigara, kan sekerini dengelemeyi zorlastirir. Bir bardak su icip birkaç dakika beklemeyi dene.',
    'healthTipDiabetes2':
      'Sigarasiz gecen her saat, dolasimindaki kan sekeri kontrolune küçük bir katki.',
    'healthTipCopd1':
      'KOAH ile sigara bir arada gitmez. Şu anki istegin, birkaç dakika icinde azalacak.',
    'healthTipCopd2':
      'Kisa bir nefes egzersizi, akcigerlerine sigaradan cok daha fazla iyilik yapar.',
    'healthTipHeartDisease1':
      'Sigara, kalbini gereksiz yere hizlandirir. Sakin bir nefes molasi kalbin icin daha iyi bir secim.',
    'healthTipHeartDisease2':
      'Kalp sagligin icin attigin en degerli adim, şu anki sigarayi icmemek.',
    'menuReports': 'Raporlar',
    'reportsTitle': 'Raporlar',
    'reportsWeeklyTab': 'Haftalik',
    'reportsMonthlyTab': 'Aylik',
    'reportsPreviewButton': 'Onizle / Yazdir',
    'reportsShareButton': 'PDF Olarak Paylas',
    'reportsPdfTitle': 'Nikotin Away Raporu',
    'reportsCigarettesLogged': 'Kaydedilen sigara sayisi',
    'reportsAvgPerDay': 'Gunluk ortalama',
    'reportsRiskScore': 'Risk skoru',
    'reportsRiskTrend': 'Risk egilimi',
    'reportsBreathTrend': 'Nefes egilimi',
    'reportsSmokingTrend': 'Sigara egilimi',
    'reportsTaskSuccess': 'Tamamlanan gorevler',
    'reportsTaskCompletionRate': 'Gorev basari orani',
    'reportsWeeklySurveys': 'Tamamlanan haftalik anketler',
    'reportsBreathTests': 'Tamamlanan nefes testleri',
    'reportsDaysSinceQuit': 'Programa baslayali gecen gun',
    'reportsTotalSteps': 'Toplam adim',
    'reportsAvgStepsPerDay': 'Gunluk ortalama adim',
    'settingsLocationIntelligenceRow': 'Konum Zekasi',
    'settingsLocationIntelligenceRowSubtitle': 'Sik gittigin yerleri ogrenerek destek ol',
    'locationIntelligenceTitle': 'Konum Zekasi',
    'locationIntelligenceIntro':
      'Acik oldugunda, uygulama zamanla en fazla 8 sik gittigin yeri ogrenir (ornegin ev, is). Bu yerlerden birine vardiginda kisa bir hatirlatma gosterilir. Ham konum gecmisi hicbir zaman kaydedilmez, sadece bu az sayidaki yerin kabaca konumu tutulur.',
    'locationIntelligencePurpose':
      'Neden: Bildirim gostermek ve risk degerlendirmene katki saglamak icin. Ayarlar > Verilerimi Sifirla ile bu veriler de silinir.',
    'locationIntelligenceBackgroundWarning':
      'Ana izin verildi ama arka plan izni verilmedi. Uygulama kapaliyken vardigin yerler algilanamaz. Ayarlar > Uygulamalar > Nikotin Away > Izinler > Konum bolumunden "Her zaman izin ver" secebilirsin.',
    'locationIntelligenceEnabledConfirmation': 'Konum zekasi acildi.',
    'locationIntelligenceDisabledConfirmation': 'Konum zekasi kapatildi.',
    'locationIntelligencePlacesTitle': 'Ogrenilen Yerler',
    'locationIntelligenceNoPlacesYet': 'Henuz bir yer ogrenilmedi.',
    'locationIntelligencePlaceRow': 'Yer',
    'locationIntelligenceVisitCount': 'ziyaret',
    'locationArrivalNotificationTitle': 'Buradasin',
    'locationArrivalNotificationBody': 'Sik gittigin bir yerdesin. Kendine iyi bak.',
    'smokingLoggedConfirmation': 'Kaydedildi. Bu, ne zaman zorlandigini daha iyi anlamamiza yardimci olur.',
    'undo': 'Geri al',
    'dailyCheckInTitle': 'Gunluk Degerlendirme',
    'dailyCheckInIntro':
      'Gunu kapatmadan once kisa bir degerlendirme yapalim. Bu, seni gereksiz yere gun boyu rahatsiz etmeden en dogru destegi vermemizi saglar.',
    'breathExerciseCardTitle': 'Nefes Egzersizi',
    'dailyCheckInHoursQuestion': 'Bugun yaklasik hangi saatlerde sigara ictin?',
    'dailyCheckInDidNotSmoke': 'Bugun hic icmedim',
    'dailyCheckInSaved': 'Tesekkurler, kaydedildi. Yarin gorusuruz.',
    'notificationContextReasonLabel': 'Bildirim baglam nedeni',
    'smokingYearsHintExample': 'orn: 5',
    'dataLoadFailed': 'Veri yuklenemedi.',
    'progressSummaryTitle': 'Genel Ozet',
    'totalRecords': 'Toplam kayit',
    'latestRiskScore': 'Son risk skoru',
    'breathProgressTitle': 'Nefes Gelisimi',
    'dailyAverageLabel': 'Gunluk ortalama',
    'weeklyAverageLabel': 'Haftalik ortalama',
    'monthlyAverageLabel': 'Aylik ortalama',
    'firstToLastAverageDiff': 'Ilk -> Son ortalama fark',
    'latestVsPrevious': 'Son test vs onceki',
    'bestConsecutiveDay': 'En iyi ardisik gun',
    'respFollowUpTitle': 'Respiratuar Izlem (KOAH-benzeri, tanisal degil)',
    'latestRespBurden': 'Son respiratuar yuk',
    'latestStatus': 'Son durum',
    'mmrcLikeGrade': 'mMRC benzeri derece',
    'catLikeTotal': 'CAT-benzeri toplam',
    'warningDaysTotal': 'Uyari gunleri toplami',
    'respFollowUpNote':
      'Not: Bu izlem tani koymaz; belirti kotulesirse klinik degerlendirme alin.',
    'trendChartsTitle': 'Trend Grafikler',
    'weeklyRiskTrendTitle': 'Haftalik risk trendi (son 12 olcum)',
    'noWeeklyDataForChart': 'Grafik icin yeterli haftalik veri yok.',
    'breathTrendTitle': 'Nefes ortalama trendi (gunluk son 14 veri)',
    'noBreathDataForChart': 'Grafik icin yeterli nefes testi verisi yok.',
    'respiratoryTrendTitle': 'Respiratuar yuk trendi (haftalik son 12)',
    'noRespDataForChart': 'Grafik icin yeterli respiratuar veri yok.',
    'taskBarrierComplianceTitle': 'Gorev ve Bariyer Uyum',
    'last10Successful': 'Son 10 basarili',
    'last10Failed': 'Son 10 basarisiz',
    'achievementsSinceStartTitle': 'Baslangictan Bugune Basarilar',
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
    'riskChange': 'Risk degisimi',
    'weeklyImprovementPeriod': 'Haftalik iyilesen donem',
    'planDayLabel': 'Plan gunu',
    'remainingDaysLabel': 'Kalan gun',
    'respAlertHistoryTitle': 'Respiratuar Uyari Gecmisi',
    'noCriticalRespAlertRecord': 'Kritik respiratuar uyari kaydi yok.',
    'weeklyHistoryTitle': 'Haftalik Gecmis',
    'noWeeklyRecordYet': 'Henuz haftalik anket kaydi yok.',
    'breathTestHistoryTitle': 'Nefes Testi Gecmisi',
    'noBreathRecordYet': 'Henuz nefes testi kaydi yok.',
    'surveyModeTitle': 'Anket modu',
    'surveyModeQuick': 'Hızlı (15 sn)',
    'surveyModeDetailed': 'Detaylı',
    'surveyModeAutoDetailedHint':
      'Geçen hafta risk yüksek görünüyor. İstersen Detaylı moda geçerek daha ince ayar yapabilirsin.',
    'weeklyQuickRespTitle': 'Hızlı Solunum Kontrolü',
    'weeklyQuickRespHint':
      'Kısa modda da solunum durumunu daha doğru yansıtmak için 3 alan doldur.',
    'adaptiveSummary': 'Uyarlanabilir ozet',
    'addNote': 'Not ekle',
    'backToHome': 'Ana sayfaya don',
    'breathAverageComparison': 'Ortalama ile karsilastirma',
    'breathComparedAverageDeclined': 'Ortalamanin altinda',
    'breathComparedAverageImproved': 'Ortalamanin ustunde',
    'breathComparedAverageStable': 'Ortalamaya yakin',
    'breathComparedPreviousDeclined': 'Onceki teste gore dusus',
    'breathComparedPreviousImproved': 'Onceki teste gore artis',
    'breathComparedPreviousStable': 'Onceki teste gore stabil',
    'breathImprovementSummary': 'Nefes gelisim ozeti',
    'breathNoReferenceYet': 'Karsilastirma icin yeterli referans yok.',
    'breathPreviousComparison': 'Onceki test ile karsilastirma',
    'breathTestRecordTitle': 'Nefes Egzersizi Kaydi',
    'breathTrend': 'Nefes trendi',
    'chainSmoking': 'Ardisik icim',
    'chainSmokingLatest': 'Son ardisik icim',
    'chainSmokingTrend': 'Ardisik icim trengi',
    'completeRegistration': 'Kaydi tamamla',
    'daily': 'Gunluk',
    'dailyBreathStatus': 'Gunluk nefes durumu',
    'days': 'gun',
    'evaluation': 'Degerlendirme',
    'exhaleDelta': 'Exhale farki',
    'failedTaskCount': 'Basarisiz gorev',
    'firstEvaluation': 'Ilk degerlendirme',
    'firstTaskNoSmoke15': 'Ilk gorev: 15 dakika sigarasiz kal',
    'goal180CadenceLabel': '180 gun hedef temposu',
    'goal180CadenceOneDay': 'Her gun duzenli',
    'goal180CadenceTwoDays': 'Iki gunde bir guclu takip',
    'goal180CadenceWeek': 'Haftalik toparlama plani',
    'goal180GuideEarly': 'Erken donemde daha sik destek normaldir.',
    'goal180GuideLate': 'Ileri donemde istikrar on planda.',
    'goal180GuideLateHard': 'Ileri donemde zorlanma varsa yuk hafifletilir.',
    'goal180GuideMid': 'Orta donemde ritim yerlesir.',
    'goal180GuideMidHard': 'Orta donemde tetikleyici odakli duzenleme yapilir.',
    'goal180ProgressLabel': '180 gun ilerleme',
    'goal180RemainingLabel': '180 gune kalan',
    'inhaleDelta': 'Inhale farki',
    'lastBreathTest': 'Son nefes testi',
    'lastExhale': 'Son exhale',
    'lastInhale': 'Son inhale',
    'lastSurveyDate': 'Son anket tarihi',
    'mandatoryTaskCommand': 'Zorunlu gorev komutu',
    'mandatoryTaskHint': 'Bugun zorunlu gorevi tamamla.',
    'mandatoryTaskStartButton': 'Kabul Et',
    'mandatoryTaskDeclineButton': 'Ertele',
    'mandatoryTaskTitle': 'Zorunlu gorev',
    'monthly': 'Aylik',
    'monthlyImprovement': 'Aylik iyilesme',
    'noRecordYet': 'Henuz kayit yok.',
    'noSurveyYet': 'Henuz anket yok.',
    'noTaskToday': 'Bugun gorev yok.',
    'openTaskFollowUpScreen': 'Gorev takibine git',
    'openViolationReportScreen': 'Ihlal raporunu ac',
    'packChangeDaily': 'Gunluk paket degisimi',
    'pointShort': 'puan',
    'predictedRiskTime': 'Tahmini risk saati',
    'predictedTrigger': 'Tahmini tetikleyici',
    'predictionConfidence': 'Tahmin guveni',
    'premiumActive': 'Premium aktif',
    'previousRecord': 'Onceki kayit',
    'progressNegative': 'Gerileme var',
    'progressNegativeDetail': 'Bu hafta risk artisi goruldu.',
    'progressPositive': 'Ilerleme var',
    'progressPositiveDetail': 'Bu hafta risk azalisi goruldu.',
    'progressRegression': 'Regresyon',
    'progressSummary': 'Ilerleme ozeti',
    'registrationCompleted': 'Kayit tamamlandi',
    'riskDelta': 'Risk farki',
    'riskyHours': 'Riskli saatler',
    'riskyTriggers': 'Riskli tetikleyiciler',
    'secShort': 'sn',
    'status': 'Durum',
    'subscriptionEnd': 'Abonelik bitis',
    'subscriptionInfo': 'Abonelik bilgisi',
    'subscriptionStart': 'Abonelik baslangic',
    'subscriptionType': 'Abonelik tipi',
    'free': 'Ucretsiz',
    'premium': 'Premium',
    'active': 'Aktif',
    'passive': 'Pasif',
    'taskTimerStartedTitle': 'Gorev basladi',
    'successfulTaskCount': 'Basarili gorev',
    'surveyHistory': 'Anket gecmisi',
    'taskBreathExercise2': '2 dakikalik nefes egzersizi yap',
    'taskCountToday': 'Bugunku gorev sayisi',
    'taskDeferredTenMinutes': 'Gorev 10 dakika ertelendi',
    'taskDelayFirstSmoke10': 'Ilk sigarayi 10 dakika ertele',
    'taskDelayFirstSmoke25': 'Ilk sigarayi 25 dakika ertele',
    'taskDrinkWater': 'Bir bardak su ic',
    'taskFollowUpEmpty': 'Bekleyen gorev takibi yok.',
    'taskFollowUpPendingCount': 'Bekleyen takip sayisi',
    'taskFollowUpScheduledAt': 'Planlanan takip saati',
    'taskFollowUpTitle': 'Gorev takipleri',
    'taskOutcomeConfirmQuestion': 'Gorev basarildi mi?',
    'taskNoSmoke10': '10 dakika sigarasiz kal',
    'taskNoSmoke120': '120 dakika sigarasiz kal',
    'taskNoSmoke30': '30 dakika sigarasiz kal',
    'taskNoSmoke45': '45 dakika sigarasiz kal',
    'taskNoSmoke60': '60 dakika sigarasiz kal',
    'taskNoSmoke90': '90 dakika sigarasiz kal',
    'adaptiveNoSmokeTaskTemplate':
      'Onumuzdeki {duration} boyunca sigara icmeyin. Elinizde sigara varsa hemen sondurun.',
    'taskNoteCraving': 'Kriz anini not et',
    'taskNotNowButton': 'Simdi degil',
    'taskOutcomeNo': 'Hayir',
    'taskOutcomeQuestion': 'Gorevi basariyla tamamladin mi?',
    'taskOutcomeYes': 'Evet',
    'taskPlanOneDayDelayAllCravings':
      '1 gun sigarasiz kalma gorevi: bugun tum kriz anlarinda sigarayi erteleyin.',
    'taskPlanOneDayDelayFirst90':
      '1 gun sigarasiz kalma gorevi: ilk sigarayi en az 90 dakika erteleyin.',
    'taskPlanOneWeekCompleteAll':
      '1 hafta sigarasiz kalma hedefi: 7 gun boyunca tum gorevleri tamamlayin.',
    'taskPlanTwoDaysBreathAndWater':
      '2 gun sigarasiz kalma plani: kriz aninda 10 derin nefes + su uygulayin.',
    'taskPlanTwoDaysDelayTriggers':
      '2 gun sigarasiz kalma gorevi: 48 saat boyunca tetikleyicilerde sigarayi erteleyin.',
    'taskReasonCadence': 'Gorev ritmi',
    'taskReasonCardTitle': 'Neden bu gorev?',
    'taskReasonCause': 'Neden',
    'taskReasonCauseBalanced': 'Dengeli zorluk secildi',
    'taskReasonCauseBootstrap': 'Yeni baslangic modu aktif',
    'taskReasonCauseFailurePressure': 'Sonuc baskisi nedeniyle ayarlandi',
    'taskReasonCauseHighRisk': 'Yuksek risk nedeniyle secildi',
    'taskReasonCauseLowRisk': 'Dusuk riskte koruyucu gorev',
    'taskReasonCauseSuccessStability': 'Basariya gore istikrar gorevi',
    'taskReasonCauseTopHour': 'En riskli saate gore secildi',
    'taskReasonCauseTopTrigger': 'En riskli tetikleyiciye gore secildi',
    'taskReasonNextNotification': 'Sonraki hatirlatma',
    'taskReasonNoPlanned': 'Planli gorev yok',
    'taskReasonNoRecentData': 'Yeterli guncel veri yok',
    'taskReasonRecentRatio': 'Son performans orani',
    'taskReasonRiskLine': 'Risk aciklamasi',
    'taskSkipOneCig': 'Bugun bir sigarayi atla',
    'taskSmokeTwoLess': 'Bugun 2 sigara eksik ic',
    'taskStartTitle': 'Gorev basladi',
    'taskStateCompleted': 'Tamamlandi',
    'taskStateDeferred': 'Ertelendi',
    'taskStateFailed': 'Basarisiz',
    'taskStateNew': 'Yeni',
    'taskSuspiciousReset': 'Supheli davranis nedeniyle sifirlandi',
    'taskUnit': 'gorev',
    'taskUseGumAtRiskHour': 'Riskli saatte seker sakiz kullan',
    'todaysTasks': 'Bugunun gorevleri',
    'totalUsage': 'Toplam kullanim',
    'trendDeclining': 'Dususte',
    'trendImproving': 'Iyilesiyor',
    'trendStable': 'Stabil',
    'trialStatus': 'Deneme durumu',
    'unnamedUser': 'Isimsiz kullanici',
    'viewAllSurveys': 'Tum anketleri gor',
    'violationHigh': 'Yuksek',
    'violationLow': 'Dusuk',
    'violationMedium': 'Orta',
    'violationReportEmpty': 'Ihlal kaydi bulunamadi.',
    'violationReportTitle': 'Ihlal Raporu',
    'violationSource': 'Kaynak',
    'violationTask': 'Gorev',
    'violationTime': 'Zaman',
    'weekly': 'Haftalik',
    'weeklyImprovement': 'Haftalik iyilesme',
    'weeklyMood': 'Haftalik ruh hali',
    'weeklyRecordTitle': 'Haftalik Kayit',
    'weeklyRiskTarget': 'Haftalik risk hedefi',
    'welcome': 'Hos geldin',
    'taskActionDone': 'Gorevi Baslat',
    'taskActionNotNow': 'Simdi Uygun Degil',
    'taskActionDoneLabel': 'Kabul Et',
    'taskActionNotNowLabel': 'Ertele',
    'taskActionDeclineLabel': 'Reddet',
    'taskActionSosLabel': 'SOS Krizdeyim',
    'postponeChoiceTitle': 'Ne kadar ertelensin?',
    'postponeChoiceBody': 'Ayni gorev secilen sure sonunda tekrar gelecek.',
    'postpone5Label': '5 dakika',
    'postpone10Label': '10 dakika',
    'postpone15Label': '15 dakika',
    'taskConfirmQuestionTitle': 'Sure doldu',
    'taskConfirmQuestion': 'Bu sure icinde sigara ictiniz mi?',
    'taskConfirmYesLabel': 'Evet',
    'taskConfirmNoLabel': 'Hayir',
    'sosPageTitle': 'Su an istegim var',
    'sosIntro': 'Bu his birkac dakika icinde gececek. Birlikte nefes alalim.',
    'sosCyclesCompleted': '{count} tur tamamlandi',
    'sosPhaseInhale': 'Nefes al',
    'sosPhaseHold': 'Tut',
    'sosPhaseExhale': 'Ver',
    'sosReassurance':
        'Istek dalgasi genelde 3-5 dakikada zirve yapip azalir. Sigara icmeden de bu ani atlatabilirsin.',
    'sosDismiss': 'Atlattim',
    'sosNeedSuggestion': 'Bana bir sey oner',
    'sosSuggestionTitle': 'Sunu dene',
    'sosSuggestionWater': 'Bir bardak su ic, yavasca.',
    'sosSuggestionWalk': 'Bes dakika yuru, tercihen disarida.',
    'sosSuggestionCall': 'Bugun konusmadigin birini ara.',
    'sosSuggestionStretch': 'Ayaga kalk ve omuzlarini gevset.',
    'sosSuggestionWash': 'Yuzunu soguk suyla yika.',
    'sosResumeQuestion': 'Gorevine ne zaman donelim?',
    'sosResume30': '30 dakika sonra',
    'sosResume60': '1 saat sonra',
    'sosResume120': '2 saat sonra',
    'sosTaskPostponed': 'Gorev ertelendi. Kendine iyi bak.',
    'medicationTimesPerDay': 'Gunde kac kez aliyorsunuz?',
    'medicationTimesPerDayHint':
        'Saatleri uyanik oldugunuz sureye esit dagitip oneriyoruz; her birini degistirebilirsiniz.',
    'medicationTimeSlotLabel': '{index}. doz',
    'medicationAdviceDisclaimer':
        'Bu bilgi genel niteliktedir; tedavinizle ilgili kararlar icin doktorunuza danisin.',
    'taskFollowUpActionYes': 'Evet',
    'taskFollowUpActionNo': 'Hayir',
    'disciplineCommand': 'Su andan itibaren sigara icme',
    'disciplineCommandBody':
      'Protokol aktif. Bildirim kapanmasi icin gorevi baslat.',
    'breathReminderTitle': 'Nefes Testi',
    'breathReminderBody': 'Gunluk nefes testi zamani geldi.',
    'breathReminderDriving':
      'Suruste guvenliginiz icin hatirlatma kisa sure ertelendi.',
    'breathReminderWorkout':
      'Aktivite tamamlaninca hatirlatma tekrar gonderilecek.',
    'breathReminderPostMeal':
      'Yemek sonrasi sigarayi ertelemek icin nefes rutinini simdi uygula.',
    'taskFollowUpTitlePush': 'Gorev Takibi',
    'taskFollowUpQuestion': 'Gorevi basariyla tamamladiniz mi?',
    'taskFollowUpQuestionDriving':
      'Surus sonrasi cevaplayin: Gorevi basariyla tamamladiniz mi?',
    'taskFollowUpQuestionWorkout':
      'Aktivite sonrasi cevaplayin: Gorevi basariyla tamamladiniz mi?',
    'taskFollowUpQuestionPostMeal':
      'Yemek sonrasi sigara istegini yonetebildiniz mi?',
    'postMealShieldCommand':
      'Yemek sonrasi 10 dakika ertele + su + sakiz rutini uygula.',
    'contextReasonDriving':
      'Bildirim surus/ulasim durumu nedeniyle ertelendi',
    'contextReasonWorkout':
      'Bildirim kosu/egzersiz durumu nedeniyle ertelendi',
    'contextReasonEating':
      'Bildirim yemek penceresi nedeniyle yemek sonrasina kaydirildi',
    'contextReasonNormal': 'Bildirim normal plana gore ayarlandi',
    'taskEscalationTitle': 'Gorev guncellendi',
    'taskEscalationBodyPrefix':
      '15 saniye icinde yanit alinmadi. 10 dakika sonra gorev tekrarlanacak:',
    'taskTimerStartedBody': 'Gorev basladi:',
    'taskTimerDuration': 'Sayac',
    'minutesShort': 'dakika',
    'oneHourLabel': '1 saat',
    'postponeReminderPromptTitle': 'Ne zaman hatirlatayim?',
    'postponeReminderPromptMessage':
      'Gorevi erteliyorsunuz. Size ne zaman tekrar hatirlatmami istersiniz?',
    'sleepActivityAdvisoryTitle': 'Hala ayakta misin?',
    'sleepActivityAdvisoryBody':
      'Uyku saatinde uyanik oldugunu fark ettik. Bugunku gorevlerini zaten tamamladin, sadece dinlenmeyi unutma.',
    'weeklySurveyReminderTitle': 'Haftalik anket zamani',
    'weeklySurveyReminderBody':
      'Risk skorunu guncellemek icin haftalik anketi doldurman gerekiyor.',
    'trialInfoTitle': '14 Gunluk Ucretsiz Deneme',
    'trialInfoMessage':
      'Nikotin Away uygulamasini 14 gun boyunca ucretsiz deneyebilirsin. Bu surede gunluk gorevler, nefes testleri ve haftalik anketlerle birakma surecini yakindan takip edecegiz.',
  };

  // English - Full translation
  static const Map<String, String> _en = {
    'appName': 'NIKOTIN AWAY',
    'selectLanguage': 'Select language',
    'continue': 'Continue',
    'yes': 'Yes',
    'no': 'No',
    'save': 'Save',
    'home': 'Home',
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
    'medicationDeleteConfirmMessage': 'Are you sure you want to delete this medication and its reminders?',
    'medicationSavedConfirmation': 'Medication saved',
    'medicationReminderTitle': 'Medication reminder',
    'medicationReminderBody': 'It\'s time to take your {name}.',
    'overlayPermissionTitle': 'Show the task screen',
    'overlayPermissionMessage': 'For the task screen to open over other apps even when the phone isn\'t locked, we need the "display over other apps" permission. Open the settings screen now?',
    'smokedLogButtonRow': 'I Smoked button',
    'smokedLogButtonTitle': 'I Smoked Button',
    'smokedLogButtonDescription':
        'A small, translucent button appears on screen. When you smoke, press and hold it for 3 seconds — the ring around it fills, a tick appears, and the moment is recorded. A stray tap records nothing.',
    'smokedLogButtonPurpose':
        'This is how the app learns which hours and which places you tend to smoke in, so it can aim tasks at exactly those moments. Location is only matched against the handful of places you already visit often; no address or movement history is stored. Everything stays on your device.',
    'smokedLogButtonEnabled': 'I Smoked button is on.',
    'smokedLogButtonDisabled': 'I Smoked button is off.',
    'smokedLogButtonNeedsOverlay':
        'This button needs the "display over other apps" permission.',
    'smokedLogButtonNotificationTitle': 'Nikotin Away',
    'smokedLogButtonNotificationBody': 'Tap to record a cigarette',
    'smokedLogButtonAction': 'I Smoked',
    'smokedLogRecordedWithUndo': 'Cigarette recorded.',
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
    'permissionSetupContinueAnyway': 'Continue for now',
    'permissionSetupOptionalNote':
        'You can change these later from Settings.',
    'packsPerDayQuestion': 'How many packs of cigarettes do you smoke per day?',
    'firstCigaretteWhen': 'How long after waking up do you smoke your first cigarette?',
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
    'weeklySurveyPromptAsk': 'Would you like to complete the weekly survey now?',
    'shareProgressTitle': 'Share your progress',
    'shareProgressMessage':
      'You just completed your weekly check-in. Want to share your progress with friends?',
    'shareProgressSkip': 'Skip',
    'shareProgressAction': 'Share',
    'shareProgressText':
      'I\'m tracking my quit-smoking journey with Nikotin Away. My current risk score: {score}/100 ({level}).',
    'saveErrorRetry': 'An error occurred while saving. Please try again.',
    'loadErrorRetry': 'Something went wrong loading this data. Please try again.',
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
    'exportComingSoon': 'PDF export coming soon.',
    'exportPDF': 'Export as PDF',
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
      '1. Sit upright and relax.\n2. Tap the circle, take a deep breath through your nose, and hold for 2 seconds.\n3. Exhale in one controlled breath.\n4. Tap the circle again when you\'re done.\n\n3 attempts will be performed, best score is saved.',
    'breathExerciseDisclaimer':
      'This is not a medical diagnostic tool; it is a simple breathing exercise for awareness and relaxation.',
    'micRationaleTitle': 'Microphone permission',
    'micRationaleMessage':
      'We can use the microphone to automatically time your exhale. Audio is never recorded or stored — only the momentary sound level is measured. If you decline, you can still finish the test manually by tapping.',
    'restingLabel': 'Resting',
    'secondsLeftLabel': 'seconds left',
    'tapCircleToFinish': 'Tap the circle when you\'re done',
    'breathListeningHint': 'Listening... exhale, it will be detected automatically',
    'breathStepSitRelax': 'Sit upright and relax.',
    'breathStepDeepBreath': 'Take a deep breath.',
    'breathStepHold': 'Hold your breath for 5 seconds and press Start.',
    'breathStepExhale':
      'Blow forcefully into the microphone until your breath is fully out.',
    'breathStepExhaleFinishHint': 'Press OK when your breath is done.',
    'breathStepOkAction': 'OK',
    'breathStepPressOkVoiceSuffix': 'Press OK.',
    'breathAutoNextAttemptInstruction':
      'Sit upright and relax. Take a deep breath. Hold for five seconds. Then blow forcefully into the microphone until your breath is fully out. Press OK when your breath is done.',
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
    'mmrcPlain3':
        'I stop for breath after about 100 metres on the flat.',
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
    'durationBarrierTitle': 'Smoke-free duration preference',
    'durationBarrierHow': 'How do you feel about smoke-free durations?',
    'durationBarrierLike': 'I like it',
    'durationBarrierNeutral': 'Neutral',
    'durationBarrierDislike': 'I do not like it',
    'durationBarrierOff': 'I do not want it',
    'durationBarrierFrequencyHow': 'How often should smoke-free durations appear?',
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
    'barrierEvaluationTitle': 'Smoke-free duration evaluation',
    'barrierEvaluationPromptNoMinutes':
      'Smoke-free duration completed. Were you successful?',
    'barrierEvaluationPromptMinutes':
      'minute smoke-free duration ended. Were you successful?',
    'barrierFail': 'Failed',
    'barrierSuccess': 'Successful',
    'barrierSavedSuccess':
      'Smoke-free duration saved as successful. Next durations will be tuned accordingly.',
    'barrierSavedFailure':
      'Smoke-free duration saved as failed. Next durations will be adjusted to your adherence.',
    'commandDeferred10': 'Command deferred by 10 minutes.',
    'barrierDeferred10': 'Smoke-free duration deferred by 10 minutes.',
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
    'quickMenuTitle': 'Quick menu',
    'menuBreathTest': 'Breathing Exercise',
    'menuWeeklySurvey': 'Weekly Survey',
    'menuPersonalProgress': 'Personal Progress',
    'menuViolationReport': 'Violation Report',
    'menuSurveyHistory': 'Survey History',
    'menuLogSmokingNow': 'I smoked now',
    'menuDailyCheckIn': 'Daily Check-in',
    'mentorCardTitle': 'From your mentor',
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
    'settingsPermissionsRow': 'Permissions Center',
    'settingsPermissionsRowSubtitle': 'See which permissions we use and why',
    'settingsResetDataRow': 'Reset My Data',
    'settingsResetDataSubtitle': 'Permanently deletes all your records',
    'settingsResetDataConfirmTitle': 'Are you sure?',
    'settingsResetDataConfirmMessage':
      'All your smoking logs, survey results and progress will be permanently deleted. This cannot be undone.',
    'settingsResetDataConfirmAction': 'Yes, Delete',
    'settingsResetDataDone': 'Your data has been deleted.',
    'permissionsCenterTitle': 'Permissions Center',
    'permissionsCenterIntro':
      'Here\'s why we ask for each permission and how we use it. All of them are optional and can be turned off anytime.',
    'permissionStatusGranted': 'Granted',
    'permissionStatusDenied': 'Not granted',
    'permissionActionRequest': 'Grant',
    'permissionActionOpenSettings': 'Open Settings',
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
    'permissionPhonePurpose':
      'Why: we never read call numbers or content.',
    'permissionExactAlarmTitle': 'Exact Timing',
    'permissionExactAlarmDescription':
      'Makes sure reminders and mentor messages arrive exactly on time.',
    'permissionExactAlarmPurpose':
      'Why: Android manages this permission from system settings.',
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
    'settingsCoachModeRowSubtitle': 'How often and how firmly the app should push you',
    'coachModeTitle': 'Coach Mode',
    'coachModeIntro':
      'Choose how often and how firmly the app should support you. You can change this anytime.',
    'coachModeEasyTitle': 'Easy',
    'coachModeEasyDescription': 'Few, gentle reminders. For going at your own pace.',
    'coachModeNormalTitle': 'Normal',
    'coachModeNormalDescription': 'Balanced support frequency. Recommended for most users.',
    'coachModeHardTitle': 'Hard',
    'coachModeHardDescription': 'Frequent, firm reminders. For extra discipline.',
    'coachModeCustomLabel': 'Custom',
    'coachModeCustomDescription': 'A combination you set yourself in Advanced Settings.',
    'coachModeAdvancedToggle': 'Advanced Settings',
    'coachModeSavedConfirmation': 'Coach mode updated.',
    'settingsSleepIntelligenceRow': 'Sleep Intelligence',
    'sleepIntelligenceTitle': 'Sleep Intelligence',
    'sleepIntelligenceDescription':
      'When on, the app checks your phone\'s screen and charging state a few times overnight to estimate your sleep hours. This estimate is used to make your risk assessment more accurate.',
    'sleepIntelligencePurpose':
      'Why: only whether the screen is on/off and charging is checked, nothing else is read. If there isn\'t enough data, it falls back to the sleep time you gave in the survey.',
    'sleepIntelligenceEnabledConfirmation': 'Sleep intelligence turned on.',
    'sleepIntelligenceDisabledConfirmation': 'Sleep intelligence turned off.',
    'settingsSnoringDetectionRow': 'Snoring Test (Experimental)',
    'snoringDetectionTitle': 'Snoring Test (Experimental)',
    'snoringDetectionDescription':
      'When on, a few seconds of audio are sampled during your sleep hours and analyzed on-device for a rhythmic, snore-like sound pattern. The recording is never written to disk or sent anywhere -- only the result (yes/no) is stored.',
    'snoringDetectionPurpose':
      'Why: snoring can affect sleep quality and, in turn, next-day smoking risk. Sleep Intelligence must be on first for this feature, since it runs on the same overnight cycle.',
    'snoringDetectionEnabledConfirmation': 'Snoring test turned on.',
    'snoringDetectionDisabledConfirmation': 'Snoring test turned off.',
    'snoringDetectionRequiresSleepIntelligence':
      'Turn on Sleep Intelligence first -- the snoring test runs on top of it.',
    'snoringDetectionLastNightCount': 'Snore-like patterns detected last night',
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
    'sedentaryReminderTitle': 'Time to move a bit',
    'sedentaryReminderBody':
      'You\'ve been still for a while. A short walk is good for your legs and for cravings alike.',
    'healthTipTitle': 'Health Tip',
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
    'settingsLocationIntelligenceRowSubtitle': 'Learn your frequent places to support you better',
    'locationIntelligenceTitle': 'Location Intelligence',
    'locationIntelligenceIntro':
      'When on, the app gradually learns up to 8 places you visit often (e.g. home, work). A short reminder is shown when you arrive at one of them. Your raw location history is never recorded — only the rough location of this small set of places is kept.',
    'locationIntelligencePurpose':
      'Why: to show the reminder and contribute to your risk assessment. Settings > Reset My Data also clears this data.',
    'locationIntelligenceBackgroundWarning':
      'The main permission was granted but background permission was not. Arrivals can\'t be detected while the app is closed. You can choose "Allow all the time" from Settings > Apps > Nikotin Away > Permissions > Location.',
    'locationIntelligenceEnabledConfirmation': 'Location intelligence turned on.',
    'locationIntelligenceDisabledConfirmation': 'Location intelligence turned off.',
    'locationIntelligencePlacesTitle': 'Learned Places',
    'locationIntelligenceNoPlacesYet': 'No place learned yet.',
    'locationIntelligencePlaceRow': 'Place',
    'locationIntelligenceVisitCount': 'visits',
    'locationArrivalNotificationTitle': 'You\'re here',
    'locationArrivalNotificationBody': 'You\'re at a place you visit often. Take care of yourself.',
    'smokingLoggedConfirmation': 'Logged. This helps us understand when things are hardest for you.',
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
    'achievementInterval100Desc':
        'Your gap between cigarettes has doubled.',
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
    'mandatoryTaskHint': 'Complete the mandatory task today.',
    'mandatoryTaskStartButton': 'Accept',
    'mandatoryTaskDeclineButton': 'Postpone',
    'mandatoryTaskTitle': 'Mandatory task',
    'monthly': 'Monthly',
    'monthlyImprovement': 'Monthly improvement',
    'noRecordYet': 'No record yet.',
    'noSurveyYet': 'No survey yet.',
    'noTaskToday': 'No task today.',
    'notificationPermissionRequired':
      'Reminders may not work without notification permission.',
    'onePack': '1 pack',
    'onlyBreaks': 'Only during breaks',
    'openAlarmReminderSettings': 'Open Alarm/Reminder Settings',
    'openSettings': 'Open Settings',
    'openTaskFollowUpScreen': 'Open task follow-up screen',
    'openViolationReportScreen': 'Open violation report screen',
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
    'taskFollowUpScheduledAt': 'Scheduled follow-up time',
    'taskFollowUpTitle': 'Task follow-ups',
    'taskOutcomeConfirmQuestion': 'Was the task completed?',
    'taskNoSmoke10': 'Stay smoke-free for 10 minutes',
    'taskNoSmoke120': 'Stay smoke-free for 120 minutes',
    'taskNoSmoke30': 'Stay smoke-free for 30 minutes',
    'taskNoSmoke45': 'Stay smoke-free for 45 minutes',
    'taskNoSmoke60': 'Stay smoke-free for 60 minutes',
    'taskNoSmoke90': 'Stay smoke-free for 90 minutes',
    'adaptiveNoSmokeTaskTemplate':
      'Do not smoke for the next {duration}. If you have a cigarette in your hand, put it out now.',
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
    'taskStateFailed': 'Failed',
    'taskStateNew': 'New',
    'taskSuspiciousReset': 'Reset due to suspicious behavior',
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
    'validationChainCountRequired':
      'Please select consecutive smoking count.',
    'validationChainHabitRequired':
      'Please select consecutive smoking habit.',
    'validationFirstCigaretteRequired':
      'Please select how soon after waking you smoke your first cigarette.',
    'validationFixHighlightedFields':
      'Please fix the highlighted fields.',
    'validationSleepTimeRequired': 'Please select sleep time.',
    'validationSmokeYearsRange':
      'Smoking duration must be between 0 and 90 years.',
    'validationWakeTimeRequired': 'Please select wake-up time.',
    'viewAllSurveys': 'View all surveys',
    'violationHigh': 'High',
    'violationLow': 'Low',
    'violationMedium': 'Medium',
    'violationReportEmpty': 'No violation records found.',
    'violationReportTitle': 'Violation Report',
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
    'taskConfirmYesLabel': 'Yes',
    'taskConfirmNoLabel': 'No',
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
    'taskEscalationTitle': 'Task updated',
    'taskEscalationBodyPrefix':
      'No response in 15 seconds. Task will repeat after 10 minutes:',
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
      'You can use Nikotin Away free for 14 days. During this period, we guide your quit journey with daily tasks, breath tests, and weekly surveys.',
  };

  // All 40 languages - each inherits from EN, with top keys translated
  static final Map<String, Map<String, String>> _data = {
    'tr': _tr,
    'en': _en,
    // German
    'de': {
      ..._en,
      'selectLanguage': 'Sprache wählen',
      'appName': 'NIKOTIN AWAY',
      'initialSurvey': 'Anfangsumfrage',
      'continue': 'Weiter',
      'yes': 'Ja',
      'no': 'Nein',
      'home': 'Startseite',
      'weeklySurvey': 'Wöchentliche Umfrage',
      'riskAnalysis': 'Risikoanalyse',
      'save': 'Speichern',
      'retry': 'Erneut versuchen',
      'start': 'Starten',
      'name': 'Name',
      'age': 'Alter',
      'gender': 'Geschlecht',
      'male': 'Männlich',
      'female': 'Weiblich',
    },
    // Arabic
    'ar': {
      ..._en,
      'selectLanguage': 'اختر اللغة',
      'appName': 'NIKOTIN AWAY',
      'initialSurvey': 'الاستطلاع الأولي',
      'continue': 'تابع',
      'yes': 'نعم',
      'no': 'لا',
      'home': 'الرئيسية',
      'weeklySurvey': 'المسح الأسبوعي',
      'save': 'حفظ',
      'start': 'ابدأ',
      'name': 'الاسم',
    },
    // French
    'fr': {
      ..._en,
      'selectLanguage': 'Choisir la langue',
      'appName': 'NIKOTIN AWAY',
      'initialSurvey': 'Enquête initiale',
      'continue': 'Continuer',
      'yes': 'Oui',
      'no': 'Non',
      'home': 'Accueil',
      'weeklySurvey': 'Enquête hebdomadaire',
      'save': 'Enregistrer',
      'start': 'Démarrer',
      'name': 'Nom',
    },
    // Spanish
    'es': {
      ..._en,
      'selectLanguage': 'Seleccionar idioma',
      'appName': 'NIKOTIN AWAY',
      'initialSurvey': 'Encuesta inicial',
      'continue': 'Continuar',
      'yes': 'Sí',
      'no': 'No',
      'home': 'Inicio',
      'weeklySurvey': 'Encuesta semanal',
      'save': 'Guardar',
      'start': 'Comenzar',
      'name': 'Nombre',
    },
    // Portuguese
    'pt': {
      ..._en,
      'selectLanguage': 'Selecione o idioma',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Continuar',
      'yes': 'Sim',
      'no': 'Não',
      'home': 'Início',
      'save': 'Salvar',
      'start': 'Começar',
      'name': 'Nome',
    },
    // Italian
    'it': {
      ..._en,
      'selectLanguage': 'Seleziona lingua',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Continua',
      'yes': 'Sì',
      'no': 'No',
      'home': 'Home',
      'save': 'Salva',
      'start': 'Inizia',
      'name': 'Nome',
    },
    // Polish
    'pl': {
      ..._en,
      'selectLanguage': 'Wybierz język',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Dalej',
      'yes': 'Tak',
      'no': 'Nie',
      'home': 'Strona główna',
      'save': 'Zapisz',
      'start': 'Rozpocznij',
      'name': 'Imię',
    },
    // Russian
    'ru': {
      ..._en,
      'selectLanguage': 'Выберите язык',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Продолжить',
      'yes': 'Да',
      'no': 'Нет',
      'home': 'Главная',
      'save': 'Сохранить',
      'start': 'Начать',
      'name': 'Имя',
    },
    // Japanese
    'ja': {
      ..._en,
      'selectLanguage': '言語を選択',
      'appName': 'NIKOTIN AWAY',
      'continue': '続行',
      'yes': 'はい',
      'no': 'いいえ',
      'home': 'ホーム',
      'save': '保存',
      'start': '開始',
      'name': '名前',
    },
    // Chinese
    'zh': {
      ..._en,
      'selectLanguage': '选择语言',
      'appName': 'NIKOTIN AWAY',
      'continue': '继续',
      'yes': '是',
      'no': '否',
      'home': '首页',
      'save': '保存',
      'start': '开始',
      'name': '名字',
    },
    // Korean
    'ko': {
      ..._en,
      'selectLanguage': '언어 선택',
      'appName': 'NIKOTIN AWAY',
      'continue': '계속',
      'yes': '예',
      'no': '아니오',
      'home': '홈',
      'save': '저장',
      'start': '시작',
      'name': '이름',
    },
    // Hindi
    'hi': {
      ..._en,
      'selectLanguage': 'भाषा चुनें',
      'appName': 'NIKOTIN AWAY',
      'continue': 'जारी रखें',
      'yes': 'हाँ',
      'no': 'नहीं',
      'home': 'होम',
      'save': 'सहेजें',
      'start': 'शुरु करें',
      'name': 'नाम',
    },
    // Thai
    'th': {
      ..._en,
      'selectLanguage': 'เลือกภาษา',
      'appName': 'NIKOTIN AWAY',
      'continue': 'ต่อไป',
      'yes': 'ใช่',
      'no': 'ไม่ใช่',
      'home': 'หน้าแรก',
      'save': 'บันทึก',
      'start': 'เริ่ม',
      'name': 'ชื่อ',
    },
    // Vietnamese
    'vi': {
      ..._en,
      'selectLanguage': 'Chọn ngôn ngữ',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Tiếp tục',
      'yes': 'Có',
      'no': 'Không',
      'home': 'Trang chủ',
      'save': 'Lưu',
      'start': 'Bắt đầu',
      'name': 'Tên',
    },
    // Indonesian
    'id': {
      ..._en,
      'selectLanguage': 'Pilih bahasa',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Lanjutkan',
      'yes': 'Ya',
      'no': 'Tidak',
      'home': 'Beranda',
      'save': 'Simpan',
      'start': 'Mulai',
      'name': 'Nama',
    },
    // Bengali
    'bn': {
      ..._en,
      'selectLanguage': 'ভাষা নির্বাচন করুন',
      'continue': 'চালিয়ে যান',
      'yes': 'হাঁ',
      'no': 'না',
      'home': 'হোম',
      'save': 'সংরক্ষণ করুন',
      'start': 'শুরু করুন',
    },
    // Punjabi
    'pa': {
      ..._en,
      'selectLanguage': 'ਭਾਸ਼ਾ ਚੁਣੋ',
      'continue': 'ਜਾਰੀ ਰੱਖੋ',
      'yes': 'ਹਾਂ',
      'no': 'ਨਹੀਂ',
      'home': 'ਹੋਮ',
      'save': 'ਸੰਭਾਲੋ',
      'start': 'ਸ਼ੁਰੂ ਕਰੋ',
    },
    // Telugu
    'te': {
      ..._en,
      'selectLanguage': 'భాషను ఎంచుకోండి',
      'continue': 'కొనసాగించు',
      'yes': 'అవును',
      'no': 'కాదు',
      'home': 'హోమ్',
      'save': 'సేవ్ చేయండి',
      'start': 'ప్రారంభించండి',
    },
    // Tamil
    'ta': {
      ..._en,
      'selectLanguage': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'continue': 'தொடரவும்',
      'yes': 'ஆம்',
      'no': 'இல்லை',
      'home': 'வீடு',
      'save': 'சேமிக்கவும்',
      'start': 'தொடங்கவும்',
    },
    // Malayalam
    'ml': {
      ..._en,
      'selectLanguage': 'ഭാഷ തിരഞ്ഞെടുക്കുക',
      'continue': 'തുടരുക',
      'yes': 'അതെ',
      'no': 'ഇല്ല',
      'home': 'ഹോം',
      'save': 'സംരക്ഷിക്കുക',
      'start': 'തുടങ്ങുക',
    },
    // Gujarati
    'gu': {
      ..._en,
      'selectLanguage': 'ભાષા પસંદ કરો',
      'continue': 'આગળ વધો',
      'yes': 'હા',
      'no': 'ના',
      'home': 'હોમ',
      'save': 'સંગ્રહો',
      'start': 'શરુ કરો',
    },
    // Kannada
    'kn': {
      ..._en,
      'selectLanguage': 'ಭಾಷೆ ಆರಿಸಿ',
      'continue': 'ಮುಂದುವರಿಸಿ',
      'yes': 'ಹೌದು',
      'no': 'ಇಲ್ಲ',
      'home': 'ಮುಖಪುಟ',
      'save': 'ಉಳಿಸಿ',
      'start': 'ಪ್ರಾರಂಭಿಸಿ',
    },
    // Marathi
    'mr': {
      ..._en,
      'selectLanguage': 'भाषा निवडा',
      'continue': 'चालू ठेवा',
      'yes': 'होय',
      'no': 'नाही',
      'home': 'मुखपृष्ठ',
      'save': 'जतन करा',
      'start': 'सुरू करा',
    },
    // Ukrainian
    'uk': {
      ..._en,
      'selectLanguage': 'Виберіть мову',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Продовжити',
      'yes': 'Так',
      'no': 'Ні',
      'home': 'Головна',
      'save': 'Зберегти',
      'start': 'Почати',
    },
    // Romanian
    'ro': {
      ..._en,
      'selectLanguage': 'Alegeți limba',
      'continue': 'Continuă',
      'yes': 'Da',
      'no': 'Nu',
      'home': 'Acasă',
      'save': 'Salvează',
      'start': 'Început',
    },
    // Greek
    'el': {
      ..._en,
      'selectLanguage': 'Επιλέξτε γλώσσα',
      'continue': 'Συνέχεια',
      'yes': 'Ναι',
      'no': 'Όχι',
      'home': 'Αρχική',
      'save': 'Αποθήκευση',
      'start': 'Εκκίνηση',
    },
    // Hungarian
    'hu': {
      ..._en,
      'selectLanguage': 'Válassza ki a nyelvet',
      'continue': 'Folytatás',
      'yes': 'Igen',
      'no': 'Nem',
      'home': 'Kezdőlap',
      'save': 'Mentés',
      'start': 'Indítás',
    },
    // Czech
    'cs': {
      ..._en,
      'selectLanguage': 'Vyberte jazyk',
      'continue': 'Pokračovat',
      'yes': 'Ano',
      'no': 'Ne',
      'home': 'Domů',
      'save': 'Uložit',
      'start': 'Začít',
    },
    // Swedish
    'sv': {
      ..._en,
      'selectLanguage': 'Välj språk',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Fortsätt',
      'yes': 'Ja',
      'no': 'Nej',
      'home': 'Hem',
      'save': 'Spara',
      'start': 'Börja',
    },
    // Danish
    'da': {
      ..._en,
      'selectLanguage': 'Vælg sprog',
      'continue': 'Fortsæt',
      'yes': 'Ja',
      'no': 'Nej',
      'home': 'Hjem',
      'save': 'Gem',
      'start': 'Start',
    },
    // Norwegian
    'no': {
      ..._en,
      'selectLanguage': 'Velg språk',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Fortsett',
      'yes': 'Ja',
      'no': 'Nei',
      'home': 'Hjem',
      'save': 'Lagre',
      'start': 'Start',
    },
    // Finnish
    'fi': {
      ..._en,
      'selectLanguage': 'Valitse kieli',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Jatka',
      'yes': 'Kyllä',
      'no': 'Ei',
      'home': 'Koti',
      'save': 'Tallenna',
      'start': 'Aloita',
    },
    // Dutch
    'nl': {
      ..._en,
      'selectLanguage': 'Selecteer taal',
      'continue': 'Doorgaan',
      'yes': 'Ja',
      'no': 'Nee',
      'home': 'Start',
      'save': 'Opslaan',
      'start': 'Begin',
    },
    // Belarusian
    'be': {
      ..._en,
      'selectLanguage': 'Выберыце мову',
      'appName': 'NIKOTIN AWAY',
      'continue': 'Прадолжыць',
      'yes': 'Так',
      'no': 'Не',
      'home': 'Галоўная',
      'save': 'Сахаваць',
      'start': 'Пачаць',
    },
    // Serbian
    'sr': {
      ..._en,
      'selectLanguage': 'Izaberite jezik',
      'continue': 'Nastavi',
      'yes': 'Da',
      'no': 'Ne',
      'home': 'Početna',
      'save': 'Spremi',
      'start': 'Počni',
    },
    // Croatian
    'hr': {
      ..._en,
      'selectLanguage': 'Odaberite jezik',
      'continue': 'Nastavi',
      'yes': 'Da',
      'no': 'Ne',
      'home': 'Početna',
      'save': 'Spremi',
      'start': 'Počni',
    },
    // Malay
    'ms': {
      ..._en,
      'selectLanguage': 'Pilih bahasa',
      'continue': 'Lanjutkan',
      'yes': 'Ya',
      'no': 'Tidak',
      'home': 'Beranda',
      'save': 'Simpan',
      'start': 'Mulai',
    },
    // Filipino
    'fil': {
      ..._en,
      'selectLanguage': 'Piliin ang wika',
      'continue': 'Magpatuloy',
      'yes': 'Oo',
      'no': 'Hindi',
      'home': 'Tahanan',
      'save': 'I-save',
      'start': 'Magsimula',
    },
  };

  static String textForCode(String code, String key) {
    if (code == 'tr') {
      return _tr[key] ?? _en[key] ?? key;
    }
    if (code == 'en') {
      return _en[key] ?? _tr[key] ?? key;
    }

    final generatedMap = generatedLanguageData[code];
    if (generatedMap != null && generatedMap.containsKey(key)) {
      return generatedMap[key] ?? _en[key] ?? _tr[key] ?? key;
    }

    final langMap = _data[code] ?? _data['en']!;
    return langMap[key] ?? _data['en']![key] ?? _data['tr']![key] ?? key;
  }

  /// Kept so callers do not have to know whether a language needs loading.
  ///
  /// It used to fetch the whole string table from translate.googleapis.com
  /// on first use of any language without bundled data — an undocumented
  /// endpoint, and a network call in an app whose data-safety declaration
  /// says nothing leaves the device. Every language now resolves from the
  /// bundle, falling back to English for keys not yet translated.
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
      return isTr
          ? '$days gün'
          : '$days day${days == 1 ? '' : 's'}';
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
    return isTr ? '$minutes dakika' : '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  static String localizeCanonicalTextForCode(String code, String value) {
    final normalized = value.trim();

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

    return value;
  }

  static String localizeCanonicalText(BuildContext context, String value) {
    final code = Localizations.localeOf(context).languageCode;
    return localizeCanonicalTextForCode(code, value);
  }
}

extension AppTextsX on BuildContext {
  String t(String key) => AppTexts.text(this, key);
}
