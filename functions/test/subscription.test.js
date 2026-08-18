import { test, mock } from "node:test";
import assert from "node:assert/strict";
import { google } from "googleapis";
import { verifyPlaySubscription } from "../subscription.js";

// verifyPlaySubscription's only external dependency is
// google.androidpublisher(...).purchases.subscriptionsv2.get(...). Node's
// built-in test mocking stubs that one call for the duration of each test
// and restores it in teardown, so this never talks to real Play servers —
// consistent with plan.test.js/auth.test.js only exercising pure logic,
// this isolates the one impure call this file makes.
function stubAndroidPublisher(getImpl) {
  return mock.method(google, "androidpublisher", () => ({
    purchases: {
      subscriptionsv2: {
        get: getImpl,
      },
    },
  }));
}

test.afterEach(() => {
  mock.restoreAll();
});

test("an active subscription is reported active with its line item details", async () => {
  stubAndroidPublisher(async () => ({
    data: {
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      lineItems: [
        {
          productId: "no_smoke_starter",
          expiryTime: "2026-09-01T00:00:00Z",
          autoRenewingPlan: { autoRenewEnabled: true },
        },
      ],
    },
  }));

  const result = await verifyPlaySubscription({ purchaseToken: "tok-active" });

  assert.equal(result.isActive, true);
  assert.equal(result.productId, "no_smoke_starter");
  assert.equal(result.expiryTimeMillis, Date.parse("2026-09-01T00:00:00Z"));
  assert.equal(result.autoRenewing, true);
  assert.equal(result.rawState, "SUBSCRIPTION_STATE_ACTIVE");
});

test("a grace-period subscription still counts as active", async () => {
  // Grace period is the whole point of ACTIVE_STATES being a set rather
  // than a single string — a lapsed payment that Play is still retrying
  // must not immediately lock the user out.
  stubAndroidPublisher(async () => ({
    data: {
      subscriptionState: "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      lineItems: [{ productId: "no_smoke_plus" }],
    },
  }));

  const result = await verifyPlaySubscription({ purchaseToken: "tok-grace" });

  assert.equal(result.isActive, true);
  assert.equal(result.rawState, "SUBSCRIPTION_STATE_IN_GRACE_PERIOD");
});

test("a canceled or expired subscription is reported inactive", async () => {
  stubAndroidPublisher(async () => ({
    data: {
      subscriptionState: "SUBSCRIPTION_STATE_CANCELED",
      lineItems: [{ productId: "no_smoke_starter" }],
    },
  }));

  const result = await verifyPlaySubscription({ purchaseToken: "tok-canceled" });

  assert.equal(result.isActive, false);
  assert.equal(result.rawState, "SUBSCRIPTION_STATE_CANCELED");
});

test("a missing subscriptionState is reported inactive rather than throwing", async () => {
  stubAndroidPublisher(async () => ({ data: {} }));

  const result = await verifyPlaySubscription({ purchaseToken: "tok-empty" });

  assert.equal(result.isActive, false);
  assert.equal(result.productId, null);
  assert.equal(result.expiryTimeMillis, null);
  assert.equal(result.autoRenewing, false);
  assert.equal(result.rawState, null);
});

test("a missing lineItems array does not throw and reports empty details", async () => {
  stubAndroidPublisher(async () => ({
    data: { subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" },
  }));

  const result = await verifyPlaySubscription({ purchaseToken: "tok-no-lineitem" });

  assert.equal(result.isActive, true);
  assert.equal(result.productId, null);
  assert.equal(result.expiryTimeMillis, null);
  assert.equal(result.autoRenewing, false);
});

test("queries Play with the app's own package name and the given token, not the caller's productId", async () => {
  // The function's own comment: it ignores any caller-supplied productId
  // entirely when talking to Play — the token alone determines what Play
  // reports back. This is a regression guard for that contract: if a
  // productId parameter is ever added to the call, it must not leak into
  // the request Play receives ahead of verification.
  let receivedArgs;
  stubAndroidPublisher(async (args) => {
    receivedArgs = args;
    return { data: { subscriptionState: "SUBSCRIPTION_STATE_ACTIVE", lineItems: [] } };
  });

  await verifyPlaySubscription({ purchaseToken: "the-real-token" });

  assert.equal(receivedArgs.packageName, "com.nikotinaway.app");
  assert.equal(receivedArgs.token, "the-real-token");
  assert.equal(Object.keys(receivedArgs).length, 2);
});
