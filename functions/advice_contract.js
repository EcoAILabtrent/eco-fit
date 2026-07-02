const ADVICE_KEYS = [
  "calories",
  "protein",
  "fat",
  "carbohydrates",
  "iron",
  "magnesium",
  "calcium",
  "phosphorus",
  "potassium",
  "sodium",
  "zinc",
  "vitamin_a",
  "vitamin_c",
  "vitamin_d",
  "vitamin_e",
  "vitamin_k",
  "vitamin_b1",
  "vitamin_b2",
  "vitamin_b3",
  "vitamin_b6",
  "vitamin_b9",
  "vitamin_b12",
  "copper",
  "manganese",
  "selenium",
  "iodine",
  "molybdenum",
  "chromium",
  "chloride",
  "fluoride",
  "choline",
  "biotin",
  "pantothenic_acid",
];

function extractAdviceItems(decoded) {
  const text = extractText(decoded);
  if (!text) return [];

  const compact = text.replace(/```(?:json)?|```/gi, "").trim();
  const start = compact.indexOf("{");
  const end = compact.lastIndexOf("}");
  if (start < 0 || end <= start) return [];

  try {
    const parsed = JSON.parse(compact.slice(start, end + 1));
    if (!isPlainObject(parsed.advice)) return [];
    return ADVICE_KEYS.flatMap((id) => {
      const value = parsed.advice[id];
      if (typeof value !== "string") return [];
      const cleaned = cleanAdviceItem(value);
      return cleaned.length >= 12 ? [{ id, text: cleaned }] : [];
    });
  } catch (error) {
    return [];
  }
}

function extractText(decoded) {
  const choices = decoded && decoded.choices;
  if (!Array.isArray(choices)) return "";

  return choices
    .map((choice) => choice && choice.message && choice.message.content)
    .filter((content) => typeof content === "string" && content.trim())
    .join("\n");
}

function cleanAdviceItem(value) {
  return value
    .replace(/\*\*|__|`/g, "")
    .replace(/^\s*(?:[-*]|\u2022)\s*/, "")
    .replace(/^\s*\d+[\).]\s*/, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 700)
    .trim();
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

module.exports = { ADVICE_KEYS, extractAdviceItems };
