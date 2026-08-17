import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { chatWithAI } from "./ai.js";
import { verifyPlaySubscription } from "./subscription.js";
import { requireAuth, sanitizeHistory } from "./auth.js";

initializeApp();
const db = getFirestore();

// Provider keys are stored as Firebase Secrets (never in source code or the Flutter app).
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// This flag must be true only in the separate development Firebase project.
// Production must keep it false. The Flutter debug client also sends debugClient=true.
const DEBUG_AI_BYPASS = process.env.AI_DEBUG_BYPASS === "true";

const PLAN_CONFIG = Object.freeze({
  no_smoke_starter: Object.freeze({
    planId: "starter",
    dailyLimit: 10,
    monthlyLimit: 300,
  }),
  no_smoke_plus: Object.freeze({
    planId: "plus",
    dailyLimit: 30,
    monthlyLimit: 900,
  }),
  no_smoke_pro: Object.freeze({
    planId: "pro",
    dailyLimit: 60,
    monthlyLimit: 1800,
  }),
  debug: Object.freeze({
    planId: "debug",
    dailyLimit: 100,
    monthlyLimit: 3000,
  }),
});

function planForProduct(productId) {
  return typeof productId === "string" ? PLAN_CONFIG[productId] ?? null : null;
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
    return PLAN_CONFIG.debug;
  }

  const subscription = userData.subscription;
  const plan = planForProduct(subscription?.productId);
  const purchaseToken = subscription?.purchaseToken;
  if (!plan || typeof purchaseToken !== "string" || purchaseToken.length < 20) {
    return null;
  }

  try {
    const result = await verifyPlaySubscription({
      productId: subscription.productId,
      purchaseToken,
    });
    if (!result.isActive) return null;
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
      const result = await verifyPlaySubscription({ productId, purchaseToken });
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
      console.error("verifySubscription failed", err);
      throw new HttpsError("internal", "verification failed");
    }
  },
);
