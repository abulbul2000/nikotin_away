import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "https://integrate.api.nvidia.com/v1",
  apiKey: "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"
});

export async function chatWithAI(messages) {
  const completion = await client.chat.completions.create({
    model: "nvidia/nemotron-3.5-lightning-30b-a3b",
    messages: messages
  });

  return completion.choices[0].message.content;
}
