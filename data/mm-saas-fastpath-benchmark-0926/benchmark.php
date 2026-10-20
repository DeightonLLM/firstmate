<?php
/**
 * Music Metrics fastpath benchmark runner (subprocess mode)
 * Each iteration runs in a fresh PHP process to avoid function-redeclaration issues.
 * Measures TTFB and query count for OLD vs NEW leadlists.php.
 *
 * Run: php benchmark.php
 */
define('BENCH_DB_HOST', '127.0.0.1');
define('BENCH_DB_PORT', '3306');
define('BENCH_DB_NAME', 'musicmetrics');
define('BENCH_DB_USER', 'root');
define('BENCH_DB_PASS', 'benchrootpass');
define('BENCH_USER_ID', 1);
define('BENCH_ITERATIONS', 5);

// Paths
define('SNAPSHOT_DIR', '/snapshot');
define('BENCH_WORK_DIR', '/stubs/work');
define('OLD_FILE', BENCH_WORK_DIR . '/old-leadlists-pre-fastpath.php');
define('NEW_FILE', BENCH_WORK_DIR . '/live-current/leadlists.php');
define('STUB_DIR', '/stubs');
define('FLAG_DIR', '/stubs/mm-cache');
define('WORKER_SCRIPT', '/stubs/worker.php');

/** @return PDO */
function getPdo(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            BENCH_DB_HOST, BENCH_DB_PORT, BENCH_DB_NAME);
        $pdo = new PDO($dsn, BENCH_DB_USER, BENCH_DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
    return $pdo;
}

function clearBootstrapFlag(string $phpFile = null): void {
    // Bootstrap flag is written to __DIR__ . '/mm-cache' by the PHP file.
    // OLD patched file is at BENCH_WORK_DIR/old-leadlists-pre-fastpath.php -> flag at BENCH_WORK_DIR/mm-cache/
    // NEW patched file is at BENCH_WORK_DIR/live-current/leadlists.php -> flag at BENCH_WORK_DIR/live-current/mm-cache/
    @unlink(BENCH_WORK_DIR . '/mm-cache/mm-bootstrap.flag');
    @unlink(BENCH_WORK_DIR . '/live-current/mm-cache/mm-bootstrap.flag');
}

function setBootstrapFlag(string $version = '2026-09-25-1'): void {
    // For NEW version, flag goes to BENCH_WORK_DIR/live-current/mm-cache/
    @mkdir(BENCH_WORK_DIR . '/live-current/mm-cache', 0775, true);
    file_put_contents(BENCH_WORK_DIR . '/live-current/mm-cache/mm-bootstrap.flag', $version);
}

function runSingleIteration(string $phpFile, bool $cold, string $flagVersion = ''): array {
    // Each run in a fresh process to avoid function redeclaration
    // Pass params via environment
    $env = [
        'BENCH_PHP_FILE' => $phpFile,
        'BENCH_COLD' => $cold ? '1' : '0',
        'BENCH_FLAG_VERSION' => $flagVersion,
        'BENCH_USER_ID' => (string)BENCH_USER_ID,
    ];
    if ($flagVersion !== '') {
        setBootstrapFlag($flagVersion);
    }
    if ($cold) {
        dropAppTables(getPdo());
    }

    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];
    // Copy PHP files to bench work dir and patch requires to absolute paths
    @mkdir(BENCH_WORK_DIR . '/includes', 0775, true);
    @mkdir(BENCH_WORK_DIR . '/config', 0775, true);
    @mkdir(BENCH_WORK_DIR . '/live-current', 0775, true);
    // The bootstrap flag is written to __DIR__ . '/mm-cache' by the PHP file
    // Since __DIR__ = BENCH_WORK_DIR, the flag must be at BENCH_WORK_DIR/mm-cache
    @mkdir(BENCH_WORK_DIR . '/mm-cache', 0775, true);

    // Copy and patch OLD version
    $oldSrc = file_get_contents(SNAPSHOT_DIR . '/old-leadlists-pre-fastpath.php');
    $oldPatched = str_replace(
        ["require_once 'includes/auth.php';",
         "require_once __DIR__ . '/includes/theme_bootstrap.php';",
         "require_once __DIR__ . '/includes/category_icons.php';",
         "require_once 'config/rapidapi.php';"],
        ["require_once '/stubs/includes/auth.php';",
         "require_once '/stubs/includes/theme_bootstrap.php';",
         "require_once '/stubs/includes/category_icons.php';",
         "require_once '/stubs/config/rapidapi.php';"],
        $oldSrc
    );
    file_put_contents(BENCH_WORK_DIR . '/old-leadlists-pre-fastpath.php', $oldPatched);

    // Copy and patch NEW version (live-current/leadlists.php)
    $newSrc = file_get_contents(SNAPSHOT_DIR . '/live-current/leadlists.php');
    $newPatched = str_replace(
        ["require_once 'includes/auth.php';",
         "require_once __DIR__ . '/includes/theme_bootstrap.php';",
         "require_once __DIR__ . '/includes/category_icons.php';",
         "require_once 'config/rapidapi.php';"],
        ["require_once '/stubs/includes/auth.php';",
         "require_once '/stubs/includes/theme_bootstrap.php';",
         "require_once '/stubs/includes/category_icons.php';",
         "require_once '/stubs/config/rapidapi.php';"],
        $newSrc
    );
    file_put_contents(BENCH_WORK_DIR . '/live-current/leadlists.php', $newPatched);
    @mkdir(BENCH_WORK_DIR . '/live-current', 0775, true);

    $proc = proc_open(
        'php ' . escapeshellarg(WORKER_SCRIPT),
        $descriptors,
        $pipes,
        '/stubs',
        $env
    );
    if (!is_resource($proc)) {
        return ['ttfb_ms' => -1, 'queries' => -1, 'error' => 'proc_open failed'];
    }
    fclose($pipes[0]);
    // Read stdout (action JSON) but discard - we get timing from result file
    $actionOutput = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[2]);
    $exitCode = proc_close($proc);

    // Read timing result from file written by shutdown function
    $resultFile = "/tmp/bench_" . $workerPid . ".json";
    // Worker PID not available directly; use a fixed path based on parent PID
    $resultFile = "/tmp/bench_result.json";
    if (file_exists($resultFile)) {
        $result = json_decode(file_get_contents($resultFile), true);
        @unlink($resultFile);
        if ($result) return $result;
    }
    // Fallback: parse from stderr if available
    if ($stderr && preg_match('/\\{"ttfb_ms":.*?\}/', $stderr, $m)) {
        return json_decode($m[0], true);
    }
    return ['ttfb_ms' => -1, 'queries' => -1, 'error' => "no result: $stderr", 'stdout' => substr($actionOutput,0,200)];

    $result = json_decode($stdout, true);
    if ($result === null) {
        return ['ttfb_ms' => -1, 'queries' => -1, 'error' => "parse failed: $stdout $stderr"];
    }
    return $result;
}

function dropAppTables(PDO $pdo): void {
    $tables = ['lead_list_items','lead_lists','lead_list_searches',
        'scrape_city_jobs','ghl_connections','ghl_import_logs',
        'ghl_import_items','geo_countries','geo_cities'];
    foreach ($tables as $t) {
        try { $pdo->exec("DROP TABLE IF EXISTS $t"); } catch (Exception $e) {}
    }
}

function recreateSchema(PDO $pdo): void {
    dropAppTables($pdo);
    $pdo->exec("CREATE TABLE IF NOT EXISTS lead_lists (
        id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL,
        name VARCHAR(255) NOT NULL, description TEXT,
        category_group VARCHAR(100) DEFAULT NULL,
        category VARCHAR(100) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS lead_list_items (
        id BIGINT AUTO_INCREMENT PRIMARY KEY, list_id INT NOT NULL, user_id INT NOT NULL,
        business_id VARCHAR(255), business_name VARCHAR(500), address VARCHAR(500),
        city VARCHAR(255), state VARCHAR(255), phone VARCHAR(100), website VARCHAR(500),
        rating DECIMAL(3,2), review_count INT DEFAULT 0, types TEXT,
        latitude DECIMAL(10,8), longitude DECIMAL(11,8),
        emails JSON, social_media_links JSON, notes TEXT,
        status ENUM('cold','warm','hot') DEFAULT 'cold',
        visited_website TINYINT DEFAULT 0, visited_social TINYINT DEFAULT 0,
        reached_out TINYINT DEFAULT 0, website_visited_at DATETIME NULL,
        social_visited_at DATETIME NULL, reached_out_at DATETIME NULL, raw_data JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        enriched_at DATETIME NULL DEFAULT NULL, visited_socials JSON DEFAULT NULL,
        pipeline_stage VARCHAR(20) DEFAULT 'new', outreach_email TINYINT DEFAULT 0,
        outreach_instagram TINYINT DEFAULT 0, follow_up_count INT DEFAULT 0,
        first_contacted_at DATETIME NULL DEFAULT NULL, last_follow_up_at DATETIME NULL DEFAULT NULL,
        enrichment_status VARCHAR(20) DEFAULT NULL, replicate_id VARCHAR(64) DEFAULT NULL,
        ghl_contact_id VARCHAR(100) DEFAULT NULL,
        has_email TINYINT DEFAULT 0, has_socials TINYINT DEFAULT 0,
        has_phone TINYINT DEFAULT 0, has_website TINYINT DEFAULT 0, has_notes TINYINT DEFAULT 0,
        lead_score INT DEFAULT NULL,
        INDEX idx_list (list_id), INDEX idx_user (user_id), INDEX idx_status (status),
        INDEX idx_list_status (list_id, status), INDEX idx_lead_score (lead_score),
        INDEX idx_list_user_created (list_id, user_id, created_at DESC),
        INDEX idx_list_user (list_id, user_id),
        INDEX idx_list_pipeline (list_id, pipeline_stage),
        INDEX idx_list_has_email (list_id, has_email),
        INDEX idx_list_stats_cover (list_id, user_id, status, pipeline_stage, visited_website, visited_social, reached_out, has_email, has_socials, has_phone, has_website, has_notes, outreach_email, outreach_instagram, follow_up_count),
        FULLTEXT idx_search (business_name, address, notes)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS lead_list_searches (
        id INT AUTO_INCREMENT PRIMARY KEY, list_id INT NOT NULL, user_id INT NOT NULL,
        search_query VARCHAR(500), state_name VARCHAR(255), city VARCHAR(255),
        results_count INT DEFAULT 0, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_list (list_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS scrape_city_jobs (
        id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, list_id INT NOT NULL,
        country VARCHAR(12) NOT NULL DEFAULT 'US', country_code VARCHAR(4) DEFAULT NULL,
        state_name VARCHAR(255) NOT NULL, city VARCHAR(255) NOT NULL,
        search_query VARCHAR(500) NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'queued', results_count INT DEFAULT 0,
        error_message VARCHAR(500) DEFAULT NULL, locked_at DATETIME DEFAULT NULL,
        started_at DATETIME DEFAULT NULL, completed_at DATETIME DEFAULT NULL,
        run_id VARCHAR(64) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_scrape_city_job (user_id, list_id, country, state_name, city, search_query),
        INDEX idx_scrape_status (status, created_at),
        INDEX idx_scrape_user_list (user_id, list_id),
        INDEX idx_scrape_run (run_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS ghl_connections (
        id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL,
        name VARCHAR(255) NOT NULL, api_key VARCHAR(500) DEFAULT NULL,
        location_id VARCHAR(100) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS ghl_import_logs (
        id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL,
        connection_id INT DEFAULT NULL, connection_name VARCHAR(255) DEFAULT NULL,
        status VARCHAR(30) DEFAULT 'pending', records_imported INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS ghl_import_items (
        id INT AUTO_INCREMENT PRIMARY KEY, log_id INT NOT NULL,
        ghl_contact_id VARCHAR(100) DEFAULT NULL, status VARCHAR(30) DEFAULT 'pending',
        error_message VARCHAR(500) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX idx_log (log_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS geo_countries (
        id INT AUTO_INCREMENT PRIMARY KEY, country_code VARCHAR(4) NOT NULL UNIQUE,
        name VARCHAR(255) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS geo_cities (
        id INT AUTO_INCREMENT PRIMARY KEY, country_code VARCHAR(4) NOT NULL,
        state_name VARCHAR(255) NOT NULL, city VARCHAR(255) NOT NULL,
        latitude DECIMAL(10,8), longitude DECIMAL(11,8),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_country (country_code), INDEX idx_state (state_name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function seedData(PDO $pdo): void {
    $pdo->exec("DELETE FROM lead_list_items WHERE user_id = " . BENCH_USER_ID);
    $pdo->exec("DELETE FROM lead_lists WHERE user_id = " . BENCH_USER_ID);
    $categories = [
        ['Doctors','Medical','Medical Clinics'],
        ['Law Firms','Legal','Law Firms'],
        ['Accounting Firms','Finance','Accounting Firms'],
        ['Gas Stations','Automotive','Gas Stations'],
        ['Fire Departments','Emergency','Fire Departments'],
    ];
    $states = ['CA','TX','FL','NY','IL','PA','OH','GA','NC','MI'];
    $cities = ['Los Angeles','Houston','Miami','New York','Chicago','Philadelphia','Columbus','Atlanta','Charlotte','Detroit'];
    $statuses = ['cold','warm','hot'];
    $pipelineStages = ['new','contacted','engaged','no_response','client'];
    $listIds = [];
    foreach ($categories as $cat) {
        $stmt = $pdo->prepare("INSERT INTO lead_lists (user_id, name, description, category_group, category) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([BENCH_USER_ID, $cat[0], $cat[2].' - Benchmark Data', $cat[1], $cat[0]]);
        $listIds[] = $pdo->lastInsertId();
    }
    $target = 50000;
    $batch = 1000;
    $done = 0;
    while ($done < $target) {
        $n = min($batch, $target - $done);
        $vals = [];
        $params = [];
        for ($i = 0; $i < $n; $i++) {
            $lid = $listIds[array_rand($listIds)];
            $st = $states[array_rand($states)];
            $ct = $cities[array_rand($cities)];
            $vals[] = "(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
            $params = array_merge($params, [
                $lid, BENCH_USER_ID, 'Biz-'.($done+$i+1),
                "$ct $st Business ".($done+$i+1), "$i $ct St, $st",
                $ct, $st, rand(1000000000,9999999999),
                "https://example$done$i.com",
                rand(0,100)/20, rand(0,500),
                $statuses[array_rand($statuses)],
                rand(0,1), rand(0,1), rand(0,1),
                rand(0,1), rand(0,1), rand(0,1), rand(0,1),
                $pipelineStages[array_rand($pipelineStages)],
                rand(0,100), rand(0,2)===0 ? 'completed' : null,
            ]);
        }
        $pdo->prepare(
            "INSERT INTO lead_list_items (list_id,user_id,business_id,business_name,address,city,state,phone,website,rating,review_count,status,visited_website,visited_social,reached_out,has_email,has_phone,has_website,has_socials,pipeline_stage,lead_score,enrichment_status) VALUES ".implode(',',$vals)
        )->execute($params);
        $done += $n;
    }
    $cnt = $pdo->query("SELECT COUNT(*) FROM lead_list_items")->fetchColumn();
    echo "  Seeded $cnt rows\n";
}

// ========== WORKER SCRIPT (written to disk for subprocess calls) ==========
$workerCode = '<?php
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
';
file_put_contents(WORKER_SCRIPT, $workerCode);

// ========== MAIN ==========
echo "=== Music Metrics Fastpath Benchmark ===\n";
echo "Timestamp: " . date('c') . "\n";
echo "PHP: " . PHP_VERSION . " (benchmark harness)\n";
echo "MariaDB: 10.6 via container networking\n";
echo "\n";

@mkdir(FLAG_DIR, 0775, true);

// Create schema first, then seed data
echo "Seeding 50,000 synthetic lead_list_items...\n";
recreateSchema(getPdo()); // Create tables first
seedData(getPdo());
echo "\n";

// COLD RUNS
echo "--- COLD RUNS (no bootstrap flag; DDL executes) ---\n";
$results = [];
for ($i = 1; $i <= BENCH_ITERATIONS; $i++) {
    echo "  OLD-cold #$i... ";
    $r = runSingleIteration(OLD_FILE, true);
    printf("TTFB=%.4fms  queries=%d\n", $r['ttfb_ms'], $r['queries']);
    $results[] = ['label'=>"OLD-cold#$i",'cold'=>true,'ttfb_ms'=>$r['ttfb_ms'],'queries'=>$r['queries']];
}
for ($i = 1; $i <= BENCH_ITERATIONS; $i++) {
    echo "  NEW-cold #$i... ";
    $r = runSingleIteration(NEW_FILE, true);
    printf("TTFB=%.4fms  queries=%d\n", $r['ttfb_ms'], $r['queries']);
    $results[] = ['label'=>"NEW-cold#$i",'cold'=>true,'ttfb_ms'=>$r['ttfb_ms'],'queries'=>$r['queries']];
}

// WARM RUNS
echo "\n--- WARM RUNS (bootstrap flag present) ---\n";

// Re-create schema and re-seed for warm runs (cold runs dropped tables)
echo "  Re-creating schema and re-seeding for warm tests...\n";
recreateSchema(getPdo());
seedData(getPdo());

// Prime NEW bootstrap flag by running it once (cold=true creates the flag)
echo "  Priming NEW bootstrap flag...\n";
runSingleIteration(NEW_FILE, true);  // creates flag at /stubs/work/mm-cache/mm-bootstrap.flag
clearBootstrapFlag();  // Clear for OLD warm runs (OLD ignores flag anyway)

echo "  [OLD warm: DDL checks run every request]\n";
for ($i = 1; $i <= BENCH_ITERATIONS; $i++) {
    echo "  OLD-warm #$i... ";
    $r = runSingleIteration(OLD_FILE, false);
    printf("TTFB=%.4fms  queries=%d\n", $r['ttfb_ms'], $r['queries']);
    $results[] = ['label'=>"OLD-warm#$i",'cold'=>false,'ttfb_ms'=>$r['ttfb_ms'],'queries'=>$r['queries']];
}

echo "  [NEW warm: DDL skipped — fastpath active]\n";
for ($i = 1; $i <= BENCH_ITERATIONS; $i++) {
    setBootstrapFlag('2026-09-25-1'); // Set flag so NEW skips DDL
    echo "  NEW-warm #$i... ";
    $r = runSingleIteration(NEW_FILE, false);
    printf("TTFB=%.4fms  queries=%d\n", $r['ttfb_ms'], $r['queries']);
    $results[] = ['label'=>"NEW-warm#$i",'cold'=>false,'ttfb_ms'=>$r['ttfb_ms'],'queries'=>$r['queries']];
}

// SUMMARY
echo "\n=== SUMMARY ===\n";

function avgMs($a) { return empty($a) ? 0 : array_sum(array_column($a,'ttfb_ms'))/count($a); }
function avgQ($a)  { return empty($a) ? 0 : array_sum(array_column($a,'queries'))/count($a); }
function minMs($a) { return empty($a) ? 0 : min(array_column($a,'ttfb_ms')); }
function maxMs($a) { return empty($a) ? 0 : max(array_column($a,'ttfb_ms')); }
function minQ($a)  { return empty($a) ? 0 : min(array_column($a,'queries')); }
function maxQ($a)  { return empty($a) ? 0 : max(array_column($a,'queries')); }

$oldCold = array_filter($results, fn($r)=>strpos($r['label'],'OLD-cold')===0);
$newCold = array_filter($results, fn($r)=>strpos($r['label'],'NEW-cold')===0);
$oldWarm = array_filter($results, fn($r)=>strpos($r['label'],'OLD-warm')===0);
$newWarm = array_filter($results, fn($r)=>strpos($r['label'],'NEW-warm')===0);

$stats = [
    'OLD-cold' => ['ttfb_avg'=>round(avgMs($oldCold),4),'ttfb_min'=>round(minMs($oldCold),4),'ttfb_max'=>round(maxMs($oldCold),4),'q_avg'=>round(avgQ($oldCold)),'q_min'=>minQ($oldCold),'q_max'=>maxQ($oldCold)],
    'NEW-cold' => ['ttfb_avg'=>round(avgMs($newCold),4),'ttfb_min'=>round(minMs($newCold),4),'ttfb_max'=>round(maxMs($newCold),4),'q_avg'=>round(avgQ($newCold)),'q_min'=>minQ($newCold),'q_max'=>maxQ($newCold)],
    'OLD-warm' => ['ttfb_avg'=>round(avgMs($oldWarm),4),'ttfb_min'=>round(minMs($oldWarm),4),'ttfb_max'=>round(maxMs($oldWarm),4),'q_avg'=>round(avgQ($oldWarm)),'q_min'=>minQ($oldWarm),'q_max'=>maxQ($oldWarm)],
    'NEW-warm' => ['ttfb_avg'=>round(avgMs($newWarm),4),'ttfb_min'=>round(minMs($newWarm),4),'ttfb_max'=>round(maxMs($newWarm),4),'q_avg'=>round(avgQ($newWarm)),'q_min'=>minQ($newWarm),'q_max'=>maxQ($newWarm)],
];

printf("%-12s %14s %14s %14s %10s %10s\n","","TTFB-avg(ms)","TTFB-min(ms)","TTFB-max(ms)","Q-avg","Q-range");
foreach ($stats as $name => $s) {
    printf("%-12s %14.4f %14.4f %14.4f %10.0f %4d-%d\n",
        $name,$s['ttfb_avg'],$s['ttfb_min'],$s['ttfb_max'],$s['q_avg'],$s['q_min'],$s['q_max']);
}

$oldWarmT = $stats['OLD-warm']['ttfb_avg'];
$newWarmT = $stats['NEW-warm']['ttfb_avg'];
$oldWarmQ = $stats['OLD-warm']['q_avg'];
$newWarmQ = $stats['NEW-warm']['q_avg'];

if ($oldWarmT > 0 && $newWarmT > 0) {
    $speedup = $oldWarmT / $newWarmT;
    $savings = (1 - $newWarmT / $oldWarmT) * 100;
    $queryDiff = $oldWarmQ - $newWarmQ;
    echo "\n";
    echo "WARM scenario improvement:\n";
    echo sprintf("  TTFB speedup: %.2fx (%.1f%% reduction)\n", $speedup, $savings);
    echo sprintf("  Query reduction: %.0f fewer queries per request (%.0f -> %.0f)\n", $queryDiff, $oldWarmQ, $newWarmQ);
}

file_put_contents(STUB_DIR.'/results.json', json_encode([
    'timestamp'=>date('c'),
    'php_version'=>PHP_VERSION,
    'results'=>$results,
    'stats'=>$stats,
    'warm_speedup'=>isset($speedup) ? round($speedup,4) : null,
    'warm_savings_pct'=>isset($savings) ? round($savings,2) : null,
    'warm_query_diff'=>isset($queryDiff) ? round($queryDiff) : null,
], JSON_PRETTY_PRINT));
echo "\nResults: " . STUB_DIR . "/results.json\n";
