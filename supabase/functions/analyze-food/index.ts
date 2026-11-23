// =============================================================================
// NutriAI Edge Function: analyze-food
//
// One pipeline for camera photos and gallery photos:
//   1. Checks the caller is signed in AND approved by the admin.
//   2. Sends the photo to a vision AI (Groq by default, Gemini optional) and asks
//      for structured JSON: every food, its estimated weight in grams, confidence.
//   3. Looks up nutrition per 100 g for every food:
//        a) NutriAI Tunisian dishes table (for Tunisian dishes),
//        b) USDA FoodData Central (official US food composition database),
//        c) the AI's own estimate only when neither has a reliable match.
//      Each item says which source was used.
//
// Secrets (Supabase > Edge Functions > Secrets). API keys never reach the app.
//   GROQ_API_KEY    required when AI_PROVIDER = groq (default)
//   GEMINI_API_KEY  required when AI_PROVIDER = gemini
//   AI_PROVIDER     optional: "groq" (default) or "gemini"
//   AI_MODEL        optional: overrides the default model id
//   USDA_API_KEY    optional but recommended (free at api.data.gov); falls back to DEMO_KEY
//
// Deploy with "Verify JWT" turned OFF: this function verifies the user itself.
// No imports: works when pasted into the Supabase dashboard editor.
// =============================================================================

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
const ALLOWED_MIME = ["image/jpeg", "image/png", "image/webp"];
const DEFAULT_GROQ_MODEL = "qwen/qwen3.8-27b";
const DEFAULT_GEMINI_MODEL = "gemini-3.5-flash-lite";

export type Per100g = {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number;
  sugar: number;
};

export type AiFood = {
  name: string;
  usdaQuery: string;
  grams: number;
  confidence: number;
  isTunisianDish: boolean;
  estimate: Per100g | null;
};

export type ResultItem = {
  name: string;
  estimated_weight_grams: number;
  confidence: number;
  source: "tunisian_table" | "usda" | "ai_estimate";
  source_label: string;
  fdc_id: number | null;
  matched_description: string | null;
  per_100g: Per100g;
};

export class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

// -----------------------------------------------------------------------------
// Prompt
// -----------------------------------------------------------------------------
export const FOOD_PROMPT = `You are a nutrition assistant that analyses a photo of a meal.
Identify every food that is clearly visible and estimate how much of it is on the plate.

Respond with ONLY a JSON object of this exact shape:
{
  "foods": [
    {
      "name": "Grilled chicken breast",
      "usda_query": "chicken breast grilled",
      "estimated_weight_grams": 150,
      "confidence": 0.9,
      "is_tunisian_dish": false,
      "calories_per_100g": 165,
      "protein_per_100g": 31,
      "carbs_per_100g": 0,
      "fat_per_100g": 3.6,
      "fiber_per_100g": 0,
      "sugar_per_100g": 0
    }
  ],
  "notes": "short description of the plate"
}

Rules:
- List separate components separately (for example rice, chicken and salad are 3 items).
- A known composite dish that cannot be separated (pizza, lasagna, soup, stew, a sandwich,
  or a Tunisian dish such as couscous, ojja, lablabi, brik, kafteji, chakchouka,
  salade mechouia, tajine, makrouna, mloukhia) is ONE item named after the dish.
  Set "is_tunisian_dish": true for Tunisian dishes.
- "usda_query" is a short, generic English description for a food database search,
  cooking method included when visible (examples: "rice white cooked", "egg whole boiled",
  "apple raw", "bread white"). No brand names.
- Estimate weights in grams as served, using the plate (about 26 cm), cutlery and hands
  as size references. Be realistic, do not round everything to 100.
- "confidence" is between 0 and 1.
- The *_per_100g values are your best estimate; they are only used when no database
  match exists.
- Never invent foods that are not visible. Drinks count only if clearly visible.
- If there is no food in the photo, return {"foods": [], "notes": "No food detected."}`;

// -----------------------------------------------------------------------------
// Tunisian dishes (same values as the app's built-in food list)
// -----------------------------------------------------------------------------
type TunisianDish = { name: string; keywords: string[][]; per100g: Per100g };

export const TUNISIAN_DISHES: TunisianDish[] = [
  { name: "Tunisian Couscous with Fish", keywords: [["couscous", "fish"], ["couscous", "poisson"], ["couscous", "grouper"]],
    per100g: { calories: 145, protein: 9.8, carbs: 20.0, fat: 3.5, fiber: 2.5, sugar: 1.8 } },
  { name: "Tunisian Couscous with Lamb & Veggies", keywords: [["couscous"]],
    per100g: { calories: 175, protein: 8.5, carbs: 22.0, fat: 6.2, fiber: 2.8, sugar: 2.1 } },
  { name: "Ojja with Merguez Sausage & Eggs", keywords: [["ojja"], ["merguez"]],
    per100g: { calories: 165, protein: 8.2, carbs: 5.5, fat: 12.5, fiber: 1.8, sugar: 3.0 } },
  { name: "Brik with Tuna & Egg", keywords: [["brik"], ["brick", "egg"]],
    per100g: { calories: 220, protein: 12.5, carbs: 16.0, fat: 12.0, fiber: 1.0, sugar: 0.8 } },
  { name: "Lablabi (Chickpea Soup)", keywords: [["lablabi"], ["leblebi"]],
    per100g: { calories: 135, protein: 6.8, carbs: 22.0, fat: 2.8, fiber: 4.5, sugar: 1.5 } },
  { name: "Kafteji", keywords: [["kafteji"], ["kaftaji"]],
    per100g: { calories: 155, protein: 4.5, carbs: 9.0, fat: 11.5, fiber: 2.5, sugar: 3.5 } },
  { name: "Salade Mechouia", keywords: [["mechouia"], ["mechwia"], ["slata", "mechouia"]],
    per100g: { calories: 85, protein: 2.5, carbs: 6.0, fat: 5.8, fiber: 2.2, sugar: 3.2 } },
  { name: "Tajine Maadnous", keywords: [["tajine", "maadnous"], ["tunisian", "tajine"], ["tajine", "egg"]],
    per100g: { calories: 185, protein: 14.5, carbs: 5.0, fat: 12.0, fiber: 1.2, sugar: 1.0 } },
  { name: "Chakchouka", keywords: [["chakchouka"], ["shakshuka"], ["chakchuka"]],
    per100g: { calories: 95, protein: 4.8, carbs: 7.2, fat: 5.5, fiber: 2.0, sugar: 4.0 } },
  { name: "Tunisian Makrouna", keywords: [["makrouna"], ["makarouna"]],
    per100g: { calories: 168, protein: 8.8, carbs: 24.5, fat: 4.2, fiber: 1.8, sugar: 2.2 } },
  { name: "Mloukhia", keywords: [["mloukhia"], ["mloukhiya"], ["molokhia"]],
    per100g: { calories: 190, protein: 13.0, carbs: 4.0, fat: 13.5, fiber: 2.0, sugar: 0.5 } },
  { name: "Tunisian Tabouna Bread", keywords: [["tabouna"], ["tabuna"]],
    per100g: { calories: 260, protein: 8.5, carbs: 52.0, fat: 2.0, fiber: 3.0, sugar: 1.5 } },
];

export function matchTunisianDish(name: string, isTunisianDish: boolean): TunisianDish | null {
  const text = name.toLowerCase();
  for (const dish of TUNISIAN_DISHES) {
    for (const group of dish.keywords) {
      if (group.every((kw) => text.includes(kw))) {
        // "couscous" alone is only trusted when the AI flagged a Tunisian dish
        if (group.length === 1 && group[0] === "couscous" && !isTunisianDish) continue;
        return dish;
      }
    }
  }
  return null;
}

// -----------------------------------------------------------------------------
// Parsing helpers
// -----------------------------------------------------------------------------
function num(value: unknown): number | null {
  const n = typeof value === "string" ? Number(value) : value;
  return typeof n === "number" && Number.isFinite(n) ? n : null;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, n));
}

export function extractJsonObject(raw: string): Record<string, unknown> {
  let text = raw.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
  if (text.startsWith("```")) {
    text = text.replace(/^```[a-zA-Z]*\s*/, "").replace(/```\s*$/, "").trim();
  }
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start >= 0 && end > start) {
      return JSON.parse(text.slice(start, end + 1));
    }
    throw new HttpError(502, "ai_bad_response", "The AI answer could not be read. Please try again.");
  }
}

export function parseAiFoods(obj: Record<string, unknown>): { foods: AiFood[]; notes: string } {
  const list = Array.isArray(obj.foods) ? obj.foods : [];
  const foods: AiFood[] = [];
  for (const entry of list.slice(0, 15)) {
    if (!entry || typeof entry !== "object") continue;
    const f = entry as Record<string, unknown>;
    const name = String(f.name ?? "").trim();
    if (!name) continue;
    const grams = num(f.estimated_weight_grams);
    const cal = num(f.calories_per_100g);
    const protein = num(f.protein_per_100g) ?? 0;
    const carbs = num(f.carbs_per_100g) ?? 0;
    const fat = num(f.fat_per_100g) ?? 0;
    let estimate: Per100g | null = null;
    if (cal !== null || protein + carbs + fat > 0) {
      estimate = {
        calories: clamp(cal ?? protein * 4 + carbs * 4 + fat * 9, 0, 900),
        protein: clamp(protein, 0, 100),
        carbs: clamp(carbs, 0, 100),
        fat: clamp(fat, 0, 100),
        fiber: clamp(num(f.fiber_per_100g) ?? 0, 0, 100),
        sugar: clamp(num(f.sugar_per_100g) ?? 0, 0, 100),
      };
    }
    foods.push({
      name: name.slice(0, 80),
      usdaQuery: String(f.usda_query ?? name).trim().slice(0, 80) || name,
      grams: clamp(Math.round(grams ?? 100), 5, 2000),
      confidence: clamp(num(f.confidence) ?? 0.7, 0, 1),
      isTunisianDish: f.is_tunisian_dish === true,
      estimate,
    });
  }
  const notes = typeof obj.notes === "string" ? obj.notes.slice(0, 300) : "";
  return { foods, notes };
}

// -----------------------------------------------------------------------------
// USDA FoodData Central
// -----------------------------------------------------------------------------
type UsdaNutrient = { nutrientId?: number; nutrientNumber?: string; unitName?: string; value?: number };
type UsdaFood = { fdcId: number; description: string; dataType?: string; foodNutrients?: UsdaNutrient[] };

export function usdaPer100g(food: UsdaFood): Per100g | null {
  const nutrients = food.foodNutrients ?? [];
  const pick = (ids: number[], numbers: string[], unit?: string): number | null => {
    for (const id of ids) {
      const n = nutrients.find((x) => x.nutrientId === id && (!unit || (x.unitName ?? "").toUpperCase() === unit));
      if (n && typeof n.value === "number") return n.value;
    }
    for (const nr of numbers) {
      const n = nutrients.find((x) => x.nutrientNumber === nr && (!unit || (x.unitName ?? "").toUpperCase() === unit));
      if (n && typeof n.value === "number") return n.value;
    }
    return null;
  };
  const protein = pick([1003], ["203"]);
  const fat = pick([1004], ["204"]);
  const carbs = pick([1005], ["205"]);
  let calories = pick([1008, 2048, 2047], ["208", "958", "957"], "KCAL");
  if (calories === null && protein !== null && fat !== null && carbs !== null) {
    calories = protein * 4 + carbs * 4 + fat * 9;
  }
  if (calories === null || calories <= 0) return null;
  return {
    calories: Math.round(calories * 10) / 10,
    protein: protein ?? 0,
    carbs: carbs ?? 0,
    fat: fat ?? 0,
    fiber: pick([1079], ["291"]) ?? 0,
    sugar: pick([2000, 1063], ["269", "269.3"]) ?? 0,
  };
}

function stem(word: string): string {
  if (word.length > 4 && word.endsWith("ies")) return word.slice(0, -3) + "y"; // berries -> berry
  if (word.length > 4 && word.endsWith("oes")) return word.slice(0, -2); // tomatoes -> tomato
  if (word.length > 3 && word.endsWith("s") && !word.endsWith("ss")) return word.slice(0, -1); // apples -> apple
  return word;
}

function tokens(text: string): string[] {
  return text.toLowerCase().replace(/[^a-z0-9 ]+/g, " ").split(/\s+/).filter((t) => t.length > 2).map(stem);
}

export function pickBestUsdaFood(query: string, foods: UsdaFood[]): UsdaFood | null {
  const q = tokens(query);
  if (q.length === 0) return null;
  let best: UsdaFood | null = null;
  let bestScore = 0;
  for (const [index, food] of foods.entries()) {
    const d = new Set(tokens(food.description ?? ""));
    const overlap = q.filter((t) => d.has(t)).length;
    if (overlap === 0 || !d.has(q[0])) continue; // main word must match
    const coverage = overlap / q.length;
    const brevity = 1 / (1 + Math.max(0, d.size - q.length) * 0.08);
    const rankBonus = 0.15 / (1 + index);
    const score = coverage + 0.25 * brevity + rankBonus;
    if (score > bestScore) {
      bestScore = score;
      best = food;
    }
  }
  return bestScore >= 0.6 ? best : null;
}

async function searchUsda(query: string): Promise<UsdaFood[]> {
  const key = Deno.env.get("USDA_API_KEY") || "DEMO_KEY";
  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query,
      dataType: ["Foundation", "SR Legacy", "Survey (FNDDS)"],
      pageSize: 10,
    }),
    signal: AbortSignal.timeout(8000),
  });
  if (!res.ok) throw new Error(`USDA ${res.status}`);
  const data = await res.json();
  return Array.isArray(data.foods) ? data.foods : [];
}

function plausible(db: Per100g, estimate: Per100g | null): boolean {
  if (!estimate || estimate.calories <= 0) return true;
  const ratio = db.calories / estimate.calories;
  return ratio >= 0.4 && ratio <= 2.5;
}

export async function enrichItem(
  food: AiFood,
  usdaSearch: (q: string) => Promise<UsdaFood[]> = searchUsda,
): Promise<{ item: ResultItem; usdaFailed: boolean }> {
  const base = {
    name: food.name,
    estimated_weight_grams: food.grams,
    confidence: Math.round(food.confidence * 100) / 100,
  };

  const dish = matchTunisianDish(food.name, food.isTunisianDish);
  if (dish) {
    return {
      item: { ...base, source: "tunisian_table", source_label: "NutriAI Tunisian dishes table",
        fdc_id: null, matched_description: dish.name, per_100g: dish.per100g },
      usdaFailed: false,
    };
  }

  let usdaFailed = false;
  try {
    const results = await usdaSearch(food.usdaQuery);
    const best = pickBestUsdaFood(food.usdaQuery, results);
    const per100g = best ? usdaPer100g(best) : null;
    if (best && per100g && plausible(per100g, food.estimate)) {
      return {
        item: { ...base, source: "usda", source_label: "USDA FoodData Central",
          fdc_id: best.fdcId, matched_description: best.description, per_100g: per100g },
        usdaFailed: false,
      };
    }
  } catch (_) {
    usdaFailed = true;
  }

  const estimate = food.estimate ?? { calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0 };
  return {
    item: { ...base, source: "ai_estimate", source_label: "AI estimate (no database match)",
      fdc_id: null, matched_description: null, per_100g: estimate },
    usdaFailed,
  };
}

// -----------------------------------------------------------------------------
// Vision AI providers
// -----------------------------------------------------------------------------
function aiHttpError(status: number, detail: string): HttpError {
  if (status === 401 || status === 403) {
    return new HttpError(502, "ai_key_invalid",
      "The AI service rejected the server key. Admin: check the GROQ_API_KEY / GEMINI_API_KEY secret.");
  }
  if (status === 429) {
    return new HttpError(429, "ai_busy", "The free AI limit is reached for the moment. Wait a minute and try again.");
  }
  if (status === 413) {
    return new HttpError(413, "image_too_large", "The photo is too large. Please try again.");
  }
  console.error("AI provider error", status, detail.slice(0, 500));
  return new HttpError(502, "ai_unavailable", "The AI service is not available right now. Please try again.");
}

async function callGroq(base64: string, mime: string): Promise<string> {
  const key = Deno.env.get("GROQ_API_KEY");
  if (!key) throw new HttpError(500, "ai_not_configured", "AI is not configured yet. Admin: add the GROQ_API_KEY secret.");
  const model = Deno.env.get("AI_MODEL") || DEFAULT_GROQ_MODEL;
  const messages = [{
    role: "user",
    content: [
      { type: "text", text: FOOD_PROMPT },
      { type: "image_url", image_url: { url: `data:${mime};base64,${base64}` } },
    ],
  }];
  // Most capable request first; simpler fallbacks if the model rejects a parameter.
  const attempts: Record<string, unknown>[] = [
    { response_format: { type: "json_object" }, reasoning_format: "hidden", reasoning_effort: "none" },
    { response_format: { type: "json_object" } },
    {},
  ];
  let last: { status: number; detail: string } | null = null;
  for (const extra of attempts) {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({ model, messages, temperature: 0.1, max_completion_tokens: 2048, ...extra }),
      signal: AbortSignal.timeout(45000),
    });
    if (res.ok) {
      const data = await res.json();
      const content = data?.choices?.[0]?.message?.content;
      if (typeof content === "string" && content.trim()) return content;
      throw new HttpError(502, "ai_bad_response", "The AI returned an empty answer. Please try again.");
    }
    const detail = await res.text();
    last = { status: res.status, detail };
    if (res.status !== 400) break; // only parameter problems are worth a retry
  }
  throw aiHttpError(last?.status ?? 500, last?.detail ?? "");
}

async function callGemini(base64: string, mime: string): Promise<string> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new HttpError(500, "ai_not_configured", "AI is not configured yet. Admin: add the GEMINI_API_KEY secret.");
  const model = Deno.env.get("AI_MODEL") || DEFAULT_GEMINI_MODEL;
  // "AQ." keys are Vertex AI express mode keys and need the Vertex endpoint.
  const url = key.startsWith("AQ.")
    ? `https://aiplatform.googleapis.com/v1/publishers/google/models/${model}:generateContent?key=${encodeURIComponent(key)}`
    : `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: FOOD_PROMPT }, { inlineData: { mimeType: mime, data: base64 } }] }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 2048, responseMimeType: "application/json" },
    }),
    signal: AbortSignal.timeout(45000),
  });
  if (!res.ok) throw aiHttpError(res.status, await res.text());
  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const text = parts.map((p: { text?: string }) => p.text ?? "").join("");
  if (!text.trim()) throw new HttpError(502, "ai_bad_response", "The AI returned an empty answer. Please try again.");
  return text;
}

// -----------------------------------------------------------------------------
// Auth: signed in AND approved
// -----------------------------------------------------------------------------
async function requireApprovedUser(req: Request): Promise<string> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    throw new HttpError(401, "not_signed_in", "Please sign in again.");
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const apikey = req.headers.get("apikey") || Deno.env.get("SUPABASE_ANON_KEY") || "";

  const userRes = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { Authorization: authHeader, apikey },
  });
  if (!userRes.ok) throw new HttpError(401, "session_expired", "Your session expired. Please sign in again.");
  const user = await userRes.json();
  const userId = String(user?.id ?? "");
  if (!userId) throw new HttpError(401, "session_expired", "Your session expired. Please sign in again.");

  const profileRes = await fetch(
    `${supabaseUrl}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=status,is_admin,access_until`,
    { headers: { Authorization: authHeader, apikey, Accept: "application/json" } },
  );
  const rows = profileRes.ok ? await profileRes.json() : [];
  const p = Array.isArray(rows) ? rows[0] : null;
  const approved = !!p && (p.is_admin === true ||
    (p.status === "approved" && (!p.access_until || new Date(p.access_until).getTime() > Date.now())));
  if (!approved) {
    throw new HttpError(403, "not_approved", "Your account is not approved yet. Ask the admin for access.");
  }
  return userId;
}

// -----------------------------------------------------------------------------
// Request handler
// -----------------------------------------------------------------------------
function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export async function analyzeImage(
  base64: string,
  mime: string,
  deps: {
    vision?: (b64: string, mime: string) => Promise<string>;
    usdaSearch?: (q: string) => Promise<UsdaFood[]>;
  } = {},
) {
  const provider = (Deno.env.get("AI_PROVIDER") || "groq").toLowerCase();
  const vision = deps.vision ?? (provider === "gemini" ? callGemini : callGroq);
  const raw = await vision(base64, mime);
  const { foods, notes } = parseAiFoods(extractJsonObject(raw));
  const enriched = await Promise.all(foods.map((f) => enrichItem(f, deps.usdaSearch)));
  const items = enriched.map((e) => e.item);
  const usdaDown = enriched.some((e) => e.usdaFailed);
  return {
    items,
    notes: usdaDown
      ? `${notes} (The USDA database could not be reached for some items, AI estimates were used.)`.trim()
      : notes,
    provider,
  };
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    // Allow whatever headers the Supabase client library sends (they change between versions).
    const requested = req.headers.get("Access-Control-Request-Headers");
    return new Response("ok", {
      headers: requested ? { ...CORS_HEADERS, "Access-Control-Allow-Headers": requested } : CORS_HEADERS,
    });
  }
  if (req.method !== "POST") return json(405, { status: "error", code: "method", message: "Use POST" });

  try {
    await requireApprovedUser(req);

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      throw new HttpError(400, "bad_request", "The request was not valid JSON.");
    }
    let base64 = String(body.image ?? "");
    if (base64.includes(",")) base64 = base64.split(",", 2)[1];
    base64 = base64.replace(/\s/g, "");
    const mime = String(body.mime_type ?? "image/jpeg").toLowerCase();

    if (!base64) throw new HttpError(400, "no_image", "No photo was received.");
    if (!ALLOWED_MIME.includes(mime)) {
      throw new HttpError(415, "unsupported_image", "Please use a JPG, PNG or WebP photo.");
    }
    if ((base64.length * 3) / 4 > MAX_IMAGE_BYTES) {
      throw new HttpError(413, "image_too_large", "The photo is too large (max 6 MB).");
    }

    const result = await analyzeImage(base64, mime);
    return json(200, { status: "success", data: result });
  } catch (e) {
    if (e instanceof HttpError) {
      return json(e.status, { status: "error", code: e.code, message: e.message });
    }
    if (e instanceof DOMException && e.name === "TimeoutError") {
      return json(504, { status: "error", code: "ai_timeout", message: "The AI took too long to answer. Please try again." });
    }
    console.error("analyze-food failed", e);
    return json(500, { status: "error", code: "internal", message: "Something went wrong while analysing the photo." });
  }
}

if (!Deno.env.get("NUTRIAI_TEST_MODE")) {
  Deno.serve(handleRequest);
}
