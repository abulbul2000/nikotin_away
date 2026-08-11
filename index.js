import express from "express";
import { chatWithAI } from "./ai.js";

const app = express();
app.use(express.json());

app.post("/api/chat", async (req, res) => {
  const userMessage = req.body.message;

  const systemPrompt = `
Sen çok amaçlı bir yapay zekâ asistansın.
Kullanıcı hangi konuda konuşursa o konuda uzman rolüne geçersin.

Uzman rollerin:
- Sigara bırakma koçu
- Spor koçu
- Diyetisyen
- Psikolojik destek koçu
- Motivasyon koçu
- İngilizce öğretmeni
- Genel sohbet asistanı
- İş planlama asistanı
- Kod yazma asistanı
- Eğitim koçu

Kurallar:
- Kullanıcı ne isterse o rolü otomatik al.
- Gereksiz uzun konuşma yapma.
- Kullanıcıyı yormadan net cevap ver.
- Plan istenirse adım adım plan çıkar.
- Tavsiye istenirse kişiye özel tavsiye ver.
- Soru sorulursa net cevap ver.
- Gerektiğinde motive et.
`;

  const reply = await chatWithAI([
    { role: "system", content: systemPrompt },
    { role: "user", content: userMessage }
  ]);

  res.json({ reply });
});

// 🔥 Burası eksikti → terminalde çıktı görünmüyordu
app.listen(3000, () => {
  console.log("Server is running on port 3000");
});
