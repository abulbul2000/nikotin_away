import { google } from "googleapis";

const PACKAGE_NAME = "com.nikotinaway.app";

const ACTIVE_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
]);

async function getAndroidPublisherClient() {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  return google.androidpublisher({ version: "v3", auth });
}

// Stateless on purpose: this function never persists anything about the
// purchase it's asked to verify. It just asks Google "is this token
// active right now" and hands the answer straight back — the app itself
// (subscription_state table, device-side) is the only place a durable
// record of the result lives. See the subscription plan doc for why: the
// project keeps user data on-device by default, and adding a server-side
// user/subscription database here would be a bigger architectural change
// than this feature needs.
export async function verifyPlaySubscription({ productId, purchaseToken }) {
  const publisher = await getAndroidPublisherClient();
  const res = await publisher.purchases.subscriptionsv2.get({
    packageName: PACKAGE_NAME,
    token: purchaseToken,
  });

  const state = res.data.subscriptionState;
  const lineItem = res.data.lineItems?.[0];

  return {
    isActive: ACTIVE_STATES.has(state),
    expiryTimeMillis: lineItem?.expiryTime
      ? Date.parse(lineItem.expiryTime)
      : null,
    autoRenewing: !!lineItem?.autoRenewingPlan?.autoRenewEnabled,
    rawState: state ?? null,
  };
}
