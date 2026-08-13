import { test } from "node:test";
import assert from "node:assert/strict";
import { HttpsError } from "firebase-functions/v2/https";
import { requireAuth, sanitizeHistory, MAX_HISTORY, MAX_MESSAGE_LENGTH } from "../auth.js";

test("requireAuth throws unauthenticated when request.auth is missing", () => {
  assert.throws(
    () => requireAuth({}),
    (err) => err instanceof HttpsError && err.code === "unauthenticated"
  );
});

test("requireAuth throws unauthenticated when request.auth.uid is missing", () => {
  assert.throws(
    () => requireAuth({ auth: {} }),
    (err) => err instanceof HttpsError && err.code === "unauthenticated"
  );
});

test("requireAuth returns the uid when present", () => {
  assert.equal(requireAuth({ auth: { uid: "user-123" } }), "user-123");
});

test("sanitizeHistory rejects non-array input", () => {
  assert.equal(sanitizeHistory(undefined), null);
  assert.equal(sanitizeHistory("not an array"), null);
});

test("sanitizeHistory rejects empty or oversized history", () => {
  assert.equal(sanitizeHistory([]), null);
  const tooLong = Array.from({ length: MAX_HISTORY + 1 }, () => ({
    role: "user",
    content: "hi",
  }));
  assert.equal(sanitizeHistory(tooLong), null);
});

test("sanitizeHistory rejects invalid roles and oversized messages", () => {
  assert.equal(sanitizeHistory([{ role: "system", content: "hi" }]), null);
  assert.equal(
    sanitizeHistory([{ role: "user", content: "a".repeat(MAX_MESSAGE_LENGTH + 1) }]),
    null
  );
});

test("sanitizeHistory accepts a valid history", () => {
  const history = [
    { role: "user", content: "merhaba" },
    { role: "assistant", content: "selam" },
  ];
  assert.deepEqual(sanitizeHistory(history), history);
});
