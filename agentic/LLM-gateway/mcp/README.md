# MCP servers in ShoeString — `JMcpServer`

Build Model Context Protocol servers in Object Pascal, compiled to Node.
Zero npm dependencies: the MCP **stdio** transport (newline-delimited
JSON-RPC 2.0) is implemented directly, `asm` only at the protocol boundary —
the same discipline as `JLLMProxy`. No `@modelcontextprotocol/sdk` (the
`node/examples/mcp-mysql` precedent uses the SDK; this is the thin
zero-dependency take).

## The scaffold (`JMcpServer.pas`)

```pascal
uses JMcpServer;

RegisterTool(name, description, inputSchemaJson,
  procedure(Args: variant; Resolve: TMcpResolve; Reject: TMcpReject)
  begin
    // sync: call Resolve/Reject now.
    // async: call them later from a fetch/db/child-process callback —
    //        the scaffold writes the JSON-RPC reply whenever they fire.
  end);

StartMcp('server-name', '1.0.0');
```

Handled: `initialize`, `notifications/initialized` (ignored), `tools/list`
(emits each tool's parsed JSON schema), `tools/call` (dispatch), unknown
method → JSON-RPC `-32601`, unknown tool → `-32602`, handler exception →
tool result with `isError:true`.

**Invariant:** stdout is JSON-RPC only. Diagnostics use `console.error`
(stderr). Violating this corrupts the protocol — the scaffold never writes
anything but responses to stdout, and `StartMcp` logs its banner to stderr.

## Example server (`example/`)

`McpExampleTools.pas` registers three tools: `echo` (sync), `now` (sync),
`http_get` (async, Node 18 `fetch`). A database tool is a drop-in — a
handler that `require('mysql2/promise')` and calls `Resolve` with the rows;
the scaffold is indifferent (it only needs Resolve/Reject), so a DB
dependency stays out of this zero-dep example.

## Build (one-time, Quartex IDE — no CLI compiler)

```
cd ShoeStringV2
mv app.entrypoint.pas                              app.entrypoint.dom.pas
cp agentic/mcp/example/app.entrypoint.mcp.pas      app.entrypoint.pas
# ensure JMcpServer + McpExampleTools + NodeTypes are in the project
# Compile in the Quartex IDE → ShoeStringV2/index.js
cp ShoeStringV2/index.js agentic/mcp/example/index.js
mv app.entrypoint.dom.pas app.entrypoint.pas
```

## Run / register with Claude Code

```bash
cd agentic/mcp/example          # no npm install needed (zero deps, Node 18+)
node index.js                   # speaks MCP on stdin/stdout

claude mcp add shoestring-example node /abs/path/agentic/mcp/example/index.js
# or .claude/settings.local.json:
# { "mcpServers": { "shoestring-example": {
#     "command": "node",
#     "args": ["/abs/path/agentic/mcp/example/index.js"] } } }
```

Quick manual check (newline-delimited JSON-RPC):

```bash
printf '%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | node index.js
```

## Adding a tool

One `RegisterTool` call. No scaffold change, no protocol code. Onboarding a
tool is to `JMcpServer` what onboarding a provider is to `JLLMProxy`: a
contained edit at the edge.

## Honesty

Written to the documented dialect and the proven `AsyncDemo`/`JLLMProxy`
`asm` idioms (closure-param-in-asm for Resolve/Reject, `@unitVar`,
single-line JSON-RPC frames) and hand-verified — **not compiler-checked**
(Quartex IDE is GUI-only here). Runnable once compiled per the build steps.
