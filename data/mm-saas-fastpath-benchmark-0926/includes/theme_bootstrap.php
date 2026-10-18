<?php
/**
 * Stub for includes/theme_bootstrap.php
 * Sets up $pdo for benchmark harness.
 * Inside the shared container network, MariaDB is at 127.0.0.1:3306.
 */
if (!isset($pdo) || !($pdo instanceof PDO)) {
    $dsn = 'mysql:host=127.0.0.1;port=3306;dbname=musicmetrics;charset=utf8mb4';
    $pdo = new PDO($dsn, 'root', 'benchrootpass', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
}
if (!function_exists('renderThemeBootstrap')) {
    function renderThemeBootstrap(): void {
        // Minimal stub - outputs basic CSS needed for page render
        echo '<style>body{font-family:Inter,sans-serif;margin:0;padding:0}</style>';
    }
}
