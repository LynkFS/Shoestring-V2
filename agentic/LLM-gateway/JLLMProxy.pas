unit JLLMProxy;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JLLMProxy — stateless generic LLM proxy (Phase 2: non-streaming)
//
//  Object Pascal compiled to JavaScript, run as:  node index.js
//
//  This is the STABLE SKELETON. It compiles once. It never learns a
//  provider's wire format — that lives in runtime-loaded JS plugins
//  (plugins/*.js) selected by providers.json. Adding or retuning a provider
//  is a JSON + plugin edit, no skeleton recompile. (See the plan: this is
//  what makes the high-churn surface future-proof under the IDE-only
//  compiler.)
//
//  Responsibilities (and nothing else):
//    * env / .env config, providers.json load
//    * optional JWT auth (open if JWT_SECRET unset — logged)
//    * rate limit, CORS, /health
//    * route POST /v1/chat by `provider` → plugin.complete(req, cfg)
//
//  STATELESS: the client sends the full `messages` array every turn.
//  `providerSessionId` is an opaque token passed straight through to the
//  plugin and echoed back — the proxy never stores or interprets it.
//
//  Plugin contract (v1, non-streaming):
//    module.exports = {
//      name, capabilities,
//      async complete(req, cfg) -> {
//        text, usage:{inputTokens,outputTokens}, finishReason,
//        webSearchUsed, webSearchUnavailable, providerSessionId }
//    }
//    req = the unified body; cfg = { endpoint, apiKey, modelDefault }
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes;

procedure StartServer;

implementation

var
  Providers   : variant;   // providers.json  { id: {plugin,endpoint,keyEnv,modelDefault} }
  PluginCache : variant;   // { absPath: module }
  JwtLib      : variant;   // require('jsonwebtoken') or undefined
  RateMap     : variant;   // JS Map ip -> [timestamps]
  CorsAllowed : variant;   // JS Set or null
  JwtSecret   : String;
  MaxBody     : Integer;

const
  RATE_WINDOW_MS = 60000;
  RATE_MAX       = 120;


// ═════════════════════════════════════════════════════════════════════════
// Env / config
// ═════════════════════════════════════════════════════════════════════════

function GetEnv(const AName, ADefault: String): String;
begin
  Result := ADefault;
  asm
    var v = process.env[@AName];
    if (v !== undefined && v !== null && String(v).trim() !== '') {
      @Result = String(v).trim();
    }
  end;
end;

// ─────────────────────────────────────────────────────────────────────────
// Replacement for the LoadDotEnv procedure in JLLMProxy.pas
// (approximately lines 74-102 in the agentic source).
//
// Reason: the original uses a JS regex literal /^["']|["']$/g inside an
// asm block. DWScript's lexer still scans asm bodies for quote pairing
// (because @var substitutions must be parsed), and the unbalanced
// quotes in the character class trip it: "End of string constant not
// found (end of line)".
//
// Fix: strip surrounding quotes with explicit slice logic instead of a
// regex literal. Same semantics, no quote-pairing trap.
// ─────────────────────────────────────────────────────────────────────────

procedure LoadDotEnv;
var
  envPath: String;
begin
  envPath := GetEnv('DOTENV_PATH', '.env');
  // The asm body below avoids JS regex literals because DWScript's lexer
  // still parses asm content for @var substitutions, and unbalanced
  // quotes inside a regex character class confuse it. We strip the
  // surrounding quote pair with plain string operations instead.
  asm
    try {
      var fs = require('fs');
      if (fs.existsSync(@envPath)) {
        var lines = fs.readFileSync(@envPath, 'utf8').split('\n');
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (!line || line.charAt(0) === '#') continue;
          var eq = line.indexOf('=');
          if (eq === -1) continue;
          var k = line.slice(0, eq).trim();
          var val = line.slice(eq + 1).trim();
          if (val.length >= 2) {
            var first = val.charAt(0);
            var last  = val.charAt(val.length - 1);
            var dq = (first === '"' && last === '"');
            var sq = (first === '\u0027' && last === '\u0027');
            if (dq || sq) val = val.slice(1, -1);
          }
          if (k && !(k in process.env)) process.env[k] = val;
        }
      }
    } catch (e) { /* env is optional */ }
  end;
end;

procedure LoadProviders;
var
  mapPath: String;
  ok: Boolean;
begin
  mapPath := GetEnv('PROVIDERS_FILE', 'providers.json');
  asm
    var src = process.env.PROVIDERS;
    if (!src) {
      try { src = require('fs').readFileSync(@mapPath, 'utf8'); }
      catch (e) { src = ''; }
    }
    try { @Providers = JSON.parse(src || 'null'); }
    catch (e) { @Providers = null; }
  end;
  ok := False;
  asm
    @ok = !!(@Providers) && typeof @Providers === 'object'
          && Object.keys(@Providers).length > 0;
  end;
  if not ok then
    raise Exception.Create(
      'JLLMProxy: no provider map. Set PROVIDERS or provide providers.json ' +
      '(see providers.example.json).');
end;


// ═════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════

procedure SendJson(res: variant; ACode: Integer; const ABody: String);
begin
  asm
    (@res).writeHead(@ACode, {
      'Content-Type':           'application/json',
      'X-Content-Type-Options': 'nosniff'
    });
    (@res)['end'](@ABody);
  end;
end;

procedure SendStatus(res: variant; ACode: Integer);
begin
  asm
    (@res).writeHead(@ACode);
    (@res)['end']();
  end;
end;

function RateLimited(const AIp: String): Boolean;
begin
  asm
    var now = Date.now();
    var arr = (@RateMap).get(@AIp) || [];
    arr = arr.filter(function (t) { return now - t < 60000; });
    arr.push(now);
    (@RateMap).set(@AIp, arr);
    @Result = arr.length > 120;
  end;
end;

// Optional JWT. Returns True if the request is authorised. When JWT_SECRET
// is unset the proxy is open (logged once at boot).
function Authorised(const AAuth: String): Boolean;
var
  tok: String;
begin
  if JwtSecret = '' then
  begin
    Result := True;
    exit;
  end;
  Result := False;
  if Copy(AAuth, 1, 7) <> 'Bearer ' then exit;
  tok := Copy(AAuth, 8, Length(AAuth));
  asm
    try { (@JwtLib).verify(@tok, @JwtSecret); @Result = true; }
    catch (e) { @Result = false; }
  end;
end;

function ApplyCors(req, res: variant): Boolean;
begin
  Result := False;
  asm
    var origin = (@req).headers['origin'];
    if (origin && (@CorsAllowed) && (@CorsAllowed).has(origin)) {
      (@res).setHeader('Access-Control-Allow-Origin', origin);
      (@res).setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
      (@res).setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      (@res).setHeader('Access-Control-Allow-Credentials', 'true');
      (@res).setHeader('Vary', 'Origin');
    }
  end;
  if String(req.method) = 'OPTIONS' then
  begin
    SendStatus(res, 204);
    Result := True;
  end;
end;


// ═════════════════════════════════════════════════════════════════════════
// Dispatch — the only non-skeleton logic, and it still knows no wire format
// ═════════════════════════════════════════════════════════════════════════

procedure HandleChat(res: variant; const ABody: String);
begin
  // One async IIFE. The Pascal/await rules don't apply inside JS; the proxy
  // only routes — plugin.complete owns the upstream call entirely.
  asm
    (async function () {
      var req;
      try { req = JSON.parse(@ABody || '{}'); }
      catch (e) {
        (@res).writeHead(400, { 'Content-Type': 'application/json' });
        (@res)['end'](JSON.stringify({ error: 'Invalid JSON body.' }));
        return;
      }

      var provId = req && req.provider;
      var cfg    = provId && (@Providers)[provId];
      if (!cfg) {
        (@res).writeHead(400, { 'Content-Type': 'application/json' });
        (@res)['end'](JSON.stringify({ error: 'Unknown provider: ' + provId }));
        return;
      }
      if (!Array.isArray(req.messages) || req.messages.length === 0) {
        (@res).writeHead(400, { 'Content-Type': 'application/json' });
        (@res)['end'](JSON.stringify({ error: '"messages" must be a non-empty array.' }));
        return;
      }

      // Resolve the upstream config. Every provider-config field flows
      // through (CLI/managed need extras like cliBin / skill); the secret
      // is read HERE (single place for secret handling) — never logged.
      // A second optional key (keyEnv2) covers transports that need their
      // own credential (e.g. a managed-agents gateway).
      var resolved = {};
      for (var k in cfg) { if (cfg.hasOwnProperty(k)) resolved[k] = cfg[k]; }
      resolved.endpoint     = cfg.endpoint || '';
      resolved.modelDefault = cfg.modelDefault || '';
      resolved.apiKey       = cfg.keyEnv  ? (process.env[cfg.keyEnv]  || '') : '';
      resolved.apiKey2      = cfg.keyEnv2 ? (process.env[cfg.keyEnv2] || '') : '';

      // Load + cache the plugin. require resolves relative to cwd.
      var plugin;
      try {
        var path    = require('path');
        var abs     = path.resolve(cfg.plugin);
        plugin = (@PluginCache)[abs];
        if (!plugin) { plugin = require(abs); (@PluginCache)[abs] = plugin; }
      } catch (e) {
        console.error('[llm-proxy] plugin load: ' + (e && e.message));
        (@res).writeHead(500, { 'Content-Type': 'application/json' });
        (@res)['end'](JSON.stringify({ error: 'Provider plugin unavailable.' }));
        return;
      }

      // ── Streaming branch ───────────────────────────────────────────────
      // Skeleton owns the SSE frame only; the plugin owns the upstream
      // stream and emits unified events via onEvent. Stateless: nothing
      // is buffered here.
      if (req.stream === true && typeof plugin.stream === 'function') {
        (@res).writeHead(200, {
          'Content-Type':      'text/event-stream',
          'Cache-Control':     'no-cache',
          'Connection':        'keep-alive',
          'X-Accel-Buffering': 'no'
        });
        var onEvent = function (ev) {
          try { (@res).write('data: ' + JSON.stringify(ev) + '\n\n'); }
          catch (_) { /* client gone */ }
        };
        try {
          await plugin.stream(req, resolved, onEvent);
        } catch (e) {
          console.error('[llm-proxy] ' + provId + ' stream: ' + (e && e.message));
          onEvent({ type: 'error', error: 'Upstream provider error.' });
        }
        try { (@res)['end'](); } catch (_) {}
        return;
      }

      // ── Non-streaming branch ───────────────────────────────────────────
      try {
        var out = await plugin.complete(req, resolved);
        (@res).writeHead(200, {
          'Content-Type':           'application/json',
          'X-Content-Type-Options': 'nosniff'
        });
        (@res)['end'](JSON.stringify({
          text:                 (out && out.text) || '',
          usage:                (out && out.usage) || { inputTokens: 0, outputTokens: 0 },
          finishReason:         (out && out.finishReason) || 'stop',
          webSearchUsed:        !!(out && out.webSearchUsed),
          webSearchUnavailable: !!(out && out.webSearchUnavailable),
          providerSessionId:    (out && out.providerSessionId) || ''
        }));
      } catch (e) {
        var st = (e && e.status) || 502;
        console.error('[llm-proxy] ' + provId + ': ' + (e && e.message));
        (@res).writeHead(st, { 'Content-Type': 'application/json' });
        (@res)['end'](JSON.stringify({
          error: (st >= 400 && st < 500) ? (e && e.message) : 'Upstream provider error.'
        }));
      }
    })();
  end;
end;

procedure HandleModels(res: variant);
var
  json: String;
begin
  json := '{}';
  asm
    var out = {};
    var p = @Providers || {};
    for (var id in p) {
      if (p.hasOwnProperty(id)) {
        out[id] = Array.isArray(p[id].models) ? p[id].models : [];
      }
    }
    @json = JSON.stringify(out);
  end;
  SendJson(res, 200, json);
end;

procedure HandleHealth(res: variant);
var
  provList: String;
begin
  provList := '';
  asm @provList = Object.keys(@Providers || {}).join(','); end;
  SendJson(res, 200,
    '{"status":"ok","service":"llm-proxy","providers":"' + provList + '"}');
end;


// ═════════════════════════════════════════════════════════════════════════
// Server
// ═════════════════════════════════════════════════════════════════════════

procedure StartServer;
var
  http, server, port: variant;
  corsCsv: String;
  jwtOpen: Boolean;
begin
  MaxBody := 262144;   // 256 KB — conversations can be large

  LoadDotEnv;
  asm @PluginCache = {}; @RateMap = new Map(); end;

  JwtSecret := GetEnv('JWT_SECRET', '');
  jwtOpen := JwtSecret = '';
  if not jwtOpen then
    JwtLib := ReqNodeModule('jsonwebtoken');

  corsCsv := GetEnv('CORS_ORIGINS', '');
  asm
    @CorsAllowed = (@corsCsv)
      ? new Set((@corsCsv).split(',').map(function (s) { return s.trim(); }))
      : null;
  end;

  LoadProviders;

  http := ReqNodeModule('http');

  server := http.createServer(
    procedure(req, res: variant)
    var
      verb, pathname, auth, ip: String;
      cont: procedure(const ABody: String);
    begin
      if ApplyCors(req, res) then exit;

      verb := String(req.method);
      asm @pathname = require('url').parse((@req).url).pathname; end;
      // Strip /proxy prefix so tunnel (ide.lynkfs.com/proxy/*) and direct
      // (localhost:3030/*) requests both reach the same route handlers.
      if Copy(pathname, 1, 6) = '/proxy' then
        pathname := Copy(pathname, 7, Length(pathname));

      if (pathname = '/health') and (verb = 'GET') then
      begin
        HandleHealth(res);
        exit;
      end;

      if (pathname = '/v1/models') and (verb = 'GET') then
      begin
        HandleModels(res);
        exit;
      end;

      if (pathname <> '/v1/chat') or (verb <> 'POST') then
      begin
        SendJson(res, 404, '{"error":"Not found"}');
        exit;
      end;

      asm @ip = (@req).socket.remoteAddress || ''; end;
      if RateLimited(ip) then
      begin
        SendJson(res, 429, '{"error":"Too many requests, please slow down."}');
        exit;
      end;

      asm @auth = (@req).headers['authorization'] || ''; end;
      if not Authorised(auth) then
      begin
        SendJson(res, 401, '{"error":"Invalid or missing token"}');
        exit;
      end;

      cont := procedure(const ABody: String)
              begin
                try
                  HandleChat(res, ABody);
                except on E: Exception do
                  SendJson(res, 500, '{"error":"Internal server error."}');
                end;
              end;
      asm
        var chunks = '', tooBig = false;
        (@req).on('data', function (c) {
          chunks += c;
          if (chunks.length > @MaxBody) {
            tooBig = true;
            (@res).writeHead(413, { 'Content-Type': 'application/json' });
            (@res)['end'](JSON.stringify({ error: 'Request body too large.' }));
            (@req).destroy();
          }
        });
        (@req).on('end', function () {
          if (!tooBig) { (@cont)(chunks); }
        });
      end;
    end);

  asm @port = process.env.PORT || 3000; end;

  server.listen(port, '0.0.0.0', procedure()
  begin
    console.log('[llm-proxy] (shoestring) listening on port ' + String(port));
    if jwtOpen then
      console.log('[llm-proxy] WARNING: JWT_SECRET unset — auth is OPEN.');
  end);
end;

initialization
  StartServer;
end.
