import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { chatWithAI } from "./ai.js";
import { verifyPlaySubscription } from "./subscription.js";

const nvidiaApiKey = defineSecret("NVIDIA_API_KEY");

const MAX_MESSAGE_LENGTH = 4000;
const MAX_HISTORY = 20;

function sanitizeHistory(history) {
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

const TRIAL_DURATION_MS = 14 * 24 * 60 * 60 * 1000;

// Whether the caller is allowed to use the AI mentor right now. There is
// no server-side user database (see subscription.js's stateless design),
// so this trusts the client-reported trialStartedAt for trial users — a
// known, accepted limitation (see the subscription plan doc): per-message
// cost is low and MAX_HISTORY/MAX_MESSAGE_LENGTH already bound it, so a
// forged trial date is a minor abuse case, not a blocking one. Purchased
// subscriptions are always re-verified against Google directly, never
// trusted from the client.
async function hasAiAccess(subscriptionProof) {
  const trialStartedAt = subscriptionProof?.trialStartedAt;
  if (typeof trialStartedAt === "string") {
    const startedMs = Date.parse(trialStartedAt);
    if (!Number.isNaN(startedMs) && Date.now() < startedMs + TRIAL_DURATION_MS) {
      return true;
    }
  }

  const { productId, purchaseToken } = subscriptionProof ?? {};
  if (typeof productId === "string" && typeof purchaseToken === "string") {
    try {
      const result = await verifyPlaySubscription({ productId, purchaseToken });
      return result.isActive;
    } catch (err) {
      console.error("aiChat subscription check failed", err);
      return false;
    }
  }

  return false;
}

export const aiChat = onCall(
  { secrets: [nvidiaApiKey], region: "europe-west1" },
  async (request) => {
    const history = sanitizeHistory(request.data?.history);
    if (!history) {
      throw new HttpsError("invalid-argument", "valid history is required");
    }

    const allowed = await hasAiAccess(request.data?.subscriptionProof);
    if (!allowed) {
      throw new HttpsError(
        "permission-denied",
        "trial expired or no active subscription"
      );
    }

    try {
      const result = await chatWithAI(nvidiaApiKey.value(), history);
      return result;
    } catch (err) {
      console.error("aiChat failed", err);
      throw new HttpsError("internal", "AI request failed");
    }
  }
);

export const verifySubscription = onCall(
  { region: "europe-west1" },
  async (request) => {
    const { productId, purchaseToken } = request.data ?? {};
    if (typeof productId !== "string" || typeof purchaseToken !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "productId and purchaseToken are required"
      );
    }

    try {
      return await verifyPlaySubscription({ productId, purchaseToken });
    } catch (err) {
      console.error("verifySubscription failed", err);
      throw new HttpsError("internal", "verification failed");
    }
  }
);
