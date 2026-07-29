import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALPACA_BASE = "https://data.alpaca.markets/v2";

// Credentials come only from the environment — never fall back to a literal.
const ALPACA_KEY_ID     = Deno.env.get("ALPACA_KEY_ID");
const ALPACA_KEY_SECRET = Deno.env.get("ALPACA_KEY_SECRET");

// Which Alpaca data feed to query. "iex" is a single exchange carrying ~2% of
// US volume, so its prints are thin and often stale; "delayed_sip" is the full
// consolidated tape 15 minutes behind, and "sip" is the same in real time but
// needs a paid subscription. Overridable so the plan can change without a deploy.
const ALPACA_FEED = Deno.env.get("ALPACA_FEED") ?? "delayed_sip";

// Simple 60-second in-memory cache shared across requests in the same isolate
const cache = new Map<string, { data: unknown; expires: number }>();

Deno.serve(async (req) => {
  // Fail fast if the function is misconfigured, before doing any other work.
  if (!ALPACA_KEY_ID || !ALPACA_KEY_SECRET) {
    const missing = [
      !ALPACA_KEY_ID     && "ALPACA_KEY_ID",
      !ALPACA_KEY_SECRET && "ALPACA_KEY_SECRET",
    ].filter(Boolean).join(", ");
    console.error(`market-data: missing required secret(s): ${missing}`);
    return new Response(
      `Server misconfigured: missing required secret(s): ${missing}`,
      { status: 500 }
    );
  }

  // Verify the caller is a signed-in app user
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: { user }, error } = await supabaseAdmin.auth.getUser(
    authHeader.replace("Bearer ", "")
  );
  if (error || !user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const url = new URL(req.url);
  const type    = url.searchParams.get("type");      // "snapshots" | "bars"
  const symbols = url.searchParams.get("symbols") ?? "";
  const limit   = url.searchParams.get("limit") ?? "7";

  // Caller-selected bar size (1Min, 5Min, 1Day, 1Week…). Allow-listed so the
  // value can't be injected straight into the upstream URL.
  const ALLOWED_TIMEFRAMES = new Set([
    "1Min", "5Min", "15Min", "30Min", "1Hour", "1Day", "1Week", "1Month",
  ]);
  const requested = url.searchParams.get("timeframe") ?? "1Day";
  const timeframe = ALLOWED_TIMEFRAMES.has(requested) ? requested : "1Day";

  if (!type || !symbols) {
    return new Response("Missing type or symbols", { status: 400 });
  }

  // Serve from cache if fresh — timeframe is part of the key so different bar
  // sizes for the same symbols don't collide.
  const cacheKey = `${type}:${symbols}:${timeframe}:${limit}`;
  const hit = cache.get(cacheKey);
  if (hit && hit.expires > Date.now()) {
    return new Response(JSON.stringify(hit.data), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const alpacaURL =
    type === "snapshots"
      ? `${ALPACA_BASE}/stocks/snapshots?symbols=${symbols}&feed=${ALPACA_FEED}`
      : `${ALPACA_BASE}/stocks/bars?symbols=${symbols}&timeframe=${timeframe}&limit=${limit}&feed=${ALPACA_FEED}`;

  const alpacaRes = await fetch(alpacaURL, {
    headers: {
      "APCA-API-KEY-ID": ALPACA_KEY_ID,
      "APCA-API-SECRET-KEY": ALPACA_KEY_SECRET,
    },
  });

  if (!alpacaRes.ok) {
    // Alpaca explains the rejection in the body (unpermitted feed, bad symbol,
    // expired subscription). Log it in full for the dashboard, and pass a
    // trimmed version to the client so failures are diagnosable from the app
    // instead of surfacing as a bare "Upstream error".
    const detail = (await alpacaRes.text().catch(() => "")).slice(0, 500);
    console.error(
      `market-data: Alpaca ${alpacaRes.status} for type=${type} feed=${ALPACA_FEED} ` +
      `symbols=${symbols} — ${detail || "(empty body)"}`
    );
    return new Response(
      `Upstream error ${alpacaRes.status}: ${detail || "(no detail)"}`,
      { status: alpacaRes.status },
    );
  }

  const data = await alpacaRes.json();

  // A 200 doesn't mean every symbol came back whole — Alpaca omits fields per
  // symbol (outside market hours `latestTrade` is often absent). The client
  // decodes the whole map at once, so one gap can drop every price. Log a
  // summary rather than the payload, which would flood the logs.
  if (type === "snapshots" && data && typeof data === "object") {
    const snaps = data as Record<string, Record<string, unknown> | null>;
    const syms = Object.keys(snaps);
    const noTrade = syms.filter((s) => !snaps[s]?.latestTrade);
    const noDaily = syms.filter((s) => !snaps[s]?.dailyBar);
    console.log(
      `market-data: snapshots ok — ${syms.length} symbols, ` +
      `${noTrade.length} missing latestTrade${noTrade.length ? ` (${noTrade.slice(0, 10).join(",")})` : ""}, ` +
      `${noDaily.length} missing dailyBar${noDaily.length ? ` (${noDaily.slice(0, 10).join(",")})` : ""}`
    );
  }

  // Cache for 60 seconds
  cache.set(cacheKey, { data, expires: Date.now() + 60_000 });

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
