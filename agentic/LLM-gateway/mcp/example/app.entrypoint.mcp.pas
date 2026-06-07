// ═══════════════════════════════════════════════════════════════════════════
//
//  app.entrypoint.mcp.pas — Node target for the example MCP server
//
//  Swap into the ShoeStringV2 project (same dance as the other agentic
//  entrypoints), compile in the Quartex IDE → index.js, then run it as an
//  MCP stdio server: `node index.js`. See README.md.
//
//  McpExampleTools' `initialization` registers the tools and calls StartMcp.
//  STDOUT is JSON-RPC only — diagnostics go to STDERR.
//
// ═══════════════════════════════════════════════════════════════════════════

uses McpExampleTools;
