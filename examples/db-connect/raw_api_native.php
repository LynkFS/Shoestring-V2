<?php
/**
 * Raw SQL API — Native MySQL on the Mac Mini
 *
 * Reaches the Mac's native MySQL (port 3306) from inside the Docker php-api
 * container via host.docker.internal.
 *
 * Copy to: ~/Docker/services/php-api/public/raw_api_native.php
 * Endpoint: https://lynkfs.com/api/php/raw_api_native.php
 *
 * POST  sql_statement=SELECT * FROM books
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// ── Optional API key guard ────────────────────────────────────────────────────
// $apiKey = $_POST['api_key'] ?? '';
// if ($apiKey !== 'change-me') { http_response_code(401); echo json_encode(['error'=>'Unauthorised']); exit; }

// ── Connection ────────────────────────────────────────────────────────────────

$password = trim(file_get_contents('/run/secrets/mysql_password'));
$conn = mysqli_connect('host.docker.internal', 'app_user', $password, 'demo_db', 3306);
if (!$conn) {
    echo json_encode(['error' => 'Connection failed: ' . mysqli_connect_error()]);
    exit;
}

// ── Execute ───────────────────────────────────────────────────────────────────

$sql = trim($_POST['sql_statement'] ?? '');
if ($sql === '') {
    http_response_code(400);
    echo json_encode(['error' => 'sql_statement is required']);
    mysqli_close($conn);
    exit;
}

try {
    $result = mysqli_query($conn, $sql);

    if ($result === false) {
        echo json_encode(['ok' => false, 'error' => mysqli_error($conn)]);
    } elseif (is_bool($result)) {
        echo json_encode([
            'ok'            => true,
            'affected_rows' => mysqli_affected_rows($conn),
            'insert_id'     => (int) mysqli_insert_id($conn),
        ]);
    } else {
        $rows = [];
        while ($row = mysqli_fetch_assoc($result)) $rows[] = $row;
        mysqli_free_result($result);
        echo json_encode(['ok' => true, 'rows' => $rows]);
    }
} catch (Exception $e) {
    echo json_encode(['ok' => false, 'error' => $e->getMessage()]);
}

mysqli_close($conn);
?>
