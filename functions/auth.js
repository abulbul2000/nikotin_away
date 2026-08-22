import { HttpsError } from "firebase-functions/v2/https";

// No I/O — kept separate from index.js so it can be unit-tested without
// initializing firebase-admin or talking to a real Firestore/App Check
// backend (see test/auth.test.js).
export function requireAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "sign-in required");
  }
  return uid;
}

export const MAX_MESSAGE_LENGTH = 4000;
export const MAX_HISTORY = 20;

export function sanitizeHistory(history) {
  if (!Array.isArray(history)) return null;
  if (history.length === 0 || history.length > MAX_HISTORY) return null;

  const cleaned = [];
  for (const entry of history) {
    const role = entry?.role;
    const content = entry?.content;
    if ((role !== "user" && role !== "assistant") || typeof content !== "string") {
      return null;
    }
    if (content.length === 0 || content.length > MAX_MESSAGE_LENGTH) return null;
    cleaned.push({ role, content });
  }
  return cleaned;
}
