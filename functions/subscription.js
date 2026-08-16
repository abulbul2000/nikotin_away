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

// This helper only talks to Google Play and returns the current entitlement.
// The caller stores the verified product/token server-side so aiChat can
// enforce access and quotas without trusting the Flutter client.
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
