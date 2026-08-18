import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DEBUG_PLAN,
  PLAN_CONFIG,
  planForProduct,
  hashPurchaseToken,
  isProductMismatch,
} from "../plan.js";

test("planForProduct resolves known product ids", () => {
  assert.equal(planForProduct("no_smoke_starter"), PLAN_CONFIG.no_smoke_starter);
  assert.equal(planForProduct("no_smoke_plus"), PLAN_CONFIG.no_smoke_plus);
  assert.equal(planForProduct("no_smoke_pro"), PLAN_CONFIG.no_smoke_pro);
});

test("planForProduct rejects unknown or non-string ids, including 'debug'", () => {
  // The debug plan (10x the paid quota) must never be reachable through a
  // client-claimed productId — only through the explicit DEBUG_AI_BYPASS +
  // debugClient path in index.js. Regression test for the exploit where
  // claiming productId: "debug" on a real (any-plan) purchase token bought
  // 10x quota.
  assert.equal(planForProduct("debug"), null);
  assert.equal(planForProduct("unknown_product"), null);
  assert.equal(planForProduct(undefined), null);
  assert.equal(planForProduct(null), null);
  assert.equal(planForProduct(42), null);
});

test("DEBUG_PLAN is not present in PLAN_CONFIG under any key", () => {
  assert.ok(!Object.values(PLAN_CONFIG).includes(DEBUG_PLAN));
  assert.equal(PLAN_CONFIG.debug, undefined);
});

test("hashPurchaseToken is deterministic and does not echo the raw token", () => {
  const token = "a-real-looking-play-purchase-token";
  const hash = hashPurchaseToken(token);
  assert.equal(hash, hashPurchaseToken(token));
  assert.notEqual(hash, token);
  assert.match(hash, /^[0-9a-f]{64}$/);
});

test("hashPurchaseToken gives different tokens different hashes", () => {
  assert.notEqual(hashPurchaseToken("token-a"), hashPurchaseToken("token-b"));
});

test("isProductMismatch is false when the verified product matches the claim", () => {
  const result = { isActive: true, productId: "no_smoke_starter" };
  assert.equal(isProductMismatch(result, "no_smoke_starter"), false);
});

test("isProductMismatch is true when a real token is claimed under a different product", () => {
  // Regression test: paying for Starter, then calling verifySubscription
  // with productId: "no_smoke_pro" using that same (valid) Starter token
  // must not be able to grant Pro-level quota.
  const result = { isActive: true, productId: "no_smoke_starter" };
  assert.equal(isProductMismatch(result, "no_smoke_pro"), true);
  assert.equal(isProductMismatch(result, "debug"), true);
});

test("isProductMismatch is false for an inactive purchase regardless of claimed product", () => {
  // An inactive purchase is already rejected on that basis alone elsewhere;
  // this helper should not itself flag it as a "mismatch" case.
  const result = { isActive: false, productId: "no_smoke_starter" };
  assert.equal(isProductMismatch(result, "no_smoke_pro"), false);
});
