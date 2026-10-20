<?php
// Worker script for single benchmark iteration
// Uses register_shutdown_function to capture timing even when the
// included file calls exit() (as most action handlers do).
$phpFile = getenv("BENCH_PHP_FILE");
$resultFile = "/tmp/bench_result.json";

// Connect to DB
$pdo = new PDO(
    "mysql:host=127.0.0.1;port=3306;dbname=musicmetrics;charset=utf8mb4",
    "root", "benchrootpass",
    [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]
);

// Baseline query count
$stmt = $pdo->query("SHOW SESSION STATUS LIKE \"Questions\"");
$baseline = (int)$stmt->fetch(PDO::FETCH_ASSOC)["Value"];

// Start timing
$start = hrtime(true);

// Set up session via session file (needed because leadlists.php calls session_start())
$savePath = sys_get_temp_dir();
session_save_path($savePath);
session_start();
$_SESSION["user_id"] = (int)getenv("BENCH_USER_ID");
$_SESSION["logged_in"] = true;
session_write_close();

// Use getLists action to return JSON quickly without HTML rendering
$_GET["action"] = "getLists";

// Capture end time before include so we have it for the shutdown function
$GLOBALS["_bench_start"] = $start;
$GLOBALS["_bench_baseline"] = $baseline;
$GLOBALS["_bench_pdo"] = $pdo;

// Register shutdown to capture timing and write to file
// This fires even when the included file calls exit()
register_shutdown_function(function() use ($resultFile) {
    $start = $GLOBALS["_bench_start"];
    $baseline = $GLOBALS["_bench_baseline"];
    $pdo = $GLOBALS["_bench_pdo"];
    $end = hrtime(true);
    try {
        $stmt = $pdo->query("SHOW SESSION STATUS LIKE \"Questions\"");
        $q = max(0, (int)$stmt->fetch(PDO::FETCH_ASSOC)["Value"] - $baseline);
    } catch (Exception $e) { $q = -1; }
    $elapsed = round(($end - $start) / 1e6, 4);
    @file_put_contents($resultFile, json_encode(["ttfb_ms"=>$elapsed,"queries"=>$q]));
});

try {
    include($phpFile);
} catch (Throwable $e) {
    // DDL errors on cold runs
}
