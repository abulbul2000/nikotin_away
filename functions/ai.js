import OpenAI from "openai";

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
        "Kullanıcının ilaç/destek ürünü hatırlatıcı saatlerini ayarlar veya temizler.",
      parameters: {
        type: "object",
        properties: {
          times: {
            type: "array",
            items: {
              type: "object",
              properties: {
                hour: { type: "integer", minimum: 0, maximum: 23 },
                minute: { type: "integer", minimum: 0, maximum: 59 },
              },
              required: ["hour", "minute"],
            },
            description: "Hatırlatma saatleri (24 saatlik format)",
          },
          clear: {
            type: "boolean",
            description:
              "true ise mevcut hatırlatmalar silinir, times alanı yok sayılır",
          },
        },
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

export async function chatWithAI(apiKey, history) {
  const client = new OpenAI({
    baseURL: "https://integrate.api.nvidia.com/v1",
    apiKey,
  });

  const completion = await client.chat.completions.create({
    model: "nvidia/nemotron-3.5-lightning-30b-a3b",
    messages: [{ role: "system", content: SYSTEM_PROMPT }, ...history],
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
    };
  }

  return { reply: choice.content?.trim() || "", action: null };
}
