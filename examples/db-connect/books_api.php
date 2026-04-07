<?php
/**
 * Scenario 4 — Action-based PHP API (prepared statements)
 *
 * Copy to: ~/Docker/services/static-sites/scenario4/books_api.php
 * Endpoint: https://lynkfs.com/scenario4/books_api.php
 *
 * POST  action=books_all
 * POST  action=books_get    id=N
 * POST  action=books_insert title author price stock
 * POST  action=books_delete id=N
 *
 * No raw SQL travels over the network. Each action maps to a hardcoded
 * prepared statement — unknown actions are rejected outright.
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// ── Optional API key guard ────────────────────────────────────────────────────
// Uncomment and set a secret. The Pascal client must include &api_key=<secret>
// in every POST body. Simple protection for internet-facing endpoints.
//
// $apiKey = $_POST['api_key'] ?? '';
// if ($apiKey !== 'change-me-to-a-long-random-string') {
//     http_response_code(401);
//     echo json_encode(['ok' => false, 'error' => 'Unauthorised']);
//     exit;
// }

// ── Connection ────────────────────────────────────────────────────────────────
// Runs inside the php-api container. Password comes from the Docker secret.
// Use 'mysql' for Docker MySQL, 'host.docker.internal' for native MySQL.

$password = trim(file_get_contents('/run/secrets/mysql_password'));
$conn = mysqli_connect('mysql', 'app_user', $password, 'demo_db');
if (!$conn) {
    echo json_encode(['ok' => false, 'error' => 'Connection failed: ' . mysqli_connect_error()]);
    exit;
}

// ── Action dispatch ───────────────────────────────────────────────────────────

$action = trim($_POST['action'] ?? '');

switch ($action) {

    // ── List all books ────────────────────────────────────────────────────────

    case 'books_all':
        $result = mysqli_query($conn, 'SELECT id, title, author, price, stock FROM books ORDER BY title');
        if ($result === false) {
            echo json_encode(['ok' => false, 'error' => mysqli_error($conn)]);
            break;
        }
        $rows = [];
        while ($row = mysqli_fetch_assoc($result)) {
            $rows[] = $row;
        }
        mysqli_free_result($result);
        echo json_encode(['ok' => true, 'rows' => $rows]);
        break;

    // ── Get single book ───────────────────────────────────────────────────────

    case 'books_get':
        $id   = intval($_POST['id'] ?? 0);
        $stmt = mysqli_prepare($conn, 'SELECT * FROM books WHERE id = ?');
        mysqli_stmt_bind_param($stmt, 'i', $id);
        mysqli_stmt_execute($stmt);
        $result = mysqli_stmt_get_result($stmt);
        $row    = mysqli_fetch_assoc($result);
        echo json_encode(['ok' => true, 'row' => $row ?: null]);
        mysqli_stmt_close($stmt);
        break;

    // ── Insert book ───────────────────────────────────────────────────────────

    case 'books_insert':
        $title  = trim($_POST['title']  ?? '');
        $author = trim($_POST['author'] ?? '');
        $price  = floatval($_POST['price'] ?? 0);
        $stock  = intval($_POST['stock']  ?? 0);

        if (!$title || !$author) {
            echo json_encode(['ok' => false, 'error' => 'title and author are required']);
            break;
        }

        $stmt = mysqli_prepare($conn,
            'INSERT INTO books (title, author, price, stock) VALUES (?, ?, ?, ?)');
        mysqli_stmt_bind_param($stmt, 'ssdi', $title, $author, $price, $stock);
        mysqli_stmt_execute($stmt);
        echo json_encode(['ok' => true, 'insert_id' => (int) mysqli_insert_id($conn)]);
        mysqli_stmt_close($stmt);
        break;

    // ── Delete book ───────────────────────────────────────────────────────────

    case 'books_delete':
        $id   = intval($_POST['id'] ?? 0);
        $stmt = mysqli_prepare($conn, 'DELETE FROM books WHERE id = ?');
        mysqli_stmt_bind_param($stmt, 'i', $id);
        mysqli_stmt_execute($stmt);
        echo json_encode([
            'ok'            => true,
            'affected_rows' => mysqli_affected_rows($conn),
        ]);
        mysqli_stmt_close($stmt);
        break;

    // ── Unknown action ────────────────────────────────────────────────────────

    case '':
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'action is required']);
        break;

    default:
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => "Unknown action: $action"]);
}

mysqli_close($conn);
?>
