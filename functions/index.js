const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineInt, defineSecret, defineString } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { ADVICE_KEYS, extractAdviceItems } = require("./advice_contract");

const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");
const deepseekModel = defineString("DEEPSEEK_MODEL", {
  default: "deepseek-v4-flash",
});
const rateLimitWindowSeconds = defineInt("AI_ADVICE_RATE_LIMIT_WINDOW_SECONDS", {
  default: 60,
});
const rateLimitMaxRequests = defineInt("AI_ADVICE_RATE_LIMIT_MAX_REQUESTS", {
  default: 8,
});

const rateLimitBuckets = new Map();
const supportedLanguages = new Map([
  ["en", "English"],
  ["ru", "Russian"],
  ["uz_latn", "Uzbek in Latin script"],
  ["uz_cyrl", "Uzbek in Cyrillic script"],
]);

exports.aiAdvice = onCall(
  {
    region: "us-central1",
    enforceAppCheck: true,
    consumeAppCheckToken: true,
    secrets: [deepseekApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.app) {
      throw new HttpsError("failed-precondition", "App Check required.");
    }
    enforceRateLimit(request);

    const snapshot = request.data && request.data.snapshot;
    validateSnapshot(snapshot);

    const model = deepseekModel.value().trim();
    const response = await fetch(
      "https://api.deepseek.com/chat/completions",
      {
        method: "POST",
        headers: {
          "authorization": `Bearer ${deepseekApiKey.value()}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(buildDeepSeekRequest(snapshot, model)),
      },
    );

    const raw = await response.text();
    if (!response.ok) {
      logger.warn("DeepSeek request failed", { status: response.status });
      throw new HttpsError("unavailable", "AI service is temporarily unavailable.");
    }

    let decoded;
    try {
      decoded = JSON.parse(raw);
    } catch (error) {
      logger.warn("DeepSeek returned non-JSON transport response");
      throw new HttpsError("internal", "AI returned an unexpected response.");
    }

    const items = extractAdviceItems(decoded);
    if (items.length < ADVICE_KEYS.length) {
      logger.warn("DeepSeek returned an incomplete structured response", {
        receivedKeys: items.map((item) => item.id),
      });
    }

    return { schemaVersion: 2, items };
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

  if (!supportedLanguages.has(snapshot.language)) {
    throw new HttpsError("invalid-argument", "Unsupported advice language.");
  }

  if (!isPlainObject(snapshot.profile) || !isPlainObject(snapshot.daily_targets)) {
    throw new HttpsError("invalid-argument", "Nutrition snapshot is incomplete.");
  }

  validateProfile(snapshot.profile);
  validateDailyTargets(snapshot.daily_targets);
}

function buildDeepSeekRequest(snapshot, model) {
  return {
    model,
    messages: [
      {
        role: "system",
        content: instructionsFor(snapshot.language),
      },
      {
        role: "user",
        content: JSON.stringify(snapshot),
      },
    ],
    response_format: { type: "json_object" },
    thinking: { type: "disabled" },
    max_tokens: 6000,
    temperature: 0.2,
    stream: false,
  };
}

function instructionsFor(languageCode) {
  const lang = supportedLanguages.get(languageCode) || "the user's language";

  return `
You are Eco Fit's nutrition advisor. Answer only in ${lang}.
Use mainstream public-health nutrition guidance. Be practical and concise.
Analyze the user's daily food diary, calories, macros, and any micronutrients provided.
Use daily_target_gaps and micronutrient_reference_gaps for exact numbers.
All micronutrient references are personalized DRI RDA/AI values selected by age and sex; treat reference_per_day as the target for every nutrient.
The snapshot includes only micronutrients populated in the app database. Do not invent or discuss unlisted micronutrients.
Never treat a micronutrient with status insufficient_data as zero intake or as a deficiency.
Use data_quality and data_coverage_percent when judging confidence. With low coverage, mark the amount as approximate (for example, with ≈) instead of adding a separate caveat sentence.
For sodium, CDRR is the risk-reduction limit; never recommend eating more sodium merely to reach AI. For sodium, reference_per_day is the CDRR limit itself (not the AI); status within_cdrr means intake stays under that limit, which is good.
When a nutrient carries an ear field, status below_ear_by means intake is under the Estimated Average Requirement — a stronger inadequacy signal than below_target_by (which is merely under the RDA/AI). Treat below_ear_by as a likely real shortfall and prioritise it; treat a value between the EAR and the RDA as only mildly low.
Keep UL separate from the daily target. Respect notes when a UL applies only to supplements or a specific nutrient form.
If the snapshot period is week or month, focus on repeated patterns and averages, not one meal.
If logged_days is low for the selected period, say the conclusion is limited by missing diary data.
Do not diagnose from food-log data. Describe consequences conditionally: "if this shortfall persists" or an equivalent concise phrase.
Recommend food changes first; supplements or medical care only when appropriate.
Do not spend an advice item on a generic medical disclaimer; the app shows that separately.
For period=day, is_current_day=true, and is_day_complete=false, only the calories value should briefly say that the numbers are "so far". Do not repeat an intermediate-day caveat in every nutrient.
For period=day and is_day_complete=true, breakfast, lunch, and dinner are all logged. Evaluate it as the completed food log and never call it intermediate or suggest "later meals".
Every below-target value must contain: amount versus reference and exact shortfall; one concrete possible consequence if the shortfall persists; and only 2 or 3 food examples.
Every above-target value must contain: amount versus reference and exact excess; one concrete consequence if the excess persists; and one concise action with no more than 3 examples.
If the difference is below 5% of the reference, say it is small and has no practical consequence instead of warning about deficiency.
Use a maximum of two concise sentences per value. Do not repeat stock phrases, generic caveats, or the same consequence across items.
Never write filler such as "this does not confirm a deficiency", "this is only an estimate", "one day is not enough", or "consult a professional" inside nutrient values.
The required fields are calories, protein, fat, carbohydrates, iron, magnesium, calcium, phosphorus, potassium, sodium, zinc, vitamin_a, vitamin_c, vitamin_d, vitamin_e, vitamin_k, vitamin_b1, vitamin_b2, vitamin_b3, vitamin_b6, vitamin_b9, vitamin_b12, copper, manganese, selenium, iodine, molybdenum, chromium, chloride, fluoride, choline, biotin, and pantothenic_acid. Never combine fields and never substitute one field for another.
Field vitamin_b9 is folate and field vitamin_b3 is niacin. Read each nutrient from micronutrient_reference_gaps by its snapshot key: zinc=zn, vitamin_a=vit_a, vitamin_c=vit_c, vitamin_d=vit_d, vitamin_e=vit_e, vitamin_k=vit_k, vitamin_b1=vit_b1, vitamin_b2=vit_b2, vitamin_b3=vit_b3, vitamin_b6=vit_b6, vitamin_b9=vit_b9, vitamin_b12=vit_b12, copper=cu, manganese=mn, selenium=se, iodine=i, molybdenum=mo, chromium=cr, chloride=cl, fluoride=f, choline=vit_b4, biotin=vit_h, pantothenic_acid=vit_b5.
Units in the data may read mcg_rae (vitamin A), mcg_dfe (folate), or mg_ne (niacin); present them to the user simply as mcg, mcg, and mg respectively.
If micronutrient status is insufficient_data, state the personalized reference, explain that the logged foods lack usable nutrient data, and give food ideas. Never present the missing amount as zero.
For low data coverage, use an approximate number without adding a separate explanation.
For sodium below CDRR, explain that this is below a risk-reduction limit and never recommend adding salt to reach a target.
Keep every value to at most two short sentences suitable for a mobile card. Avoid repeating one stock template.
Return only valid JSON with this exact shape:
{"advice":{"calories":"...","protein":"...","fat":"...","carbohydrates":"...","iron":"...","magnesium":"...","calcium":"...","phosphorus":"...","potassium":"...","sodium":"...","zinc":"...","vitamin_a":"...","vitamin_c":"...","vitamin_d":"...","vitamin_e":"...","vitamin_k":"...","vitamin_b1":"...","vitamin_b2":"...","vitamin_b3":"...","vitamin_b6":"...","vitamin_b9":"...","vitamin_b12":"...","copper":"...","manganese":"...","selenium":"...","iodine":"...","molybdenum":"...","chromium":"...","chloride":"...","fluoride":"...","choline":"...","biotin":"...","pantothenic_acid":"..."}}
Every key is mandatory and must appear exactly once. Values must not repeat their key as a heading because the app adds localized headings.
Do not use Markdown, bold text, headings, asterisks, code fences, or diagnosis labels.
Do not invent foods eaten, symptoms, allergies, laboratory results, or medical history.
`;
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function enforceRateLimit(request) {
  const key = request.rawRequest?.ip || request.app?.appId || "unknown";
  const now = Date.now();
  const windowMs = Math.max(10, rateLimitWindowSeconds.value()) * 1000;
  const maxRequests = Math.max(1, rateLimitMaxRequests.value());
  const bucket = rateLimitBuckets.get(key);

  if (!bucket || now - bucket.startedAt >= windowMs) {
    rateLimitBuckets.set(key, { startedAt: now, count: 1 });
    pruneRateLimitBuckets(now, windowMs);
    return;
  }

  bucket.count += 1;
  if (bucket.count > maxRequests) {
    throw new HttpsError("resource-exhausted", "Too many AI requests. Try again later.");
  }
}

function pruneRateLimitBuckets(now, windowMs) {
  if (rateLimitBuckets.size <= 2000) return;
  for (const [key, bucket] of rateLimitBuckets) {
    if (now - bucket.startedAt >= windowMs) {
      rateLimitBuckets.delete(key);
    }
  }
}

function validateProfile(profile) {
  if (profile.gender != null && !["m", "f"].includes(profile.gender)) {
    throw new HttpsError("invalid-argument", "Unsupported profile gender.");
  }
  assertOptionalNumber(profile.age, "profile age", 1, 120);
  assertOptionalNumber(profile.height_cm, "profile height", 40, 250);
  assertOptionalNumber(profile.weight_kg, "profile weight", 2, 350);
}

function validateDailyTargets(targets) {
  assertOptionalNumber(targets.kcal, "calorie target", 500, 10000);
  assertOptionalNumber(targets.protein_g, "protein target", 0, 500);
  assertOptionalNumber(targets.fat_g, "fat target", 0, 500);
  assertOptionalNumber(targets.carbs_g, "carbohydrate target", 0, 1500);
}

function assertOptionalNumber(value, label, min, max) {
  if (value == null) return;
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError("invalid-argument", `Invalid ${label}.`);
  }
}
