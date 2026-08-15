import OpenAI from "openai";

const SUPPORTED_AI_LANGUAGES = new Set([
  "tr", "en", "de", "ar", "fr", "es", "pt", "it", "pl", "ru", "ja",
  "zh", "ko", "hi", "bn", "pa", "te", "mr", "ta", "gu", "kn", "ml",
  "th", "vi", "id", "ms", "fil", "uk", "ro", "el", "hu", "cs", "sv",
  "da", "no", "fi", "nl", "be", "sr", "hr",
]);

const SYSTEM_PROMPT = `
Sen "No Smoke" adlı sigara azaltma/bırakma uygulamasının içindeki yapay zeka mentörüsün.
Görevin SADECE bu uygulama ve kullanıcının sigarayı azaltma/bırakma süreciyle ilgili konularda
yardımcı olmak: motivasyon, sigara arası süreyi uzatma stratejileri, kriz anlarında destek,
uygulamanın Koç Modu, ilaç hatırlatıcı ve izin ayarlarını kullanıcı adına düzenlemeyi önermek.

Kurallar:
- Uygulama ve sigara bırakma dışındaki konularda (genel sohbet, kod yazma, spor, diyet, çeviri,
  vb.) yardımcı OLMA. Böyle bir istek gelirse kısaca "Ben sadece No Smoke uygulaması ve sigara
  bırakma sürecinle ilgili yardımcı olabilirim" de ve konuyu geri sigaraya/uygulamaya getir.
- Kullanıcı Koç Modu'nu (kolay/normal/zor bariyer ve sıklık) veya ilaç hatırlatıcı saatlerini
  değiştirmek isterse, ilgili tool'u çağır. Tool'u çağırmadan önce kullanıcının ne istediğinden
  eminsen çağır; belirsizse önce netleştirici soru sor.
- Kullanıcı bir izni (mikrofon, konum, adım sayısı, sağlık verisi, kullanım erişimi) açmak
  isterse set_permission tool'unu çağır. Android bir izni programatik olarak KAPATMAYA izin
  vermez — kullanıcı bir izni kapatmak isterse tool çağırma, bunun için telefon Ayarlar'ından
  uygulama izinlerine gitmesi gerektiğini söyle.
- Asla tıbbi doz, tanı veya tedavi önerisi verme; sağlık konularında "doktorunuza danışın" de.
- Gereksiz uzun konuşma yapma, net ve kısa cevap ver.
`;

const TOOLS = [
  {
    type: "function",
    function: {
      name: "set_coach_mode",
      description:
        "Kullanıcının Koç Modu tercihini (sigara arası bariyerin ne kadar zorlayıcı olacağı) ve sıklığını değiştirir.",
      parameters: {
        type: "object",
        properties: {
          preference: {
            type: "string",
            enum: ["like", "neutral", "dislike", "off"],
            description: "like=zor/zorlayıcı, neutral=normal, dislike=kolay, off=kapalı",
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

export async function chatWithAI(apiKey, history, language = "en") {
  const normalizedLanguage = SUPPORTED_AI_LANGUAGES.has(language) ? language : "en";
  const languageInstruction = `Kullanıcının uygulama dili ${normalizedLanguage} kodudur. Yanıtının görünen tüm doğal dil bölümlerini bu dilde yaz. Teknik araç adlarını, enum değerlerini ve saat biçimlerini değiştirme.`;
  const client = new OpenAI({
    baseURL: "https://integrate.api.nvidia.com/v1",
    apiKey,
  });

  const completion = await client.chat.completions.create({
    model: "nvidia/nemotron-3.5-lightning-30b-a3b",
    messages: [
      { role: "system", content: `${SYSTEM_PROMPT}\n\n${languageInstruction}` },
      ...history,
    ],
    tools: TOOLS,
    max_tokens: 800,
  });

  const choice = completion.choices[0].message;
  const toolCall = choice.tool_calls?.[0];

  if (toolCall) {
    let args = {};
    try {
      args = JSON.parse(toolCall.function.arguments);
    } catch {
      args = {};
    }
    return {
      reply: choice.content?.trim() || "",
      action: { name: toolCall.function.name, arguments: args },
      language: normalizedLanguage,
    };
  }

  return {
    reply: choice.content?.trim() || "",
    action: null,
    language: normalizedLanguage,
  };
}
