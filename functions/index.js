const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const geminiModel = defineString("GEMINI_MODEL", {
  default: "gemini-3.1-flash-lite",
});

exports.aiAdvice = onCall(
  {
    region: "us-central1",
    enforceAppCheck: true,
    secrets: [geminiApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 20,
  },
  async (request) => {
    if (!request.app) {
      throw new HttpsError("failed-precondition", "App Check required.");
    }

    const snapshot = request.data && request.data.snapshot;
    validateSnapshot(snapshot);

    const model = geminiModel.value().trim();
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": geminiApiKey.value(),
        },
        body: JSON.stringify(buildGeminiRequest(snapshot, model)),
      },
    );

    const raw = await response.text();
    if (!response.ok) {
      logger.warn("Gemini request failed", { status: response.status });
      throw new HttpsError("unavailable", "AI service is temporarily unavailable.");
    }

    let decoded;
    try {
      decoded = JSON.parse(raw);
    } catch (error) {
      logger.warn("Gemini returned non-JSON transport response");
      throw new HttpsError("internal", "AI returned an unexpected response.");
    }

    const items = extractAdviceItems(decoded);
    if (items.length < 2) {
      logger.warn("Gemini returned no usable advice items");
      throw new HttpsError("internal", "AI returned an empty response.");
    }

    return { items: items.slice(0, 4) };
  },
);

function validateSnapshot(snapshot) {
  if (!isPlainObject(snapshot)) {
    throw new HttpsError("invalid-argument", "Missing nutrition snapshot.");
  }

  const serialized = JSON.stringify(snapshot);
  if (Buffer.byteLength(serialized, "utf8") > 65000) {
    throw new HttpsError("invalid-argument", "Nutrition snapshot is too large.");
  }

  if (!["day", "week", "month"].includes(snapshot.period)) {
    throw new HttpsError("invalid-argument", "Unsupported advice period.");
  }

  if (!isPlainObject(snapshot.profile) || !isPlainObject(snapshot.daily_targets)) {
    throw new HttpsError("invalid-argument", "Nutrition snapshot is incomplete.");
  }
}

function buildGeminiRequest(snapshot, model) {
  const thinkingConfig = thinkingConfigFor(model);

  return {
    store: false,
    systemInstruction: {
      parts: [{ text: instructionsFor(snapshot.language_name) }],
    },
    contents: [
      {
        role: "user",
        parts: [{ text: JSON.stringify(snapshot) }],
      },
    ],
    generationConfig: {
      maxOutputTokens: 1200,
      responseMimeType: "application/json",
      responseSchema: {
        type: "object",
        properties: {
          items: {
            type: "array",
            minItems: 4,
            maxItems: 4,
            items: { type: "string" },
          },
        },
        required: ["items"],
      },
      ...(thinkingConfig ? { thinkingConfig } : {}),
    },
  };
}

function instructionsFor(languageName) {
  const lang = typeof languageName === "string" && languageName.trim()
    ? languageName.trim()
    : "the user's language";

  return `
You are Eco Fit's nutrition advisor. Answer only in ${lang}.
Use mainstream public-health nutrition guidance. Be practical and concise.
Analyze the user's daily food diary, calories, macros, and any micronutrients provided.
Use daily_target_gaps and micronutrient_reference_gaps for exact numbers.
If the snapshot period is week or month, focus on repeated patterns and averages, not one meal.
If logged_days is low for the selected period, say the conclusion is limited by missing diary data.
Mention likely deficiency or excess patterns only as risks, never as a diagnosis.
When relevant, explain what health problems may be associated with sustained lack or excess of nutrients or food groups.
Do not claim certainty from one day of data. If data is incomplete, say so briefly.
Never call a one-day intake a severe deficiency. Prefer neutral wording like "today is below target" or "if this repeats for weeks".
Recommend food changes first; supplements or medical care only when appropriate.
Do not spend an advice item on a generic medical disclaimer; the app shows that separately.
Each item should include: observed amount vs target, shortage/excess amount, possible long-term risk, and concrete foods to add/reduce when relevant.
Return exactly 4 advice items. Keep each item concise enough for a mobile card.
Return only valid JSON with this exact shape:
{"items":["short advice 1","short advice 2","short advice 3","short advice 4"]}
Do not use Markdown, bold text, headings, asterisks, code fences, or diagnosis labels.
Each item must be a complete sentence and fit on a mobile card.
`;
}

function thinkingConfigFor(model) {
  if (model.startsWith("gemini-2.5")) {
    return { thinkingBudget: 0 };
  }
  if (model.startsWith("gemini-3")) {
    return { thinkingLevel: "minimal" };
  }
  return null;
}

function extractAdviceItems(decoded) {
  const text = extractText(decoded);
  if (!text) return [];

  const compact = text.replace(/```(?:json)?|```/gi, "").trim();
  const start = compact.indexOf("{");
  const end = compact.lastIndexOf("}");
  if (start < 0 || end <= start) return [];

  try {
    const parsed = JSON.parse(compact.slice(start, end + 1));
    if (!Array.isArray(parsed.items)) return [];
    return parsed.items
      .filter((item) => typeof item === "string")
      .map(cleanAdviceItem)
      .filter((item) => item.length >= 12);
  } catch (error) {
    return [];
  }
}

function extractText(decoded) {
  const candidates = decoded && decoded.candidates;
  if (!Array.isArray(candidates)) return "";

  const parts = [];
  for (const candidate of candidates) {
    const contentParts = candidate && candidate.content && candidate.content.parts;
    if (!Array.isArray(contentParts)) continue;

    for (const piece of contentParts) {
      if (piece && typeof piece.text === "string" && piece.text.trim()) {
        parts.push(piece.text);
      }
    }
  }
  return parts.join("\n");
}

function cleanAdviceItem(value) {
  return value
    .replace(/\*\*|__|`/g, "")
    .replace(/^\s*(?:[-*]|\u2022)\s*/, "")
    .replace(/^\s*\d+[\).]\s*/, "")
    .replace(/\s+/g, " ")
    .trim();
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
