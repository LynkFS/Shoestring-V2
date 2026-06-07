unit McpExampleTools;

// ═══════════════════════════════════════════════════════════════════════════
//
//  McpExampleTools — a worked MCP server on the JMcpServer scaffold
//
//  Three tools, zero npm dependencies:
//    echo      — sync handler (returns immediately)
//    now       — sync handler (server time)
//    http_get  — ASYNC handler (Node 18 fetch); proves Resolve/Reject can
//                fire long after the handler returns — the scaffold writes
//                the JSON-RPC response whenever they're called.
//
//  A database tool is a drop-in: a handler that does
//  `require('mysql2/promise')` and calls Resolve with the rows — the
//  scaffold doesn't care (it only needs Resolve/Reject). Kept out of this
//  example to stay dependency-free.
//
//  Run as an MCP stdio server:  node index.js   (see README.md)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes, JMcpServer;

implementation

procedure RegisterAll;
begin
  RegisterTool('echo',
    'Echo the provided text back unchanged.',
    '{"type":"object","properties":{"text":{"type":"string",' +
    '"description":"Text to echo"}},"required":["text"]}',
    procedure(Args: variant; Resolve: TMcpResolve; Reject: TMcpReject)
    var
      s: String;
    begin
      s := '';
      asm @s = String((@Args).text || ''); end;
      if s = '' then
        Reject('Missing required argument "text".')
      else
        Resolve(s);
    end);

  RegisterTool('now',
    'Current server time as ISO 8601 plus epoch milliseconds.',
    '{"type":"object","properties":{}}',
    procedure(Args: variant; Resolve: TMcpResolve; Reject: TMcpReject)
    var
      s: String;
    begin
      s := '';
      asm @s = new Date().toISOString() + '  (' + Date.now() + ')'; end;
      Resolve(s);
    end);

  RegisterTool('http_get',
    'HTTP GET a URL and return up to 4000 characters of the response body.',
    '{"type":"object","properties":{"url":{"type":"string",' +
    '"description":"Absolute http(s) URL"}},"required":["url"]}',
    procedure(Args: variant; Resolve: TMcpResolve; Reject: TMcpReject)
    var
      url: String;
    begin
      url := '';
      asm @url = String((@Args).url || ''); end;
      if url = '' then
      begin
        Reject('Missing required argument "url".');
        exit;
      end;
      // Async: Resolve/Reject fire from the fetch continuation. Same
      // closure-param-in-asm idiom as the JPromise executor (AsyncDemo).
      asm
        (async function () {
          try {
            var r = await fetch(@url);
            var t = await r.text();
            if (!r.ok) { (@Reject)('HTTP ' + r.status); return; }
            (@Resolve)(t.slice(0, 4000));
          } catch (e) {
            (@Reject)('fetch: ' + (e && e.message));
          }
        })();
      end;
    end);
end;

initialization
  RegisterAll;
  StartMcp('shoestring-example-mcp', '1.0.0');
end.
