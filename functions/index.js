import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { chatWithAI } from "./ai.js";
import { verifyPlaySubscription } from "./subscription.js";
import { requireAuth, sanitizeHistory } from "./auth.js";

initializeApp();
const db = getFirestore();

// Provider keys are stored as Firebase Secrets (never in source code or the Flutter app).
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const TRIAL_DURATION_MS = 14 * 24 * 60 * 60 * 1000;
const DAILY_MESSAGE_LIMIT = 50;

// Reads/creates users/{uid} and returns its trial/subscription fields.
// trialStartedAt is set exactly once, from the server clock, on the first
// call any given uid ever makes — this is the only source of truth for
// "when did this user's trial start" (see functions.js's now-removed
// client-reported subscriptionProof, which this replaces).
async function getOrCreateUserDoc(uid) {
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  if (snap.exists) {
    return { ref, data: snap.data() };
  }
  const data = { trialStartedAt: FieldValue.serverTimestamp() };
  await ref.set(data, { merge: true });
  const freshSnap = await ref.get();
  return { ref, data: freshSnap.data() };
}

// AI is currently free for all users (no subscription required).
// When monetization is enabled in production, re-enable the trial/subscription
// check below and remove this early return.
async function hasAiAccess(uid, userData) {
  return true;

  // --- Re-enable for monetized version ---
  // const trialStartedAt = userData.trialStartedAt?.toMillis?.();
  // if (typeof trialStartedAt === "number" && Date.now() < trialStartedAt + TRIAL_DURATION_MS) {
  //   return true;
  // }
  // const subscription = userData.subscription;
  // const productId = subscription?.productId;
  // const purchaseToken = subscription?.purchaseToken;
  // if (typeof productId === "string" && typeof purchaseToken === "string") {
  //   try {
  //     const result = await verifyPlaySubscription({ productId, purchaseToken });
  //     return result.isActive;
  //   } catch (err) {
  //     console.error("aiChat subscription check failed", err);
  //     return false;
  //   }
  // }
  // return false;
}

// Per-uid, per-day message counter under users/{uid}/aiUsage/{YYYY-MM-DD}.
// A transaction avoids a race between concurrent calls from the same user
// (e.g. two in-flight requests) both reading the count before either
// writes it back.
async function consumeDailyMessageQuota(uid) {
  const today = new Date().toISOString().slice(0, 10);
  const usageRef = db
    .collection("users")
    .doc(uid)
    .collection("aiUsage")
    .doc(today);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(usageRef);
    const count = snap.exists ? snap.data().count ?? 0 : 0;
    if (count >= DAILY_MESSAGE_LIMIT) {
      return false;
    }
    tx.set(usageRef, { count: count + 1 }, { merge: true });
    return true;
  });
}

// AI requests must carry a verified App Check token so a copied client
// cannot freely consume provider secrets or forge the app's trial flow.
export const aiChat = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
    secrets: [GEMINI_API_KEY],
  },
  async (request) => {
    const uid = requireAuth(request);

    const history = sanitizeHistory(request.data?.history);
    const requestedLanguage =
      typeof request.data?.language === "string"
        ? request.data.language.toLowerCase().trim()
        : "en";
    const language = /^[a-z]{2,3}$/.test(requestedLanguage)
      ? requestedLanguage
      : "en";
    if (!history) {
      throw new HttpsError("invalid-argument", "valid history is required");
    }

    const { data: userData } = await getOrCreateUserDoc(uid);

    const allowed = await hasAiAccess(uid, userData);
    if (!allowed) {
      throw new HttpsError(
        "permission-denied",
        "trial expired or no active subscription"
      );
    }

    const withinQuota = await consumeDailyMessageQuota(uid);
    if (!withinQuota) {
      throw new HttpsError(
        "resource-exhausted",
        "daily message limit reached"
      );
    }

    try {
      const result = await chatWithAI(
        {
          geminiApiKey: GEMINI_API_KEY.value(),
          openaiApiKey: null,
        },
        history,
        language
      );
      // Echoed back so the client can sync its local subscription_state
      // cache (see SubscriptionService.resolveAccess) with the
      // server-authoritative trial start — the server value always wins,
      // the client copy is a read cache for the offline-friendly access
      // check, never the source of truth.
      const trialStartedAtMs = userData.trialStartedAt?.toMillis?.() ?? Date.now();
      return { ...result, trialStartedAtMs };
    } catch (err) {
      console.error("aiChat failed", err);
      throw new HttpsError("internal", "AI request failed");
    }
  }
);

export const verifySubscription = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);

    const { productId, purchaseToken } = request.data ?? {};
    if (typeof productId !== "string" || typeof purchaseToken !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "productId and purchaseToken are required"
      );
    }

    try {
      const result = await verifyPlaySubscription({ productId, purchaseToken });
      // Recorded so aiChat's hasAiAccess can re-check this subscription
      // without the client having to resend the purchase token on every
      // chat message — the client remains the source of truth for *when*
      // to call verifySubscription (see SubscriptionService.handlePurchase),
      // this just lets the server remember the last-verified result.
      await db
        .collection("users")
        .doc(uid)
        .set(
          {
            subscription: result.isActive
              ? { productId, purchaseToken }
              : FieldValue.delete(),
          },
          { merge: true }
        );
      return result;
    } catch (err) {
      console.error("verifySubscription failed", err);
      throw new HttpsError("internal", "verification failed");
    }
  }
);
