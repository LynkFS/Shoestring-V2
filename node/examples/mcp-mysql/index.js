// MCP MySQL Server
//
// Exposes three tools to an MCP client:
//   execute_sql    — run any SQL statement (SELECT, INSERT, UPDATE, DELETE, DDL…)
//   list_tables    — list all tables in the connected database
//   describe_table — show column structure of a table
//
// Configuration via environment variables:
//   MYSQL_HOST      (default: localhost)
//   MYSQL_PORT      (default: 3306)
//   MYSQL_USER      (default: root)
//   MYSQL_PASSWORD  (default: "")
//   MYSQL_DATABASE  (default: "")
//
// Usage:
//   npm install
//   MYSQL_HOST=localhost MYSQL_USER=root MYSQL_PASSWORD=secret MYSQL_DATABASE=mydb node index.js
//
// Claude Code .claude/settings.local.json entry:
//   {
//     "mcpServers": {
//       "mysql": {
//         "command": "node",
//         "args": ["/path/to/mcp-mysql/index.js"],
//         "env": {
//           "MYSQL_HOST": "localhost",
//           "MYSQL_USER": "root",
//           "MYSQL_PASSWORD": "secret",
//           "MYSQL_DATABASE": "mydb"
//         }
//       }
//     }
//   }

import { Server }               from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import mysql from 'mysql2/promise';

// ── Connection pool ──────────────────────────────────────────────────────────

const pool = mysql.createPool({
  host:             process.env.MYSQL_HOST     || 'localhost',
  port:             parseInt(process.env.MYSQL_PORT || '3306', 10),
  user:             process.env.MYSQL_USER     || 'root',
  password:         process.env.MYSQL_PASSWORD || '',
  database:         process.env.MYSQL_DATABASE || '',
  waitForConnections: true,
  connectionLimit:  10,
  multipleStatements: false,   // prevent stacked injections in parameterised calls
});

// ── Server ───────────────────────────────────────────────────────────────────

const server = new Server(
  { name: 'mcp-mysql', version: '1.0.0' },
  { capabilities: { tools: {} } },
);

// ── Tool definitions ─────────────────────────────────────────────────────────

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'execute_sql',
      description:
        'Execute any SQL statement on the MySQL database. ' +
        'Returns rows as JSON for SELECT/SHOW queries, or affectedRows/insertId for DML. ' +
        'Use the params array for parameterised queries (? placeholders).',
      inputSchema: {
        type: 'object',
        properties: {
          sql: {
            type: 'string',
            description: 'The SQL statement to execute.',
          },
          params: {
            type: 'array',
            items: {},
            description: 'Optional values for ? placeholders in the SQL.',
          },
        },
        required: ['sql'],
      },
    },
    {
      name: 'list_tables',
      description: 'List all tables in the connected database.',
      inputSchema: {
        type: 'object',
        properties: {},
      },
    },
    {
      name: 'describe_table',
      description: 'Show the column structure (name, type, nullable, key, default) of a table.',
      inputSchema: {
        type: 'object',
        properties: {
          table: {
            type: 'string',
            description: 'Table name.',
          },
        },
        required: ['table'],
      },
    },
  ],
}));

// ── Tool handlers ─────────────────────────────────────────────────────────────

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === 'execute_sql') {
      const [rows] = await pool.execute(args.sql, args.params ?? []);

      if (Array.isArray(rows)) {
        // SELECT / SHOW — return the row set
        return {
          content: [{ type: 'text', text: JSON.stringify(rows, null, 2) }],
        };
      } else {
        // ResultSetHeader — INSERT / UPDATE / DELETE / DDL
        return {
          content: [{
            type: 'text',
            text: JSON.stringify({
              affectedRows: rows.affectedRows,
              insertId:     rows.insertId,
              info:         rows.info,
            }, null, 2),
          }],
        };
      }
    }

    if (name === 'list_tables') {
      const [rows] = await pool.execute('SHOW TABLES');
      const tables = rows.map(row => Object.values(row)[0]);
      return {
        content: [{ type: 'text', text: JSON.stringify(tables, null, 2) }],
      };
    }

    if (name === 'describe_table') {
      const table = args.table.replace(/`/g, '');   // strip backticks from name
      const [rows] = await pool.execute(`DESCRIBE \`${table}\``);
      return {
        content: [{ type: 'text', text: JSON.stringify(rows, null, 2) }],
      };
    }

    throw new Error(`Unknown tool: ${name}`);

  } catch (err) {
    return {
      content: [{ type: 'text', text: `Error: ${err.message}` }],
      isError: true,
    };
  }
});

// ── Start ─────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
