import OpenAI from "openai";

const SYSTEM_PROMPT = `
Sen "No Smoke" adlı sigara azaltma/bırakma uygulamasının içindeki yapay zeka mentörüsün.
Görevin SADECE bu uygulama ve kullanıcının sigarayı azaltma/bırakma süreciyle ilgili konularda
yardımcı olmak: motivasyon, sigara arası süreyi uzatma stratejileri, kriz anlarında destek,
uygulamanın Koç Modu ve ilaç hatırlatıcı ayarlarını kullanıcı adına düzenlemeyi önermek.

Kurallar:
- Uygulama ve sigara bırakma dışındaki konularda (genel sohbet, kod yazma, spor, diyet, çeviri,
  vb.) yardımcı OLMA. Böyle bir istek gelirse kısaca "Ben sadece No Smoke uygulaması ve sigara
  bırakma sürecinle ilgili yardımcı olabilirim" de ve konuyu geri sigaraya/uygulamaya getir.
- Kullanıcı Koç Modu'nu (kolay/normal/zor bariyer ve sıklık) veya ilaç hatırlatıcı saatlerini
  değiştirmek isterse, ilgili tool'u çağır. Tool'u çağırmadan önce kullanıcının ne istediğinden
  eminsen çağır; belirsizse önce netleştirici soru sor.
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
            description:
              "like=zor/zorlayıcı, neutral=normal, dislike=kolay, off=kapalı",
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
        "Var olan bir ilacın hatırlatma saatlerini değiştirir. Saatler 24 saat formatında HH:mm olmalı.",
      parameters: {
        type: "object",
        properties: {
          medicationName: {
            type: "string",
            description: "Saatleri değişecek ilacın adı",
          },
          times: {
            type: "array",
            items: { type: "string" },
            description: "Yeni hatırlatma saatleri, örn. [\"08:00\", \"20:00\"]",
          },
        },
        required: ["medicationName", "times"],
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
      reply: choice.content || "",
      action: { name: toolCall.function.name, arguments: args },
    };
  }

  return { reply: choice.content || "", action: null };
}
