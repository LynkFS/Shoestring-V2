unit JMcpServer;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JMcpServer — minimal MCP server scaffold (ShoeString → Node)
//
//  Zero npm dependencies. Implements the Model Context Protocol stdio
//  transport directly: newline-delimited JSON-RPC 2.0 on stdin/stdout.
//  `asm` appears only at the JSON-RPC boundary — same discipline as
//  JLLMProxy.
//
//  Handlers are Pascal closures. They may resolve synchronously or much
//  later (HTTP, DB, child process): the scaffold writes the JSON-RPC
//  response when Resolve/Reject is called, so async tools "just work"
//  without async-on-method gymnastics.
//
//  Methods handled:
//    initialize                 → serverInfo + tools capability
//    notifications/initialized  → ignored (no id)
//    tools/list                 → registered tools + their JSON schemas
//    tools/call                 → dispatch to the handler
//    (anything else with an id) → JSON-RPC -32601
//
//  CRITICAL: stdout carries ONLY JSON-RPC. Never console.log here — use
//  console.error (stderr) for diagnostics, or the host will see corrupt
//  protocol frames.
//
//  Usage:
//    uses JMcpServer;
//    RegisterTool('echo', 'Echo text back',
//      '{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}',
//      procedure(Args: variant; Resolve: TMcpResolve; Reject: TMcpReject)
//      var s: String;
//      begin
//        asm @s = String((@Args).text || ''); end;
//        Resolve(s);
//      end);
//    StartMcp('my-server', '1.0.0');
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes;

type
  TMcpResolve = procedure(const AText: String);
  TMcpReject  = procedure(const AError: String);
  TMcpHandler = procedure(Args: variant; Resolve: TMcpResolve; Reject: TMcpReject);

procedure RegisterTool(const AName, ADescription, AInputSchemaJson: String;
                       AHandler: TMcpHandler);

procedure StartMcp(const AServerName, AVersion: String);

implementation

var
  FNames:    array of String;
  FDescs:    array of String;
  FSchemas:  array of String;       // JSON text, parsed when listed
  FHandlers: array of TMcpHandler;
  SrvName:   String;
  SrvVer:    String;


// ── Registry ───────────────────────────────────────────────────────────────

procedure RegisterTool(const AName, ADescription, AInputSchemaJson: String;
                       AHandler: TMcpHandler);
var
  n: Integer;
begin
  n := Length(FNames);
  SetLength(FNames,    n + 1);
  SetLength(FDescs,    n + 1);
  SetLength(FSchemas,  n + 1);
  SetLength(FHandlers, n + 1);
  FNames[n]    := AName;
  FDescs[n]    := ADescription;
  FSchemas[n]  := AInputSchemaJson;
  FHandlers[n] := AHandler;
end;

function FindTool(const AName: String): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Length(FNames) - 1 do
    if FNames[i] = AName then
    begin
      Result := i;
      exit;
    end;
end;


// ── JSON-RPC out (single line each; stdout is protocol-only) ────────────────

procedure SendInit(AId: variant);
begin
  asm
    var resp = { jsonrpc: '2.0', id: @AId, result: {
      protocolVersion: '2024-11-05',
      capabilities:    { tools: {} },
      serverInfo:      { name: @SrvName, version: @SrvVer }
    } };
    process.stdout.write(JSON.stringify(resp) + '\n');
  end;
end;

procedure SendToolList(AId: variant);
var
  arr: variant;
  i: Integer;
  nm, ds, sc: String;
begin
  asm @arr = []; end;
  for i := 0 to Length(FNames) - 1 do
  begin
    nm := FNames[i];
    ds := FDescs[i];
    sc := FSchemas[i];
    asm
      var schema;
      try { schema = JSON.parse(@sc); }
      catch (e) { schema = { type: 'object' }; }
      (@arr).push({ name: @nm, description: @ds, inputSchema: schema });
    end;
  end;
  asm
    var resp = { jsonrpc: '2.0', id: @AId, result: { tools: @arr } };
    process.stdout.write(JSON.stringify(resp) + '\n');
  end;
end;

procedure SendToolResult(AId: variant; const AText: String; AIsError: Boolean);
begin
  asm
    var resp = { jsonrpc: '2.0', id: @AId, result: {
      content: [ { type: 'text', text: @AText } ],
      isError: @AIsError
    } };
    process.stdout.write(JSON.stringify(resp) + '\n');
  end;
end;

procedure SendError(AId: variant; ACode: Integer; const AMsg: String);
begin
  asm
    var resp = { jsonrpc: '2.0', id: @AId,
      error: { code: @ACode, message: @AMsg } };
    process.stdout.write(JSON.stringify(resp) + '\n');
  end;
end;


// ── Dispatch ────────────────────────────────────────────────────────────────

procedure HandleLine(const ALine: String);
var
  obj, msgId, params, args: variant;
  method, toolName: String;
  hasId, okObj: Boolean;
  idx: Integer;
  rid: variant;
  res: TMcpResolve;
  rej: TMcpReject;
begin
  hasId := False;
  okObj := False;
  asm
    try { @obj = JSON.parse(@ALine); }
    catch (e) { @obj = null; }
    @okObj = (@obj !== null && @obj !== undefined && typeof @obj === 'object');
  end;
  if not okObj then exit;

  asm
    @method = (@obj).method || '';
    @hasId  = ('id' in (@obj)) && (@obj).id !== undefined && (@obj).id !== null;
    @msgId  = @hasId ? (@obj).id : null;
    @params = (@obj).params || {};
  end;

  // Notifications (no id) — acknowledge nothing.
  if not hasId then exit;

  if method = 'initialize' then
  begin
    SendInit(msgId);
    exit;
  end;

  if method = 'tools/list' then
  begin
    SendToolList(msgId);
    exit;
  end;

  if method = 'tools/call' then
  begin
    asm
      @toolName = (@params).name || '';
      @args     = (@params).arguments || {};
    end;
    idx := FindTool(toolName);
    if idx < 0 then
    begin
      SendError(msgId, -32602, 'Unknown tool: ' + toolName);
      exit;
    end;

    // Capture the id for the (possibly async) handler callbacks.
    rid := msgId;
    res := procedure(const AText: String)
           begin
             SendToolResult(rid, AText, False);
           end;
    rej := procedure(const AError: String)
           begin
             SendToolResult(rid, AError, True);
           end;

    try
      FHandlers[idx](args, res, rej);
    except
      on E: Exception do
        SendToolResult(rid, 'Handler exception: ' + E.Message, True);
    end;
    exit;
  end;

  SendError(msgId, -32601, 'Method not found: ' + method);
end;


// ── Boot ────────────────────────────────────────────────────────────────────

procedure StartMcp(const AServerName, AVersion: String);
var
  onLine: procedure(const ALine: String);
begin
  SrvName := AServerName;
  SrvVer  := AVersion;

  onLine := procedure(const ALine: String)
            begin
              HandleLine(ALine);
            end;

  asm
    process.stdin.setEncoding('utf8');
    var buf = '';
    process.stdin.on('data', function (d) {
      buf += d;
      var idx;
      while ((idx = buf.indexOf('\n')) !== -1) {
        var line = buf.slice(0, idx).trim();
        buf = buf.slice(idx + 1);
        if (line) { (@onLine)(line); }
      }
    });
    process.stdin.on('end', function () { process.exit(0); });
  end;

  // Diagnostics go to STDERR — stdout is protocol-only.
  console.error('[mcp] ' + AServerName + ' ' + AVersion + ' ready ('
    + IntToStr(Length(FNames)) + ' tools)');
end;

end.
