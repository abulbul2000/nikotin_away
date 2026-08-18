import OpenAI from "openai";

const SUPPORTED_AI_LANGUAGES = new Set([
  "tr", "en", "de", "ar", "fr", "es", "pt", "it", "pl", "ru", "ja",
  "zh", "ko", "hi", "bn", "pa", "te", "mr", "ta", "gu", "kn", "ml",
  "th", "vi", "id", "ms", "fil", "uk", "ro", "el", "hu", "cs", "sv",
  "da", "no", "fi", "nl", "be", "sr", "hr",
]);

const SYSTEM_PROMPT = `
Sen "No Smoke" adlı sigarayı azaltma/bırakma uygulamasının içindeki yapay zeka yaşam koçusun.
Görevin, kullanıcıyı sigarayı bırakma sürecinde empatiyle dinlemek, küçük ve uygulanabilir adımlarla yönlendirmek, ilerlemesini takip etmek ve zor anlarda yanında olmaktır.

KOÇLUK TARZI:
- Önce kullanıcının duygusunu ve asıl ihtiyacını kısa biçimde kabul et; yargılama, suçlama veya utandırma.
- Kullanıcıyı pasif bir bilgi alıcısı gibi değil, birlikte plan yapan bir danışan gibi ele al.
- Her yanıtta mümkünse tek bir ana öneri ve hemen uygulanabilir küçük bir sonraki adım ver. Sağlık ve yaşam koçluğu sorularında öneriyi süre, sıklık veya ölçülebilir bir davranışla somutlaştır; aynı anda çok sayıda alışkanlık yükleme.
- Belirsiz veya önemli bir konuda varsayım yapma; en fazla bir netleştirici soru sor.
- Kullanıcının hazır oluşuna göre yönlendir: zorlamadan seçenek sun, ama gerektiğinde net ve kararlı bir öneri yap.
- Kriz, sigara isteği veya nüks anında 3 adımlı yaklaşım kullan: tetikleyiciyi adlandır, kısa süreli başa çıkma eylemi öner, kullanıcıdan sonucu/istek düzeyini sor. Yaşam koçluğu sorularında da aynı küçük adım yaklaşımını koru: bugün yapılabilecek bir davranış seç, engeli öngör ve takip sorusu sor.
- Nüksü başarısızlık olarak etiketleme. Ne olduğunu anlamaya, bir sonraki sigarayı ertelemeye ve planı yeniden kurmaya odaklan.
- Kullanıcı ilerleme bildirdiğinde bunu fark et ve somut biçimde güçlendir; abartılı övgü veya gerçek dışı vaat kullanma.
- Uzun dersler, klişeler ve art arda çok sayıda öneri verme. Genellikle 2-5 kısa paragraf veya kısa maddeler yeterlidir.
- Kullanıcıdan uygulama içindeki bilgileri tekrar tekrar isteme; mevcut konuşma bağlamını kullan.

KAPSAM VE ARAÇLAR:
- Öncelikli alanın No Smoke uygulaması ve sigarayı azaltma/bırakma sürecidir. Bunun yanında uyku düzeni, stres yönetimi, günlük rutin, hareket, su tüketimi, dengeli beslenme alışkanlıkları, odaklanma ve yaşam düzeni gibi genel sağlık ve yaşam koçluğu konularında da küçük, uygulanabilir ve güvenli öneriler ver. Bu önerileri sigara bırakma hedefiyle ilişkilendir; tıbbi tanı veya kişiye özel tedavi yerine davranış değişikliği koçluğu yap.
- Kod, çeviri, hukuki/finansal karar, teşhis veya konu dışı isteklerde kapsamı kısaça belirt ve uygun olduğunda konuşmayı sigarayı bırakma, sağlık alışkanlıkları veya yaşam düzenine yönlendir.
- Kullanıcı Koç Modu'nu veya ilaç/destek ürünü hatırlatıcı saatlerini değiştirmek isterse ilgili tool'u kullan. Emin değilsen önce netleştirici soru sor; kullanıcı açıkça istemeden ayar değiştirme.
- Kullanıcı bir izni açmak isterse set_permission tool'unu kullan. Android izinleri programatik olarak kapatılamaz; kapatma isteğinde tool kullanma ve telefon Ayarları'na yönlendir.
- Tool çağırdıktan sonra kullanıcıya yapılan işlemi, değiştirilmiş ayarı ve gerekiyorsa bir sonraki adımı kısaça açıkla.

SAĞLIK VE GÜVENLİK SINIRLARI:
- Sen doktor değilsin. Tanı koyma, tıbbi tedavi belirleme, ilaç başlatma/durdurma veya doz önerme.
- Yoksunluk belirtileri, ilaçlar, gebelik, ciddi hastalık, göğüs ağrısı, nefes darlığı, bayılma, yeme/uyku ile ilgili ağır bozulma veya şiddetli belirtilerde kullanıcıyı gecikmeden bir sağlık profesyoneline yönlendir. Acil tehlikede yerel acil yardım numarasını ara.
- Kullanıcı kendine zarar verme, yaşamak istememe veya benzeri kriz sinyali verirse sigara koçluğuna devam etme; empati kur, yalnız kalmamasını söyle ve Türkiye'de 112'yi veya bulunduğu yerdeki acil yardım hizmetini hemen aramasını öner.
- Kişisel sağlık verilerini gereksiz yere isteme ve kesin sonuç vaat etme.

YANIT DİLİ:
- Sistem tarafından verilen uygulama dilinde yanıt ver. Yanıtın doğal dil bölümlerini seçili dile çevir; tool adlarını, enum değerlerini, saat biçimlerini ve teknik parametreleri değiştirme.
`;


const TOOLS = [
  {
    type: "function",
    function: {
      name: "set_coach_mode",
      description:
        "Kullanıcının Koç Modu'nu (sigara arası bariyer görevlerini) açar veya kapatır, ve sıklığını değiştirir. Zorluk seviyesi diye ayrı bir eksen yok — kullanıcı 'sevmedim/kötü/beğenmedim' derse bunu kapatma isteği say.",
      parameters: {
        type: "object",
        properties: {
          preference: {
            type: "string",
            enum: ["like", "neutral", "dislike", "off"],
            description:
              "like/neutral=açık, dislike/off=kapalı. dislike ve off aynı sonucu üretir; ikisi de sadece geriye dönük uyumluluk için var.",
          },
          frequency: {
            type: "string",
            enum: ["az", "orta", "cok"],
            description: "Bariyer değişikliğinin sıklığı",
          },
        },
        required: ["preference"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "set_medication_times",
      description:
        "Kullanıcının seçtiği ilaç/destek ürünü için hatırlatıcı saatlerini ayarlar.",
      parameters: {
        type: "object",
        properties: {
          medicationName: {
            type: "string",
            description: "Mevcut ilaç veya destek ürününün adı",
          },
          times: {
            type: "array",
            items: {
              type: "string",
              pattern: "^([01]?\\d|2[0-3]):[0-5]\\d$",
            },
            description: "Hatırlatma saatleri; HH:mm biçiminde, örneğin 08:30",
          },
        },
        required: ["medicationName", "times"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "set_permission",
      description:
        "Kullanıcının uygulama izin tercihlerinden birini (mikrofon, konum, adım sayısı, sağlık verisi, kullanım erişimi) açmayı önerir.",
      parameters: {
        type: "object",
        properties: {
          permission: {
            type: "string",
            enum: [
              "microphone",
              "location",
              "activityRecognition",
              "health",
              "usageAccess",
            ],
            description:
              "microphone=nefes testi mikrofonu, location=Konum Zekası, activityRecognition=adım sayısı, health=Health Connect (nabız vb.), usageAccess=meşguliyet tespiti için uygulama kullanım erişimi",
          },
        },
        required: ["permission"],
      },
    },
  },
];

const PROVIDERS = [
  {
    name: "gemini",
    baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/",
    model: "gemini-3.6-flash",
    keyName: "geminiApiKey",
  },
  {
    name: "openai",
    baseURL: "https://api.openai.com/v1",
    model: "gpt-4o-mini",
    keyName: "openaiApiKey",
  },
];

function hasUsableKey(value) {
  return typeof value === "string" && value.trim().length > 0;
}

async function requestFromProvider(provider, apiKey, messages) {
  const client = new OpenAI({ baseURL: provider.baseURL, apiKey });
  return client.chat.completions.create({
    model: provider.model,
    messages,
    tools: TOOLS,
    tool_choice: "auto",
    max_tokens: 1600,
  });
}

function normalizeCompletion(completion, normalizedLanguage, providerName) {
  const choice = completion.choices?.[0]?.message;
  if (!choice) {
    throw new Error(`${providerName} returned an empty completion`);
  }

  const toolCall = choice.tool_calls?.[0];
  if (toolCall) {
    let args = {};
    try {
      args = JSON.parse(toolCall.function.arguments || "{}");
    } catch {
      args = {};
    }
    return {
      reply: choice.content?.trim() || "",
      action: { name: toolCall.function.name, arguments: args },
      language: normalizedLanguage,
      provider: providerName,
    };
  }

  return {
    reply: choice.content?.trim() || "",
    action: null,
    language: normalizedLanguage,
    provider: providerName,
  };
}

export async function chatWithAI({ geminiApiKey, openaiApiKey }, history, language = "en") {
  const normalizedLanguage = SUPPORTED_AI_LANGUAGES.has(language) ? language : "en";
  const languageInstruction = `Kullanıcının uygulama dili ${normalizedLanguage} kodudur. Yanıtının görünen tüm doğal dil bölümlerini bu dilde yaz. Teknik araç adlarını, enum değerlerini ve saat biçimlerini değiştirme.`;
  const messages = [
    { role: "system", content: `${SYSTEM_PROMPT}\n\n${languageInstruction}` },
    ...history,
  ];
  const errors = [];

  for (const provider of PROVIDERS) {
    const apiKey = provider.keyName === "geminiApiKey" ? geminiApiKey : openaiApiKey;
    if (!hasUsableKey(apiKey)) {
      errors.push(`${provider.name}: missing API key`);
      continue;
    }
    try {
      const completion = await requestFromProvider(provider, apiKey, messages);
      return normalizeCompletion(completion, normalizedLanguage, provider.name);
    } catch (error) {
      console.error(`${provider.name} AI request failed; trying next provider`, error);
      errors.push(`${provider.name}: ${error?.message || "request failed"}`);
    }
  }

  throw new Error(`No AI provider succeeded: ${errors.join("; ")}`);
}
