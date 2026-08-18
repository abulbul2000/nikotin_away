import { createHash } from "node:crypto";

// No I/O — kept separate from index.js so it can be unit-tested without
// initializing firebase-admin or talking to a real Firestore/Play backend
// (see test/plan.test.js). Mirrors the auth.js split.

// Only ever reachable through the DEBUG_AI_BYPASS + debugClient path in
// index.js — never through planForProduct, so no purchased/claimed
// productId can select it. Keeping it out of PLAN_CONFIG is what makes that
// true; a prior version had it in PLAN_CONFIG, which meant claiming
// productId: "debug" on a verifySubscription call (with any real purchase
// token) bought 10x quota.
export const DEBUG_PLAN = Object.freeze({
  planId: "debug",
  dailyLimit: 100,
  monthlyLimit: 3000,
});

export const PLAN_CONFIG = Object.freeze({
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
});

export function planForProduct(productId) {
  return typeof productId === "string" ? PLAN_CONFIG[productId] ?? null : null;
}

export function hashPurchaseToken(purchaseToken) {
  return createHash("sha256").update(purchaseToken).digest("hex");
}

// True when a Play-verified purchase should be rejected because it is for a
// different product than the client claimed (e.g. paying for Starter and
// claiming Pro/debug). Only meaningful when the purchase is actually active
// — an inactive/cancelled purchase is already rejected on that basis alone.
export function isProductMismatch({ isActive, productId: verifiedProductId }, claimedProductId) {
  return isActive && verifiedProductId !== claimedProductId;
}
