# mcp-mysql

Two things in one directory:

- **`index.js`** — MCP server (stdio) for Claude Code. Exposes `execute_sql`, `list_tables`, `describe_table`.
- **`server.js`** — HTTP companion for `FormDemo.pas`. Bridges the browser to MySQL.

---

## Prerequisites

- Node.js 18+
- MySQL running and accessible
- For the browser form: ShoeStringV2 compiled to `index.js`

---

## Install

```bash
cd ShoeStringV2/node/examples/mcp-mysql
npm install
```

---

## 1. MCP Server (Claude Code tool use)

### Start

```bash
# Mac / Linux
MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PASSWORD=secret MYSQL_DATABASE=legacy_app node index.js

# Windows (PowerShell)
$env:MYSQL_HOST="127.0.0.1"; $env:MYSQL_USER="root"; $env:MYSQL_PASSWORD="secret"; $env:MYSQL_DATABASE="legacy_app"; node index.js
```

### Register with Claude Code

Add to `.claude/settings.local.json`:

```json
{
  "mcpServers": {
    "mysql": {
      "command": "node",
      "args": ["C:\\path\\to\\mcp-mysql\\index.js"],
      "env": {
        "MYSQL_HOST": "127.0.0.1",
        "MYSQL_USER": "root",
        "MYSQL_PASSWORD": "secret",
        "MYSQL_DATABASE": "legacy_app"
      }
    }
  }
}
```

Or via CLI:

```bash
claude mcp add mysql node /path/to/mcp-mysql/index.js \
  --env MYSQL_HOST=127.0.0.1 \
  --env MYSQL_USER=root \
  --env MYSQL_PASSWORD=secret \
  --env MYSQL_DATABASE=legacy_app
```

Restart Claude Code. Verify with `claude mcp list`.

### Tools available

| Tool | Description |
|---|---|
| `execute_sql` | Run any SQL — returns rows or affectedRows/insertId |
| `list_tables` | List all tables in the connected database |
| `describe_table` | Show column structure of a table |

---

## 2. HTTP Server + FormDemo (browser UI)

### Start the HTTP server

No database is hardcoded — the browser selects one at runtime.

```bash
# Mac / Linux
MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PASSWORD=secret node server.js

# Windows (PowerShell)
$env:MYSQL_HOST="127.0.0.1"; $env:MYSQL_USER="root"; $env:MYSQL_PASSWORD="secret"; node server.js
```

Listens on `http://localhost:3001` by default. Override with `HTTP_PORT=3002`.

### Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/connect?db=name` | Test connection to a specific database |
| GET | `/databases` | List all databases on the server |
| GET | `/tables?db=name` | List tables in a database |
| POST | `/query` | Run SQL — body: `{ sql, db?, params? }` |

### Register FormDemo in ShoeStringV2

Add to `app.entrypoint.pas`:

```pascal
uses ..., FormDemo;
Application.CreateForm('FormDemo', TFormDemo);
```

Set as startup form:

```pascal
Application.GoToForm('FormDemo');
```

Compile in Quartex Pascal IDE, then open `index.html` in the browser.

---

## Connecting from a remote machine (e.g. Win11 VMware VM)

Test connectivity first:

```powershell
Test-NetConnection -ComputerName 192.168.1.202 -Port 3306
```

If MySQL is bound to `127.0.0.1` only, edit `/opt/homebrew/etc/my.cnf` on the Mac:

```ini
bind-address = 0.0.0.0
```

Then restart MySQL:

```bash
brew services restart mysql
```

Set `MYSQL_HOST` to the Mac's IP when starting either server:

```bash
MYSQL_HOST=192.168.1.202 MYSQL_USER=root MYSQL_PASSWORD=secret node server.js
```

---

## Deploying behind nginx (lynkfs.com)

Run `server.js` natively on the Mac Mini. Add to `nginx/conf.d/main.conf`:

```nginx
upstream legacy-api {
    server host.docker.internal:3001;
    keepalive 16;
}

location /api/legacy/ {
    proxy_pass http://legacy-api/;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Update `FormDemo.pas`:

```pascal
const
  ServerURL = '/api/legacy';
```

No CORS headers needed — same origin via nginx.
