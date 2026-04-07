# Scenario 4 — Simple PHP API + MySQL

Browser → HTTPS → PHP file in static-sites → MySQL (Docker or native)

No nginx routing changes needed. PHP files placed in
`~/Docker/services/static-sites/` are processed automatically by the
existing catch-all location in `main.conf`.

---

## How it works

The existing nginx config already has:

```nginx
location ~ ^(?!/phpmyadmin/).*\.php$ {
    root /var/www/static;
    fastcgi_pass php-api;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    ...
}
```

`/var/www/static` maps to `~/Docker/services/static-sites/` on the host,
and the php-api container mounts the same directory. Any `.php` file
copied there is live immediately — no nginx reload required.

---

## Files

| File | Deploy to | Endpoint |
|---|---|---|
| `raw_api_native.php` | `static-sites/db-connect/` | `https://lynkfs.com/db-connect/raw_api_native.php` |
| `raw_api_docker.php` | `static-sites/db-connect/` | `https://lynkfs.com/db-connect/raw_api_docker.php` |
| `books_api.php` | `static-sites/db-connect/` | `https://lynkfs.com/db-connect/books_api.php` |
| `FormBooksRaw.pas` | ShoeStringV2 project | uses `raw_api_native.php` by default |
| `FormBooks.pas` | ShoeStringV2 project | uses `books_api.php` |
| `schema.sql` | reference | database and table definitions |

`raw_api_native.php` and `raw_api_docker.php` are already deployed and tested.

---

## MySQL targets

| PHP file | Host used | MySQL instance |
|---|---|---|
| `raw_api_native.php` | `host.docker.internal` | Native Mac Mini MySQL :3306 |
| `raw_api_docker.php` | `mysql` | Docker MySQL container |
| `books_api.php` | `mysql` | Docker MySQL container |

Both instances have `demo_db` with a `books` table set up and verified.

---

## API styles

### raw_api — accepts any SQL statement

```
POST sql_statement=SELECT * FROM books
← { "rows": [...] }

POST sql_statement=INSERT INTO books (title, author) VALUES ('x', 'y')
← { "affected_rows": 1, "insert_id": 6 }
```

No SQL sanitisation beyond single-quote escaping in the Pascal client.
Suitable for personal/private tools. Keep behind an API key for anything
internet-accessible (uncomment the guard block at the top of the file).

### books_api — action-based, prepared statements

```
POST action=books_all
POST action=books_get    id=N
POST action=books_insert title=x author=y price=9.99 stock=5
POST action=books_delete id=N
```

No raw SQL travels over the network. Safe for more open use.

---

## Deploying books_api.php

```bash
cp books_api.php ~/Docker/services/static-sites/db-connect/
```

Verify:

```bash
curl -s -X POST https://lynkfs.com/db-connect/books_api.php \
     -d 'action=books_all' | jq .
```

---

## MySQL users

Any user with the necessary privileges on the target database will work.
Change the username (and password if different) in the `mysqli_connect` call.

### Available users — native MySQL

| User | Host | Access |
|---|---|---|
| `app_user` | `%` | All privileges on `demo_db` |
| `demo_db_user` | `%` | All privileges on `demo_db` only |
| `emergent_user` | `localhost` only | All privileges on `emergent_design` only |

`demo_db_user` is a direct alternative to `app_user` for `demo_db` — same
privileges, reachable from Docker. `emergent_user` is restricted to Unix socket
connections on the Mac itself and cannot be reached from a Docker container.

### Available users — Docker MySQL

| User | Host | Access |
|---|---|---|
| `app_user` | `%` | Global privileges + all privileges on `demo_db` |

### Using a different user

If the user shares the Docker secret password:

```php
$password = trim(file_get_contents('/run/secrets/mysql_password'));
$conn = mysqli_connect('host.docker.internal', 'demo_db_user', $password, 'demo_db', 3306);
```

If the user has a different password, hardcode it or store it in a separate file:

```php
$conn = mysqli_connect('host.docker.internal', 'other_user', 'their_password', 'their_db', 3306);
```

---

## Pascal forms

### FormBooksRaw.pas

Uses `raw_api_native.php`. Change the `ApiURL` constant to switch targets:

```pascal
ApiURL = 'https://lynkfs.com/db-connect/raw_api_native.php';  // native MySQL
ApiURL = 'https://lynkfs.com/db-connect/raw_api_docker.php';  // Docker MySQL
```

Register in `app.entrypoint.pas`:

```pascal
uses ..., FormBooksRaw;
Application.CreateForm('FormBooksRaw', TFormBooksRaw);
Application.GoToForm('FormBooksRaw');
```

### FormBooks.pas

Uses `books_api.php` (action-based). Register the same way with `TFormBooks`.
