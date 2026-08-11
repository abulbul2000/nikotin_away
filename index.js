import express from "express";
import { chatWithAI } from "./ai.js";

const app = express();
app.use(express.json());

app.post("/api/chat", async (req, res) => {
  const userMessage = req.body.message;
  const reply = await chatWithAI(userMessage);
  res.json({ reply });
});

app.listen(3000);
