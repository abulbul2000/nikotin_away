import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { chatWithAI } from "./ai.js";
import { verifyPlaySubscription } from "./subscription.js";
import { requireAuth, sanitizeHistory } from "./auth.js";
import { DEBUG_PLAN, planForProduct, hashPurchaseToken, isProductMismatch } from "./plan.js";

initializeApp();
const db = getFirestore();

// Provider keys are stored as Firebase Secrets (never in source code or the Flutter app).
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// The bypass is available only to the dedicated development project and only
// when the caller is also a Flutter debug client. The explicit env flag remains
// supported for local emulators, but a production project can never enable the
// bypass accidentally by inheriting a shared environment variable.
const DEVELOPMENT_PROJECT_ID = "nikotin-away-development-eb94d";
const DEBUG_AI_BYPASS =
  process.env.AI_DEBUG_BYPASS === "true" ||
  process.env.GCLOUD_PROJECT === DEVELOPMENT_PROJECT_ID;

// Claims purchaseToken for uid, atomically. A Play purchase token identifies
// one specific purchase — legitimately it should only ever belong to the
// account that bought it. Without this check, one real purchase token could
// be shared (posted in a forum, sold, etc.) and replayed by an unlimited
// number of other UIDs, each getting full access off a single payment.
// Throws if the token is already claimed by a different uid.
async function claimPurchaseTokenOrThrow(uid, purchaseToken) {
  const tokenRef = db.collection("purchase_tokens").doc(hashPurchaseToken(purchaseToken));
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(tokenRef);
    if (snap.exists && snap.data().uid !== uid) {
      throw new HttpsError(
        "already-exists",
        "this purchase is already linked to a different account",
      );
    }
    tx.set(tokenRef, { uid, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
}

async function getOrCreateUserDoc(uid) {
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  if (snap.exists) return { ref, data: snap.data() };
  const data = { createdAt: FieldValue.serverTimestamp() };
  await ref.set(data, { merge: true });
  const freshSnap = await ref.get();
  return { ref, data: freshSnap.data() };
}

async function resolveAiEntitlement(request, userData) {
  if (DEBUG_AI_BYPASS && request.data?.debugClient === true) {
    return DEBUG_PLAN;
  }

  const subscription = userData.subscription;
  const plan = planForProduct(subscription?.productId);
  const purchaseToken = subscription?.purchaseToken;
  if (!plan || typeof purchaseToken !== "string" || purchaseToken.length < 20) {
    return null;
  }

  try {
    const result = await verifyPlaySubscription({ purchaseToken });
    if (!result.isActive || isProductMismatch(result, subscription.productId)) {
      return null;
    }
    return plan;
  } catch (err) {
    console.error("aiChat subscription check failed", err);
    return null;
  }
}

async function consumeQuota(uid, plan) {
  const now = new Date();
  const dayKey = now.toISOString().slice(0, 10);
  const monthKey = now.toISOString().slice(0, 7);
  const userRef = db.collection("users").doc(uid);
  const dailyRef = userRef.collection("aiUsageDaily").doc(dayKey);
  const monthlyRef = userRef.collection("aiUsageMonthly").doc(monthKey);

  return db.runTransaction(async (tx) => {
    const dailySnap = await tx.get(dailyRef);
    const monthlySnap = await tx.get(monthlyRef);
    const dailyCount = dailySnap.exists ? dailySnap.data().count ?? 0 : 0;
    const monthlyCount = monthlySnap.exists ? monthlySnap.data().count ?? 0 : 0;

    if (dailyCount >= plan.dailyLimit || monthlyCount >= plan.monthlyLimit) {
      return false;
    }

    tx.set(
      dailyRef,
      { count: dailyCount + 1, planId: plan.planId, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    tx.set(
      monthlyRef,
      { count: monthlyCount + 1, planId: plan.planId, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return true;
  });
}

export const aiChat = onCall(
  {
    region: "europe-west1",
    // Development bypass avoids requiring a registered Android debug token.
    // Production keeps App Check enforcement because DEBUG_AI_BYPASS is false.
    enforceAppCheck: !DEBUG_AI_BYPASS,
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
    // Behavior-engine output only (trigger names, hour labels, a risk
    // level) — never user-typed text — but still passed through as a plain
    // object rather than trusted field-by-field; ai.js's own sanitizer is
    // what actually bounds what reaches the prompt.
    const behaviorContext =
      request.data?.behaviorContext &&
      typeof request.data.behaviorContext === "object" &&
      !Array.isArray(request.data.behaviorContext)
        ? request.data.behaviorContext
        : null;

    const { data: userData } = await getOrCreateUserDoc(uid);
    const plan = await resolveAiEntitlement(request, userData);
    if (!plan) {
      throw new HttpsError(
        "permission-denied",
        "an active AI subscription is required",
      );
    }

    const withinQuota = await consumeQuota(uid, plan);
    if (!withinQuota) {
      throw new HttpsError(
        "resource-exhausted",
        "your AI usage limit for this period has been reached",
      );
    }

    try {
      const result = await chatWithAI(
        {
          geminiApiKey: GEMINI_API_KEY.value(),
          openaiApiKey: null,
        },
        history,
        language,
        behaviorContext,
      );
      return {
        ...result,
        planId: plan.planId,
        dailyLimit: plan.dailyLimit,
        monthlyLimit: plan.monthlyLimit,
      };
    } catch (err) {
      console.error("aiChat failed", err);
      throw new HttpsError("internal", "AI request failed");
    }
  },
);

export const verifySubscription = onCall(
  {
    region: "europe-west1",
    // Keep production verification strict; development bypass is explicit.
    enforceAppCheck: !DEBUG_AI_BYPASS,
  },
  async (request) => {
    const uid = requireAuth(request);
    const { productId, purchaseToken } = request.data ?? {};
    const plan = planForProduct(productId);
    if (!plan || typeof purchaseToken !== "string") {
      throw new HttpsError("invalid-argument", "valid product and purchase token are required");
    }

    try {
      const result = await verifyPlaySubscription({ purchaseToken });
      if (isProductMismatch(result, productId)) {
        // The token is real, but for a different product than the client
        // claimed — e.g. paying for Starter and claiming Pro. Trust what
        // Play reports the token is actually for, not what the client sent.
        throw new HttpsError(
          "invalid-argument",
          "purchase token does not match the requested product",
        );
      }

      if (result.isActive) {
        await claimPurchaseTokenOrThrow(uid, purchaseToken);
      }

      const userRef = db.collection("users").doc(uid);
      await userRef.set(
        {
          subscription: result.isActive
            ? {
                productId,
                planId: plan.planId,
                purchaseToken,
                expiryTimeMillis: result.expiryTimeMillis,
                autoRenewing: result.autoRenewing,
                lastVerifiedAt: FieldValue.serverTimestamp(),
              }
            : FieldValue.delete(),
        },
        { merge: true },
      );
      return { ...result, planId: plan.planId };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("verifySubscription failed", err);
      throw new HttpsError("internal", "verification failed");
    }
  },
);
