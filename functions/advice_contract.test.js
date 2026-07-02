const test = require("node:test");
const assert = require("node:assert/strict");

const { ADVICE_KEYS, extractAdviceItems } = require("./advice_contract");

function response(content) {
  return { choices: [{ message: { content } }] };
}

test("extracts the complete named advice contract in canonical order", () => {
  const advice = Object.fromEntries(
    ADVICE_KEYS.map((key) => [key, `A sufficiently detailed ${key} observation.`]),
  );

  const items = extractAdviceItems(response(JSON.stringify({ advice })));

  assert.deepEqual(items.map((item) => item.id), ADVICE_KEYS);
  assert.equal(items.length, ADVICE_KEYS.length);
});

test("keeps valid named fields and ignores missing or unknown fields", () => {
  const items = extractAdviceItems(response(JSON.stringify({
    advice: {
      calories: "A useful calorie observation for the current period.",
      magnesium: "A useful magnesium observation for the current period.",
      unknown: "This field must never reach the client.",
      fat: "short",
    },
  })));

  assert.deepEqual(items.map((item) => item.id), ["calories", "magnesium"]);
});

test("rejects the old positional array contract", () => {
  const items = extractAdviceItems(response(JSON.stringify({
    items: ADVICE_KEYS.map((key) => `${key} advice without a stable identifier`),
  })));

  assert.deepEqual(items, []);
});
