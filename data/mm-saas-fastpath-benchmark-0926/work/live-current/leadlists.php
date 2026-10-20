<?php
// Extend session lifetime to 8 hours for scrape workflows (auth.php params applied here)
ini_set('session.gc_maxlifetime', '28800');
ini_set('session.cookie_lifetime', '28800');
session_set_cookie_params([
    'lifetime' => 28800,
    'secure'   => true,
    'httponly' => true,
    'samesite' => 'Strict',
]);

session_start();
require_once '/stubs/includes/auth.php';
require_once '/stubs/includes/theme_bootstrap.php';
require_once '/stubs/includes/category_icons.php';
require_once '/stubs/config/rapidapi.php';

// ---------------------------------------------------------------------------
// Internal webhook auth token (audit S-C1, 2026-07-04):
// Inline helper to fetch DB_SCHEMA_PROBE_TOKEN once per request so the
// in-app callers (fireAllScrapes, recoverStuckEnrichments, retryFailedEnrichments)
// can authenticate to webhook_scrape.php via the X-API-Token header.
// fallback: empty string so the gate in webhook_scrape.php rejects with 401
// when the token cannot be resolved (fail-closed).
// ---------------------------------------------------------------------------
if (!function_exists('_internal_webhook_token')) {
    function _internal_webhook_token(): string {
        static $cached = null;
        if ($cached !== null) return $cached;
        $cached = '';
        $envFile = __DIR__ . '/.env';
        if (!is_readable($envFile)) return $cached;
        $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '' || $line[0] === '#' || strpos($line, '=') === false) continue;
            list($key, $val) = explode('=', $line, 2);
            if (trim($key) !== 'DB_SCHEMA_PROBE_TOKEN') continue;
            $val = trim($val);
            if (preg_match('/^([\'"])(.*)\1$/', $val, $m)) $val = $m[2];
            $cached = $val;
            break;
        }
        return $cached;
    }
}

if (!isLoggedIn()) {
    header('Location: login.php');
    exit();
}

$userId = $_SESSION['user_id'];
$isAdminViewing = isset($_SESSION['admin_original_id']);
$stmt = $pdo->prepare("SELECT credits, shared_for_credits FROM users WHERE id = ?");
$stmt->execute([$userId]);
$uRow = $stmt->fetch(PDO::FETCH_ASSOC);
$userCredits = $uRow['credits'] ?? 0;
$userHasShared = $uRow['shared_for_credits'] ?? 0;
$selectedCategoryGroup = trim($_GET['category_group'] ?? '');
$selectedCategory = trim($_GET['category'] ?? '');

function ensureColumn(PDO $pdo, string $table, string $column, string $definition): void {
    try {
        $stmt = $pdo->prepare("SHOW COLUMNS FROM `$table` LIKE ?");
        $stmt->execute([$column]);
        if ($stmt->rowCount() === 0) $pdo->exec("ALTER TABLE `$table` ADD COLUMN $definition");
    } catch (Exception $e) {}
}

function ensureIndex(PDO $pdo, string $table, string $index, string $definition): void {
    try {
        $stmt = $pdo->prepare("SHOW INDEX FROM `$table` WHERE Key_name = ?");
        $stmt->execute([$index]);
        if ($stmt->rowCount() === 0) $pdo->exec("ALTER TABLE `$table` ADD INDEX $definition");
    } catch (Exception $e) {}
}

// Metrics for overview cards
try {
    $metricsStmt = $pdo->prepare("
        SELECT
            COUNT(id) as total_leads,
            SUM(has_email) as verified_emails,
            SUM(has_socials) as have_socials,
            SUM(has_phone) as have_phone,
            ? as remaining_credits
        FROM lead_list_items
        WHERE user_id = ?
    ");
    $metricsStmt->execute([$userCredits, $userId]);
    $metrics = $metricsStmt->fetch(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    $metrics = ['total_leads' => 0, 'verified_emails' => 0, 'have_socials' => 0, 'have_phone' => 0, 'remaining_credits' => $userCredits];
}

try { $pdo->prepare("UPDATE users SET last_active_at = NOW() WHERE id = ?")->execute([$userId]); } catch (Exception $e) {}


// === MM-BOOTSTRAP-FASTPATH:HELPERS ===
if (!defined('MM_BOOTSTRAP_VERSION')) define('MM_BOOTSTRAP_VERSION', '2026-09-25-1');
if (!function_exists('mm_bootstrap_flag_path_dir')) {
function mm_bootstrap_flag_path_dir(): string {
    foreach ([__DIR__ . '/mm-cache', sys_get_temp_dir()] as $dir) {
        if (@is_dir($dir) && @is_writable($dir)) return rtrim($dir, '/');
        if (@mkdir($dir, 0775, true) && @is_writable($dir)) return rtrim($dir, '/');
    }
    return '';
}
}
if (!function_exists('mm_bootstrap_flag_path')) {
function mm_bootstrap_flag_path(): string {
    $d = mm_bootstrap_flag_path_dir();
    return $d === '' ? '' : $d . '/mm-bootstrap.flag';
}
}
if (!function_exists('mm_bootstrap_needed')) {
/** true = run DDL bootstrap; false = flag matches version, skip entirely. */
function mm_bootstrap_needed(string $version, ?string $dirOverride = null): bool {
    $dir = ($dirOverride !== null) ? rtrim($dirOverride, '/') : mm_bootstrap_flag_path_dir();
    if ($dir === '') return true;
    $c = @file_get_contents($dir . '/mm-bootstrap.flag');
    return ($c === false || trim((string)$c) !== $version);
}
}
// === MM-BOOTSTRAP-FASTPATH:HELPERS-END ===

// Relocated above the bootstrap guard: needed by request handlers regardless of skip state.
if (!function_exists('computeLeadScore')) {
function computeLeadScore($lead) {
    // 1. Contact Completeness (max 20)
    $contactScore = 0;
    if (!empty($lead['emails']) || ($lead['has_email'] ?? 0)) $contactScore += 7;
    if (!empty($lead['phone']) || ($lead['has_phone'] ?? 0)) $contactScore += 5;
    if (!empty($lead['website']) || ($lead['has_website'] ?? 0)) $contactScore += 5;
    if (!empty($lead['social_media_links']) || ($lead['has_socials'] ?? 0)) $contactScore += 3;

    // 2. Reputation (max 15): Google/local rating normalised
    $repScore = 0;
    if (!empty($lead['rating']) && floatval($lead['rating']) > 0) {
        $repScore = min(15, round(floatval($lead['rating']) / 5 * 15, 0));
    }

    // 3. Engagement Depth (max 25 + up to 12 from follow-ups)
    $stage = $lead['pipeline_stage'] ?? 'new';
    $stageScore = match($stage) {
        'client'      => 25,
        'engaged'     => 18,
        'contacted'   => 10,
        'no_response' => 4,
        default       => 0
    };
    $followUps = intval($lead['follow_up_count'] ?? 0);
    $engageScore = $stageScore + min(12, $followUps * 3);

    // 4. Outreach Status (max 20 + 5+5+3 extras)
    $outreachScore = ($lead['reached_out'] ?? 0) ? 20 : 0;
    if ($lead['outreach_email'] ?? 0)    $outreachScore += 5;
    if ($lead['outreach_instagram'] ?? 0) $outreachScore += 5;
    if (!empty($lead['first_contacted_at'])) $outreachScore += 3;

    // 5. Enrichment Quality (max 10 + up to 5 recency bonus)
    $enrichScore = (($lead['enrichment_status'] ?? '') === 'completed') ? 10 : 0;
    if (!empty($lead['enriched_at'])) {
        $daysSince = (time() - strtotime($lead['enriched_at'])) / 86400;
        if ($daysSince <= 30) $enrichScore += 5;
    }

    // 6. Freshness (max 10)
    $freshScore = 0;
    if (!empty($lead['enriched_at'])) {
        $daysSince = (time() - strtotime($lead['enriched_at'])) / 86400;
        if ($daysSince <= 30) $freshScore = 10;
        elseif ($daysSince <= 90) $freshScore = 5;
    }

    $score = max(0, min(100, $contactScore + $repScore + $engageScore + $outreachScore + $enrichScore + $freshScore));
    $tier  = $score >= 72 ? 'hot' : ($score >= 45 ? 'warm' : 'cold');
    $label = ucfirst($tier);

    return ['score' => (int)$score, 'tier' => $tier, 'label' => $label];
}

}
if (!function_exists('persistLeadScore')) {
/**
 * Persist lead_score and sync status column for a single lead row.
 */
function persistLeadScore($pdo, $userId, $leadId, $lead) {
    $result = computeLeadScore($lead);
    $stmt = $pdo->prepare("UPDATE lead_list_items SET lead_score = ?, status = ? WHERE id = ? AND user_id = ?");
    $stmt->execute([$result['score'], $result['tier'], $leadId, $userId]);
}

}

$mmBootstrapSkip = !mm_bootstrap_needed(MM_BOOTSTRAP_VERSION);
// Recovery escape: ?mm_rebootstrap=1 forces a full DDL re-run this request (review finding #3).
if (isset($_GET['mm_rebootstrap'])) { @unlink(mm_bootstrap_flag_path()); $mmBootstrapSkip = false; }
if (!$mmBootstrapSkip) { // === MM-BOOTSTRAP-FASTPATH:SECTION ===
// Auto-create tables
try {
    $pdo->query("SELECT 1 FROM lead_lists LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("CREATE TABLE lead_lists (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user (user_id)
    )");
}

try {
    $pdo->query("SELECT 1 FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("CREATE TABLE lead_list_items (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        list_id INT NOT NULL,
        user_id INT NOT NULL,
        business_id VARCHAR(255),
        business_name VARCHAR(500),
        address VARCHAR(500),
        city VARCHAR(255),
        state VARCHAR(255),
        phone VARCHAR(100),
        website VARCHAR(500),
        rating DECIMAL(3,2),
        review_count INT DEFAULT 0,
        types TEXT,
        latitude DECIMAL(10,8),
        longitude DECIMAL(11,8),
        emails JSON,
        social_media_links JSON,
        notes TEXT,
        status ENUM('cold','warm','hot') DEFAULT 'cold',
        visited_website TINYINT DEFAULT 0,
        visited_social TINYINT DEFAULT 0,
        reached_out TINYINT DEFAULT 0,
        website_visited_at DATETIME NULL,
        social_visited_at DATETIME NULL,
        reached_out_at DATETIME NULL,
        raw_data JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_list (list_id),
        INDEX idx_user (user_id),
        INDEX idx_status (status),
        INDEX idx_list_status (list_id, status),
        FULLTEXT idx_search (business_name, address, notes)
    )");
}

try {
    $pdo->query("SELECT 1 FROM lead_list_searches LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("CREATE TABLE lead_list_searches (
        id INT AUTO_INCREMENT PRIMARY KEY,
        list_id INT NOT NULL,
        user_id INT NOT NULL,
        search_query VARCHAR(500),
        state_name VARCHAR(255),
        city VARCHAR(255),
        results_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_list (list_id)
    )");
}

try {
    $pdo->query("SELECT enriched_at FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN enriched_at DATETIME NULL DEFAULT NULL");
}

try {
    $pdo->query("SELECT visited_socials FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN visited_socials JSON DEFAULT NULL");
}

try {
    $pdo->query("SELECT pipeline_stage FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN pipeline_stage VARCHAR(20) DEFAULT 'new'");
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN outreach_email TINYINT DEFAULT 0");
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN outreach_instagram TINYINT DEFAULT 0");
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN follow_up_count INT DEFAULT 0");
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN first_contacted_at DATETIME NULL DEFAULT NULL");
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN last_follow_up_at DATETIME NULL DEFAULT NULL");
    $pdo->exec("UPDATE lead_list_items SET pipeline_stage = 'contacted' WHERE reached_out = 1");
}

try {
    $pdo->query("SELECT enrichment_status FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN enrichment_status VARCHAR(20) DEFAULT NULL");
    $pdo->exec("UPDATE lead_list_items SET enrichment_status = 'completed' WHERE enriched_at IS NOT NULL");
}

try {
    $pdo->query("SELECT replicate_id FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN replicate_id VARCHAR(64) DEFAULT NULL");
}

try {
    $pdo->query("SELECT public_token FROM lead_lists LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_lists ADD COLUMN is_public TINYINT DEFAULT 0");
    $pdo->exec("ALTER TABLE lead_lists ADD COLUMN public_token VARCHAR(64) DEFAULT NULL");
    $pdo->exec("ALTER TABLE lead_lists ADD UNIQUE INDEX idx_public_token (public_token)");
}

foreach (['lead_lists', 'lead_list_items'] as $categoryTable) {
    ensureColumn($pdo, $categoryTable, 'category_group', 'category_group VARCHAR(120) DEFAULT NULL');
    ensureColumn($pdo, $categoryTable, 'category', 'category VARCHAR(160) DEFAULT NULL');
    ensureColumn($pdo, $categoryTable, 'subcategory', 'subcategory VARCHAR(160) DEFAULT NULL');
    ensureColumn($pdo, $categoryTable, 'source', 'source VARCHAR(120) DEFAULT NULL');
    ensureColumn($pdo, $categoryTable, 'country', 'country VARCHAR(80) DEFAULT NULL');
    ensureIndex($pdo, $categoryTable, "idx_{$categoryTable}_category", "idx_{$categoryTable}_category (user_id, category_group, category)");
}

// Custom icon/color for lead lists
try { $pdo->query("SELECT icon_class FROM lead_lists LIMIT 1"); } catch (Exception $e) {
    try { $pdo->exec("ALTER TABLE lead_lists ADD COLUMN icon_class VARCHAR(80) DEFAULT NULL"); } catch (Exception $e2) {}
    try { $pdo->exec("ALTER TABLE lead_lists ADD COLUMN icon_color VARCHAR(40) DEFAULT NULL"); } catch (Exception $e2) {}
}

try {
    $pdo->query("SELECT 1 FROM scrape_city_jobs LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("CREATE TABLE scrape_city_jobs (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        list_id INT NOT NULL,
        country VARCHAR(12) NOT NULL DEFAULT 'US',
        state_name VARCHAR(255) NOT NULL,
        city VARCHAR(255) NOT NULL,
        search_query VARCHAR(500) NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'queued',
        results_count INT DEFAULT 0,
        error_message VARCHAR(500) DEFAULT NULL,
        locked_at DATETIME DEFAULT NULL,
        started_at DATETIME DEFAULT NULL,
        completed_at DATETIME DEFAULT NULL,
        run_id VARCHAR(64) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_scrape_city_job (user_id, list_id, country, state_name, city, search_query),
        INDEX idx_scrape_status (status, created_at),
        INDEX idx_scrape_user_list (user_id, list_id),
        INDEX idx_scrape_run (run_id)
    )");
}
ensureColumn($pdo, 'scrape_city_jobs', 'run_id', 'run_id VARCHAR(64) DEFAULT NULL');
ensureIndex($pdo, 'scrape_city_jobs', 'idx_scrape_run', 'idx_scrape_run (run_id)');
// [HOTFIX-20260801] Country-mapping: store per-job ISO 3166-1 alpha-2 country code.
ensureColumn($pdo, 'scrape_city_jobs', 'country_code', 'country_code VARCHAR(4) DEFAULT NULL');

try {
    $pdo->query("SELECT ghl_api_key FROM users LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE users ADD COLUMN ghl_api_key VARCHAR(255) DEFAULT NULL");
    $pdo->exec("ALTER TABLE users ADD COLUMN ghl_location_id VARCHAR(100) DEFAULT NULL");
}

try {
    $pdo->query("SELECT ghl_contact_id FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN ghl_contact_id VARCHAR(100) DEFAULT NULL");
}

try {
    $pdo->query("SELECT has_email FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN has_email TINYINT DEFAULT 0, ADD COLUMN has_socials TINYINT DEFAULT 0");
    $pdo->exec("UPDATE lead_list_items SET has_email = 1 WHERE JSON_LENGTH(COALESCE(emails, '[]')) > 0");
    $pdo->exec("UPDATE lead_list_items SET has_socials = 1 WHERE JSON_LENGTH(COALESCE(social_media_links, '[]')) > 0");
}

try {
    $pdo->query("SELECT has_phone FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN has_phone TINYINT DEFAULT 0, ADD COLUMN has_website TINYINT DEFAULT 0, ADD COLUMN has_notes TINYINT DEFAULT 0");
    $pdo->exec("UPDATE lead_list_items SET has_phone = 1 WHERE phone IS NOT NULL AND phone != ''");
    $pdo->exec("UPDATE lead_list_items SET has_website = 1 WHERE website IS NOT NULL AND website != ''");
    $pdo->exec("UPDATE lead_list_items SET has_notes = 1 WHERE notes IS NOT NULL AND notes != ''");
}

// ── Lead Rating System v1 ───────────────────────────────────────────────────
try {
    $pdo->query("SELECT lead_score FROM lead_list_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("ALTER TABLE lead_list_items ADD COLUMN lead_score INT DEFAULT NULL");
    $pdo->exec("CREATE INDEX idx_lead_score ON lead_list_items (lead_score)");
    // Backfill: compute scores for all existing leads
    $pdo->exec("UPDATE lead_list_items SET lead_score = (
        SELECT contact_score + reputation_score + engagement_score + outreach_score + enrichment_score + freshness_score
        FROM (
            SELECT id,
                IF(has_email=1,7,0) + IF(has_phone=1,5,0) + IF(has_website=1,5,0) + IF(has_socials=1,3,0) AS contact_score,
                IF(rating IS NOT NULL AND rating > 0, LEAST(ROUND(rating/5*15,0),15), 0) AS reputation_score,
                IF(pipeline_stage='client',25, IF(pipeline_stage='engaged',18, IF(pipeline_stage='contacted',10, IF(pipeline_stage='no_response',4, 0)))) + LEAST(follow_up_count*3,12) AS engagement_score,
                IF(reached_out=1,20,0) + IF(outreach_email=1,5,0) + IF(outreach_instagram=1,5,0) + IF(first_contacted_at IS NOT NULL,3,0) AS outreach_score,
                IF(enrichment_status='completed',10,0) + IF(enriched_at IS NOT NULL AND enriched_at >= DATE_SUB(NOW(), INTERVAL 30 DAY),5,0) AS enrichment_score,
                IF(enriched_at IS NOT NULL AND enriched_at >= DATE_SUB(NOW(), INTERVAL 30 DAY),10,0) AS freshness_score
            FROM lead_list_items
        ) AS scored
        WHERE scored.id = lead_list_items.id
    )");
    // Sync status column from backfilled scores
    $pdo->exec("UPDATE lead_list_items SET status = 'hot' WHERE lead_score >= 72");
    $pdo->exec("UPDATE lead_list_items SET status = 'warm' WHERE lead_score >= 45 AND lead_score < 72");
    $pdo->exec("UPDATE lead_list_items SET status = 'cold' WHERE lead_score < 45");
}

/**
 * Compute a lead's composite score (0–100) and derive tier label.
 * Dimensions: Contact Completeness (20) + Reputation (15) + Engagement Depth (25)
 *           + Outreach Status (20) + Enrichment Quality (10) + Freshness (10)
 * Tiers:    Hot ≥72 | Warm ≥45 | Cold <45
 */


// ── END Lead Rating System ───────────────────────────────────────────────────

try {
    $result = $pdo->query("SHOW INDEX FROM lead_list_items WHERE Key_name = 'idx_list_stats_cover'")->fetch();
    if (!$result) throw new Exception('missing');
} catch (Exception $e) {
    try { $pdo->exec("ALTER TABLE lead_list_items ADD INDEX idx_list_user_created (list_id, user_id, created_at DESC)"); } catch (Exception $e2) {}
    try { $pdo->exec("ALTER TABLE lead_list_items ADD INDEX idx_list_user (list_id, user_id)"); } catch (Exception $e2) {}
    try { $pdo->exec("ALTER TABLE lead_list_items ADD INDEX idx_list_pipeline (list_id, pipeline_stage)"); } catch (Exception $e2) {}
    try { $pdo->exec("ALTER TABLE lead_list_items ADD INDEX idx_list_has_email (list_id, has_email)"); } catch (Exception $e2) {}
    try { $pdo->exec("ALTER TABLE lead_list_items ADD INDEX idx_list_stats_cover (list_id, user_id, status, pipeline_stage, visited_website, visited_social, reached_out, has_email, has_socials, has_phone, has_website, has_notes, outreach_email, outreach_instagram, follow_up_count)"); } catch (Exception $e2) {}
}

try {
    $pdo->query("SELECT 1 FROM ghl_connections LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("CREATE TABLE ghl_connections (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        name VARCHAR(255) NOT NULL,
        api_key VARCHAR(255) NOT NULL,
        location_id VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user (user_id)
    )");
    // Migrate existing credentials from users table
    $pdo->exec("INSERT INTO ghl_connections (user_id, name, api_key, location_id)
        SELECT id, 'My GHL Account', ghl_api_key, ghl_location_id
        FROM users WHERE ghl_api_key IS NOT NULL AND ghl_api_key != '' AND ghl_location_id IS NOT NULL AND ghl_location_id != ''");
}

try {
    $pdo->query("SELECT 1 FROM ghl_import_logs LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("CREATE TABLE ghl_import_logs (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        list_id INT NOT NULL,
        connection_id INT DEFAULT NULL,
        connection_name VARCHAR(255) DEFAULT NULL,
        status ENUM('pending','running','paused','completed','cancelled','failed') DEFAULT 'pending',
        total_contacts INT DEFAULT 0,
        imported INT DEFAULT 0,
        updated INT DEFAULT 0,
        failed INT DEFAULT 0,
        processed INT DEFAULT 0,
        tags JSON,
        workflow_id VARCHAR(100) DEFAULT NULL,
        workflow_name VARCHAR(255) DEFAULT NULL,
        drip_enabled TINYINT DEFAULT 0,
        drip_batch_size INT DEFAULT 0,
        drip_interval_minutes INT DEFAULT 0,
        drip_timezone VARCHAR(50) DEFAULT 'America/New_York',
        drip_send_hour INT DEFAULT NULL,
        drip_send_minute INT DEFAULT NULL,
        drip_next_batch_at DATETIME DEFAULT NULL,
        errors JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        completed_at DATETIME DEFAULT NULL,
        INDEX idx_user (user_id),
        INDEX idx_list (list_id),
        INDEX idx_status (status),
        INDEX idx_drip_next (drip_next_batch_at, status)
    )");
}

try { $pdo->query("SELECT connection_id FROM ghl_import_logs LIMIT 1"); } catch (Exception $e) {
    try { $pdo->exec("ALTER TABLE ghl_import_logs ADD COLUMN connection_id INT DEFAULT NULL"); } catch (Exception $e2) {}
    try { $pdo->exec("ALTER TABLE ghl_import_logs ADD COLUMN connection_name VARCHAR(255) DEFAULT NULL"); } catch (Exception $e2) {}
}

try {
    $pdo->query("SELECT 1 FROM ghl_import_items LIMIT 1");
} catch (Exception $e) {
    $pdo->exec("CREATE TABLE ghl_import_items (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        import_log_id BIGINT NOT NULL,
        lead_id BIGINT NOT NULL,
        user_id INT NOT NULL,
        ghl_contact_id VARCHAR(100) DEFAULT NULL,
        status ENUM('pending','success','failed','skipped') DEFAULT 'pending',
        is_new TINYINT DEFAULT 0,
        error_message TEXT DEFAULT NULL,
        lead_data JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_import (import_log_id),
        INDEX idx_lead (lead_id),
        INDEX idx_status (import_log_id, status)
    )");
}

/**
 * Load canonical geo SQL file into DB with INSERT IGNORE semantics.
 * Falls back to local file path lookup. Returns true on success (incl. partial).
 */
function mm_load_geo_sql(PDO $pdo, string $sqlPath, string $tableName): bool {
    $content = @file_get_contents($sqlPath);
    if ($content === false || $content === '' || strlen($content) < 100) {
        return false;
    }
    // Strip TRUNCATE so we never wipe existing data; convert INSERT into INSERT IGNORE.
    $stripped = preg_replace('/^\s*TRUNCATE\s+TABLE\s+\S+\s*;\s*$/mi', '', $content);
    // Split the multi-row VALUES by parsing balanced parens of each tuple.
    // We rely on the canonical files having one INSERT statement format:
    //   INSERT INTO geo_xxx (...) VALUES\n( a, b, ... ),\n( ... ),\n...;\n
    if (!preg_match('/INSERT\s+INTO\s+' . preg_quote($tableName, '/') . '\s*\([^)]+\)\s*VALUES\s*(.+);/is', $stripped, $m)) {
        return false;
    }
    $valuesBlock = $m[1];
    // Match each tuple: ( ... ), — use a simple split-by-paren pattern.
    $rows = [];
    $depth = 0; $start = -1;
    $len = strlen($valuesBlock);
    for ($i = 0; $i < $len; $i++) {
        $c = $valuesBlock[$i];
        if ($c === '(') { if ($depth === 0) $start = $i + 1; $depth++; }
        elseif ($c === ')') { $depth--; if ($depth === 0 && $start >= 0) { $rows[] = substr($valuesBlock, $start, $i - $start); $start = -1; } }
    }
    if (empty($rows)) return false;

    // Detect column list
    if (!preg_match('/INSERT\s+INTO\s+' . preg_quote($tableName, '/') . '\s*\(([^)]+)\)/is', $stripped, $cm)) return false;
    $cols = array_map(function($x){ return trim(preg_replace('/\s+/', '', $x)); }, explode(',', $cm[1]));
    $colCount = count($cols);

    $placeholder = implode(',', array_fill(0, $colCount, '?'));
    $sql = "INSERT IGNORE INTO `$tableName` (" . implode(',', array_map(fn($c)=>"`$c`", $cols)) . ") VALUES ($placeholder)";
    $stmt = $pdo->prepare($sql);
    $inserted = 0; $failed = 0;
    foreach ($rows as $row) {
        // Parse each tuple into PHP scalars.
        $vals = [];
        $buf = ''; $inStr = false; $rowLen = strlen($row);
        for ($i = 0; $i < $rowLen; $i++) {
            $c = $row[$i];
            if ($inStr) {
                if ($c === '\\' && isset($row[$i+1])) { $buf .= $row[$i+1]; $i++; continue; }
                if ($c === "'") { $inStr = false; }
                else { $buf .= $c; }
            } else {
                if ($c === "'") { $inStr = true; }
                elseif ($c === ',') { $vals[] = trim($buf); $buf = ''; }
                else { $buf .= $c; }
            }
        }
        if (trim($buf) !== '') $vals[] = trim($buf);
        if (count($vals) !== $colCount) { $failed++; continue; }
        // Normalize NULL
        $vals = array_map(fn($v) => strtoupper((string)$v) === 'NULL' ? null : $v, $vals);
        try { $stmt->execute($vals); $inserted += $stmt->rowCount(); }
        catch (Exception $e) { $failed++; }
    }
    return $inserted > 0 || $failed === 0;
}

// Geo reference tables: create if missing, seed from canonical SQL files (needed for Top Cities presets).
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS geo_countries (
        geoname_id INT PRIMARY KEY,
        country_name VARCHAR(120) NOT NULL,
        country_code CHAR(2) NOT NULL,
        geo_region_code VARCHAR(20) NOT NULL,
        population BIGINT DEFAULT NULL,
        timezone VARCHAR(60) DEFAULT NULL,
        INDEX idx_region (geo_region_code),
        INDEX idx_code (country_code)
    )");
    $cnt = (int)$pdo->query("SELECT COUNT(*) FROM geo_countries")->fetchColumn();
    if ($cnt < 200) {
        // Load canonical geo_countries from bundled SQL file.
        $geoSqlPath = __DIR__ . '/sql/geo_countries.sql';
        mm_load_geo_sql($pdo, $geoSqlPath, 'geo_countries');
    }
} catch (Exception $e) { /* geo tables optional */ }

try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS geo_cities (
        geoname_id INT PRIMARY KEY,
        country_code CHAR(2) NOT NULL,
        city_name VARCHAR(200) NOT NULL,
        latitude DECIMAL(9,6) DEFAULT NULL,
        longitude DECIMAL(9,6) DEFAULT NULL,
        admin_name VARCHAR(200) DEFAULT NULL,
        admin_code VARCHAR(50) DEFAULT NULL,
        population BIGINT DEFAULT NULL,
        geo_region_code VARCHAR(20) NOT NULL,
        INDEX idx_region (geo_region_code),
        INDEX idx_country (country_code),
        INDEX idx_pop (population)
    )");
    $cnt = (int)$pdo->query("SELECT COUNT(*) FROM geo_cities")->fetchColumn();
    if ($cnt < 100) {
        // Load canonical cities from bundled SQL file. Top 500 must return up to 500 matching cities,
        // so the seed must be the full canonical set (Canadian-only seed was insufficient).
        $geoSqlPath = __DIR__ . '/sql/geo_cities.sql';
        if (!mm_load_geo_sql($pdo, $geoSqlPath, 'geo_cities')) {
            error_log("geo_cities SQL load failed for " . $geoSqlPath);
        }
    }
} catch (Exception $e) { /* geo_cities optional */ }

@file_put_contents(mm_bootstrap_flag_path(), MM_BOOTSTRAP_VERSION);
} // === MM-BOOTSTRAP-FASTPATH:SECTION-END ===


$ghlConnsStmt = $pdo->prepare("SELECT * FROM ghl_connections WHERE user_id = ? ORDER BY created_at ASC");
$ghlConnsStmt->execute([$userId]);
$ghlConnections = $ghlConnsStmt->fetchAll(PDO::FETCH_ASSOC);
$ghlConnected = count($ghlConnections) > 0;

// API Endpoints
if (isset($_GET['action'])) {
    header('Content-Type: application/json');
    // Apply gzip if browser supports it — safe for JSON responses only.
    // exportCSV/exportLeads set their own Content-Type and must clean the
    // buffer before doing so (see ob_end_clean in those case blocks).
    if (headers_sent() === false && in_array('ob_gzhandler', ob_list_handlers(), true) === false) {
        ob_start('ob_gzhandler');
    }
    $input = json_decode(file_get_contents('php://input'), true);

    switch ($_GET['action']) {

        case 'getLists':
            try {
                $filterGroup = trim($_GET['category_group'] ?? '');
                $filterCategory = trim($_GET['category'] ?? '');
                $aliases = [
                    'Doctors' => ['Doctors', 'Medical Clinics'],
                    'Medical Clinics' => ['Medical Clinics', 'Doctors'],
                    'Law Firms' => ['Law Firms', 'Lawyers'],
                    'Accounting Firms' => ['Accounting Firms', 'CPAs'],
                    'Fire Departments' => ['Fire Departments', 'Fire Station'],
                    'Police Departments' => ['Police Departments', 'Police Station'],
                    'Gas Stations' => ['Gas Stations', 'Petrol Stations'],
                    'Petrol Stations' => ['Petrol Stations', 'Gas Stations']
                ];
                $categoryAliases = $aliases[$filterCategory] ?? ($filterCategory ? [$filterCategory] : []);
                $hasClaimsTable = false;
                try { $pdo->query("SELECT 1 FROM list_claims LIMIT 1"); $hasClaimsTable = true; } catch (Exception $e) {}
                $claimsJoin = $hasClaimsTable ? "LEFT JOIN (SELECT source_list_id, COUNT(*) as cnt FROM list_claims GROUP BY source_list_id) cl ON cl.source_list_id = l.id" : "";
                $claimsCol = $hasClaimsTable ? "COALESCE(cl.cnt, 0)" : "0";
                $where = "l.user_id = ?";
                $params = [$userId];
                if ($filterGroup !== '' && $filterCategory !== '') {
                    $aliasClauses = ["l.category = ?"];
                    $params[] = $filterCategory;
                    foreach ($categoryAliases as $alias) {
                        if ($alias === $filterCategory) continue;
                        $aliasClauses[] = "l.category = ?";
                        $params[] = $alias;
                    }
                    foreach ($categoryAliases as $alias) {
                        $aliasClauses[] = "l.name = ?";
                        $params[] = $alias;
                        $aliasClauses[] = "l.description LIKE ?";
                        $params[] = $alias . ' -%';
                    }
                    $where .= " AND (" . implode(" OR ", $aliasClauses) . ") AND l.category_group = ?";
                    $params[] = $filterGroup;
                } elseif ($filterCategory !== '') {
                    $aliasClauses = ["l.category = ?"];
                    $params[] = $filterCategory;
                    foreach ($categoryAliases as $alias) {
                        if ($alias === $filterCategory) continue;
                        $aliasClauses[] = "l.category = ?";
                        $params[] = $alias;
                    }
                    foreach ($categoryAliases as $alias) {
                        $aliasClauses[] = "l.name = ?";
                        $params[] = $alias;
                        $aliasClauses[] = "l.description LIKE ?";
                        $params[] = $alias . ' -%';
                    }
                    $where .= " AND (" . implode(" OR ", $aliasClauses) . ")";
                }
                $stmt = $pdo->prepare("
                    SELECT l.*,
                        COALESCE(stats.lead_count, 0) as lead_count,
                        COALESCE(stats.visited_count, 0) as visited_count,
                        COALESCE(stats.reached_out_count, 0) as reached_out_count,
                        COALESCE(stats.stage_new, 0) as stage_new,
                        COALESCE(stats.stage_contacted, 0) as stage_contacted,
                        COALESCE(stats.engaged_count, 0) as engaged_count,
                        COALESCE(stats.client_count, 0) as client_count,
                        COALESCE(stats.stage_no_response, 0) as stage_no_response,
                        COALESCE(searches.cities_searched, 0) as cities_searched,
                        $claimsCol as claim_count
                    FROM lead_lists l
                    LEFT JOIN (
                        SELECT list_id,
                            COUNT(*) as lead_count,
                            SUM(visited_website = 1) as visited_count,
                            SUM(reached_out = 1) as reached_out_count,
                            SUM(pipeline_stage = 'new' OR pipeline_stage IS NULL) as stage_new,
                            SUM(pipeline_stage = 'contacted') as stage_contacted,
                            SUM(pipeline_stage = 'engaged') as engaged_count,
                            SUM(pipeline_stage = 'client') as client_count,
                            SUM(pipeline_stage = 'no_response') as stage_no_response
                        FROM lead_list_items
                        WHERE user_id = ?
                        GROUP BY list_id
                    ) stats ON stats.list_id = l.id
                    LEFT JOIN (
                        SELECT list_id,
                            COUNT(DISTINCT CONCAT(COALESCE(city,''), COALESCE(state_name,''))) as cities_searched
                        FROM lead_list_searches
                        WHERE user_id = ?
                        GROUP BY list_id
                    ) searches ON searches.list_id = l.id
                    $claimsJoin
                    WHERE $where ORDER BY l.updated_at DESC
                ");
                $stmt->execute(array_merge([$userId, $userId], $params));
                echo json_encode(['success' => true, 'lists' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            } catch (Exception $e) {
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            exit;

        case 'getWorkerStatus':
            try {
                $stmt = $pdo->prepare("SELECT setting_key, setting_value FROM worker_settings");
                $stmt->execute();
                $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
                $settings = [];
                foreach ($rows as $row) {
                    $settings[$row['setting_key']] = $row['setting_value'];
                }
                $paused = (isset($settings['worker_paused']) && $settings['worker_paused'] === '1');
                echo json_encode([
                    'success' => true,
                    'worker_paused' => $paused,
                    'pause_reason' => $settings['pause_reason'] ?? '',
                    'paused_at' => $settings['paused_at'] ?? '',
                    'paused_by' => $settings['paused_by'] ?? ''
                ]);
            } catch (Exception $e) {
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            exit;

        case 'toggleWorkerPause':
            $pausedVal = isset($input['worker_paused']) && $input['worker_paused'] ? '1' : '0';
            $reason = trim($input['pause_reason'] ?? 'manual');
            try {
                $pdo->beginTransaction();
                
                $stmt = $pdo->prepare("UPDATE worker_settings SET setting_value = ? WHERE setting_key = 'worker_paused'");
                $stmt->execute([$pausedVal]);
                
                $stmt = $pdo->prepare("UPDATE worker_settings SET setting_value = ? WHERE setting_key = 'pause_reason'");
                $stmt->execute([$reason]);
                
                $stmt = $pdo->prepare("UPDATE worker_settings SET setting_value = ? WHERE setting_key = 'paused_by'");
                $stmt->execute([$pausedVal === '1' ? 'admin' : '']);
                
                $stmt = $pdo->prepare("UPDATE worker_settings SET setting_value = ? WHERE setting_key = 'paused_at'");
                $stmt->execute([$pausedVal === '1' ? date('Y-m-d H:i:s') : '']);
                
                $pdo->commit();
                echo json_encode(['success' => true, 'worker_paused' => ($pausedVal === '1')]);
            } catch (Exception $e) {
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            exit;

        case 'createList':
            $name = trim($input['name'] ?? '');
            if (!$name) { echo json_encode(['success' => false, 'error' => 'Name required']); exit; }
            $stmt = $pdo->prepare("INSERT INTO lead_lists (user_id, name, description, category_group, category, subcategory, source, country, icon_class, icon_color) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->execute([$userId, $name, $input['description'] ?? '', $input['category_group'] ?? null, $input['category'] ?? null, $input['subcategory'] ?? null, $input['source'] ?? null, $input['country'] ?? null, $input['icon_class'] ?? null, $input['icon_color'] ?? null]);
            echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
            exit;

        case 'updateList':
            $stmt = $pdo->prepare("UPDATE lead_lists SET name = ?, description = ?, category_group = ?, category = ?, subcategory = ?, source = ?, country = ?, icon_class = ?, icon_color = ? WHERE id = ? AND user_id = ?");
            $stmt->execute([$input['name'], $input['description'] ?? '', $input['category_group'] ?? null, $input['category'] ?? null, $input['subcategory'] ?? null, $input['source'] ?? null, $input['country'] ?? null, $input['icon_class'] ?? null, $input['icon_color'] ?? null, $input['id'], $userId]);
            echo json_encode(['success' => true]);
            exit;

        case 'deleteList':
            $pdo->beginTransaction();
            try {
                $pdo->prepare("DELETE FROM lead_list_items WHERE list_id = ? AND user_id = ?")->execute([$input['id'], $userId]);
                $pdo->prepare("DELETE FROM lead_list_searches WHERE list_id = ? AND user_id = ?")->execute([$input['id'], $userId]);
                $pdo->prepare("DELETE FROM lead_lists WHERE id = ? AND user_id = ?")->execute([$input['id'], $userId]);
                $pdo->commit();
                echo json_encode(['success' => true]);
            } catch (Exception $e) {
                $pdo->rollBack();
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            exit;

        case 'togglePublic':
            $listId = $input['id'] ?? 0;
            $makePublic = $input['is_public'] ?? 0;
            if ($makePublic) {
                $token = bin2hex(random_bytes(32));
                $pdo->prepare("UPDATE lead_lists SET is_public = 1, public_token = ? WHERE id = ? AND user_id = ?")
                    ->execute([$token, $listId, $userId]);
                echo json_encode(['success' => true, 'is_public' => 1, 'public_token' => $token]);
            } else {
                $pdo->prepare("UPDATE lead_lists SET is_public = 0, public_token = NULL WHERE id = ? AND user_id = ?")
                    ->execute([$listId, $userId]);
                echo json_encode(['success' => true, 'is_public' => 0, 'public_token' => null]);
            }
            exit;

        case 'getListClaims':
            $listId = $_GET['list_id'] ?? 0;
            try {
                $pdo->query("SELECT 1 FROM list_claims LIMIT 1");
            } catch (Exception $e) {
                echo json_encode(['success' => true, 'claims' => []]);
                exit;
            }
            $claimStmt = $pdo->prepare("SELECT claimed_user_name, claimed_user_email, claim_type, created_at FROM list_claims WHERE source_list_id = ? AND owner_user_id = ? ORDER BY created_at DESC");
            $claimStmt->execute([$listId, $userId]);
            echo json_encode(['success' => true, 'claims' => $claimStmt->fetchAll(PDO::FETCH_ASSOC)]);
            exit;

        case 'getListDetail':
            $listId = $_GET['id'] ?? 0;
            // APCu cache (audit 2026-07-04): short-lived shared cache to dampen
            // per-tab poll pressure on this expensive aggregate. 5s TTL is
            // user/list scoped; bypasses safely when APCu is unavailable.
            $__cache_key = function_exists('apcu_fetch') ? "getListDetail:$userId:$listId" : '';
            if ($__cache_key) {
                $__cached = apcu_fetch($__cache_key, $__hit);
                if ($__hit && is_string($__cached) && $__cached !== '') { echo $__cached; exit; }
            }
            $stmt = $pdo->prepare("SELECT * FROM lead_lists WHERE id = ? AND user_id = ?");
            $stmt->execute([$listId, $userId]);
            $list = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$list) { echo json_encode(['success' => false, 'error' => 'Not found']); exit; }
            $stats = $pdo->prepare("
                SELECT
                    COUNT(*) as total,
                    SUM(status = 'cold') as cold,
                    SUM(status = 'warm') as warm,
                    SUM(status = 'hot') as hot,
                    SUM(visited_website) as websites_visited,
                    SUM(visited_social) as socials_visited,
                    SUM(reached_out) as reached_out_count,
                    SUM(has_website) as has_website,
                    SUM(has_phone) as has_phone,
                    SUM(has_email) as has_email,
                    SUM(has_socials) as has_socials,
                    SUM(has_notes) as has_notes,
                    SUM(outreach_email) as emailed_count,
                    SUM(outreach_instagram) as ig_dm_count,
                    SUM(COALESCE(pipeline_stage,'new') = 'new') as stage_new,
                    SUM(pipeline_stage = 'contacted') as stage_contacted,
                    SUM(pipeline_stage = 'engaged') as stage_engaged,
                    SUM(pipeline_stage = 'client') as stage_client,
                    SUM(pipeline_stage = 'no_response') as stage_no_response,
                    AVG(follow_up_count) as avg_follow_ups
                FROM lead_list_items WHERE list_id = ? AND user_id = ?
            ");
            $stats->execute([$listId, $userId]);
            $list['stats'] = $stats->fetch(PDO::FETCH_ASSOC);

            // Searched cities: prefer lead_list_searches (scrape history); fall back to
            // distinct city/state from lead_list_items so CSV-imported leads also show.
            $searches = $pdo->prepare("
                SELECT state_name, city
                FROM lead_list_searches
                WHERE list_id = ? AND user_id = ? AND city IS NOT NULL AND city != ''
                GROUP BY state_name, city
                ORDER BY state_name ASC, city ASC
            ");
            $searches->execute([$listId, $userId]);
            $list['searches'] = $searches->fetchAll(PDO::FETCH_ASSOC);

            $importedCities = $pdo->prepare("
                SELECT COALESCE(state,'') AS state_name, city
                FROM lead_list_items
                WHERE list_id = ? AND user_id = ? AND city IS NOT NULL AND city != ''
                GROUP BY state, city
                ORDER BY state ASC, city ASC
            ");
            $importedCities->execute([$listId, $userId]);
            $list['imported_cities'] = $importedCities->fetchAll(PDO::FETCH_ASSOC);

            if (empty($list['searches'])) {
                // No scrape-history rows: derive city list from imported lead rows instead.
                $list['searches'] = $list['imported_cities'];
            }

            // Aggregate state_stats from whichever source populated searches
            $stateMap = [];
            foreach ($list['searches'] as $s) {
                $st = $s['state_name'] ?? '';
                $stateMap[$st] = ($stateMap[$st] ?? 0) + 1;
            }
            $list['state_stats'] = [];
            foreach ($stateMap as $stateName => $cnt) {
                $list['state_stats'][] = ['state_name' => $stateName, 'cities_searched' => $cnt];
            }
            usort($list['state_stats'], fn($a, $b) => strcmp($a['state_name'], $b['state_name']));

            $__payload = json_encode(['success' => true, 'list' => $list]);
            if ($__cache_key) apcu_store($__cache_key, $__payload, 5);
            echo $__payload;
            exit;

        case 'getLeads':
            $listId = $_GET['list_id'] ?? ($input['list_id'] ?? 0);
            $page = max(1, intval($_GET['page'] ?? ($input['page'] ?? 1)));
            $perPage = min(500, max(10, intval($_GET['per_page'] ?? ($input['per_page'] ?? 50))));
            $search = $_GET['search'] ?? ($input['search'] ?? '');
            $status = $_GET['status'] ?? ($input['status'] ?? '');
            $offset = ($page - 1) * $perPage;

            $where = "list_id = ? AND user_id = ?";
            $params = [$listId, $userId];

            if ($search) {
                $where .= " AND (business_name LIKE ? OR address LIKE ? OR phone LIKE ? OR notes LIKE ?)";
                $s = "%$search%";
                $params = array_merge($params, [$s, $s, $s, $s]);
            }
            if ($status && in_array($status, ['cold', 'warm', 'hot'])) {
                $where .= " AND status = ?";
                $params[] = $status;
            }
            $has = $_GET['has'] ?? ($input['has'] ?? '');
            if ($has === 'email') {
                $where .= " AND has_email = 1";
            } elseif ($has === 'phone') {
                $where .= " AND has_phone = 1";
            } elseif ($has === 'socials') {
                $where .= " AND has_socials = 1";
            } elseif ($has === 'notes') {
                $where .= " AND has_notes = 1";
            } elseif ($has === 'visited') {
                $where .= " AND visited_website = 1";
            } elseif ($has === 'reached_out') {
                $where .= " AND reached_out = 1";
            } elseif ($has === 'emailed') {
                $where .= " AND outreach_email = 1";
            } elseif ($has === 'ig_dm') {
                $where .= " AND outreach_instagram = 1";
            } elseif ($has === 'stage_new') {
                $where .= " AND (pipeline_stage = 'new' OR pipeline_stage IS NULL)";
            } elseif ($has === 'stage_contacted') {
                $where .= " AND pipeline_stage = 'contacted'";
            } elseif ($has === 'stage_engaged') {
                $where .= " AND pipeline_stage = 'engaged'";
            } elseif ($has === 'stage_client') {
                $where .= " AND pipeline_stage = 'client'";
            } elseif ($has === 'stage_no_response') {
                $where .= " AND pipeline_stage = 'no_response'";
            } elseif ($has === 'selected') {
                $selectedIds = $input['selected_ids'] ?? [];
                if (!empty($selectedIds)) {
                    $selectedIds = array_map('intval', $selectedIds);
                    $placeholders = implode(',', array_fill(0, count($selectedIds), '?'));
                    $where .= " AND id IN ($placeholders)";
                    $params = array_merge($params, $selectedIds);
                } else {
                    $where .= " AND 1=0";
                }
            }

            $countStmt = $pdo->prepare("SELECT COUNT(*) FROM lead_list_items WHERE $where");
            $countStmt->execute($params);
            $total = $countStmt->fetchColumn();

            // SKINNY payload: no raw_data (large JSON blob, fetched on-demand per task 5)
            $stmt = $pdo->prepare("
                SELECT id, business_name, address, phone, website, rating, review_count, types,
                       latitude, longitude, city, state,
                       emails, social_media_links,
                       status, pipeline_stage, visited_website, reached_out,
                       has_email, has_socials, has_phone, has_website, has_notes,
                       lead_score, outreach_email, outreach_instagram, follow_up_count,
                       enriched_at, enrichment_status, created_at, updated_at
                FROM lead_list_items WHERE $where ORDER BY created_at DESC LIMIT $perPage OFFSET $offset
            ");
            $stmt->execute($params);
            $leads = $stmt->fetchAll(PDO::FETCH_ASSOC);

            foreach ($leads as &$lead) {
                $lead['emails'] = json_decode($lead['emails'] ?: '[]', true);
                $lead['social_media_links'] = json_decode($lead['social_media_links'] ?: '[]', true);
                $lead['visited_socials'] = json_decode($lead['visited_socials'] ?: '[]', true);
            }

            echo json_encode([
                'success' => true,
                'leads' => $leads,
                'total' => (int)$total,
                'page' => $page,
                'per_page' => $perPage,
                'total_pages' => ceil($total / $perPage)
            ]);
            exit;

        case 'getLeadDetail':
            // On-demand fetch of a single lead's full raw_data for detail slide
            $id = (int)($_GET['id'] ?? 0);
            if (!$id) { echo json_encode(['success' => false]); exit; }
            $detail = $pdo->prepare("SELECT id, raw_data FROM lead_list_items WHERE id = ? AND user_id = ?");
            $detail->execute([$id, $userId]);
            $row = $detail->fetch(PDO::FETCH_ASSOC);
            if (!$row) { echo json_encode(['success' => false]); exit; }
            echo json_encode([
                'success' => true,
                'raw_data' => json_decode($row['raw_data'] ?: '{}', true)
            ]);
            exit;

        case 'getMapLeads':
            $listId = (int)($_GET['list_id'] ?? 0);
            $stmt = $pdo->prepare("SELECT id, business_name, address as full_address, phone, website, latitude, longitude, rating, review_count, types, city, state FROM lead_list_items WHERE list_id = ? AND user_id = ? AND latitude IS NOT NULL AND latitude != '' AND longitude IS NOT NULL AND longitude != ''");
            $stmt->execute([$listId, $userId]);
            $leads = $stmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($leads as &$lead) {
                $lead['emails'] = json_decode($lead['emails'] ?: '[]', true);
                $lead['social_media_links'] = json_decode($lead['social_media_links'] ?: '[]', true);
            }
            echo json_encode(['success' => true, 'leads' => $leads]);
            exit;

        case 'addLeads':
            $listId = $input['list_id'] ?? 0;
            $leads = $input['leads'] ?? [];
            if (!$listId || empty($leads)) {
                echo json_encode(['success' => false, 'error' => 'Missing data']);
                exit;
            }

            $existingIds = [];
            $chk = $pdo->prepare("SELECT business_id FROM lead_list_items WHERE list_id = ? AND user_id = ? AND business_id IS NOT NULL");
            $chk->execute([$listId, $userId]);
            while ($row = $chk->fetch(PDO::FETCH_ASSOC)) {
                $existingIds[$row['business_id']] = true;
            }

            $listMetaStmt = $pdo->prepare("SELECT category_group, category, subcategory, source, country FROM lead_lists WHERE id = ? AND user_id = ?");
            $listMetaStmt->execute([$listId, $userId]);
            $listMeta = $listMetaStmt->fetch(PDO::FETCH_ASSOC) ?: [];

            $inserted = 0;
            $skipped = 0;
            $stmt = $pdo->prepare("
                INSERT INTO lead_list_items
                (list_id, user_id, business_id, business_name, address, city, state, phone, website,
                 rating, review_count, types, latitude, longitude, emails, social_media_links, raw_data,
                 has_email, has_socials, has_phone, has_website, has_notes, category_group, category, subcategory, source, country)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");

            foreach ($leads as $lead) {
                $bid = $lead['business_id'] ?? null;
                if ($bid && isset($existingIds[$bid])) { $skipped++; continue; }
                if ($bid) $existingIds[$bid] = true;
                try {
                    $leadEmails = $lead['emails'] ?? [];
                    $leadSocials = $lead['social_media_links'] ?? [];
                    $leadPhone = $lead['phone_number'] ?? $lead['phone'] ?? '';
                    $leadWebsite = $lead['website'] ?? '';
                    $stmt->execute([
                        $listId, $userId,
                        $bid,
                        $lead['name'] ?? $lead['business_name'] ?? '',
                        $lead['full_address'] ?? $lead['address'] ?? '',
                        $lead['city'] ?? '',
                        $lead['state'] ?? '',
                        $leadPhone,
                        $leadWebsite,
                        $lead['rating'] ?? null,
                        $lead['review_count'] ?? 0,
                        is_array($lead['types'] ?? null) ? implode(', ', $lead['types']) : ($lead['types'] ?? ''),
                        $lead['latitude'] ?? null,
                        $lead['longitude'] ?? null,
                        json_encode($leadEmails),
                        json_encode($leadSocials),
                        json_encode($lead),
                        !empty($leadEmails) ? 1 : 0,
                        !empty($leadSocials) ? 1 : 0,
                        ($leadPhone !== '') ? 1 : 0,
                        ($leadWebsite !== '') ? 1 : 0,
                        0,
                        $listMeta['category_group'] ?? null,
                        $listMeta['category'] ?? null,
                        $listMeta['subcategory'] ?? null,
                        $listMeta['source'] ?? null,
                        $listMeta['country'] ?? null
                    ]);
                    $inserted++;
                } catch (Exception $e) {
                    error_log("Error inserting lead: " . $e->getMessage());
                }
            }

            $pdo->prepare("UPDATE lead_lists SET updated_at = NOW() WHERE id = ? AND user_id = ?")->execute([$listId, $userId]);

            // Backfill lead_score for newly inserted leads
            if ($inserted > 0) {
                $lastId = $pdo->lastInsertId();
                $backfillStmt = $pdo->prepare("SELECT * FROM lead_list_items WHERE list_id = ? AND user_id = ? AND lead_score IS NULL LIMIT 200");
                $backfillStmt->execute([$listId, $userId]);
                $scoreStmt = $pdo->prepare("UPDATE lead_list_items SET lead_score = ?, status = ? WHERE id = ?");
                while ($row = $backfillStmt->fetch(PDO::FETCH_ASSOC)) {
                    $result = computeLeadScore($row);
                    $scoreStmt->execute([$result['score'], $result['tier'], $row['id']]);
                }
            }

            echo json_encode(['success' => true, 'inserted' => $inserted, 'skipped' => $skipped]);
            exit;

        case 'updateLead':
            $id = $input['id'] ?? 0;
            $allowed = ['notes', 'status', 'visited_website', 'visited_social', 'reached_out', 'emails', 'social_media_links', 'visited_socials', 'pipeline_stage', 'outreach_email', 'outreach_instagram', 'follow_up_count'];
            $sets = [];
            $params = [];

            foreach ($allowed as $field) {
                if (isset($input[$field])) {
                    if (in_array($field, ['emails', 'social_media_links', 'visited_socials'])) {
                        $sets[] = "$field = ?";
                        $params[] = json_encode($input[$field]);
                        if ($field === 'emails') {
                            $sets[] = "has_email = ?";
                            $params[] = !empty($input[$field]) ? 1 : 0;
                        } elseif ($field === 'social_media_links') {
                            $sets[] = "has_socials = ?";
                            $params[] = !empty($input[$field]) ? 1 : 0;
                        }
                    } else {
                        $sets[] = "$field = ?";
                        $params[] = $input[$field];
                        if ($field === 'notes') {
                            $sets[] = "has_notes = ?";
                            $params[] = ($input[$field] !== null && $input[$field] !== '') ? 1 : 0;
                        }
                    }
                }
            }

            if (isset($input['visited_website']) && $input['visited_website']) {
                $sets[] = "website_visited_at = NOW()";
            }
            if (isset($input['visited_social']) && $input['visited_social']) {
                $sets[] = "social_visited_at = NOW()";
            }
            if (isset($input['reached_out']) && $input['reached_out']) {
                $sets[] = "reached_out_at = NOW()";
            }
            if ((isset($input['outreach_email']) && $input['outreach_email']) || (isset($input['outreach_instagram']) && $input['outreach_instagram'])) {
                $sets[] = "first_contacted_at = COALESCE(first_contacted_at, NOW())";
            }
            if (isset($input['follow_up_count']) && $input['follow_up_count'] > 0) {
                $sets[] = "last_follow_up_at = NOW()";
            }

            // Auto-calculate status
            if (isset($input['visited_website']) || isset($input['visited_social']) || isset($input['reached_out'])) {
                $checkStmt = $pdo->prepare("SELECT visited_website, visited_social, reached_out FROM lead_list_items WHERE id = ? AND user_id = ?");
                $checkStmt->execute([$id, $userId]);
                $current = $checkStmt->fetch(PDO::FETCH_ASSOC);
                if ($current) {
                    $vw = $input['visited_website'] ?? $current['visited_website'];
                    $vs = $input['visited_social'] ?? $current['visited_social'];
                    $ro = $input['reached_out'] ?? $current['reached_out'];
                    if ($ro) {
                        $sets[] = "status = 'hot'";
                    } elseif ($vw || $vs) {
                        $sets[] = "status = 'warm'";
                    } else {
                        $sets[] = "status = 'cold'";
                    }
                }
            }

            if (empty($sets)) { echo json_encode(['success' => false, 'error' => 'No fields']); exit; }

            $params[] = $id;
            $params[] = $userId;
            $stmt = $pdo->prepare("UPDATE lead_list_items SET " . implode(', ', $sets) . " WHERE id = ? AND user_id = ?");
            $stmt->execute($params);
            echo json_encode(['success' => true]);
            exit;

        case 'deleteLead':
            $pdo->prepare("DELETE FROM lead_list_items WHERE id = ? AND user_id = ?")->execute([$input['id'], $userId]);
            echo json_encode(['success' => true]);
            exit;

        case 'deleteLeads':
            $ids = $input['ids'] ?? [];
            if (!empty($ids)) {
                $placeholders = implode(',', array_fill(0, count($ids), '?'));
                $params = array_merge($ids, [$userId]);
                $pdo->prepare("DELETE FROM lead_list_items WHERE id IN ($placeholders) AND user_id = ?")->execute($params);
            }
            echo json_encode(['success' => true]);
            exit;

        case 'bulkUpdateLeads':
            $ids = $input['ids'] ?? [];
            $field = $input['field'] ?? '';
            $value = $input['value'] ?? 0;
            $allowedFields = ['visited_website', 'reached_out', 'outreach_email', 'outreach_instagram', 'pipeline_stage'];
            if (!empty($ids) && in_array($field, $allowedFields)) {
                $placeholders = implode(',', array_fill(0, count($ids), '?'));
                $params = array_merge([$value], $ids, [$userId]);
                $pdo->prepare("UPDATE lead_list_items SET $field = ? WHERE id IN ($placeholders) AND user_id = ?")->execute($params);
                if (in_array($field, ['outreach_email', 'outreach_instagram']) && $value) {
                    $pdo->prepare("UPDATE lead_list_items SET first_contacted_at = COALESCE(first_contacted_at, NOW()) WHERE id IN ($placeholders) AND user_id = ?")->execute(array_merge($ids, [$userId]));
                }
                // Recalculate scores for all affected leads
                $fetchStmt = $pdo->prepare("SELECT * FROM lead_list_items WHERE id IN ($placeholders) AND user_id = ?");
                $fetchStmt->execute(array_merge($ids, [$userId]));
                $scoreUpdate = $pdo->prepare("UPDATE lead_list_items SET lead_score = ?, status = ? WHERE id = ?");
                while ($row = $fetchStmt->fetch(PDO::FETCH_ASSOC)) {
                    $result = computeLeadScore($row);
                    $scoreUpdate->execute([$result['score'], $result['tier'], $row['id']]);
                }
            }
            echo json_encode(['success' => true]);
            exit;
        case 'importCSV':
            @set_time_limit(300);
            ignore_user_abort(true);

            $listId = intval($_POST['list_id'] ?? 0);
            if (!$listId) { echo json_encode(['success' => false, 'error' => 'No list_id']); exit; }

            $own = $pdo->prepare("SELECT id FROM lead_lists WHERE id = ? AND user_id = ?");
            $own->execute([$listId, $userId]);
            if (!$own->fetchColumn()) { echo json_encode(['success' => false, 'error' => 'List not found']); exit; }

            if (empty($_FILES['csv']) || $_FILES['csv']['error'] !== UPLOAD_ERR_OK) {
                echo json_encode(['success' => false, 'error' => 'No CSV file uploaded']); exit;
            }

            $listMetaStmt = $pdo->prepare("SELECT category_group, category, subcategory, source, country FROM lead_lists WHERE id = ? AND user_id = ?");
            $listMetaStmt->execute([$listId, $userId]);
            $listMeta = $listMetaStmt->fetch(PDO::FETCH_ASSOC) ?: [];

            $fh = fopen($_FILES['csv']['tmp_name'], 'r');
            if (!$fh) { echo json_encode(['success' => false, 'error' => 'Could not read file']); exit; }

            $first = fgets($fh);
            if ($first === false) { fclose($fh); echo json_encode(['success' => false, 'error' => 'Empty file']); exit; }
            if (substr($first, 0, 3) === "\xEF\xBB\xBF") $first = substr($first, 3);
            rewind($fh);
            if (substr(fread($fh, 3), 0, 3) !== "\xEF\xBB\xBF") rewind($fh);

            $headerRow = fgetcsv($fh);
            if (!$headerRow) { fclose($fh); echo json_encode(['success' => false, 'error' => 'Missing header row']); exit; }
            $normalizeCsvHeader = function($header) {
                $key = strtolower(trim((string)$header));
                $key = preg_replace('/^\xEF\xBB\xBF/', '', $key);
                $key = preg_replace('/[^a-z0-9]+/', '_', $key);
                $key = trim($key, '_');

                $aliases = [
                    'business' => 'business_name',
                    'businessname' => 'business_name',
                    'business_name' => 'business_name',
                    'business_title' => 'business_name',
                    'business_legal_name' => 'business_name',
                    'business_display_name' => 'business_name',
                    'business_title_text' => 'business_name',
                    'place' => 'business_name',
                    'place_name' => 'business_name',
                    'title' => 'business_name',
                    'organization' => 'business_name',
                    'organisation' => 'business_name',
                    'company' => 'business_name',
                    'company_name' => 'business_name',
                    'companyname' => 'business_name',
                    'name' => 'business_name',
                    'full_address' => 'address',
                    'formatted_address' => 'address',
                    'street_address' => 'address',
                    'phone_number' => 'phone',
                    'telephone' => 'phone',
                    'tel' => 'phone',
                    'url' => 'website',
                    'site' => 'website',
                    'domain' => 'website',
                    'web' => 'website',
                    'reviews' => 'reviews',
                    'review_count' => 'reviews',
                    'reviews_count' => 'reviews',
                    'total_reviews' => 'reviews',
                    'rating_value' => 'rating',
                    'pipeline' => 'pipeline_stage',
                    'stage' => 'pipeline_stage',
                    'pipeline_status' => 'pipeline_stage',
                    'lead_status' => 'status',
                    'note' => 'notes',
                    'comments' => 'notes',
                    'email' => 'email_1',
                    'email_address' => 'email_1',
                    'email1' => 'email_1',
                    'email_1' => 'email_1',
                    'email2' => 'email_2',
                    'email_2' => 'email_2',
                    'email3' => 'email_3',
                    'email_3' => 'email_3',
                    'email4' => 'email_4',
                    'email_4' => 'email_4',
                    'email5' => 'email_5',
                    'email_5' => 'email_5',
                    'other_social' => 'other_socials',
                    'other_social_links' => 'other_socials',
                    'socials' => 'other_socials',
                    'social_links' => 'other_socials',
                    // City aliases for gym / non-standard CSVs
                    'town'          => 'city',
                    'town_city'     => 'city',
                    'city_town'     => 'city',
                    'town_or_city'  => 'city',
                    'city_name'     => 'city',
                    'location'      => 'city',
                    'locality'      => 'city',
                    'area'          => 'city',
                ];

                return $aliases[$key] ?? $key;
            };
            $headers = array_map($normalizeCsvHeader, $headerRow);

            $col = function($name) use ($headers, $normalizeCsvHeader) {
                $idx = array_search($normalizeCsvHeader($name), $headers);
                return $idx === false ? null : $idx;
            };
            $getFirst = function(array $names) use (&$row, $col) {
                foreach ($names as $name) {
                    $i = $col($name);
                    if ($i !== null) {
                        $value = trim($row[$i] ?? '');
                        if ($value !== '') return $value;
                    }
                }
                return '';
            };

            $socialPlatforms = ['Facebook','Instagram','Twitter','LinkedIn','YouTube','TikTok'];

            $existing = [];
            $chk = $pdo->prepare("SELECT LOWER(CONCAT(COALESCE(business_name,''),'|',COALESCE(address,''))) AS k FROM lead_list_items WHERE list_id = ? AND user_id = ?");
            $chk->execute([$listId, $userId]);
            while ($r = $chk->fetch(PDO::FETCH_ASSOC)) { $existing[$r['k']] = true; }

            $stmt = $pdo->prepare("
                INSERT INTO lead_list_items
                (list_id, user_id, business_name, address, city, state, phone, website,
                 rating, review_count, status, pipeline_stage, notes, emails, social_media_links,
                 has_email, has_socials, has_phone, has_website, has_notes,
                 category_group, category, subcategory, source, country)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");

            $inserted = 0; $skipped = 0; $errors = 0;
            while (($row = fgetcsv($fh)) !== false) {
                if (count($row) === 1 && trim($row[0]) === '') continue;

                $get = function($name) use ($row, $col) {
                    $i = $col($name);
                    return $i === null ? '' : trim($row[$i] ?? '');
                };

                $businessName = $getFirst(['Business Name', 'Company Name', 'Company', 'Business', 'Name', 'Title', 'Place Name', 'Organization', 'Organisation']);
                $address = $getFirst(['Address', 'Full Address', 'Formatted Address', 'Street Address']);
                if ($businessName === '' && $address === '') { $skipped++; continue; }

                $key = strtolower($businessName . '|' . $address);
                if (isset($existing[$key])) { $skipped++; continue; }
                $existing[$key] = true;

                $emails = [];
                for ($i = 1; $i <= 5; $i++) {
                    $e = $get("Email $i");
                    if ($e !== '') $emails[] = $e;
                }
                if (empty($emails)) {
                    $email = $getFirst(['Email', 'Email Address']);
                    if ($email !== '') $emails[] = $email;
                }

                $socials = [];
                foreach ($socialPlatforms as $p) {
                    $u = $get($p);
                    if ($u !== '') $socials[] = $u;
                }
                $other = $get('Other Socials');
                if ($other !== '') {
                    foreach (preg_split('/[;,]\s*/', $other) as $u) {
                        $u = trim($u);
                        if ($u !== '') $socials[] = $u;
                    }
                }

                $status = strtolower($getFirst(['Status', 'Lead Status']));
                if (!in_array($status, ['cold','warm','hot'])) $status = 'cold';

                $pipeline = strtolower($getFirst(['Pipeline Stage', 'Pipeline', 'Stage', 'Pipeline Status']));
                if (!in_array($pipeline, ['new','contacted','engaged','client','no_response'])) $pipeline = 'new';

                $phone = $getFirst(['Phone', 'Phone Number', 'Telephone', 'Tel']);
                $website = $getFirst(['Website', 'URL', 'Site', 'Domain', 'Web']);
                $notes = $getFirst(['Notes', 'Note', 'Comments']);
                $rating = $getFirst(['Rating', 'Rating Value']);
                $reviews = $getFirst(['Reviews', 'Review Count', 'Reviews Count', 'Total Reviews']);

                try {
                    $stmt->execute([
                        $listId, $userId,
                        $businessName,
                        $address,
                        $getFirst(['City', 'Town', 'Locality']),
                        $getFirst(['State', 'State Name', 'Region', 'Province', 'Country']),
                        $phone,
                        $website,
                        $rating !== '' ? floatval($rating) : null,
                        $reviews !== '' ? intval($reviews) : 0,
                        $status,
                        $pipeline,
                        $notes,
                        json_encode($emails),
                        json_encode($socials),
                        !empty($emails) ? 1 : 0,
                        !empty($socials) ? 1 : 0,
                        $phone !== '' ? 1 : 0,
                        $website !== '' ? 1 : 0,
                        $notes !== '' ? 1 : 0,
                        $listMeta['category_group'] ?? null,
                        $listMeta['category'] ?? null,
                        $listMeta['subcategory'] ?? null,
                        $listMeta['source'] ?? null,
                        $listMeta['country'] ?? null
                    ]);
                    $inserted++;
                } catch (Exception $e) {
                    $errors++;
                }
            }
            fclose($fh);

            $pdo->prepare("UPDATE lead_lists SET updated_at = NOW() WHERE id = ? AND user_id = ?")->execute([$listId, $userId]);
            echo json_encode(['success' => true, 'inserted' => $inserted, 'skipped' => $skipped, 'errors' => $errors]);
            exit;

        case 'logSearch':
            $stmt = $pdo->prepare("INSERT INTO lead_list_searches (list_id, user_id, search_query, state_name, city, results_count) VALUES (?, ?, ?, ?, ?, ?)");
            $stmt->execute([$input['list_id'], $userId, $input['search_query'] ?? '', $input['state_name'] ?? '', $input['city'] ?? '', $input['results_count'] ?? 0]);
            echo json_encode(['success' => true]);
            exit;

        case 'getStates':
            $country = $_GET['country'] ?? 'US';
            if ($country === 'UK') {
                try {
                    $stmt = $pdo->query("SELECT DISTINCT admin_name AS state_name, admin_code AS state_id, country_name FROM ukcities ORDER BY admin_name");
                    echo json_encode(['success' => true, 'states' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
                } catch (Exception $e) {
                    echo json_encode(['success' => true, 'states' => []]);
                }
            } elseif ($country === 'EU') {
                try {
                    $stmt = $pdo->query("SELECT DISTINCT country AS state_name, country AS state_id FROM european_cities_towns_44_countries_hd2data ORDER BY country");
                    echo json_encode(['success' => true, 'states' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
                } catch (Exception $e) {
                    echo json_encode(['success' => true, 'states' => []]);
                }
            } elseif (in_array($country, ['CA-LAT', 'CAR', 'AF', 'ME-CA', 'RU-CN', 'SA-SEA-OC'])) {
                // Use normalized geo_countries table for new regions
                try {
                    $stmt = $pdo->prepare("SELECT country_name AS state_name, country_code AS state_id FROM geo_countries WHERE geo_region_code = ? ORDER BY country_name");
                    $stmt->execute([$country]);
                    echo json_encode(['success' => true, 'states' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
                } catch (Exception $e) {
                    echo json_encode(['success' => true, 'states' => []]);
                }
            } else {
                try {
                    $stmt = $pdo->query("SELECT DISTINCT state AS state_name, state AS state_id FROM usa_all_states_cities_full_hd2data ORDER BY state");
                    echo json_encode(['success' => true, 'states' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
                } catch (Exception $e) {
                    $stmt = $pdo->query("SELECT DISTINCT state_id, state_name FROM locations ORDER BY state_name");
                    echo json_encode(['success' => true, 'states' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
                }
            }
            exit;

        case 'getCities':
            $stateId = $_GET['state_id'] ?? '';
            $country = $_GET['country'] ?? 'US';
            if ($country === 'UK') {
                $stmt = $pdo->prepare("SELECT DISTINCT city, NULL as population FROM ukcities WHERE admin_code = ? ORDER BY city");
            } elseif ($country === 'EU') {
                try {
                    $stmt = $pdo->prepare("SELECT DISTINCT city_or_town AS city, population FROM european_cities_towns_44_countries_hd2data WHERE country = ? ORDER BY city_or_town");
                } catch (Exception $e) {
                    $stmt = $pdo->prepare("SELECT DISTINCT city, NULL as population FROM european_cities WHERE admin_code = ? ORDER BY city");
                }
            } elseif (in_array($country, ['CA-LAT', 'CAR', 'AF', 'ME-CA', 'RU-CN', 'SA-SEA-OC'])) {
                // Use normalized geo_cities table for new regions
                try {
                    $stmt = $pdo->prepare("
                        SELECT DISTINCT c.city_name AS city, c.population, c.country_code AS state_id, COALESCE(co.country_name, c.country_code) AS state_name
                        FROM geo_cities c
                        LEFT JOIN geo_countries co ON c.country_code = co.country_code
                        WHERE c.geo_region_code = ? AND c.country_code = ? AND c.city_name IS NOT NULL AND c.city_name != ''
                        ORDER BY c.city_name
                    ");
                    $stmt->execute([$country, $stateId]);
                    echo json_encode(['success' => true, 'cities' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
                    exit;
                } catch (Exception $e) {
                    echo json_encode(['success' => true, 'cities' => []]);
                    exit;
                }
            } else {
                try {
                    $stmt = $pdo->prepare("SELECT DISTINCT city_or_town AS city, population FROM usa_all_states_cities_full_hd2data WHERE state = ? ORDER BY city_or_town");
                } catch (Exception $e) {
                    $stmt = $pdo->prepare("SELECT DISTINCT city, NULL as population FROM locations WHERE state_id = ? ORDER BY city");
                }
            }
            $stmt->execute([$stateId]);
            echo json_encode(['success' => true, 'cities' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            exit;

        case 'enqueueScrapeCities':
            $listId = (int)($input['list_id'] ?? 0);
            $query = trim($input['search_query'] ?? '');
            $country = trim($input['country'] ?? 'US') ?: 'US';
            $cities = $input['cities'] ?? [];
            $runId = trim((string)($input['run_id'] ?? ''));
            if ($runId === '') {
                $runId = bin2hex(random_bytes(16));
            }
            if (!$listId || $query === '' || empty($cities) || !is_array($cities)) {
                echo json_encode(['success' => false, 'error' => 'Missing queue input']);
                exit;
            }
            if ($userCredits < count($cities)) {
                echo json_encode(['success' => false, 'error' => 'Insufficient credits', 'credits_required' => count($cities), 'credits_available' => (int)$userCredits]);
                exit;
            }

            $ownsList = $pdo->prepare("SELECT id FROM lead_lists WHERE id = ? AND user_id = ?");
            $ownsList->execute([$listId, $userId]);
            if (!$ownsList->fetchColumn()) {
                echo json_encode(['success' => false, 'error' => 'List not found']);
                exit;
            }

            // [STALE-QUEUED-CLEANUP-V2] Fix: the previous implementation used UPDATE to
            // set stale jobs to status='cancelled', but the UNIQUE KEY on scrape_city_jobs
            // is (user_id, list_id, country, state_name, city, search_query) — status is
            // NOT part of the key. So INSERT IGNORE still skipped the cancelled rows,
            // causing enqueue.queued=0 and enqueue.deduped=N for all re-queued cities.
            //
            // Fix: DELETE the stale queued/cancelled/failed rows so INSERT can proceed.
            // 'completed' rows are left alone (idempotent — don't re-search already done).
            // 'running' rows are left alone (live tab still processing them).
            $deleteStale = $pdo->prepare("
                DELETE FROM scrape_city_jobs
                WHERE user_id = ? AND list_id = ? AND status IN ('queued', 'cancelled', 'failed')
            ");
            $deleteStale->execute([$userId, $listId]);

            // [HOTFIX-20260801] Build EU country-name → ISO-code lookup from geo_countries.
            // This is used to populate country_code for EU jobs where state_id is a name, not an ISO code.
            $euNameToCode = [];
            try {
                $euNamesStmt = $pdo->query("SELECT country_name, country_code FROM geo_countries WHERE geo_region_code = 'EU'");
                foreach ($euNamesStmt->fetchAll(PDO::FETCH_ASSOC) as $nameRow) {
                    $euNameToCode[strtolower(trim($nameRow['country_name']))] = strtolower(trim($nameRow['country_code']));
                }
            } catch (Exception $e) { /* geo_countries may not exist yet */ }

            $insertJob = $pdo->prepare("
                INSERT IGNORE INTO scrape_city_jobs
                    (user_id, list_id, country, state_name, city, search_query, status, run_id, country_code)
                VALUES (?, ?, ?, ?, ?, ?, 'queued', ?, ?)
            ");
            $queued = 0;
            $deduped = 0;
            foreach ($cities as $city) {
                $cityName = trim($city['city'] ?? '');
                $stateName = trim($city['state_name'] ?? $city['state'] ?? '');
                if ($cityName === '' || $stateName === '') continue;
                // [HOTFIX-20260801] Derive per-job ISO country code.
                $stateId = trim($city['state_id'] ?? '');
                $cc = null;
                if ($country === 'US') {
                    $cc = 'us';
                } elseif ($country === 'UK') {
                    $cc = 'gb';
                } elseif ($country === 'EU') {
                    $cc = $euNameToCode[strtolower($stateId)] ?? null;
                } else {
                    // New regions (CA-LAT, CAR, AF, ME-CA, RU-CN, SA-SEA-OC): state_id is already ISO code.
                    if (preg_match('/^[A-Za-z]{2}$/', $stateId)) {
                        $cc = strtolower($stateId);
                    }
                }
                $insertJob->execute([$userId, $listId, $country, $stateName, $cityName, $query, $runId, $cc]);
                if ($insertJob->rowCount() > 0) $queued++;
                else $deduped++;
            }
            echo json_encode(['success' => true, 'queued' => $queued, 'deduped' => $deduped]);
            exit;

        case 'getTopCities':
            $country = $_GET['country'] ?? 'US';
            $allowedLimits = [100, 200, 300, 400, 500, 1000, 2000, 3000, 5000, 10000];
            $limit = (int)($_GET['limit'] ?? 0);
            if (!in_array($limit, $allowedLimits, true)) {
                echo json_encode(['success' => false, 'error' => 'Invalid limit. Allowed values: 100, 200, 300, 400, 500, 1000, 2000, 3000, 5000, 10000.']);
                exit;
            }
            $supportedCountries = ['US', 'UK', 'EU', 'CA-LAT', 'CAR', 'AF', 'ME-CA', 'RU-CN', 'SA-SEA-OC'];
            if (!in_array($country, $supportedCountries, true)) {
                echo json_encode(['success' => false, 'error' => 'Unsupported country/region: ' . htmlspecialchars($country)]);
                exit;
            }
            $cities = [];
            $listId = (int)($_GET['list_id'] ?? 0);
            $candidateLimit = $listId > 0 ? max($limit, min(5000, $limit * 20)) : $limit;
            $scopeRaw = $_GET['state_ids'] ?? $_GET['scope_states'] ?? '';
            if (is_array($scopeRaw)) {
                $scopeStates = $scopeRaw;
            } else {
                $scopeStates = preg_split('/\s*,\s*/', (string)$scopeRaw, -1, PREG_SPLIT_NO_EMPTY);
            }
            $scopeStates = array_values(array_unique(array_filter(array_map(function($value) {
                return substr(trim((string)$value), 0, 80);
            }, $scopeStates), fn($value) => $value !== '')));
            $sortClause = "ORDER BY (population IS NULL) ASC, population DESC, city ASC, state_name ASC LIMIT " . $candidateLimit;
            try {
                if ($country === 'US') {
                    $sql = "SELECT DISTINCT city_or_town AS city, population, state AS state_id, state AS state_name "
                         . "FROM usa_all_states_cities_full_hd2data "
                         . "WHERE city_or_town IS NOT NULL AND city_or_town != '' "
                         . "  AND state IS NOT NULL AND state != '' "
                         . (!empty($scopeStates) ? "AND state IN (" . implode(',', array_fill(0, count($scopeStates), '?')) . ") " : "")
                         . $sortClause;
                    $stmt = $pdo->prepare($sql);
                    $stmt->execute($scopeStates);
                    $cities = $stmt->fetchAll(PDO::FETCH_ASSOC);
                } elseif ($country === 'UK') {
                    $sql = "SELECT DISTINCT city, population, country_name AS state_id, country_name AS state_name "
                         . "FROM ukcities "
                         . "WHERE city IS NOT NULL AND city != '' "
                         . (!empty($scopeStates) ? "AND country_name IN (" . implode(',', array_fill(0, count($scopeStates), '?')) . ") " : "")
                         . $sortClause;
                    $stmt = $pdo->prepare($sql);
                    $stmt->execute($scopeStates);
                    $cities = $stmt->fetchAll(PDO::FETCH_ASSOC);
                } elseif ($country === 'EU') {
                    // Canonical sync with lawyer/core: exclude United Kingdom.
                    $sql = "SELECT DISTINCT city_or_town AS city, population, country AS state_id, country AS state_name "
                         . "FROM european_cities_towns_44_countries_hd2data "
                         . "WHERE city_or_town IS NOT NULL AND city_or_town != '' "
                         . "  AND country != 'United Kingdom' "
                         . (!empty($scopeStates) ? "AND country IN (" . implode(',', array_fill(0, count($scopeStates), '?')) . ") " : "")
                         . $sortClause;
                    $stmt = $pdo->prepare($sql);
                    $stmt->execute($scopeStates);
                    $cities = $stmt->fetchAll(PDO::FETCH_ASSOC);
                } else {
                    // Added regions: CA-LAT, CAR, AF, ME-CA, RU-CN, SA-SEA-OC.
                    $sortClauseGeo = "ORDER BY (c.population IS NULL) ASC, c.population DESC, c.city_name ASC, COALESCE(co.country_name, c.country_code) ASC LIMIT " . $candidateLimit;
                    $sql = "SELECT DISTINCT c.city_name AS city, c.population, c.country_code AS state_id, "
                         . "COALESCE(co.country_name, c.country_code) AS state_name "
                         . "FROM geo_cities c "
                         . "LEFT JOIN geo_countries co ON c.country_code = co.country_code "
                         . "WHERE c.geo_region_code = ? AND c.city_name IS NOT NULL AND c.city_name != '' "
                         . (!empty($scopeStates) ? "AND c.country_code IN (" . implode(',', array_fill(0, count($scopeStates), '?')) . ") " : "")
                         . $sortClauseGeo;
                    $stmt = $pdo->prepare($sql);
                    $stmt->execute(array_merge([$country], $scopeStates));
                    $cities = $stmt->fetchAll(PDO::FETCH_ASSOC);
                }
            } catch (Exception $e) {
                // Never fatal. Return empty list so the preset shows "0 cities" gracefully.
                $cities = [];
            }

            $coveredCount = 0;
            $poolSize = count($cities);
            $coveredInPool = 0;
            if ($listId > 0 && !empty($cities)) {
                $own = $pdo->prepare("SELECT id FROM lead_lists WHERE id = ? AND user_id = ?");
                $own->execute([$listId, $userId]);
                if (!$own->fetchColumn()) {
                    echo json_encode(['success' => false, 'error' => 'List not found']);
                    exit;
                }

                $normalizeCoverageKey = function($value) {
                    return strtolower(trim((string)($value ?? '')));
                };
                $coverageStateAliases = function($stateName, $stateId = '') use ($normalizeCoverageKey) {
                    $values = array_values(array_filter([
                        $normalizeCoverageKey($stateName),
                        $normalizeCoverageKey($stateId)
                    ]));
                    $aliases = array_fill_keys($values, true);
                    $countryAliases = [
                        'ca' => ['canada'],
                        'canada' => ['ca'],
                        'gb' => ['united kingdom', 'great britain', 'uk'],
                        'uk' => ['united kingdom', 'great britain', 'gb'],
                        'united kingdom' => ['uk', 'gb', 'great britain'],
                        'us' => ['united states', 'united states of america', 'usa'],
                        'usa' => ['us', 'united states', 'united states of america'],
                        'united states' => ['us', 'usa', 'united states of america']
                    ];
                    foreach ($values as $value) {
                        foreach (($countryAliases[$value] ?? []) as $alias) {
                            $aliases[$alias] = true;
                        }
                    }
                    return array_keys($aliases);
                };

                $covered = [];
                $coveredCityOnly = [];
                $addCovered = function($city, $stateName = '', $stateId = '') use (&$covered, &$coveredCityOnly, $normalizeCoverageKey, $coverageStateAliases) {
                    $cityKey = $normalizeCoverageKey($city);
                    if ($cityKey === '') return;
                    $aliases = $coverageStateAliases($stateName, $stateId);
                    if (empty($aliases)) {
                        $coveredCityOnly[$cityKey] = true;
                        return;
                    }
                    foreach ($aliases as $stateKey) {
                        if ($stateKey !== '') $covered[$cityKey . '|' . $stateKey] = true;
                    }
                };

                $searches = $pdo->prepare("
                    SELECT state_name, city
                    FROM lead_list_searches
                    WHERE list_id = ? AND user_id = ? AND city IS NOT NULL AND city != ''
                    GROUP BY state_name, city
                ");
                $searches->execute([$listId, $userId]);
                foreach ($searches->fetchAll(PDO::FETCH_ASSOC) as $row) {
                    $addCovered($row['city'] ?? '', $row['state_name'] ?? '');
                }

                $importedCities = $pdo->prepare("
                    SELECT COALESCE(state,'') AS state_name, city
                    FROM lead_list_items
                    WHERE list_id = ? AND user_id = ? AND city IS NOT NULL AND city != ''
                    GROUP BY state, city
                ");
                $importedCities->execute([$listId, $userId]);
                foreach ($importedCities->fetchAll(PDO::FETCH_ASSOC) as $row) {
                    $addCovered($row['city'] ?? '', $row['state_name'] ?? '');
                }

                // MM-MATH-LIVE-FIX-001: full-scan the candidate pool so covered counts
                // are exact. skipped_covered keeps its historical prefix semantics
                // (covered rows encountered before the limit break) for compatibility;
                // covered_in_pool counts every covered row in the pool.
                $unsearched = [];
                $limitReached = false;
                foreach ($cities as $cityRow) {
                    $cityKey = $normalizeCoverageKey($cityRow['city'] ?? '');
                    $stateAliases = $coverageStateAliases($cityRow['state_name'] ?? '', $cityRow['state_id'] ?? '');
                    $isCovered = isset($coveredCityOnly[$cityKey]);
                    foreach ($stateAliases as $stateKey) {
                        if (isset($covered[$cityKey . '|' . $stateKey])) {
                            $isCovered = true;
                            break;
                        }
                    }
                    if ($isCovered) {
                        if (!$limitReached) $coveredCount++;
                        $coveredInPool++;
                        continue;
                    }
                    if (!$limitReached) {
                        $unsearched[] = $cityRow;
                        if (count($unsearched) >= $limit) $limitReached = true;
                    }
                }
                $cities = $unsearched;
            }
            foreach ($cities as &$c) {
                if (isset($c['population'])) {
                    $c['population'] = $c['population'] !== null ? (int)$c['population'] : null;
                }
            }
            unset($c);
            echo json_encode(['success' => true, 'cities' => $cities, 'limit' => $limit, 'country' => $country, 'skipped_covered' => $coveredCount, 'pool_size' => $poolSize, 'covered_in_pool' => $coveredInPool, 'unsearched_in_pool' => $poolSize - $coveredInPool]);
            exit;

        case 'getCredits':
            $cr = $pdo->prepare("SELECT credits FROM users WHERE id = ?");
            $cr->execute([$userId]);
            echo json_encode(['success' => true, 'credits' => (int)$cr->fetchColumn()]);
            exit;
        case 'getScrapeQueueStatus':
            $listId = (int)($_GET['list_id'] ?? 0);
            $runId = trim((string)($_GET['run_id'] ?? ''));
            $where = "user_id = ?";
            $params = [$userId];
            if ($listId) {
                $where .= " AND list_id = ?";
                $params[] = $listId;
            }
            if ($runId !== '') {
                $where .= " AND run_id = ?";
                $params[] = $runId;
            }
            $summary = $pdo->prepare("
                SELECT status, COUNT(*) as count
                FROM scrape_city_jobs
                WHERE $where
                GROUP BY status
            ");
            $summary->execute($params);
            $counts = ['queued' => 0, 'running' => 0, 'completed' => 0, 'failed' => 0, 'cancelled' => 0];
            foreach ($summary->fetchAll(PDO::FETCH_ASSOC) as $row) {
                $counts[$row['status']] = (int)$row['count'];
            }
            $jobs = $pdo->prepare("
                -- [HOTFIX-20260801] Include country_code for per-job ISO mapping
                SELECT id, list_id, country, state_name, city, search_query, status, country_code, results_count, error_message, created_at, updated_at
                FROM scrape_city_jobs
                WHERE $where
                ORDER BY FIELD(status, 'running', 'queued', 'failed', 'completed', 'cancelled'), created_at ASC
                LIMIT 50
            ");
            $jobs->execute($params);
            echo json_encode(['success' => true, 'counts' => $counts, 'jobs' => $jobs->fetchAll(PDO::FETCH_ASSOC), 'max_active' => 4]);
            exit;

        case 'cancelScrape':
            $listId = (int)($input['list_id'] ?? 0);
            $runId = trim((string)($input['run_id'] ?? ''));
            if (!$listId || $runId === '') {
                echo json_encode(['success' => false, 'error' => 'Missing cancel input']);
                exit;
            }
            $stmt = $pdo->prepare("
                UPDATE scrape_city_jobs
                SET status = 'cancelled', completed_at = NOW()
                WHERE user_id = ? AND list_id = ? AND run_id = ? AND status IN ('queued', 'running')
            ");
            $stmt->execute([$userId, $listId, $runId]);
            echo json_encode(['success' => true, 'cancelled' => $stmt->rowCount()]);
            exit;

        case 'claimScrapeCityJobs':
            $listId = (int)($input['list_id'] ?? 0);
            $runId = trim((string)($input['run_id'] ?? ''));
            if ($runId === '') {
                echo json_encode(['success' => false, 'error' => 'Missing run_id']);
                exit;
            }
            // Reap zombie jobs for this user: a 'running' row that never received a
            // completion (browser/tab closed mid-scrape, network drop, refresh) would
            // hold a concurrency slot forever and deadlock the queue. Anything held
            // longer than 10 minutes cannot still be legitimately in flight.
            try {
                $reap = $pdo->prepare("
                    UPDATE scrape_city_jobs
                    SET status = 'failed',
                        error_message = 'Timed out: no completion received within 10 minutes',
                        completed_at = NOW()
                    WHERE user_id = ?
                      AND run_id = ?
                      AND status = 'running'
                      AND COALESCE(locked_at, started_at) IS NOT NULL
                      AND COALESCE(locked_at, started_at) < (NOW() - INTERVAL 10 MINUTE)
                ");
                $reap->execute([$userId, $runId]);
            } catch (Exception $e) {}

            // Concurrency cap is PER USER (one browser tab drives up to 4 parallel
            // jobs). A GLOBAL count here let any 4 stuck rows anywhere block every
            // user — root cause of the "stuck on Queueing..." deadlock.
            $activeStmt = $pdo->prepare("SELECT COUNT(*) FROM scrape_city_jobs WHERE status = 'running' AND user_id = ? AND run_id = ?");
            $activeStmt->execute([$userId, $runId]);
            $active = (int)$activeStmt->fetchColumn();
            $slots = max(0, min(4, 4 - $active)); // clamp 0–4
            if ($slots === 0) {
                echo json_encode(['success' => true, 'jobs' => [], 'active' => $active, 'max_active' => 4]);
                exit;
            }
            $where = "status = 'queued' AND user_id = ? AND run_id = ?";
            $params = [$userId, $runId];
            if ($listId) {
                $where .= " AND list_id = ?";
                $params[] = $listId;
            }
            try {
                // Use nested transaction only if not already in one
                $inTxn = $pdo->inTransaction();
                if (!$inTxn) $pdo->beginTransaction();

                // Step 1: SELECT with FOR UPDATE — locks rows so other workers cannot claim them
                $select = $pdo->prepare("
                    SELECT id FROM scrape_city_jobs
                    WHERE $where
                    ORDER BY created_at ASC
                    LIMIT $slots
                    FOR UPDATE
                ");
                $select->execute($params);
                $ids = array_map('intval', $select->fetchAll(PDO::FETCH_COLUMN));

                if (empty($ids)) {
                    if (!$inTxn) $pdo->rollBack();
                    echo json_encode(['success' => true, 'jobs' => [], 'active' => $active, 'max_active' => 4]);
                    exit;
                }

                // Step 2: UPDATE only those same IDs (already locked by FOR UPDATE)
                $placeholders = implode(',', array_fill(0, count($ids), '?'));
                $claim = $pdo->prepare("
                    UPDATE scrape_city_jobs
                    SET status = 'running', locked_at = NOW(), started_at = COALESCE(started_at, NOW())
                    WHERE id IN ($placeholders)
                ");
                $claim->execute($ids);

                // Step 3: SELECT back only those same IDs
                // [HOTFIX-20260801] Include country_code for per-job ISO mapping
                $jobStmt = $pdo->prepare("
                    SELECT id, list_id, country, state_name, city, search_query, status, country_code
                    FROM scrape_city_jobs
                    WHERE id IN ($placeholders) AND status = 'running'
                    ORDER BY created_at ASC
                ");
                $jobStmt->execute($ids);

                if (!$inTxn) $pdo->commit();
                echo json_encode(['success' => true, 'jobs' => $jobStmt->fetchAll(PDO::FETCH_ASSOC), 'active' => $active + count($ids), 'max_active' => 4]);
                exit;
            } catch (Exception $e) {
                if ($pdo->inTransaction()) $pdo->rollBack();
                echo json_encode(['success' => false, 'error' => 'Claim failed']);
                exit;
            }

        case 'completeScrapeCityJob':
            $jobId = (int)($input['job_id'] ?? 0);
            $runId = trim((string)($input['run_id'] ?? ''));
            $status = $input['status'] ?? 'completed';
            if (!$jobId || !in_array($status, ['completed', 'failed', 'cancelled'], true)) {
                echo json_encode(['success' => false, 'error' => 'Invalid job completion']);
                exit;
            }
            $jobWhere = "id = ? AND user_id = ?";
            $jobParams = [$jobId, $userId];
            if ($runId !== '') {
                $jobWhere .= " AND run_id = ?";
                $jobParams[] = $runId;
            }
            $stmt = $pdo->prepare("
                UPDATE scrape_city_jobs
                SET status = ?, results_count = ?, error_message = ?, completed_at = NOW()
                WHERE $jobWhere
            ");
            $stmt->execute(array_merge([$status, (int)($input['results_count'] ?? 0), substr((string)($input['error_message'] ?? ''), 0, 500)], $jobParams));
            echo json_encode(['success' => true]);
            exit;

        case 'exportLeads':
            $listId = $_GET['list_id'] ?? 0;
            $page = max(1, intval($_GET['page'] ?? 1));
            $perPage = min(200, max(10, intval($_GET['per_page'] ?? 50)));
            $status = $_GET['status'] ?? '';
            $has = $_GET['has'] ?? '';
            $search = $_GET['search'] ?? '';
            $pipeline = $_GET['pipeline'] ?? '';
            $where = "list_id = ? AND user_id = ?";
            $params = [$listId, $userId];
            if ($status && in_array($status, ['cold', 'warm', 'hot'])) { $where .= " AND status = ?"; $params[] = $status; }
            if ($has === 'email') { $where .= " AND has_email = 1"; }
            elseif ($has === 'phone') { $where .= " AND has_phone = 1"; }
            elseif ($has === 'socials') { $where .= " AND has_socials = 1"; }
            elseif ($has === 'notes') { $where .= " AND has_notes = 1"; }
            elseif ($has === 'visited') { $where .= " AND visited_website = 1"; }
            elseif ($has === 'reached_out') { $where .= " AND reached_out = 1"; }
            elseif ($has === 'emailed') { $where .= " AND outreach_email = 1"; }
            elseif ($has === 'ig_dm') { $where .= " AND outreach_instagram = 1"; }
            elseif ($has === 'has_website') { $where .= " AND has_website = 1"; }
            if ($pipeline && in_array($pipeline, ['new','contacted','engaged','client','no_response'])) {
                if ($pipeline === 'new') { $where .= " AND (pipeline_stage = 'new' OR pipeline_stage IS NULL)"; }
                else { $where .= " AND pipeline_stage = ?"; $params[] = $pipeline; }
            }
            if ($search) { $where .= " AND (business_name LIKE ? OR address LIKE ? OR notes LIKE ?)"; $params[] = "%$search%"; $params[] = "%$search%"; $params[] = "%$search%"; }

            $countStmt = $pdo->prepare("SELECT COUNT(*) FROM lead_list_items WHERE $where");
            $countStmt->execute($params);
            $total = (int)$countStmt->fetchColumn();

            $offset = ($page - 1) * $perPage;
            $stmt = $pdo->prepare("SELECT * FROM lead_list_items WHERE $where ORDER BY created_at DESC LIMIT $perPage OFFSET $offset");
            $stmt->execute($params);
            $leads = $stmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($leads as &$lead) {
                $lead['emails'] = json_decode($lead['emails'] ?: '[]', true);
                $lead['social_media_links'] = json_decode($lead['social_media_links'] ?: '[]', true);
                $lead['visited_socials'] = json_decode($lead['visited_socials'] ?: '[]', true);
            }
            echo json_encode(['success' => true, 'leads' => $leads, 'total' => $total, 'page' => $page, 'per_page' => $perPage, 'total_pages' => max(1, ceil($total / $perPage))]);
            exit;

        case 'exportCount':
            $listId = $_GET['list_id'] ?? 0;
            $status = $_GET['status'] ?? '';
            $has = $_GET['has'] ?? '';
            $search = $_GET['search'] ?? '';
            $pipeline = $_GET['pipeline'] ?? '';
            $where = "list_id = ? AND user_id = ?";
            $params = [$listId, $userId];
            if ($status && in_array($status, ['cold', 'warm', 'hot'])) { $where .= " AND status = ?"; $params[] = $status; }
            if ($has === 'email') { $where .= " AND has_email = 1"; }
            elseif ($has === 'phone') { $where .= " AND has_phone = 1"; }
            elseif ($has === 'socials') { $where .= " AND has_socials = 1"; }
            elseif ($has === 'notes') { $where .= " AND has_notes = 1"; }
            elseif ($has === 'visited') { $where .= " AND visited_website = 1"; }
            elseif ($has === 'reached_out') { $where .= " AND reached_out = 1"; }
            elseif ($has === 'emailed') { $where .= " AND outreach_email = 1"; }
            elseif ($has === 'ig_dm') { $where .= " AND outreach_instagram = 1"; }
            elseif ($has === 'has_website') { $where .= " AND has_website = 1"; }
            if ($pipeline && in_array($pipeline, ['new','contacted','engaged','client','no_response'])) {
                if ($pipeline === 'new') { $where .= " AND (pipeline_stage = 'new' OR pipeline_stage IS NULL)"; }
                else { $where .= " AND pipeline_stage = ?"; $params[] = $pipeline; }
            }
            if ($search) { $where .= " AND (business_name LIKE ? OR address LIKE ? OR notes LIKE ?)"; $params[] = "%$search%"; $params[] = "%$search%"; $params[] = "%$search%"; }

            $stmt = $pdo->prepare("SELECT COUNT(*) as total, SUM(has_email) as with_email, SUM(has_phone) as with_phone, SUM(has_socials) as with_socials, SUM(has_website) as with_website, SUM(status='cold') as cold, SUM(status='warm') as warm, SUM(status='hot') as hot FROM lead_list_items WHERE $where");
            $stmt->execute($params);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            echo json_encode(['success' => true, 'total' => (int)$row['total'], 'with_email' => (int)$row['with_email'], 'with_phone' => (int)$row['with_phone'], 'with_socials' => (int)$row['with_socials'], 'with_website' => (int)$row['with_website'], 'cold' => (int)$row['cold'], 'warm' => (int)$row['warm'], 'hot' => (int)$row['hot']]);
            exit;

        case 'exportCSV':
            $listId = $_GET['list_id'] ?? 0;
            $status = $_GET['status'] ?? '';
            $has = $_GET['has'] ?? '';
            $search = $_GET['search'] ?? '';
            $pipeline = $_GET['pipeline'] ?? '';
            $where = "list_id = ? AND user_id = ?";
            $params = [$listId, $userId];
            if ($status && in_array($status, ['cold', 'warm', 'hot'])) { $where .= " AND status = ?"; $params[] = $status; }
            if ($has === 'email') { $where .= " AND has_email = 1"; }
            elseif ($has === 'phone') { $where .= " AND has_phone = 1"; }
            elseif ($has === 'socials') { $where .= " AND has_socials = 1"; }
            elseif ($has === 'notes') { $where .= " AND has_notes = 1"; }
            elseif ($has === 'visited') { $where .= " AND visited_website = 1"; }
            elseif ($has === 'reached_out') { $where .= " AND reached_out = 1"; }
            elseif ($has === 'emailed') { $where .= " AND outreach_email = 1"; }
            elseif ($has === 'ig_dm') { $where .= " AND outreach_instagram = 1"; }
            elseif ($has === 'has_website') { $where .= " AND has_website = 1"; }
            if ($pipeline && in_array($pipeline, ['new','contacted','engaged','client','no_response'])) {
                if ($pipeline === 'new') { $where .= " AND (pipeline_stage = 'new' OR pipeline_stage IS NULL)"; }
                else { $where .= " AND pipeline_stage = ?"; $params[] = $pipeline; }
            }
            if ($search) { $where .= " AND (business_name LIKE ? OR address LIKE ? OR notes LIKE ?)"; $params[] = "%$search%"; $params[] = "%$search%"; $params[] = "%$search%"; }

            $countStmt = $pdo->prepare("SELECT COUNT(*) FROM lead_list_items WHERE $where");
            $countStmt->execute($params);
            $total = (int)$countStmt->fetchColumn();
            if ($total === 0) { header('HTTP/1.1 404 Not Found'); echo 'No leads match your filters.'; exit; }

            $listStmt = $pdo->prepare("SELECT name FROM lead_lists WHERE id = ? AND user_id = ?");
            $listStmt->execute([$listId, $userId]);
            $listName = preg_replace('/[^a-z0-9]/i', '_', $listStmt->fetchColumn() ?: 'leads');
            $dateStr = date('Y-m-d');

            $platforms = [
                'Facebook' => ['facebook.com','fb.com','fb.me'],
                'Instagram' => ['instagram.com','instagr.am'],
                'Twitter' => ['twitter.com','x.com'],
                'LinkedIn' => ['linkedin.com'],
                'YouTube' => ['youtube.com','youtu.be'],
                'TikTok' => ['tiktok.com']
            ];
            $csvHeaders = ['Business Name','Address','City','State','Phone','Website','Rating','Reviews','Status','Pipeline Stage','Notes','Email 1','Email 2','Email 3','Email 4','Email 5'];
            foreach (array_keys($platforms) as $p) $csvHeaders[] = $p;
            $csvHeaders[] = 'Other Socials';

            $maxPerFile = 500000;
            $chunkSize = 5000;

            $writeCsvRows = function($output, $offset, $limit) use ($pdo, $where, $params, $platforms) {
                $written = 0;
                $pos = $offset;
                $chunkSize = 5000;
                while ($written < $limit) {
                    $fetch = min($chunkSize, $limit - $written);
                    $stmt = $pdo->prepare("SELECT business_name, address, city, state, phone, website, rating, review_count, status, pipeline_stage, notes, emails, social_media_links, lead_score, follow_up_count, outreach_email, outreach_instagram, visited_website FROM lead_list_items WHERE $where ORDER BY created_at DESC LIMIT $fetch OFFSET $pos");
                    $stmt->execute($params);
                    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
                    if (empty($rows)) break;
                    foreach ($rows as $r) {
                        $emails = json_decode($r['emails'] ?: '[]', true);
                        $socials = json_decode($r['social_media_links'] ?: '[]', true);
                        $categorized = array_fill_keys(array_keys($platforms), '');
                        $other = [];
                        foreach ($socials as $url) {
                            $matched = false;
                            foreach ($platforms as $pName => $patterns) {
                                foreach ($patterns as $pat) {
                                    if (stripos($url, $pat) !== false) { if (!$categorized[$pName]) $categorized[$pName] = $url; $matched = true; break 2; }
                                }
                            }
                            if (!$matched) $other[] = $url;
                        }
                        $row = [$r['business_name'],$r['address'],$r['city'],$r['state'],$r['phone'],$r['website'],$r['rating'],$r['review_count'],$r['status'],$r['pipeline_stage'] ?? 'new',$r['notes']];
                        for ($i = 0; $i < 5; $i++) $row[] = $emails[$i] ?? '';
                        foreach (array_keys($platforms) as $p) $row[] = $categorized[$p];
                        $row[] = implode('; ', $other);
                        fputcsv($output, $row);
                        $written++;
                    }
                    $pos += count($rows);
                }
                return $written;
            };

            if ($total <= $maxPerFile) {
                header('Content-Type: text/csv; charset=utf-8');
                header("Content-Disposition: attachment; filename=\"{$listName}_{$dateStr}.csv\"");
                header('Cache-Control: no-cache');
                $output = fopen('php://output', 'w');
                fprintf($output, "\xEF\xBB\xBF");
                fputcsv($output, $csvHeaders);
                $writeCsvRows($output, 0, $total);
                fclose($output);
            } else {
                $tmpDir = sys_get_temp_dir();
                $zipPath = tempnam($tmpDir, 'leads_zip_');
                $zip = new ZipArchive();
                $zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE);
                $tmpFiles = [];
                $fileNum = 0;
                $remaining = $total;
                $offset = 0;
                while ($remaining > 0) {
                    $fileNum++;
                    $count = min($maxPerFile, $remaining);
                    $csvPath = tempnam($tmpDir, 'leads_csv_');
                    $tmpFiles[] = $csvPath;
                    $csvFile = fopen($csvPath, 'w');
                    fprintf($csvFile, "\xEF\xBB\xBF");
                    fputcsv($csvFile, $csvHeaders);
                    $writeCsvRows($csvFile, $offset, $count);
                    fclose($csvFile);
                    $zip->addFile($csvPath, "{$listName}_part{$fileNum}.csv");
                    $offset += $count;
                    $remaining -= $count;
                }
                $zip->close();
                // Binary ZIP output — strip gzip buffer before setting ZIP headers
                while (ob_get_level() > 0) { ob_end_clean(); }
                header('Content-Type: application/zip');
                header("Content-Disposition: attachment; filename=\"{$listName}_{$dateStr}.zip\"");
                header('Content-Length: ' . filesize($zipPath));
                header('Cache-Control: no-cache');
                readfile($zipPath);
                foreach ($tmpFiles as $f) @unlink($f);
                @unlink($zipPath);
            }
            exit;

        case 'fireAllScrapes':
            $listId = $input['list_id'] ?? 0;
            $batchSize = min(100, max(1, intval($input['batch_size'] ?? 100)));
            if (!$listId) { echo json_encode(['success' => false, 'error' => 'No list_id']); exit; }

            // Per-user throttle (audit 2026-07-04): APCu-backed 5s throttle keeps
            // even the new thin-enqueue calls from creating a runaway. Falls through
            // when APCu is unavailable so behavior degrades open rather than closed.
            if (function_exists('apcu_fetch')) {
                $__throttle_key = "fas_throttle:$userId";
                $__last = apcu_fetch($__throttle_key, $__thit);
                if ($__thit && (microtime(true) - (float)$__last) < 5.0) {
                    $countStmt = $pdo->prepare("
                        SELECT
                            COUNT(CASE WHEN enrichment_status = 'pending' THEN 1 END) as pending,
                            COUNT(CASE WHEN enrichment_status = 'processing' THEN 1 END) as processing,
                            COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END) as completed,
                            COUNT(CASE WHEN enrichment_status = 'failed' THEN 1 END) as failed,
                            SUM(has_website) as total_with_website,
                            COUNT(CASE WHEN has_website = 1 AND (enrichment_status IS NULL OR enrichment_status = 'failed') AND enriched_at IS NULL THEN 1 END) as needs_enrichment
                        FROM lead_list_items WHERE list_id = ? AND user_id = ?
                    ");
                    $countStmt->execute([$listId, $userId]);
                    $counts = $countStmt->fetch(PDO::FETCH_ASSOC);
                    echo json_encode([
                        'success' => true, 'fired' => 0, 'throttled' => true,
                        'pending' => (int)($counts['pending'] ?? 0),
                        'processing' => (int)($counts['processing'] ?? 0),
                        'completed' => (int)($counts['completed'] ?? 0),
                        'failed' => (int)($counts['failed'] ?? 0),
                        'total_with_website' => (int)($counts['total_with_website'] ?? 0),
                        'queued_for_worker' => (int)($counts['needs_enrichment'] ?? 0)
                    ]);
                    exit;
                }
                apcu_store($__throttle_key, (string)microtime(true), 5);
            }

            // -------------------------------------------------------------------
            // THIN-ENQUEUE PATH (audit 2026-07-04 backend-worker pass):
            // Browser-triggered fireAllScrapes no longer fans out to
            // api.replicate.com inside the PHP request. The previous behaviour set
            // enrichment_status='pending' on eligible rows, but the backend
            // worker (queue_claim.php / music_worker.py) only claims rows where
            // enrichment_status IS NULL OR 'failed'. So a row stuck in 'pending'
            // is invisible to the worker and stays untouched until something else
            // rescues it. We reclaim any orphan 'pending' rows back to NULL so
            // the worker can pick them up. The PHP request returns the queue
            // depth; the actual Replicate dispatch is the backend worker's job.
            // -------------------------------------------------------------------
            $pdo->prepare("
                UPDATE lead_list_items
                SET enrichment_status = NULL
                WHERE list_id = ? AND user_id = ?
                  AND has_website = 1
                  AND enrichment_status = 'pending'
            ")->execute([$listId, $userId]);

            $countStmt = $pdo->prepare("
                SELECT
                    COUNT(CASE WHEN enrichment_status = 'pending' THEN 1 END) as pending,
                    COUNT(CASE WHEN enrichment_status = 'processing' THEN 1 END) as processing,
                    COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END) as completed,
                    COUNT(CASE WHEN enrichment_status = 'failed' THEN 1 END) as failed,
                    SUM(has_website) as total_with_website,
                    COUNT(CASE WHEN has_website = 1 AND (enrichment_status IS NULL OR enrichment_status = 'failed') AND enriched_at IS NULL THEN 1 END) as needs_enrichment
                FROM lead_list_items WHERE list_id = ? AND user_id = ?
            ");
            $countStmt->execute([$listId, $userId]);
            $counts = $countStmt->fetch(PDO::FETCH_ASSOC);

            echo json_encode([
                'success' => true,
                'fired' => 0,
                'queued_for_worker' => (int)($counts['needs_enrichment'] ?? 0),
                'pending' => (int)($counts['pending'] ?? 0),
                'processing' => (int)($counts['processing'] ?? 0),
                'completed' => (int)($counts['completed'] ?? 0),
                'failed' => (int)($counts['failed'] ?? 0),
                'total_with_website' => (int)($counts['total_with_website'] ?? 0)
            ]);
            exit;

        case 'getEnrichmentProgress':
            $listId = $_GET['list_id'] ?? 0;
            if (!$listId) { echo json_encode(['success' => false]); exit; }
            // APCu cache (audit 2026-07-04): same rationale as getListDetail.
            // 5s TTL is user/list scoped; bypasses safely when APCu is unavailable.
            $__cache_key = function_exists('apcu_fetch') ? "getEnrichmentProgress:$userId:$listId" : '';
            if ($__cache_key) {
                $__cached = apcu_fetch($__cache_key, $__hit);
                if ($__hit && is_string($__cached) && $__cached !== '') { echo $__cached; exit; }
            }
            $stmt = $pdo->prepare("
                SELECT
                    SUM(has_website) as total_with_website,
                    COUNT(CASE WHEN enrichment_status = 'pending' THEN 1 END) as pending,
                    COUNT(CASE WHEN enrichment_status = 'processing' THEN 1 END) as processing,
                    COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END) as completed,
                    COUNT(CASE WHEN enrichment_status = 'failed' THEN 1 END) as failed,
                    COUNT(CASE WHEN enriched_at IS NOT NULL THEN 1 END) as enriched,
                    SUM(has_email) as with_emails,
                    SUM(has_socials) as with_socials,
                    COUNT(CASE WHEN has_website = 1 AND (enrichment_status IS NULL OR enrichment_status = 'failed') AND enriched_at IS NULL THEN 1 END) as needs_enrichment
                FROM lead_list_items WHERE list_id = ? AND user_id = ?
            ");
            $stmt->execute([$listId, $userId]);
            $stats = $stmt->fetch(PDO::FETCH_ASSOC);

            $__payload = json_encode([
                'success' => true,
                'total' => (int)$stats['total_with_website'],
                'enriched' => (int)$stats['enriched'],
                'pending' => (int)$stats['pending'],
                'processing' => (int)$stats['processing'],
                'completed' => (int)$stats['completed'],
                'failed' => (int)$stats['failed'],
                'needs_enrichment' => (int)$stats['needs_enrichment'],
                'with_emails' => (int)$stats['with_emails'],
                'with_socials' => (int)$stats['with_socials']
            ]);
            if ($__cache_key) apcu_store($__cache_key, $__payload, 5);
            echo $__payload;
            exit;

        case 'recoverStuckEnrichments':
            $listId = $input['list_id'] ?? 0;
            if (!$listId) { echo json_encode(['success' => false, 'error' => 'No list_id']); exit; }

            // Backend-worker containment (audit 2026-07-04 recovery-paths pass):
            // Browser-triggered recovery no longer polls Replicate. Rows stuck in
            // 'processing' or 'pending' are reclaimed back to NULL so the backend
            // worker (queue_claim.php) — when re-enabled in a separate operator
            // pass — can claim them and run the canonical poll-then-process path
            // via scrape_result.php (X-API-Token gated). replicate_id is cleared
            // to satisfy the worker's claim WHERE clause
            // (replicate_id IS NULL OR = ''). This matches the fireAllScrapes
            // semantics adopted in the previous audit patch round.
            $pdo->prepare("
                UPDATE lead_list_items
                SET enrichment_status = NULL, enriched_at = NULL, replicate_id = NULL
                WHERE list_id = ? AND user_id = ?
                  AND enrichment_status IN ('processing', 'pending')
                  AND has_website = 1
            ")->execute([$listId, $userId]);

            $countStmt = $pdo->prepare("
                SELECT
                    COUNT(CASE WHEN enrichment_status = 'pending' THEN 1 END) as pending,
                    COUNT(CASE WHEN enrichment_status = 'processing' THEN 1 END) as processing,
                    COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END) as completed,
                    COUNT(CASE WHEN enrichment_status = 'failed' THEN 1 END) as failed,
                    SUM(has_website) as total_with_website,
                    COUNT(CASE WHEN has_website = 1 AND (enrichment_status IS NULL OR enrichment_status = 'failed') AND enriched_at IS NULL THEN 1 END) as needs_enrichment
                FROM lead_list_items WHERE list_id = ? AND user_id = ?
            ");
            $countStmt->execute([$listId, $userId]);
            $c = $countStmt->fetch(PDO::FETCH_ASSOC);

            // JSON shape preserved so existing JS consumers (which only inspect
            // r.success here) keep working. recovered = current needs_enrichment
            // depth (= rows reclaimed and now claimable by the worker).
            echo json_encode([
                'success' => true,
                'recovered' => (int)($c['needs_enrichment'] ?? 0),
                'failed' => (int)($c['failed'] ?? 0),
                'still_processing' => (int)($c['processing'] ?? 0),
                'checked' => (int)($c['total_with_website'] ?? 0)
            ]);
            exit;

        case 'retryFailedEnrichments':
            $listId = $input['list_id'] ?? 0;
            if (!$listId) { echo json_encode(['success' => false, 'error' => 'No list_id']); exit; }

            // Backend-worker containment (audit 2026-07-04 recovery-paths pass):
            // Browser-triggered retry no longer polls Replicate or fans out new
            // predictions. Each 'failed' row is reclaimed back to NULL (clearing
            // replicate_id too, to satisfy the worker's claim WHERE clause
            // `replicate_id IS NULL OR = ''`) so the backend worker can pick it
            // up and drive the canonical poll-then-scrape_result path. JSON
            // shape is preserved so the _enrichLiveLoop JS condition
            // `r.recovered > 0 || r.retried > 0` still triggers `loadLeads() +
            // _enrichLiveLoop()` when rows are reclaimed.
            $reclaimStmt = $pdo->prepare("
                UPDATE lead_list_items
                SET enrichment_status = NULL, enriched_at = NULL, replicate_id = NULL
                WHERE list_id = ? AND user_id = ?
                  AND enrichment_status = 'failed'
                  AND has_website = 1
            ");
            $reclaimStmt->execute([$listId, $userId]);
            $retried = (int)$reclaimStmt->rowCount();

            $countStmt = $pdo->prepare("
                SELECT
                    COUNT(CASE WHEN enrichment_status = 'pending' THEN 1 END) as pending,
                    COUNT(CASE WHEN enrichment_status = 'processing' THEN 1 END) as processing,
                    COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END) as completed,
                    COUNT(CASE WHEN enrichment_status = 'failed' THEN 1 END) as failed,
                    SUM(has_website) as total_with_website,
                    COUNT(CASE WHEN has_website = 1 AND (enrichment_status IS NULL OR enrichment_status = 'failed') AND enriched_at IS NULL THEN 1 END) as needs_enrichment
                FROM lead_list_items WHERE list_id = ? AND user_id = ?
            ");
            $countStmt->execute([$listId, $userId]);
            $counts = $countStmt->fetch(PDO::FETCH_ASSOC);

            echo json_encode([
                'success' => true,
                'recovered' => 0,
                'retried' => $retried,
                'pending' => (int)($counts['pending'] ?? 0),
                'processing' => (int)($counts['processing'] ?? 0),
                'completed' => (int)($counts['completed'] ?? 0),
                'failed' => (int)($counts['failed'] ?? 0),
                'total_with_website' => (int)($counts['total_with_website'] ?? 0),
                'queued_for_worker' => (int)($counts['needs_enrichment'] ?? 0)
            ]);
            exit;

        case 'forceReenrich':
        case 'adminForceReenrich':
            $listId = $input['list_id'] ?? 0;
            if (!$listId) { echo json_encode(['success' => false, 'error' => 'No list_id']); exit; }

            $pdo->prepare("
                UPDATE lead_list_items
                SET enrichment_status = NULL, enriched_at = NULL, replicate_id = NULL
                WHERE list_id = ? AND user_id = ?
                  AND has_website = 1
            ")->execute([$listId, $userId]);

            $totalStmt = $pdo->prepare("
                SELECT COUNT(*) FROM lead_list_items
                WHERE list_id = ? AND user_id = ?
                  AND has_website = 1
            ");
            $totalStmt->execute([$listId, $userId]);
            $totalWebsites = (int)$totalStmt->fetchColumn();

            echo json_encode(['success' => true, 'reset' => $totalWebsites]);
            exit;

        case 'saveGHLConnection':
            $name = trim($input['name'] ?? '');
            $apiKey = trim($input['api_key'] ?? '');
            $locationId = trim($input['location_id'] ?? '');
            $connId = $input['connection_id'] ?? null;
            if (!$name || !$locationId) { echo json_encode(['success' => false, 'error' => 'Name and Location ID are required']); exit; }
            if ($connId) {
                if ($apiKey && $apiKey !== 'KEEP_EXISTING') {
                    $pdo->prepare("UPDATE ghl_connections SET name = ?, api_key = ?, location_id = ? WHERE id = ? AND user_id = ?")->execute([$name, $apiKey, $locationId, $connId, $userId]);
                } else {
                    $pdo->prepare("UPDATE ghl_connections SET name = ?, location_id = ? WHERE id = ? AND user_id = ?")->execute([$name, $locationId, $connId, $userId]);
                }
            } else {
                if (!$apiKey) { echo json_encode(['success' => false, 'error' => 'API key is required for new connections']); exit; }
                $pdo->prepare("INSERT INTO ghl_connections (user_id, name, api_key, location_id) VALUES (?,?,?,?)")->execute([$userId, $name, $apiKey, $locationId]);
                $connId = $pdo->lastInsertId();
            }
            echo json_encode(['success' => true, 'connection_id' => (int)$connId]);
            exit;

        case 'getGHLConnections':
            $s = $pdo->prepare("SELECT id, name, location_id, created_at FROM ghl_connections WHERE user_id = ? ORDER BY created_at ASC");
            $s->execute([$userId]);
            echo json_encode(['success' => true, 'connections' => $s->fetchAll(PDO::FETCH_ASSOC)]);
            exit;

        case 'deleteGHLConnection':
            $connId = $input['connection_id'] ?? 0;
            if (!$connId) { echo json_encode(['success' => false, 'error' => 'No connection_id']); exit; }
            $pdo->prepare("DELETE FROM ghl_connections WHERE id = ? AND user_id = ?")->execute([$connId, $userId]);
            echo json_encode(['success' => true]);
            exit;

        case 'ghlProxy':
            $method = strtoupper($input['method'] ?? 'GET');
            $endpoint = $input['endpoint'] ?? '';
            $body = $input['body'] ?? null;
            $connId = $input['connection_id'] ?? 0;
            if (!$endpoint) { echo json_encode(['success' => false, 'error' => 'No endpoint']); exit; }

            if ($connId) {
                $creds = $pdo->prepare("SELECT api_key, location_id FROM ghl_connections WHERE id = ? AND user_id = ?");
                $creds->execute([$connId, $userId]);
            } else {
                $creds = $pdo->prepare("SELECT api_key, location_id FROM ghl_connections WHERE user_id = ? ORDER BY created_at ASC LIMIT 1");
                $creds->execute([$userId]);
            }
            $gc = $creds->fetch(PDO::FETCH_ASSOC);
            if (empty($gc['api_key'])) { echo json_encode(['success' => false, 'error' => 'GHL not connected']); exit; }

            $url = 'https://services.leadconnectorhq.com' . $endpoint;
            $ch = curl_init($url);
            $headers = [
                'Authorization: Bearer ' . $gc['api_key'],
                'Version: 2021-07-28',
                'Content-Type: application/json'
            ];
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER => $headers,
                CURLOPT_TIMEOUT => 15
            ]);
            if ($method === 'POST') {
                curl_setopt($ch, CURLOPT_POST, true);
                if ($body) curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
            }
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            $parsed = json_decode($response, true);
            echo json_encode(['success' => $httpCode >= 200 && $httpCode < 300, 'status' => $httpCode, 'data' => $parsed]);
            exit;

        case 'ghlCreateImportFromList':
            $listId = $input['list_id'] ?? 0;
            $tags = $input['tags'] ?? [];
            $workflowId = $input['workflow_id'] ?? '';
            $workflowName = $input['workflow_name'] ?? '';
            $drip = $input['drip'] ?? null;
            $connId = $input['connection_id'] ?? 0;
            $filters = $input['filters'] ?? [];

            if (!$listId) { echo json_encode(['success' => false, 'error' => 'No list_id']); exit; }

            if ($connId) { $creds = $pdo->prepare("SELECT id, name, api_key, location_id FROM ghl_connections WHERE id = ? AND user_id = ?"); $creds->execute([$connId, $userId]); }
            else { $creds = $pdo->prepare("SELECT id, name, api_key, location_id FROM ghl_connections WHERE user_id = ? ORDER BY created_at ASC LIMIT 1"); $creds->execute([$userId]); }
            $gc = $creds->fetch(PDO::FETCH_ASSOC);
            if (empty($gc['api_key']) || empty($gc['location_id'])) { echo json_encode(['success' => false, 'error' => 'GHL not connected']); exit; }
            $connId = $gc['id'];
            $connName = $gc['name'];

            $fWhere = "list_id = ? AND user_id = ?";
            $fParams = [$listId, $userId];
            $fHas = $filters['has'] ?? '';
            $fStatus = $filters['status'] ?? '';
            $fPipeline = $filters['pipeline'] ?? '';
            $fSearch = $filters['search'] ?? '';
            $fImport = $filters['import_filter'] ?? '';
            if ($fStatus && in_array($fStatus, ['cold','warm','hot'])) { $fWhere .= " AND status = ?"; $fParams[] = $fStatus; }
            if ($fHas === 'has_email') { $fWhere .= " AND has_email = 1"; }
            elseif ($fHas === 'has_phone') { $fWhere .= " AND has_phone = 1"; }
            elseif ($fHas === 'has_both') { $fWhere .= " AND has_email = 1 AND has_phone = 1"; }
            if ($fPipeline && in_array($fPipeline, ['new','contacted','engaged','client','no_response'])) {
                if ($fPipeline === 'new') { $fWhere .= " AND (pipeline_stage = 'new' OR pipeline_stage IS NULL)"; }
                else { $fWhere .= " AND pipeline_stage = ?"; $fParams[] = $fPipeline; }
            }
            if ($fSearch) { $fWhere .= " AND (business_name LIKE ? OR address LIKE ?)"; $fParams[] = "%$fSearch%"; $fParams[] = "%$fSearch%"; }
            if ($fImport === 'not_imported') { $fWhere .= " AND (ghl_contact_id IS NULL OR ghl_contact_id = '')"; }
            elseif ($fImport === 'previously_imported') { $fWhere .= " AND ghl_contact_id IS NOT NULL AND ghl_contact_id != ''"; }

            $countStmt = $pdo->prepare("SELECT COUNT(*) FROM lead_list_items WHERE $fWhere");
            $countStmt->execute($fParams);
            $totalLeads = (int)$countStmt->fetchColumn();
            if ($totalLeads === 0) { echo json_encode(['success' => false, 'error' => 'No leads match filters']); exit; }

            $dripEnabled = !empty($drip['enabled']);
            $dripBatch = $dripEnabled ? max(1, intval($drip['batch_size'] ?? 50)) : $totalLeads;
            $dripInterval = $dripEnabled ? max(1, intval($drip['interval_minutes'] ?? 60)) : 0;
            $dripTz = $drip['timezone'] ?? 'America/New_York';
            $dripHour = isset($drip['send_hour']) ? intval($drip['send_hour']) : null;
            $dripMinute = isset($drip['send_minute']) ? intval($drip['send_minute']) : null;
            $nextBatch = null;
            if ($dripEnabled && $dripHour !== null) {
                $tz = new DateTimeZone($dripTz);
                $now = new DateTime('now', $tz);
                $send = (clone $now)->setTime($dripHour, $dripMinute ?? 0);
                if ($send <= $now) $send->modify('+1 day');
                $send->setTimezone(new DateTimeZone('UTC'));
                $nextBatch = $send->format('Y-m-d H:i:s');
            }

            $pdo->prepare("INSERT INTO ghl_import_logs (user_id, list_id, connection_id, connection_name, status, total_contacts, tags, workflow_id, workflow_name, drip_enabled, drip_batch_size, drip_interval_minutes, drip_timezone, drip_send_hour, drip_send_minute, drip_next_batch_at, errors) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)")->execute([
                $userId, $listId, $connId, $connName,
                $dripEnabled && $dripHour !== null ? 'pending' : 'running',
                $totalLeads, json_encode($tags), $workflowId, $workflowName,
                $dripEnabled ? 1 : 0, $dripBatch, $dripInterval, $dripTz,
                $dripHour, $dripMinute, $nextBatch, '[]'
            ]);
            $importId = $pdo->lastInsertId();

            $itemStmt = $pdo->prepare("INSERT INTO ghl_import_items (import_log_id, lead_id, user_id, status, lead_data) VALUES (?,?,?,?,?)");
            $leadStmt = $pdo->prepare("SELECT id, business_name, address, city, state, phone, website, emails, social_media_links, ghl_contact_id FROM lead_list_items WHERE $fWhere ORDER BY created_at DESC");
            $leadStmt->execute($fParams);
            while ($r = $leadStmt->fetch(PDO::FETCH_ASSOC)) {
                $emails = json_decode($r['emails'] ?: '[]', true);
                $leadData = json_encode([
                    '_leadId' => (int)$r['id'], 'firstName' => '', 'lastName' => '',
                    'companyName' => $r['business_name'], 'email' => $emails[0] ?? '',
                    'phone' => $r['phone'], 'city' => $r['city'], 'state' => $r['state'],
                    'website' => $r['website'], 'address' => $r['address']
                ]);
                $itemStmt->execute([$importId, $r['id'], $userId, 'pending', $leadData]);
            }

            echo json_encode(['success' => true, 'import_id' => (int)$importId, 'total' => $totalLeads, 'mode' => ($dripEnabled && $dripHour !== null) ? 'drip' : 'immediate', 'next_batch_at' => $nextBatch]);
            exit;

        case 'ghlCreateImport':
            $leads = $input['leads'] ?? [];
            $tags = $input['tags'] ?? [];
            $workflowId = $input['workflow_id'] ?? '';
            $workflowName = $input['workflow_name'] ?? '';
            $listId = $input['list_id'] ?? 0;
            $drip = $input['drip'] ?? null;
            $connId = $input['connection_id'] ?? 0;
            if (empty($leads)) { echo json_encode(['success' => false, 'error' => 'No leads']); exit; }

            if ($connId) {
                $creds = $pdo->prepare("SELECT id, name, api_key, location_id FROM ghl_connections WHERE id = ? AND user_id = ?");
                $creds->execute([$connId, $userId]);
            } else {
                $creds = $pdo->prepare("SELECT id, name, api_key, location_id FROM ghl_connections WHERE user_id = ? ORDER BY created_at ASC LIMIT 1");
                $creds->execute([$userId]);
            }
            $gc = $creds->fetch(PDO::FETCH_ASSOC);
            if (empty($gc['api_key']) || empty($gc['location_id'])) {
                echo json_encode(['success' => false, 'error' => 'GHL not connected']);
                exit;
            }
            $connId = $gc['id'];
            $connName = $gc['name'];

            $dripEnabled = !empty($drip['enabled']);
            $dripBatch = $dripEnabled ? max(1, intval($drip['batch_size'] ?? 50)) : count($leads);
            $dripInterval = $dripEnabled ? max(1, intval($drip['interval_minutes'] ?? 60)) : 0;
            $dripTz = $drip['timezone'] ?? 'America/New_York';
            $dripHour = isset($drip['send_hour']) ? intval($drip['send_hour']) : null;
            $dripMinute = isset($drip['send_minute']) ? intval($drip['send_minute']) : null;

            $nextBatch = null;
            if ($dripEnabled && $dripHour !== null) {
                $tz = new DateTimeZone($dripTz);
                $now = new DateTime('now', $tz);
                $send = (clone $now)->setTime($dripHour, $dripMinute ?? 0);
                if ($send <= $now) $send->modify('+1 day');
                $send->setTimezone(new DateTimeZone('UTC'));
                $nextBatch = $send->format('Y-m-d H:i:s');
            }

            $pdo->prepare("INSERT INTO ghl_import_logs (user_id, list_id, connection_id, connection_name, status, total_contacts, tags, workflow_id, workflow_name, drip_enabled, drip_batch_size, drip_interval_minutes, drip_timezone, drip_send_hour, drip_send_minute, drip_next_batch_at, errors) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)")->execute([
                $userId, $listId, $connId, $connName,
                $dripEnabled && $dripHour !== null ? 'pending' : 'running',
                count($leads),
                json_encode($tags), $workflowId, $workflowName,
                $dripEnabled ? 1 : 0, $dripBatch, $dripInterval, $dripTz,
                $dripHour, $dripMinute, $nextBatch, '[]'
            ]);
            $importId = $pdo->lastInsertId();

            $itemStmt = $pdo->prepare("INSERT INTO ghl_import_items (import_log_id, lead_id, user_id, status, lead_data) VALUES (?,?,?,?,?)");
            foreach ($leads as $lead) {
                $itemStmt->execute([$importId, $lead['_leadId'] ?? 0, $userId, 'pending', json_encode($lead)]);
            }

            if (!$dripEnabled || $dripHour === null) {
                echo json_encode(['success' => true, 'import_id' => (int)$importId, 'mode' => 'immediate']);
            } else {
                echo json_encode(['success' => true, 'import_id' => (int)$importId, 'mode' => 'drip', 'next_batch_at' => $nextBatch]);
            }
            exit;

        case 'ghlProcessBatch':
            $importId = $input['import_id'] ?? 0;
            if (!$importId) { echo json_encode(['success' => false, 'error' => 'No import_id']); exit; }

            $log = $pdo->prepare("SELECT * FROM ghl_import_logs WHERE id = ? AND user_id = ?");
            $log->execute([$importId, $userId]);
            $importLog = $log->fetch(PDO::FETCH_ASSOC);
            if (!$importLog) { echo json_encode(['success' => false, 'error' => 'Import not found']); exit; }
            if (in_array($importLog['status'], ['cancelled','completed'])) {
                echo json_encode(['success' => true, 'done' => true, 'status' => $importLog['status']]);
                exit;
            }

            if ($importLog['drip_enabled'] && !empty($importLog['drip_next_batch_at'])) {
                $nowUTC = new DateTime('now', new DateTimeZone('UTC'));
                $nextAt = new DateTime($importLog['drip_next_batch_at'], new DateTimeZone('UTC'));
                if ($nextAt > $nowUTC) {
                    $remainStmt2 = $pdo->prepare("SELECT COUNT(*) FROM ghl_import_items WHERE import_log_id = ? AND status = 'pending'");
                    $remainStmt2->execute([$importId]);
                    $remaining2 = (int)$remainStmt2->fetchColumn();
                    $totals2 = $pdo->prepare("SELECT imported, updated, failed, processed, total_contacts, status FROM ghl_import_logs WHERE id = ?");
                    $totals2->execute([$importId]);
                    echo json_encode([
                        'success' => true,
                        'waiting' => true,
                        'drip_next_batch_at' => $importLog['drip_next_batch_at'],
                        'wait_seconds' => $nextAt->getTimestamp() - $nowUTC->getTimestamp(),
                        'remaining' => $remaining2,
                        'totals' => $totals2->fetch(PDO::FETCH_ASSOC),
                        'done' => false
                    ]);
                    exit;
                }
            }

            $connIdForImport = $importLog['connection_id'] ?? null;
            if ($connIdForImport) {
                $creds = $pdo->prepare("SELECT api_key, location_id FROM ghl_connections WHERE id = ? AND user_id = ?");
                $creds->execute([$connIdForImport, $userId]);
            } else {
                $creds = $pdo->prepare("SELECT api_key, location_id FROM ghl_connections WHERE user_id = ? ORDER BY created_at ASC LIMIT 1");
                $creds->execute([$userId]);
            }
            $gc = $creds->fetch(PDO::FETCH_ASSOC);
            if (empty($gc['api_key']) || empty($gc['location_id'])) {
                echo json_encode(['success' => false, 'error' => 'GHL not connected']);
                exit;
            }

            $apiKey = $gc['api_key'];
            $locationId = $gc['location_id'];
            $tags = json_decode($importLog['tags'] ?: '[]', true);
            $workflowId = $importLog['workflow_id'];
            $batchSize = $importLog['drip_enabled'] ? $importLog['drip_batch_size'] : 10;

            $pdo->prepare("UPDATE ghl_import_logs SET status = 'running', drip_next_batch_at = NULL WHERE id = ?")->execute([$importId]);

            $pendingStmt = $pdo->prepare("SELECT * FROM ghl_import_items WHERE import_log_id = ? AND status = 'pending' ORDER BY id ASC LIMIT ?");
            $pendingStmt->bindValue(1, (int)$importId, PDO::PARAM_INT);
            $pendingStmt->bindValue(2, $batchSize, PDO::PARAM_INT);
            $pendingStmt->execute();
            $items = $pendingStmt->fetchAll(PDO::FETCH_ASSOC);

            $results = ['imported' => 0, 'updated' => 0, 'failed' => 0, 'errors' => [], 'processed' => 0];
            $markStmt = $pdo->prepare("UPDATE lead_list_items SET outreach_email = 1, ghl_contact_id = ?, pipeline_stage = CASE WHEN pipeline_stage = 'new' THEN 'contacted' ELSE pipeline_stage END, first_contacted_at = COALESCE(first_contacted_at, NOW()) WHERE id = ? AND user_id = ?");
            $updateItem = $pdo->prepare("UPDATE ghl_import_items SET status = ?, ghl_contact_id = ?, is_new = ?, error_message = ? WHERE id = ?");

            foreach ($items as $item) {
                $lead = json_decode($item['lead_data'], true);
                $contactData = [
                    'locationId' => $locationId,
                    'firstName' => $lead['firstName'] ?? '',
                    'lastName' => $lead['lastName'] ?? '',
                    'companyName' => $lead['companyName'] ?? '',
                    'email' => $lead['email'] ?? '',
                    'phone' => $lead['phone'] ?? '',
                    'website' => $lead['website'] ?? '',
                    'address1' => $lead['address'] ?? '',
                    'city' => $lead['city'] ?? '',
                    'state' => $lead['state'] ?? '',
                    'tags' => !empty($tags) ? $tags : [],
                    'source' => 'Lead Lists CRM'
                ];
                foreach (['firstName','lastName','companyName','email','phone','website','address1','city','state'] as $k) {
                    if (empty($contactData[$k])) unset($contactData[$k]);
                }
                if (empty($contactData['tags'])) unset($contactData['tags']);

                $ch = curl_init('https://services.leadconnectorhq.com/contacts/upsert');
                curl_setopt_array($ch, [
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_POST => true,
                    CURLOPT_HTTPHEADER => [
                        'Authorization: Bearer ' . $apiKey,
                        'Version: 2021-07-28',
                        'Content-Type: application/json'
                    ],
                    CURLOPT_POSTFIELDS => json_encode($contactData),
                    CURLOPT_TIMEOUT => 10
                ]);
                $resp = curl_exec($ch);
                $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                curl_close($ch);

                $parsed = json_decode($resp, true);
                $contactId = $parsed['contact']['id'] ?? null;

                if ($code >= 200 && $code < 300 && $contactId) {
                    $isNew = ($parsed['new'] ?? false) === true;
                    if ($isNew) $results['imported']++;
                    else $results['updated']++;

                    $updateItem->execute(['success', $contactId, $isNew ? 1 : 0, null, $item['id']]);

                    if ($workflowId && $contactId) {
                        $wch = curl_init("https://services.leadconnectorhq.com/contacts/{$contactId}/workflow/{$workflowId}");
                        curl_setopt_array($wch, [
                            CURLOPT_RETURNTRANSFER => true,
                            CURLOPT_POST => true,
                            CURLOPT_HTTPHEADER => [
                                'Authorization: Bearer ' . $apiKey,
                                'Version: 2021-07-28',
                                'Content-Type: application/json'
                            ],
                            CURLOPT_POSTFIELDS => '{}',
                            CURLOPT_TIMEOUT => 5
                        ]);
                        curl_exec($wch);
                        curl_close($wch);
                    }

                    if ($item['lead_id']) {
                        $markStmt->execute([$contactId, $item['lead_id'], $userId]);
                    }
                } else {
                    $results['failed']++;
                    $errMsg = $parsed['message'] ?? $parsed['error'] ?? "HTTP $code";
                    $results['errors'][] = ($lead['companyName'] ?? 'Unknown') . ': ' . $errMsg;
                    $updateItem->execute(['failed', null, 0, $errMsg, $item['id']]);
                }

                $results['processed']++;
                usleep(200000);
            }

            $existingErrors = $pdo->prepare("SELECT errors FROM ghl_import_logs WHERE id = ?");
            $existingErrors->execute([$importId]);
            $currentErrors = json_decode($existingErrors->fetchColumn() ?: '[]', true) ?: [];
            $mergedErrors = array_merge($currentErrors, $results['errors']);

            $pdo->prepare("UPDATE ghl_import_logs SET imported = imported + ?, updated = updated + ?, failed = failed + ?, processed = processed + ?, errors = ? WHERE id = ?")->execute([
                $results['imported'], $results['updated'], $results['failed'], $results['processed'],
                json_encode($mergedErrors), $importId
            ]);

            $remainStmt = $pdo->prepare("SELECT COUNT(*) FROM ghl_import_items WHERE import_log_id = ? AND status = 'pending'");
            $remainStmt->execute([$importId]);
            $remaining = (int)$remainStmt->fetchColumn();

            if ($remaining === 0) {
                $pdo->prepare("UPDATE ghl_import_logs SET status = 'completed', completed_at = NOW() WHERE id = ?")->execute([$importId]);
            } elseif ($importLog['drip_enabled']) {
                $tz = new DateTimeZone($importLog['drip_timezone'] ?: 'UTC');
                $next = new DateTime('now', $tz);
                $next->modify('+' . $importLog['drip_interval_minutes'] . ' minutes');
                $next->setTimezone(new DateTimeZone('UTC'));
                $pdo->prepare("UPDATE ghl_import_logs SET status = 'pending', drip_next_batch_at = ? WHERE id = ?")->execute([$next->format('Y-m-d H:i:s'), $importId]);
            }

            $totals = $pdo->prepare("SELECT imported, updated, failed, processed, total_contacts, status FROM ghl_import_logs WHERE id = ?");
            $totals->execute([$importId]);
            $totalsRow = $totals->fetch(PDO::FETCH_ASSOC);

            echo json_encode([
                'success' => true,
                'batch_results' => $results,
                'totals' => $totalsRow,
                'remaining' => $remaining,
                'done' => $remaining === 0
            ]);
            exit;

        case 'ghlGetImportLogs':
            $listId = $_GET['list_id'] ?? $input['list_id'] ?? 0;
            $where = "user_id = ?";
            $params = [$userId];
            if ($listId) { $where .= " AND list_id = ?"; $params[] = $listId; }
            $stmt = $pdo->prepare("SELECT l.*, ll.name as list_name FROM ghl_import_logs l LEFT JOIN lead_lists ll ON l.list_id = ll.id WHERE l.$where ORDER BY l.created_at DESC LIMIT 50");
            $stmt->execute($params);
            $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($logs as &$lg) {
                $lg['tags'] = json_decode($lg['tags'] ?: '[]', true);
                $errRaw = $lg['errors'] ?: '[]';
                $decoded = json_decode($errRaw, true);
                $flat = [];
                if (is_array($decoded)) { foreach ($decoded as $e) { if (is_array($e)) foreach ($e as $ee) $flat[] = $ee; else $flat[] = $e; } }
                $lg['errors'] = $flat;
            }
            echo json_encode(['success' => true, 'logs' => $logs]);
            exit;

        case 'ghlGetImportStatus':
            $importId = $_GET['import_id'] ?? $input['import_id'] ?? 0;
            $log = $pdo->prepare("SELECT * FROM ghl_import_logs WHERE id = ? AND user_id = ?");
            $log->execute([$importId, $userId]);
            $row = $log->fetch(PDO::FETCH_ASSOC);
            if (!$row) { echo json_encode(['success' => false]); exit; }
            $row['tags'] = json_decode($row['tags'] ?: '[]', true);
            $errRaw = $row['errors'] ?: '[]';
            $decoded = json_decode($errRaw, true);
            $flat = [];
            if (is_array($decoded)) { foreach ($decoded as $e) { if (is_array($e)) foreach ($e as $ee) $flat[] = $ee; else $flat[] = $e; } }
            $row['errors'] = $flat;
            echo json_encode(['success' => true, 'log' => $row]);
            exit;

        case 'ghlPauseImport':
            $importId = $input['import_id'] ?? 0;
            $pdo->prepare("UPDATE ghl_import_logs SET status = 'paused' WHERE id = ? AND user_id = ? AND status IN ('running','pending')")->execute([$importId, $userId]);
            echo json_encode(['success' => true]);
            exit;

        case 'ghlResumeImport':
            $importId = $input['import_id'] ?? 0;
            $pdo->prepare("UPDATE ghl_import_logs SET status = 'running' WHERE id = ? AND user_id = ? AND status = 'paused'")->execute([$importId, $userId]);
            echo json_encode(['success' => true]);
            exit;

        case 'ghlCancelImport':
            $importId = $input['import_id'] ?? 0;
            $pdo->prepare("UPDATE ghl_import_logs SET status = 'cancelled', completed_at = NOW() WHERE id = ? AND user_id = ? AND status IN ('running','pending','paused')")->execute([$importId, $userId]);
            $pdo->prepare("UPDATE ghl_import_items SET status = 'skipped' WHERE import_log_id = ? AND status = 'pending'")->execute([$importId]);
            echo json_encode(['success' => true]);
            exit;

        case 'claimShareCredits':
            try {
                $check = $pdo->prepare("SELECT shared_for_credits FROM users WHERE id = ?");
                $check->execute([$userId]);
                if ($check->fetchColumn()) {
                    echo json_encode(['success' => false, 'error' => 'Already claimed']);
                    exit;
                }
                $pdo->prepare("UPDATE users SET credits = credits + 5, shared_for_credits = 1 WHERE id = ?")->execute([$userId]);
                $cr = $pdo->prepare("SELECT credits FROM users WHERE id = ?");
                $cr->execute([$userId]);
                echo json_encode(['success' => true, 'credits' => (int)$cr->fetchColumn()]);
            } catch (Exception $e) {
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            exit;

    }
    exit;
}
?><!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8">
    
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lead Lists</title>
    <link rel="icon" type="image/jpeg" href="/assets/favicon-12x.png?v=202617">
    <?php renderThemeBootstrap(); ?>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <link rel="stylesheet" href="https://unpkg.com/leaflet-draw@1.0.4/dist/leaflet.draw.css">
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script src="https://unpkg.com/leaflet-draw@1.0.4/dist/leaflet.draw.js"></script>
    <?php render_theme_header(); ?>
    <?php renderThemeDarkStyles('leadlists'); ?>
    <?php echo getCategoryIconsJS(); ?>
    <style>
        :root {
            --radius: 16px;
            --radius-sm: 10px;
            --radius-xs: 8px;
            --shadow: 0 2px 12px rgba(0,0,0,0.08);
            --shadow-lg: 0 8px 32px rgba(0,0,0,0.12);
            --transition: 0.2s cubic-bezier(0.25, 0.1, 0.25, 1);
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Inter', 'Helvetica Neue', sans-serif;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 32px 40px;
        }

        /* Header */
        .page-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 32px;
        }

        .page-header h1 {
            font-size: 34px;
            font-weight: 700;
            letter-spacing: -0.5px;
            color: var(--text);
        }

        .page-header .subtitle {
            font-size: 15px;
            color: var(--text-secondary);
            margin-top: 4px;
        }

        .btn {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 10px 20px;
            border-radius: var(--radius-sm);
            font-size: 15px;
            font-weight: 600;
            border: none;
            cursor: pointer;
            transition: all var(--transition);
            text-decoration: none;
        }

        .btn-primary {
            background: var(--accent);
            color: white;
        }
        .btn-primary:hover { background: var(--accent-hover); transform: scale(1.02); }

        .btn-secondary {
            background: rgba(0,0,0,0.05);
            color: var(--text);
        }
        .btn-secondary:hover { background: rgba(0,0,0,0.1); }

        .btn-ghost {
            background: transparent;
            color: var(--accent);
            padding: 8px 12px;
        }
        .btn-ghost:hover { background: var(--accent-light); }

        .btn-danger {
            background: var(--red);
            color: white;
        }
        .btn-danger:hover { opacity: 0.9; }

        .btn-sm {
            padding: 6px 14px;
            font-size: 13px;
            border-radius: var(--radius-xs);
        }

        .btn-icon {
            width: 36px;
            height: 36px;
            padding: 0;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border-radius: 50%;
            border: none;
            cursor: pointer;
            background: rgba(0,0,0,0.04);
            color: var(--text-secondary);
            transition: all var(--transition);
        }
        .btn-icon:hover { background: rgba(0,0,0,0.08); color: var(--text); }

        /* Metrics Overview */
        .metrics-overview {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 16px;
            margin-bottom: 36px;
            margin-top: 28px;
        }

        .metric-card {
            background: var(--card);
            border: 1px solid var(--card-border);
            border-radius: var(--radius-sm);
            padding: 16px 20px;
            display: flex;
            align-items: center;
            gap: 14px;
            transition: all var(--transition);
        }

        .metric-card:hover {
            border-color: rgba(var(--accent-rgb), 0.15);
            transform: translateY(-1px);
            box-shadow: var(--shadow);
        }

        .metric-icon {
            width: 44px;
            height: 44px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            font-size: 18px;
        }

        .metric-content {
            min-width: 0;
        }

        .metric-value {
            font-size: 22px;
            font-weight: 700;
            color: var(--text-primary);
            line-height: 1.2;
            letter-spacing: -0.02em;
        }

        .metric-label {
            font-size: 12px;
            color: var(--text-secondary);
            font-weight: 500;
            margin-top: 2px;
            text-transform: uppercase;
            letter-spacing: 0.3px;
        }

        @media (max-width: 900px) {
            .metrics-overview { grid-template-columns: repeat(2, 1fr); }
        }

        @media (max-width: 540px) {
            .metrics-overview {
                grid-template-columns: repeat(2, minmax(0, 1fr));
                width: 100%;
                max-width: 100%;
                overflow: hidden;
                box-sizing: border-box;
                gap: 10px;
            }
            .metric-card {
                min-width: 0;
                max-width: 100%;
                box-sizing: border-box;
                overflow: hidden;
            }
        }

        /* Folder Grid */
/* Skeleton Folder Cards */
        .skeleton-folder-card {
            background: var(--card);
            border: 1px solid var(--card-border);
            border-radius: var(--radius);
            padding: 24px;
            display: flex;
            flex-direction: column;
            gap: 12px;
            min-height: 160px;
        }
        .sk-icon-wrap { display: flex; margin-bottom: 4px; }
        .sk-block {
            background: linear-gradient(90deg, rgba(var(--accent-rgb),0.06) 25%, rgba(var(--accent-rgb),0.12) 50%, rgba(var(--accent-rgb),0.06) 75%);
            background-size: 200% 100%;
            border-radius: 6px;
            animation: sk-shimmer 1.4s ease-in-out infinite;
        }
        .sk-icon { width: 48px; height: 48px; border-radius: 10px; }
        .sk-title { height: 16px; width: 65%; }
        .sk-desc { height: 12px; width: 90%; }
        .sk-desc-short { width: 55%; }
        @keyframes sk-shimmer {
            0% { background-position: 200% 0; }
            100% { background-position: -200% 0; }
        }

        .folder-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 20px;
            margin-top: 0;
        }

        .folder-card {
            background: var(--card);
            backdrop-filter: var(--glass-blur);
            -webkit-backdrop-filter: var(--glass-blur);
            border: 1px solid var(--card-border);
            border-radius: var(--radius);
            padding: 24px;
            cursor: pointer;
            transition: all var(--transition);
            position: relative;
            overflow: hidden;
        }
        .folder-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-lg);
            border-color: rgba(var(--accent-rgb), 0.2);
        }

        .folder-card.highlight-match {
            border-color: rgba(var(--accent-rgb), 0.4);
            box-shadow: 0 0 0 2px rgba(var(--accent-rgb), 0.1);
        }

        .folder-card.highlight-match::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: var(--accent);
            border-radius: 16px 16px 0 0;
        }

        .main-grid-layout {
            margin-top: 0;
        }

        .category-intel-toggle-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 12px 4px;
            border-bottom: 1px solid var(--card-border);
            margin-bottom: 16px;
        }

        .category-intel-toggle-row button:hover {
            background: var(--accent-light);
        }

        /* Category section visible/hidden */
        #categoryIntelSection.collapsed #categoryIntel {
            display: none;
        }
        #categoryIntelSection.collapsed #toggleCatIcon {
            transform: rotate(180deg);
        }

        /* Create-card (empty-state-in-grid) — looks like a folder-card */
        .create-card {
            background: var(--card);
            border: 2px dashed var(--card-border);
            border-radius: var(--radius);
            padding: 24px;
            cursor: pointer;
            transition: all var(--transition);
            position: relative;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 160px;
            text-align: center;
        }
        .create-card:hover {
            border-color: var(--accent);
            background: var(--accent-light);
            transform: translateY(-2px);
            box-shadow: 0 4px 16px rgba(var(--accent-rgb), 0.12);
        }
        .create-card-icon {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            background: rgba(var(--accent-rgb), 0.1);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 22px;
            color: var(--accent);
            margin-bottom: 12px;
        }
        .create-card-title {
            font-size: 15px;
            font-weight: 700;
            color: var(--text);
            margin-bottom: 6px;
        }
        .create-card-desc {
            font-size: 12px;
            color: var(--text-secondary);
            margin-bottom: 12px;
        }
        .create-card-btn {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: var(--accent);
            color: #fff;
            border: none;
            border-radius: 8px;
            padding: 7px 14px;
            font-size: 12px;
            font-weight: 600;
            font-family: inherit;
            cursor: pointer;
            transition: opacity 0.15s;
        }
        .create-card-btn:hover { opacity: 0.85; }

        .folder-icon {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 22px;
            margin-bottom: 16px;
        }

        .folder-card .name {
            font-size: 17px;
            font-weight: 600;
            margin-bottom: 4px;
            color: var(--text);
        }

        .folder-card .desc {
            font-size: 13px;
            color: var(--text-secondary);
            margin-bottom: 16px;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }

        .folder-card .meta {
            display: flex;
            align-items: center;
            gap: 16px;
            font-size: 13px;
            color: var(--text-secondary);
        }

        .folder-card .meta span {
            display: flex;
            align-items: center;
            gap: 4px;
        }

        .folder-card .score-bar {
            display: flex;
            gap: 8px;
            margin-top: 12px;
        }

        .score-pill {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        .score-pill.cold { background: rgba(var(--accent-rgb), 0.1); color: var(--accent); }
        .score-pill.warm { background: rgba(202,148,42,0.1); color: var(--orange); }
        .score-pill.hot { background: rgba(255,59,48,0.1); color: var(--red); }

        .category-intel {
            margin: 0 0 18px;
            border: 1px solid var(--card-border);
            border-radius: 16px;
            background:
                linear-gradient(135deg, rgba(var(--accent-rgb), 0.10), transparent 34%),
                linear-gradient(180deg, var(--card-bg), var(--card-solid));
            overflow: hidden;
        }

        .category-intel-head {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 18px;
            padding: 18px 18px 12px;
        }

        .category-intel-kicker {
            font-size: 10px;
            font-weight: 800;
            letter-spacing: 0.14em;
            text-transform: uppercase;
            color: var(--accent);
            margin-bottom: 5px;
        }

        .category-intel-title {
            font-size: 20px;
            font-weight: 800;
            color: var(--text-primary);
            line-height: 1.15;
        }

        .category-intel-sub {
            margin-top: 4px;
            color: var(--text-secondary);
            font-size: 13px;
            max-width: 680px;
        }

        .category-intel-score {
            min-width: 108px;
            text-align: right;
        }

        .category-intel-score .num {
            font-size: 28px;
            line-height: 1;
            font-weight: 900;
            color: var(--text-primary);
        }

        .category-intel-score .label {
            margin-top: 4px;
            color: var(--text-tertiary);
            font-size: 10px;
            font-weight: 800;
            letter-spacing: 0.1em;
            text-transform: uppercase;
        }

        .category-card-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            justify-content: space-between;
            gap: 12px;
            padding: 0 18px 18px;
        }

        .category-pilot-card {
            border: 1px solid var(--card-border);
            border-radius: 12px;
            background: rgba(255,255,255,0.03);
            padding: 14px;
            cursor: pointer;
            transition: transform 0.15s, border-color 0.15s, background 0.15s;
            display: flex;
            flex-direction: column;
            gap: 0;
        }

        .category-pilot-card:hover {
            transform: translateY(-2px);
            border-color: var(--accent);
            background: rgba(var(--accent-rgb), 0.06);
        }

        .category-pilot-card.active {
            border-color: var(--accent);
            box-shadow: 0 0 0 1px var(--accent);
        }

        .category-pilot-card-top {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            margin-bottom: 10px;
        }

        .category-pilot-icon {
            width: 40px;
            height: 40px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            flex-shrink: 0;
            background: linear-gradient(135deg, var(--accent), var(--accent-hover));
        }

        .category-pilot-count {
            font-size: 11px;
            font-weight: 800;
            color: var(--text-secondary);
            flex-shrink: 0;
            white-space: nowrap;
        }

        .category-pilot-title {
            font-size: 14px;
            font-weight: 600;
            color: var(--text-primary);
            margin-bottom: 3px;
            flex-shrink: 0;
        }

        .category-pilot-desc {
            font-size: 12px;
            line-height: 1.35;
            color: var(--text-secondary);
        }

        .category-pilot-chips {
            display: flex;
            flex-wrap: wrap;
            gap: 5px;
            margin-top: 10px;
        }

        .category-pilot-chip {
            border-radius: 999px;
            padding: 3px 7px;
            background: rgba(var(--accent-rgb), 0.10);
            color: var(--accent);
            font-size: 10px;
            font-weight: 700;
        }

        .quality-ribbon {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            padding: 4px 8px;
            border-radius: 999px;
            font-size: 10px;
            font-weight: 800;
            letter-spacing: 0.02em;
            text-transform: uppercase;
        }

        .quality-ribbon.hot { background: rgba(255,59,48,0.10); color: var(--red); }
        .quality-ribbon.warm { background: rgba(202,148,42,0.12); color: var(--orange); }
        .quality-ribbon.cold { background: rgba(var(--accent-rgb),0.10); color: var(--accent); }

        .folder-actions {
            position: absolute;
            top: 16px;
            right: 16px;
            display: flex;
            gap: 4px;
            opacity: 0;
            transition: opacity var(--transition);
        }
        .folder-card:hover .folder-actions { opacity: 1; }

        .category-badge { display:inline-flex;align-items:center;gap:4px;padding:3px 8px;border-radius:6px;background:var(--accent-light);color:var(--accent);font-size:10px;font-weight:600;letter-spacing:0.2px; }
        .category-badge i { font-size:9px; }

        .icon-grid-wrap { max-height:280px;overflow:auto;border:1px solid var(--card-border);border-radius:12px;padding:10px;background:var(--bg-secondary); }
        .icon-search-input { width:100%;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;background:var(--card-solid);color:var(--text);font-family:inherit;outline:none;margin-bottom:12px; }
        .icon-color-btn { border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;flex-shrink:0; }
        .icon-color-btn.active { border-color:var(--text-primary); }
        #iconColorPicker { display:flex;flex-wrap:wrap;gap:6px;margin-bottom:4px; }
        #iconGrid { display:grid;grid-template-columns:repeat(6,1fr);gap:6px; }
        .icon-option { width:44px;height:44px;border-radius:10px;border:2px solid var(--card-border);background:var(--card-solid);color:var(--text);cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:16px;transition:all 0.15s; }
        .icon-option:hover { border-color:var(--accent);color:var(--accent);transform:scale(1.1); }
        .icon-option.selected { border-color:var(--accent);color:var(--accent);background:var(--accent-light); }
        .icon-empty-state { text-align:center;padding:24px;color:var(--text-tertiary);font-size:13px; }

        .empty-state {
            text-align: center;
            padding: 80px 40px;
        }

        .empty-state i {
            font-size: 64px;
            color: var(--text-tertiary);
            margin-bottom: 20px;
        }

        .empty-state h3 {
            font-size: 22px;
            font-weight: 600;
            margin-bottom: 8px;
        }

        .empty-state p {
            color: var(--text-secondary);
            font-size: 15px;
            margin-bottom: 24px;
        }

        /* Welcome / First-time empty state */
        .welcome-empty {
            max-width: 640px;
            margin: 0 auto;
            padding: 60px 32px 48px;
            text-align: center;
        }
        .welcome-empty .welcome-icon {
            width: 80px;
            height: 80px;
            margin: 0 auto 24px;
            border-radius: 24px;
            background: linear-gradient(135deg, var(--accent) 0%, var(--accent-hover) 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 8px 32px rgba(var(--accent-rgb), 0.25);
        }
        .welcome-empty .welcome-icon i {
            font-size: 32px;
            color: #fff;
            margin: 0;
        }
        .welcome-empty h2 {
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 8px;
            color: var(--text-primary);
        }
        .welcome-empty .welcome-sub {
            font-size: 16px;
            color: var(--text-secondary);
            line-height: 1.5;
            margin-bottom: 32px;
        }
        .welcome-empty .free-credits-card {
            background: linear-gradient(135deg, rgba(var(--accent-rgb), 0.08) 0%, rgba(var(--accent-rgb), 0.04) 100%);
            border: 1px solid rgba(var(--accent-rgb), 0.12);
            border-radius: 16px;
            padding: 24px 28px;
            margin-bottom: 32px;
            text-align: left;
        }
        .welcome-empty .free-credits-card .fcc-header {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 14px;
        }
        .welcome-empty .free-credits-card .fcc-header i {
            font-size: 18px;
            color: var(--accent);
            margin: 0;
        }
        .welcome-empty .free-credits-card .fcc-header span {
            font-size: 15px;
            font-weight: 700;
            color: var(--accent);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .welcome-empty .free-credits-card .fcc-details {
            display: flex;
            gap: 20px;
        }
        .welcome-empty .free-credits-card .fcc-detail {
            flex: 1;
            background: #fff;
            border-radius: 12px;
            padding: 16px;
            text-align: center;
        }
        .welcome-empty .free-credits-card .fcc-detail .fcc-num {
            font-size: 28px;
            font-weight: 800;
            color: var(--text-primary);
            line-height: 1;
        }
        .welcome-empty .free-credits-card .fcc-detail .fcc-label {
            font-size: 12px;
            color: var(--text-secondary);
            margin-top: 4px;
        }
        .welcome-empty .welcome-cta {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            padding: 14px 36px;
            border-radius: 14px;
            background: linear-gradient(135deg, var(--accent) 0%, var(--accent-hover) 100%);
            color: #fff;
            font-size: 16px;
            font-weight: 600;
            border: none;
            cursor: pointer;
            box-shadow: 0 4px 16px rgba(var(--accent-rgb), 0.3);
            transition: all 0.2s ease;
        }
        .welcome-empty .welcome-cta:hover {
            transform: translateY(-1px);
            box-shadow: 0 6px 24px rgba(var(--accent-rgb), 0.4);
        }
        .welcome-empty .welcome-steps {
            display: flex;
            gap: 16px;
            margin-top: 36px;
            text-align: left;
        }
        .welcome-empty .welcome-step {
            flex: 1;
            padding: 16px;
            border-radius: 12px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
        }
        .welcome-empty .welcome-step .ws-num {
            width: 24px;
            height: 24px;
            border-radius: 8px;
            background: var(--accent);
            color: #fff;
            font-size: 12px;
            font-weight: 700;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 8px;
        }
        .welcome-empty .welcome-step .ws-title {
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 2px;
        }
        .welcome-empty .welcome-step .ws-desc {
            font-size: 11px;
            color: var(--text-secondary);
            line-height: 1.4;
        }

        /* Visual cue pulse animation */
        @keyframes cue-pulse {
            0% { box-shadow: 0 0 0 0 rgba(var(--accent-rgb), 0.5); }
            70% { box-shadow: 0 0 0 12px rgba(var(--accent-rgb), 0); }
            100% { box-shadow: 0 0 0 0 rgba(var(--accent-rgb), 0); }
        }
        .pulse-cue {
            animation: cue-pulse 1.8s ease-in-out infinite;
        }

        /* Detail View */
        .detail-header {
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 24px;
        }

        .back-btn {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            border: none;
            background: rgba(0,0,0,0.05);
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all var(--transition);
            font-size: 18px;
            color: var(--text);
        }
        .back-btn:hover { background: rgba(0,0,0,0.1); }

        .detail-title {
            flex: 1;
        }

        .detail-title h1 {
            font-size: 28px;
            font-weight: 700;
            letter-spacing: -0.3px;
        }

        .detail-title .detail-sub {
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 2px;
        }

        /* Collapsible card pattern for Map View and Searched Areas */
        .collapsible-card {
            margin-bottom: 20px;
            background: var(--card-solid);
            border: 1px solid var(--card-border);
            border-radius: var(--radius);
            overflow: hidden;
        }
        .collapsible-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 14px 20px;
            border-bottom: 1px solid var(--card-border);
            cursor: pointer;
            user-select: none;
            transition: background 150ms;
        }
        .collapsible-header:hover { background: rgba(0,0,0,0.02); }
        .collapsible-header .ch-title {
            font-weight: 600;
            font-size: 14px;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .collapsible-header .ch-title i { color: var(--accent); }
        .collapsible-header .ch-meta {
            font-size: 12px;
            color: var(--text-tertiary);
            margin-right: 12px;
        }
        .collapsible-header .ch-toggle {
            background: none;
            border: none;
            cursor: pointer;
            font-size: 14px;
            color: var(--text-tertiary);
            padding: 4px;
            transition: transform 200ms;
        }
        .collapsible-header .ch-toggle.collapsed { transform: rotate(-90deg); }

        .collapsible-content {
            overflow: hidden;
            transition: max-height 250ms ease;
        }
        .collapsible-content.collapsed { max-height: 0; }
        .collapsible-content.expanded { max-height: 2000px; }


        /* Detail view: desktop default - sections expanded when detail-view-expanded is present */
        .detail-view-expanded .collapsible-content:not(.collapsed) { max-height: none; }

        /* Stats Row */
        .stats-row {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
            gap: 12px;
            margin-bottom: 24px;
        }

        .stat-card {
            background: var(--card);
            backdrop-filter: var(--glass-blur);
            -webkit-backdrop-filter: var(--glass-blur);
            border: 1px solid var(--card-border);
            border-radius: var(--radius-sm);
            padding: 16px;
            text-align: center;
        }

        .stat-card.clickable {
            cursor: pointer;
            transition: all var(--transition);
        }
        .stat-card.clickable:hover {
            transform: translateY(-1px);
            box-shadow: var(--shadow);
        }
        .stat-card.clickable.active-filter {
            border-color: var(--accent);
            box-shadow: 0 0 0 2px rgba(var(--accent-rgb), 0.15);
        }

        .stat-card .stat-value {
            font-size: 28px;
            font-weight: 700;
            letter-spacing: -0.5px;
        }

        .stat-card .stat-label {
            font-size: 12px;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-top: 2px;
        }

        .stat-card.accent .stat-value { color: var(--accent); }
        .stat-card.green .stat-value { color: var(--green); }
        .stat-card.orange .stat-value { color: var(--orange); }
        .stat-card.red .stat-value { color: var(--red); }

        /* Toolbar */
        .toolbar {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;
            flex-wrap: wrap;
        }

        /* Hide Cities toggle pill */
        .toggle-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 5px 12px;
            border-radius: 999px;
            border: 1px solid var(--card-border);
            background: var(--bg);
            color: var(--text-secondary);
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            white-space: nowrap;
            transition: all 0.15s;
            font-family: inherit;
        }
        .toggle-pill:hover {
            background: var(--bg-secondary);
            border-color: var(--accent);
            color: var(--accent);
        }
        .toggle-pill.active {
            background: rgba(var(--accent-rgb), 0.08);
            border-color: var(--accent);
            color: var(--accent);
        }

        /* Hide city column when toggle is active */
        .leads-table.cities-hidden th:nth-child(3),
        .leads-table.cities-hidden td:nth-child(3) {
            display: none;
        }
        .ghl-spreadsheet.cities-hidden th:nth-child(7),
        .ghl-spreadsheet.cities-hidden td:nth-child(7),
        .ghl-spreadsheet.cities-hidden th:nth-child(8),
        .ghl-spreadsheet.cities-hidden td:nth-child(8) {
            display: none;
        }

        .search-box {
            flex: 1;
            min-width: 240px;
            position: relative;
        }

        .search-box i {
            position: absolute;
            left: 14px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-tertiary);
            font-size: 14px;
        }

        .search-box input {
            width: 100%;
            padding: 10px 14px 10px 40px;
            border-radius: var(--radius-sm);
            border: 1px solid var(--card-border);
            background: var(--card-solid);
            font-size: 15px;
            font-family: inherit;
            outline: none;
            transition: border-color var(--transition);
        }
        .search-box input:focus { border-color: var(--accent); }

        .filter-pills {
            display: flex;
            gap: 4px;
            background: rgba(0,0,0,0.04);
            padding: 3px;
            border-radius: var(--radius-xs);
        }

        .filter-pill {
            padding: 6px 14px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 500;
            border: none;
            cursor: pointer;
            background: transparent;
            color: var(--text-secondary);
            transition: all var(--transition);
        }
        .filter-pill.active {
            background: var(--card-solid);
            color: var(--text);
            box-shadow: 0 1px 4px rgba(0,0,0,0.08);
        }

        /* List Map */
        #listMap { z-index:1; }
        .leaflet-draw-toolbar a { background-color:#fff !important; }
        .leaflet-draw-toolbar a:hover { background-color:#f0f0f0 !important; }

        /* Leads Table */
        .leads-table-wrap {
            background: var(--card);
            backdrop-filter: var(--glass-blur);
            -webkit-backdrop-filter: var(--glass-blur);
            border: 1px solid var(--card-border);
            border-radius: var(--radius);
            overflow: hidden;
        }

        .leads-table {
            width: 100%;
            border-collapse: collapse;
        }

        .leads-table th {
            text-align: left;
            padding: 12px 16px;
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            border-bottom: 1px solid var(--card-border);
            background: rgba(0,0,0,0.02);
            white-space: nowrap;
        }

        .leads-table td {
            padding: 12px 16px;
            font-size: 14px;
            border-bottom: 1px solid rgba(0,0,0,0.03);
            vertical-align: middle;
        }

        .leads-table tr:last-child td { border-bottom: none; }

        .leads-table tbody tr {
            transition: background var(--transition);
        }
        .leads-table tbody tr:hover { background: rgba(var(--accent-rgb), 0.03); }

        .lead-name {
            font-weight: 600;
            color: var(--text);
            max-width: 220px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .lead-location {
            font-size: 13px;
            color: var(--text-secondary);
        }

        .lead-contact-icons {
            display: flex;
            gap: 6px;
        }

        .contact-icon {
            width: 28px;
            height: 28px;
            border-radius: 6px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            cursor: pointer;
            transition: all var(--transition);
            border: none;
        }

        .contact-icon.has { background: rgba(var(--accent-rgb), 0.1); color: var(--accent); }
        .contact-icon.has:hover { background: rgba(var(--accent-rgb), 0.2); }
        .contact-icon.none { background: rgba(0,0,0,0.04); color: var(--text-tertiary); }
        .contact-icon.tracked { background: rgba(52,199,89,0.15); color: var(--green); }

        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
        }

        .status-badge.cold { background: rgba(var(--accent-rgb), 0.08); color: var(--accent); }
        .status-badge.warm { background: rgba(202,148,42,0.1); color: var(--orange); }
        .status-badge.hot { background: rgba(255,59,48,0.1); color: var(--red); }

        .score-pill {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 34px;
            padding: 3px 7px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 700;
            cursor: default;
        }
        .score-pill.cold { background: rgba(var(--accent-rgb), 0.10); color: var(--accent); }
        .score-pill.warm { background: rgba(202,148,42,0.12); color: var(--orange); }
        .score-pill.hot  { background: rgba(255,59,48,0.10); color: var(--red); }

        /* Pagination */
        .pagination {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 4px;
            padding: 20px 16px;
        }

        .page-btn {
            min-width: 36px;
            height: 36px;
            padding: 0 8px;
            border-radius: var(--radius-xs);
            border: none;
            background: transparent;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            color: var(--text-secondary);
            transition: all var(--transition);
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .page-btn:hover { background: rgba(0,0,0,0.05); }
        .page-btn.active { background: var(--accent); color: white; }
        .page-btn:disabled { opacity: 0.3; cursor: default; }

        /* Modal */
        .modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.4);
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            z-index: 1000;
            display: none;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .modal-overlay.active { display: flex; }

        .modal {
            background: var(--card-solid);
            border-radius: 20px;
            width: 100%;
            max-width: 640px;
            max-height: 90vh;
            overflow: hidden;
            box-shadow: var(--shadow-lg);
            display: flex;
            flex-direction: column;
            margin: auto !important;
        }
        .modal.wide { max-width: 85vw; height: 85vh; }

        .modal-header {
            padding: 24px 24px 0;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-shrink: 0;
            width: 100%;
        }

        .modal-header h2 {
            font-size: 22px;
            font-weight: 700;
        }

        .modal-body {
            padding: 20px 24px;
            overflow-y: auto;
            flex: 1;
            min-height: 0;
        }

        .modal-footer {
            padding: 16px 24px;
            border-top: 1px solid var(--card-border);
            display: flex;
            justify-content: flex-end;
            gap: 12px;
            flex-shrink: 0;
            width: 100%;
        }

        .import-summary-grid {
            display: grid;
            grid-template-columns: repeat(3, minmax(0, 1fr));
            gap: 12px;
            margin-bottom: 14px;
        }

        .import-summary-card {
            padding: 14px 16px;
            background: var(--bg);
            border: 1px solid var(--card-border);
            border-radius: var(--radius-xs);
            min-width: 0;
        }

        .import-summary-label {
            font-size: 11px;
            color: var(--text-secondary);
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }

        .import-summary-value {
            font-size: 18px;
            font-weight: 800;
            color: var(--text);
            margin-top: 6px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .import-note {
            color: var(--text-secondary);
            font-size: 13px;
            margin-bottom: 14px;
        }

        .import-preview-table-wrap {
            max-height: 46vh;
            overflow: auto;
            border: 1px solid var(--card-border);
            border-radius: var(--radius-xs);
            background: var(--card-solid);
        }

        .import-preview-table {
            width: 100%;
            min-width: 760px;
            border-collapse: collapse;
            font-size: 13px;
        }

        .import-preview-table th {
            position: sticky;
            top: 0;
            z-index: 1;
            background: var(--bg);
            color: var(--text-secondary);
            text-align: left;
            font-size: 11px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            border-bottom: 1px solid var(--card-border);
            padding: 10px 12px;
            white-space: nowrap;
        }

        .import-preview-table td {
            padding: 9px 12px;
            border-bottom: 1px solid var(--card-border);
            max-width: 260px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            color: var(--text);
        }

        .import-status {
            margin-top: 14px;
            padding: 14px 16px;
            border-radius: var(--radius-xs);
            border: 1px solid var(--card-border);
            background: var(--bg);
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .import-status.success {
            background: rgba(52, 199, 89, 0.12);
            border-color: rgba(52, 199, 89, 0.35);
            color: var(--green);
        }

        .import-status.error {
            background: rgba(255, 59, 48, 0.12);
            border-color: rgba(255, 59, 48, 0.35);
            color: var(--red);
        }

        .import-spinner {
            width: 22px;
            height: 22px;
            border: 2px solid var(--card-border);
            border-top-color: var(--accent);
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            flex-shrink: 0;
        }

        @media (max-width: 768px) {
            .import-summary-grid { grid-template-columns: 1fr; }
            .import-preview-table-wrap { max-height: 42vh; }
        }

        /* Form Elements */
        .form-group {
            margin-bottom: 16px;
        }

        .form-group label {
            display: block;
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 6px;
            color: var(--text);
        }

        .form-group input,
        .form-group textarea,
        .form-group select {
            width: 100%;
            padding: 10px 14px;
            border: 1px solid var(--card-border);
            border-radius: var(--radius-xs);
            font-size: 15px;
            font-family: inherit;
            background: var(--bg);
            outline: none;
            transition: border-color var(--transition);
        }
        .form-group input:focus,
        .form-group textarea:focus,
        .form-group select:focus { border-color: var(--accent); }

        .form-group textarea { resize: vertical; min-height: 80px; }

        /* Country Picker */
        .country-pick {
            flex: 1;
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 12px 16px;
            border: 2px solid var(--card-border);
            border-radius: var(--radius-sm);
            background: var(--card-bg);
            cursor: pointer;
            font-family: inherit;
            transition: all 0.15s;
        }
        .country-pick:hover { border-color: var(--accent); background: rgba(var(--accent-rgb), 0.03); }
        .country-pick.active { border-color: var(--accent); background: rgba(var(--accent-rgb), 0.06); box-shadow: 0 0 0 1px var(--accent); }
        .country-pick-label { font-size: 14px; font-weight: 600; color: var(--text-primary); }
        .country-pick.active .country-pick-label { color: var(--accent); }

        /* State/City Selector */
        .selector-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            margin-top: 12px;
        }

        .selector-panel {
            border: 1px solid var(--card-border);
            border-radius: var(--radius-sm);
            overflow: hidden;
            max-height: 280px;
            display: flex;
            flex-direction: column;
        }

        .selector-header {
            padding: 10px 14px;
            background: rgba(0,0,0,0.02);
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-size: 13px;
            font-weight: 600;
        }

        .selector-list {
            overflow-y: auto;
            padding: 8px;
            flex: 1;
        }

        .selector-item {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 6px 8px;
            border-radius: 6px;
            font-size: 14px;
            cursor: pointer;
            transition: background var(--transition);
        }
        .selector-item:hover { background: rgba(0,0,0,0.03); }

        .selector-item input[type="checkbox"] {
            width: 16px;
            height: 16px;
            accent-color: var(--accent);
        }

        .selector-item .searched-badge {
            margin-left: auto;
            font-size: 10px;
            padding: 2px 6px;
            border-radius: 4px;
            background: rgba(52,199,89,0.1);
            color: var(--green);
            font-weight: 600;
        }
        .city-filter-pill {
            font-size: 11px;
            padding: 3px 8px;
            border-radius: 6px;
            border: 1px solid var(--card-border);
            background: var(--bg);
            color: var(--text-secondary);
            cursor: pointer;
            font-family: inherit;
            font-weight: 500;
            transition: all 0.15s;
        }
        .city-filter-pill.active {
            background: var(--accent);
            color: #fff;
            border-color: var(--accent);
        }

        /* Progress */
        .progress-container {
            margin-top: 16px;
        }

        .progress-bar-bg {
            width: 100%;
            height: 6px;
            border-radius: 3px;
            background: rgba(0,0,0,0.06);
            overflow: hidden;
        }

        .progress-bar-fill {
            height: 100%;
            border-radius: 3px;
            background: var(--accent);
            transition: width 0.3s ease;
            width: 0%;
        }

        .progress-text {
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 8px;
            display: flex;
            justify-content: space-between;
        }

        /* Lead Detail Slide */
        .slide-panel {
            position: fixed;
            right: -110%;
            top: 0;
            bottom: 0;
            width: 480px;
            max-width: 100vw;
            background: var(--card-solid);
            box-shadow: -4px 0 32px rgba(0,0,0,0.12);
            z-index: 1001;
            transition: right 0.3s cubic-bezier(0.25, 0.1, 0.25, 1);
            display: flex;
            flex-direction: column;
        }
        .slide-panel.open { right: 0; }

        .slide-backdrop {
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.3);
            z-index: 1000;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.3s ease;
        }
        .slide-backdrop.open { opacity: 1; pointer-events: auto; }

        .slide-header {
            padding: 24px;
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
        }

        .slide-body {
            flex: 1;
            overflow-y: auto;
            padding: 24px;
        }

        .slide-section {
            margin-bottom: 24px;
        }

        .slide-section-title {
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-secondary);
            margin-bottom: 10px;
        }

        .info-row {
            display: flex;
            align-items: flex-start;
            gap: 10px;
            padding: 8px 0;
            font-size: 14px;
        }

        .info-row i {
            width: 20px;
            text-align: center;
            color: var(--text-secondary);
            margin-top: 2px;
        }

        .info-row a {
            color: var(--accent);
            text-decoration: none;
        }
        .info-row a:hover { text-decoration: underline; }

        .tracking-toggles {
            display: flex;
            flex-direction: column;
            gap: 10px;
        }

        .tracking-toggle {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 12px 14px;
            background: var(--bg);
            border-radius: var(--radius-xs);
        }

        .tracking-toggle-label {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 14px;
            font-weight: 500;
        }

        .toggle-switch {
            position: relative;
            width: 48px;
            height: 28px;
        }

        .toggle-switch input { opacity: 0; width: 0; height: 0; }

        .toggle-slider {
            position: absolute;
            inset: 0;
            background: var(--bg-secondary);
            border-radius: 14px;
            cursor: pointer;
            transition: background var(--transition);
        }

        .toggle-slider::before {
            content: '';
            position: absolute;
            width: 22px;
            height: 22px;
            border-radius: 50%;
            background: white;
            bottom: 3px;
            left: 3px;
            transition: transform var(--transition);
            box-shadow: 0 1px 3px rgba(0,0,0,0.15);
        }

        .toggle-switch input:checked + .toggle-slider { background: var(--green); }
        .toggle-switch input:checked + .toggle-slider::before { transform: translateX(20px); }

        .notes-area {
            width: 100%;
            min-height: 100px;
            padding: 12px;
            border: 1px solid var(--card-border);
            border-radius: var(--radius-xs);
            font-size: 14px;
            font-family: inherit;
            resize: vertical;
            outline: none;
            background: var(--bg);
        }
        .notes-area:focus { border-color: var(--accent); }

        /* Toast — theme-aware surface, type-accented left border.
           Previous version used var(--text) as bg with white text, which is
           invisible in dark mode (light bg + white text). Now uses card-solid
           surface + theme text color, plus a colored left accent for type. */
        .toast {
            position: fixed;
            bottom: 24px;
            left: 50%;
            transform: translateX(-50%) translateY(100px);
            background: var(--card-solid);
            color: var(--text);
            padding: 12px 22px 12px 18px;
            border-radius: var(--radius-sm);
            border: 1px solid var(--card-border);
            border-left: 4px solid var(--accent);
            font-size: 14px;
            font-weight: 500;
            z-index: 2147483600;  /* above .modal-overlay (2001 mobile, 1000 desktop) */
            transition: transform 0.3s ease, opacity 0.3s ease;
            box-shadow: var(--shadow-lg);
            opacity: 0;
            pointer-events: none;
            max-width: 92vw;
            text-align: center;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .toast.show { transform: translateX(-50%) translateY(0); opacity: 1; }
        .toast.toast-success { border-left-color: #22c55e; }
        .toast.toast-error { border-left-color: #ef4444; }
        .toast.toast-warn, .toast.toast-warning { border-left-color: #f59e0b; }
        .toast.toast-info { border-left-color: var(--accent); }
        .toast .toast-icon { font-size: 16px; flex-shrink: 0; opacity: 0.85; }

        /* Checkbox */
        .checkbox-wrap input[type="checkbox"] {
            width: 18px;
            height: 18px;
            accent-color: var(--accent);
            cursor: pointer;
        }

        /* Scrollbar */
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.15); border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: rgba(0,0,0,0.25); }

        .hidden { display: none !important; }

        /* Pipeline stage badges */
        .pipeline-badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
            cursor: pointer;
            white-space: nowrap;
            transition: all var(--transition);
        }
        .pipeline-badge:hover { filter: brightness(0.95); }
        .pipeline-badge.stage-new { background: rgba(0,0,0,0.05); color: var(--text-secondary); }
        .pipeline-badge.stage-contacted { background: rgba(var(--accent-rgb), 0.1); color: var(--accent); }
        .pipeline-badge.stage-engaged { background: rgba(202,148,42,0.1); color: var(--orange); }
        .pipeline-badge.stage-client { background: rgba(52,199,89,0.12); color: var(--green); }
        .pipeline-badge.stage-no_response { background: rgba(255,59,48,0.08); color: var(--red); }

        /* Follow-up counter */
        .followup-counter {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
        }
        .followup-counter .count { min-width: 18px; text-align: center; }
        .followup-btn {
            width: 22px;
            height: 22px;
            border-radius: 50%;
            border: 1px solid var(--card-border);
            background: var(--card-solid);
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 10px;
            color: var(--text-secondary);
            transition: all var(--transition);
        }
        .followup-btn:hover { background: var(--accent-light); color: var(--accent); border-color: var(--accent); }

        /* Outreach icons in table */
        .outreach-icons {
            display: flex;
            gap: 4px;
            align-items: center;
        }
        .outreach-icon {
            width: 26px;
            height: 26px;
            border-radius: 6px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 11px;
            cursor: pointer;
            transition: all var(--transition);
            border: none;
        }
        .outreach-icon.done { background: rgba(52,199,89,0.15); color: var(--green); }
        .outreach-icon.not-done { background: rgba(0,0,0,0.04); color: var(--text-tertiary); }
        .outreach-icon.not-done:hover { background: rgba(0,0,0,0.08); }

        .enrich-dot {
            position: absolute;
            bottom: -2px;
            right: -2px;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            border: 1.5px solid #fff;
        }
        .enrich-done { background: var(--green); }
        .enrich-working { background: var(--purple); animation: enrich-pulse 1s ease-in-out infinite; }
        .enrich-queued { background: var(--orange); }
        .enrich-fail { background: var(--red); }
        .enrich-waiting { background: var(--text-tertiary); opacity: 0.5; }
        @keyframes enrich-pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }

        .admin-reenrich-btn {
            background: linear-gradient(135deg, #FF3B30, #FF2D55) !important;
            color: #fff !important;
            border: none !important;
            font-size: 12px;
            padding: 6px 14px;
            font-weight: 600;
        }
        .admin-reenrich-btn:hover { opacity: 0.9; }

        #adminEnrichPanel {
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: linear-gradient(135deg, #1a1a2e, #16213e);
            color: #fff;
            border-radius: 16px;
            padding: 16px 24px;
            box-shadow: 0 12px 40px rgba(0,0,0,0.3);
            z-index: 99999;
            min-width: 380px;
            font-family: inherit;
            font-size: 13px;
        }
        #adminEnrichPanel .aep-header {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 10px;
            font-weight: 700;
            font-size: 14px;
        }
        #adminEnrichPanel .aep-header i { color: #FF2D55; }
        #adminEnrichPanel .aep-bar {
            height: 6px;
            background: rgba(255,255,255,0.15);
            border-radius: 99px;
            overflow: hidden;
            margin-bottom: 8px;
        }
        #adminEnrichPanel .aep-fill {
            height: 100%;
            background: linear-gradient(90deg, #FF3B30, #FF2D55, var(--accent));
            border-radius: 99px;
            width: 0%;
            transition: width 0.4s ease;
        }
        #adminEnrichPanel .aep-stats {
            display: flex;
            gap: 16px;
            font-size: 11px;
            color: rgba(255,255,255,0.7);
        }
        #adminEnrichPanel .aep-stats span { white-space: nowrap; }
        #adminEnrichPanel .aep-stats .num { color: #fff; font-weight: 700; }

        /* GHL Export Full Screen */
        .ghl-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.5);
            z-index: 10000;
            justify-content: center;
            align-items: center;
        }
        .ghl-overlay.active { display: flex; }
        .ghl-panel {
            width: 92vw; height: 90vh;
            background: var(--card-solid);
            border-radius: 16px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            box-shadow: 0 24px 80px rgba(0,0,0,0.25);
            position: relative;
        }
        .ghl-panel-header {
            padding: 14px 20px;
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-shrink: 0;
        }
        .ghl-screen { flex: 1; overflow-y: auto; position: relative; }
        .ghl-toolbar {
            padding: 10px 20px;
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 8px;
            flex-shrink: 0;
        }
        .ghl-spreadsheet-wrap {
            flex: 1;
            overflow: auto;
            padding: 0;
        }
        .ghl-spreadsheet {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        .ghl-spreadsheet th {
            padding: 8px 10px;
            text-align: left;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-tertiary);
            background: var(--bg);
            border-bottom: 2px solid var(--card-border);
            position: sticky;
            top: 0;
            z-index: 2;
            white-space: nowrap;
        }
        .ghl-spreadsheet td {
            padding: 4px 6px;
            border-bottom: 1px solid rgba(0,0,0,0.04);
            vertical-align: middle;
        }
        .ghl-spreadsheet tbody tr:hover { background: rgba(var(--accent-rgb), 0.03); }
        .ghl-spreadsheet .ghl-cell-input {
            width: 100%;
            padding: 6px 8px;
            border: 1px solid transparent;
            border-radius: 4px;
            font-size: 13px;
            font-family: inherit;
            background: transparent;
            outline: none;
            transition: border-color 0.15s, background 0.15s;
        }
        .ghl-spreadsheet .ghl-cell-input:hover { background: var(--bg); }
        .ghl-spreadsheet .ghl-cell-input:focus {
            border-color: var(--accent);
            background: #fff;
            box-shadow: 0 0 0 2px rgba(var(--accent-rgb), 0.15);
        }
        .ghl-spreadsheet .ghl-email-cell {
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .ghl-spreadsheet .ghl-email-select {
            flex: 1;
            padding: 6px 8px;
            border: 1px solid transparent;
            border-radius: 4px;
            font-size: 13px;
            font-family: inherit;
            background: transparent;
            outline: none;
            cursor: pointer;
        }
        .ghl-spreadsheet .ghl-email-select:hover { background: var(--bg); }
        .ghl-spreadsheet .ghl-email-select:focus { border-color: var(--accent); background: #fff; }
        .ghl-bottom-bar {
            padding: 12px 20px;
            border-top: 1px solid var(--card-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-shrink: 0;
            gap: 16px;
            flex-wrap: wrap;
            background: var(--bg);
        }
        .ghl-config-section {
            display: flex;
            gap: 20px;
            align-items: center;
            flex-wrap: wrap;
        }
        .ghl-config-group { display: flex; align-items: center; gap: 8px; }
        .ghl-config-group label {
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
            white-space: nowrap;
        }
        .ghl-dropdown {
            position: absolute;
            bottom: 100%;
            left: 0;
            right: 0;
            background: var(--card-solid);
            border: 1px solid var(--card-border);
            border-radius: 8px;
            box-shadow: var(--shadow-lg);
            max-height: 200px;
            overflow-y: auto;
            z-index: 10;
            margin-bottom: 4px;
            min-width: 200px;
        }
        .ghl-dropdown .ghl-tag-option {
            padding: 8px 12px;
            font-size: 12px;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .ghl-dropdown .ghl-tag-option:hover { background: var(--bg); }
        .ghl-tag-chip {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 8px;
            border-radius: 99px;
            font-size: 11px;
            font-weight: 600;
            background: var(--accent);
            color: #fff;
        }
        .ghl-tag-chip button {
            background: none;
            border: none;
            color: rgba(255,255,255,0.7);
            cursor: pointer;
            padding: 0;
            font-size: 10px;
            line-height: 1;
        }
        .ghl-tag-chip button:hover { color: #fff; }
        .ghl-settings-slide {
            position: absolute;
            top: 0; right: 0; bottom: 0;
            width: 360px;
            background: var(--card-solid);
            border-left: 1px solid var(--card-border);
            box-shadow: -8px 0 30px rgba(0,0,0,0.1);
            z-index: 20;
            overflow-y: auto;
        }
        .ghl-log-card {
            background: var(--bg);
            border: 1px solid var(--card-border);
            border-radius: 10px;
            padding: 14px;
            margin-bottom: 10px;
            cursor: pointer;
            transition: border-color 0.15s;
        }
        .ghl-log-card:hover { border-color: var(--accent); }
        .ghl-log-status {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 8px;
            border-radius: 99px;
            font-size: 10px;
            font-weight: 700;
            text-transform: uppercase;
        }
        .ghl-log-status.running { background: #DBEAFE; color: #1E40AF; }
        .ghl-log-status.completed { background: #DCFCE7; color: #166534; }
        .ghl-log-status.failed { background: #FEE2E2; color: #991B1B; }
        .ghl-log-status.cancelled { background: #F3F4F6; color: #6B7280; }
        .ghl-log-status.paused { background: #FEF3C7; color: #92400E; }
        .ghl-log-status.pending { background: #EDE9FE; color: #5B21B6; }
        .ghl-log-progress {
            height: 4px;
            background: var(--card-border);
            border-radius: 99px;
            overflow: hidden;
            margin-top: 8px;
        }
        .ghl-log-progress-bar {
            height: 100%;
            border-radius: 99px;
            background: var(--accent);
            transition: width 0.3s;
        }
        .ghl-socials-cell { display: flex; gap: 3px; flex-wrap: wrap; }
        .ghl-socials-cell a {
            width: 22px; height: 22px;
            display: flex; align-items: center; justify-content: center;
            border-radius: 4px;
            font-size: 10px;
            color: var(--text-secondary);
            background: var(--bg);
            text-decoration: none;
        }
        .ghl-socials-cell a:hover { color: var(--accent); background: rgba(var(--accent-rgb), 0.1); }
        #ghlEditorScreen { display: flex; flex-direction: column; overflow: hidden; }
        @keyframes spin { to { transform: rotate(360deg); } }

        /* Make leads table scroll horizontally */
        .leads-table-wrap { overflow-x: auto; }

        /* Pipeline stats section */
        /* Pipeline visual funnel */
        .pipeline-funnel {
            display: flex;
            align-items: stretch;
            margin-bottom: 16px;
            background: var(--card);
            border: 1px solid var(--card-border);
            border-radius: var(--radius-sm);
            overflow: hidden;
        }
        .pipeline-funnel-stage {
            flex: 1;
            padding: 14px 10px;
            text-align: center;
            cursor: pointer;
            transition: all var(--transition);
            position: relative;
            min-width: 0;
        }
        .pipeline-funnel-stage:not(:last-child)::after {
            content: '';
            position: absolute;
            right: 0;
            top: 20%;
            height: 60%;
            width: 1px;
            background: var(--card-border);
        }
        .pipeline-funnel-stage:hover { background: rgba(0,0,0,0.02); }
        .pipeline-funnel-stage.active-filter { background: rgba(var(--accent-rgb), 0.05); box-shadow: inset 0 -3px 0 var(--accent); }
        .pipeline-funnel-stage .pf-count { font-size: 20px; font-weight: 700; line-height: 1; }
        .pipeline-funnel-stage .pf-label { font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-secondary); margin-top: 4px; }
        .pipeline-funnel-stage .pf-bar { height: 4px; border-radius: 2px; margin-top: 8px; transition: width 0.4s ease; }
        .pipeline-funnel-arrow {
            display: flex;
            align-items: center;
            color: var(--text-tertiary);
            font-size: 10px;
            padding: 0 2px;
            flex-shrink: 0;
        }

        /* Email popover tooltip */
        .email-popover {
            position: absolute;
            z-index: 100;
            background: var(--card-solid);
            border: 1px solid var(--card-border);
            border-radius: var(--radius-xs);
            box-shadow: var(--shadow-lg);
            padding: 6px;
            min-width: 220px;
            max-width: 320px;
        }
        .email-popover-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 8px;
            padding: 7px 10px;
            border-radius: 6px;
            transition: background 0.12s;
        }
        .email-popover-item:hover { background: var(--accent-light); }
        .email-popover-item .ep-email {
            font-size: 13px;
            color: var(--text);
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            min-width: 0;
            flex: 1;
        }
        .email-popover-item .ep-actions {
            display: flex;
            gap: 4px;
            flex-shrink: 0;
        }
        .email-popover-item .ep-btn {
            width: 26px;
            height: 26px;
            border-radius: 6px;
            border: none;
            background: transparent;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 11px;
            color: var(--text-tertiary);
            transition: all 0.12s;
        }
        .email-popover-item .ep-btn:hover { background: var(--accent); color: white; }

        /* Note popover */
        .note-popover {
            position: absolute;
            z-index: 100;
            background: var(--card-solid);
            border: 1px solid var(--card-border);
            border-radius: var(--radius-sm);
            box-shadow: var(--shadow-lg);
            width: 300px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }
        .note-popover-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 14px;
            border-bottom: 1px solid var(--card-border);
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
        }
        .note-popover textarea {
            width: 100%;
            border: none;
            outline: none;
            padding: 12px 14px;
            font-size: 13px;
            font-family: inherit;
            resize: none;
            min-height: 100px;
            background: transparent;
            color: var(--text);
        }
        .note-popover-footer {
            display: flex;
            justify-content: flex-end;
            padding: 8px 10px;
            border-top: 1px solid var(--card-border);
            gap: 6px;
        }

        /* Pipeline select dropdown in slide panel */
        .pipeline-select {
            padding: 8px 12px;
            border: 1px solid var(--card-border);
            border-radius: var(--radius-xs);
            font-size: 14px;
            font-family: inherit;
            font-weight: 600;
            background: var(--bg);
            outline: none;
            cursor: pointer;
            width: 100%;
        }
        .pipeline-select:focus { border-color: var(--accent); }

        /* Credits badge */
        .credits-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 14px;
            border-radius: 20px;
            background: rgba(var(--accent-rgb), 0.08);
            color: var(--accent);
            font-size: 13px;
            font-weight: 600;
        }

        /* Searched States summary */
        .searched-summary {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
            margin-top: 8px;
        }

        .searched-tag {
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 500;
            background: rgba(0,0,0,0.04);
            color: var(--text-secondary);
        }

        /* Website Preview Window */
        .web-preview-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.5);
            backdrop-filter: blur(6px);
            -webkit-backdrop-filter: blur(6px);
            z-index: 2000;
            display: flex;
            align-items: center;
            justify-content: center;
            animation: fadeInOverlay 0.2s ease;
        }
        @keyframes fadeInOverlay {
            from { opacity: 0; }
            to { opacity: 1; }
        }

        .web-preview-window {
            width: 85%;
            height: 85%;
            background: var(--card-solid);
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 24px 80px rgba(0,0,0,0.35);
            display: flex;
            flex-direction: column;
            animation: scaleIn 0.25s cubic-bezier(0.25, 0.1, 0.25, 1);
        }
        @keyframes scaleIn {
            from { opacity: 0; transform: scale(0.95); }
            to { opacity: 1; transform: scale(1); }
        }

        .web-preview-titlebar {
            height: 44px;
            background: #f0f0f0;
            border-bottom: 1px solid #d5d5d5;
            display: flex;
            align-items: center;
            padding: 0 16px;
            gap: 8px;
            flex-shrink: 0;
            user-select: none;
        }

        .titlebar-dots {
            display: flex;
            gap: 7px;
        }

        .titlebar-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            border: none;
            cursor: pointer;
            transition: filter 0.15s ease;
        }
        .titlebar-dot:hover { filter: brightness(0.85); }
        .dot-close { background: #ff5f57; }
        .dot-minimize { background: #febc2e; }
        .dot-maximize { background: #28c840; }

        .titlebar-url {
            flex: 1;
            background: #ffffff;
            border: 1px solid #d5d5d5;
            border-radius: 6px;
            padding: 5px 12px;
            font-size: 12px;
            color: var(--text-secondary);
            text-align: center;
            margin: 0 40px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .titlebar-actions {
            display: flex;
            gap: 6px;
        }

        .titlebar-btn {
            width: 28px;
            height: 28px;
            border-radius: 6px;
            border: none;
            background: transparent;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #666;
            font-size: 13px;
            transition: background 0.15s;
        }
        .titlebar-btn:hover { background: rgba(0,0,0,0.08); }

        .preview-links-bar {
            display: flex;
            gap: 2px;
            padding: 2px;
            background: #e8e8e8;
            border-radius: 8px;
        }
        .preview-link-btn {
            width: 30px;
            height: 30px;
            border-radius: 6px;
            border: none;
            background: transparent;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #888;
            font-size: 14px;
            transition: all 0.15s;
        }
        .preview-link-btn:hover { background: rgba(255,255,255,0.6); color: #333; }
        .preview-link-btn.active { background: #fff; color: var(--accent); box-shadow: 0 1px 3px rgba(0,0,0,0.1); }

        .web-preview-window iframe {
            flex: 1;
            width: 100%;
            border: none;
            background: white;
        }

        /* Gallery */
        .gallery-thumb {
            width: 80px;
            height: 80px;
            border-radius: 8px;
            object-fit: cover;
            cursor: pointer;
            flex-shrink: 0;
            transition: transform 0.15s ease;
            border: 1px solid var(--card-border);
        }
        .gallery-thumb:hover { transform: scale(1.05); }

        .gallery-lightbox {
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.92);
            z-index: 2000;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
        }
        .gallery-lightbox img {
            max-width: 90%;
            max-height: 85vh;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.6);
            object-fit: contain;
        }
        .lb-nav {
            position: absolute;
            top: 50%;
            transform: translateY(-50%);
            width: 48px;
            height: 48px;
            border-radius: 50%;
            border: none;
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(10px);
            color: white;
            font-size: 20px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
        }
        .lb-nav:hover { background: rgba(255,255,255,0.3); transform: translateY(-50%) scale(1.1); }
        .lb-prev { left: 20px; }
        .lb-next { right: 20px; }
        .lb-close {
            position: absolute;
            top: 16px;
            right: 16px;
            width: 40px;
            height: 40px;
            border-radius: 50%;
            border: none;
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(10px);
            color: white;
            font-size: 18px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
        }
        .lb-close:hover { background: rgba(255,255,255,0.3); }
        .lb-counter {
            position: absolute;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            color: rgba(255,255,255,0.7);
            font-size: 14px;
            font-weight: 500;
            background: rgba(0,0,0,0.4);
            backdrop-filter: blur(10px);
            padding: 6px 16px;
            border-radius: 99px;
        }
        .lb-thumbstrip {
            position: absolute;
            bottom: 56px;
            left: 50%;
            transform: translateX(-50%);
            display: flex;
            gap: 6px;
            max-width: 80%;
            overflow-x: auto;
            padding: 6px;
            border-radius: 10px;
            background: rgba(0,0,0,0.3);
            backdrop-filter: blur(10px);
        }
        .lb-thumb {
            width: 52px;
            height: 52px;
            border-radius: 6px;
            object-fit: cover;
            cursor: pointer;
            opacity: 0.5;
            transition: all 0.2s;
            flex-shrink: 0;
            border: 2px solid transparent;
        }
        .lb-thumb:hover { opacity: 0.8; }
        .lb-thumb.active { opacity: 1; border-color: white; }

        /* Folder color variants - industry-specific colors */
        .folder-blue { background: linear-gradient(135deg, var(--accent), var(--accent-hover)); color: white; }
        .folder-purple { background: linear-gradient(135deg, #8B5CF6, #A78BFA); color: white; }
        .folder-green { background: linear-gradient(135deg, #34C759, #30D158); color: white; }
        .folder-orange { background: linear-gradient(135deg, #F59E0B, #FBBF24); color: white; }
        .folder-pink { background: linear-gradient(135deg, #FF2D55, #FF375F); color: white; }
        .folder-brand-blue { background: linear-gradient(135deg, var(--accent), var(--accent-hover)); color: white; }
        .folder-red { background: linear-gradient(135deg, #EF4444, #F87171); color: white; }
        .folder-teal { background: linear-gradient(135deg, #14B8A6, #2DD4BF); color: white; }
        .folder-yellow { background: linear-gradient(135deg, #EAB308, #FACC15); color: #1c1c1e; }
        .folder-brown { background: linear-gradient(135deg, #92400E, #B45309); color: white; }
        .folder-gray { background: linear-gradient(135deg, #6B7280, #9CA3AF); color: white; }
        .folder-gold { background: linear-gradient(135deg, #D97706, #F59E0B); color: white; }

        @media (max-width: 768px) {
            .container { padding: 20px 16px; }
            .folder-grid { grid-template-columns: 1fr; }
            .stats-row { grid-template-columns: repeat(2, 1fr); }
            .selector-grid { grid-template-columns: 1fr; }
            .toolbar { flex-direction: column; }
            .page-header {
                flex-wrap: wrap;
                gap: 12px;
                min-height: 0;
                align-items: flex-start;
                padding-left: 0;
                width: 100%;
                max-width: 100%;
                box-sizing: border-box;
                overflow: hidden;
            }
            .page-header > div:first-child {
                padding-left: 48px;
                width: 100%;
                box-sizing: border-box;
            }
            .page-header h1 { font-size: 24px; }
            .page-header .subtitle {
                font-size: 13px;
                max-width: 145px;
                line-height: 1.35;
            }
            .page-header > div:last-child {
                display: flex;
                flex-wrap: wrap;
                gap: 10px;
                align-items: center;
                width: 100%;
                max-width: 100%;
                box-sizing: border-box;
                padding-left: 48px;
                justify-content: flex-start;
            }
            .credits-badge { font-size: 13px; padding: 6px 10px; white-space: nowrap; }
            .page-header > div:last-child .btn {
                font-size: 14px;
                padding: 12px 18px;
                white-space: nowrap;
                width: auto;
                max-width: max-content;
                min-height: 46px;
            }
            @media (max-width: 390px) {
                .page-header > div:last-child {
                    flex-direction: column;
                    align-items: flex-start;
                    padding-left: 48px;
                }
                .page-header > div:last-child .btn {
                    width: auto;
                    max-width: max-content;
                    box-sizing: border-box;
                    text-align: center;
                }
            }
            .search-box { min-width: 100%; }
            .slide-panel { width: 100%; right: -110%; }
            /* Add Leads modal: sheet-style on mobile */
            .modal-overlay { padding: 0; z-index: 2001; }
            .modal-overlay.active {
                display: flex;
                align-items: center;
                justify-content: center;
            }
            /* Hide hamburger menu-toggle behind modal so it can't overlap modal header */
            .modal-overlay.active ~ .menu-toggle,
            .modal-overlay.active ~ * .menu-toggle { display: none !important; }
            .modal.wide {
                max-width: 100%; width: 100%; height: 100dvh;
                border-radius: 16px 16px 0 0;
                overflow: visible;
                /* Ensure full-viewport fill including safe-area insets */
                position: fixed; top: auto; right: 0; bottom: 0; left: 0;
                max-height: 92dvh;
            }
            .modal.wide .modal-header { padding: 14px 16px; width: 100%; flex-shrink: 0; }
            .modal.wide .modal-header h2 { font-size: 16px; }
            .modal.wide .modal-body {
                padding: 12px 16px; width: 100%; flex: 1; min-height: 0;
                overflow-y: auto; overflow-x: hidden;
                box-sizing: border-box;
                -webkit-overflow-scrolling: touch;
            }
            .modal.wide .modal-footer {
                padding: 10px 16px max(14px, env(safe-area-inset-bottom));
                flex-wrap: nowrap; width: 100%; flex-shrink: 0;
                justify-content: space-between;
            }
            .modal.wide .modal-footer .btn {
                flex: 1; text-align: center;
                padding: 12px 16px; font-size: 15px;
            }
            .modal.wide .modal-footer .btn.btn-secondary { order: -1; }

            /* Country picker: tighter on mobile */
            #countryPicker { gap: 6px; }
            .country-pick { padding: 8px 10px; gap: 6px; }
            .country-pick-label { font-size: 12px; }

            /* City selector header: vertical stack, no wide flex row */
            .modal.wide .selector-panel .selector-header {
                flex-direction: column; align-items: flex-start; gap: 4px;
                min-height: 0; height: auto; padding: 8px 10px;
            }
            .modal.wide .selector-panel .selector-header > span:first-child { width: 100%; }
            .modal.wide .selector-panel .selector-header > div { width: 100%; flex-wrap: wrap; }
            .modal.wide .selector-header [style*="gap:3px"] { width: 100%; flex-wrap: wrap; }

            /* Selector panels: ensure they stack and are full-width */
            .selector-grid { grid-template-columns: 1fr; }
            .selector-panel { width: 100%; max-height: 220px; }
            /* Form inputs: full width within modal body */
            .modal.wide .modal-body .form-group input,
            .modal.wide .modal-body .form-group textarea,
            .modal.wide .modal-body .form-group select {
                width: 100%; box-sizing: border-box; font-size: 16px;
            }
            /* Detail header: stack on mobile */
            .detail-header {
                display: flex;
                flex-wrap: wrap;
                gap: 12px;
                padding-left: 52px;
                align-items: flex-start;
            }
            .detail-header > div:last-child {
                display: flex;
                flex-wrap: wrap;
                gap: 8px;
                align-items: center;
                width: 100%;
            }
            .back-btn { flex-shrink: 0; }
            .detail-title { width: 100%; }
            .detail-title h1 { font-size: 22px; }
            /* Table: horizontal scroll via wrapper */
            .leads-table-wrap { overflow-x: auto; -webkit-overflow-scrolling: touch; }
            .leads-table { min-width: 600px; }
            /* Map: fit viewport on mobile */
            #listMap { height: 280px !important; }
            /* Filter pills and per-page: wrap on mobile */
            .filter-pills { flex-wrap: wrap; gap: 4px; }
            #perPageSelect { width: 100%; }
            /* Collapsible: mobile default collapsed - only target .collapsed so JS toggle wins */
            .detail-view-expanded .collapsible-content.collapsed { max-height: 0; }
        }

        .top-us-city-pill, .top-city-preset-pill {
            font-size: 12px;
            padding: 6px 12px;
            border-radius: 8px;
            border: 1px solid var(--card-border);
            background: var(--bg);
            color: var(--text-secondary);
            cursor: pointer;
            font-family: inherit;
            font-weight: 600;
            transition: all 0.15s;
        }
        .top-us-city-pill:hover, .top-city-preset-pill:hover {
            border-color: var(--accent);
            color: var(--accent);
        }
        .top-us-city-pill.active, .top-city-preset-pill.active {
            background: var(--accent);
            color: #fff;
            border-color: var(--accent);
            box-shadow: 0 2px 8px rgba(99, 102, 241, 0.25);
        }

        /* [LANE-UI] Core-style 4 horizontal scrape lane tiles. Compact grid:
           4 columns desktop, 2 columns tablet, 1 column mobile. */
        #laneProgressContainer {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 8px;
        }
        @media (max-width: 900px) {
            #laneProgressContainer { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        }
        @media (max-width: 600px) {
            #laneProgressContainer { grid-template-columns: 1fr; }
        }
        .lane-tile {
            padding: 10px;
            background: var(--bg);
            border: 1px solid var(--card-border);
            border-radius: 8px;
            min-width: 0;
        }
        .lane-tile .lane-fill-bg {
            height: 6px;
            background: var(--card-border);
            border-radius: 99px;
            overflow: hidden;
            margin-bottom: 4px;
        }
        .lane-tile .lane-fill {
            height: 100%;
            width: 0%;
            background: var(--accent);
            transition: width 0.3s;
        }
        .lane-tile .lane-text {
            font-size: 11px;
            color: var(--text-tertiary);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
    </style>
    <?php renderThemeDarkStyles('leadlists'); ?>
</head>
<body>

<!-- LISTS VIEW -->
<div id="listsView" class="container">
    <div class="page-header">
        <div>
            <h1>Lead Lists</h1>
            <div class="subtitle">Organize and manage your leads</div>
        </div>
        <div style="display:flex;gap:12px;align-items:center;">
            <span class="credits-badge"><i class="fas fa-map-marker-alt"></i> <span id="creditsDisplay"><?php echo number_format($userCredits); ?></span> city searches</span>
            <button class="btn btn-primary" onclick="app.openCreateModal()"><i class="fas fa-plus"></i> New List</button>
        </div>
    </div>
    <div class="metrics-overview" id="metricsOverview">
        <div class="metric-card">
            <div class="metric-icon" style="background:linear-gradient(135deg,rgba(var(--accent-rgb),0.12),rgba(var(--accent-rgb),0.06));">
                <i class="fas fa-users" style="color:var(--accent);"></i>
            </div>
            <div class="metric-content">
                <div class="metric-value"><?php echo number_format((int)($metrics['total_leads'] ?? 0)); ?></div>
                <div class="metric-label">Total Leads</div>
            </div>
        </div>
        <div class="metric-card">
            <div class="metric-icon" style="background:linear-gradient(135deg,rgba(34,197,94,0.12),rgba(34,197,94,0.06));">
                <i class="fas fa-envelope-open-text" style="color:var(--green);"></i>
            </div>
            <div class="metric-content">
                <div class="metric-value"><?php echo number_format((int)($metrics['verified_emails'] ?? 0)); ?></div>
                <div class="metric-label">Verified Emails</div>
            </div>
        </div>
        <div class="metric-card">
            <div class="metric-icon" style="background:linear-gradient(135deg,rgba(59,130,246,0.12),rgba(59,130,246,0.06));">
                <i class="fas fa-share-alt" style="color:var(--blue);"></i>
            </div>
            <div class="metric-content">
                <div class="metric-value"><?php echo number_format((int)($metrics['have_socials'] ?? 0)); ?></div>
                <div class="metric-label">Have Socials</div>
            </div>
        </div>
        <div class="metric-card">
            <div class="metric-icon" style="background:linear-gradient(135deg,rgba(34,197,94,0.12),rgba(34,197,94,0.06));">
                <i class="fas fa-phone" style="color:var(--green);"></i>
            </div>
            <div class="metric-content">
                <div class="metric-value"><?php echo number_format((int)($metrics['have_phone'] ?? 0)); ?></div>
                <div class="metric-label">Have Phone</div>
            </div>
        </div>
    </div>
<div id="mainGrid" class="main-grid-layout">
        <div id="folderGrid" class="folder-grid">
            <div class="skeleton-folder-card">
                <div class="sk-icon-wrap"><div class="sk-block sk-icon"></div></div>
                <div class="sk-block sk-title"></div>
                <div class="sk-block sk-desc"></div>
                <div class="sk-block sk-desc sk-desc-short"></div>
            </div>
            <div class="skeleton-folder-card">
                <div class="sk-icon-wrap"><div class="sk-block sk-icon"></div></div>
                <div class="sk-block sk-title"></div>
                <div class="sk-block sk-desc"></div>
                <div class="sk-block sk-desc sk-desc-short"></div>
            </div>
            <div class="skeleton-folder-card">
                <div class="sk-icon-wrap"><div class="sk-block sk-icon"></div></div>
                <div class="sk-block sk-title"></div>
                <div class="sk-block sk-desc"></div>
                <div class="sk-block sk-desc sk-desc-short"></div>
            </div>
        </div>
    </div>

    <div id="categoryIntelSection" class="collapsed" style="margin-top:24px;">
        <div class="category-intel-toggle-row">
            <span style="font-size:12px;font-weight:600;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:0.5px;">Browse by Category</span>
            <button type="button" id="toggleCategoryIntelBtn" onclick="app.toggleCategoryIntel()" style="background:none;border:none;cursor:pointer;color:var(--accent);font-size:12px;font-weight:600;display:flex;align-items:center;gap:4px;padding:4px 8px;border-radius:6px;transition:background 0.15s;">
                <span id="toggleCatLabel">Show</span> <i class="fas fa-chevron-down" id="toggleCatIcon"></i>
            </button>
        </div>
        <div id="categoryIntel" class="category-intel"></div>
    </div>

    <div id="emptyState" class="empty-state hidden">
        <div class="welcome-empty">
            <div class="welcome-icon"><i class="fas fa-rocket"></i></div>
            <h2>Welcome to Lead Lists</h2>
            <p class="welcome-sub">You have <strong>3 free city searches</strong> to get started &mdash; each one finds up to <strong>500 leads</strong>. Create your first list and start building your pipeline.</p>

            <div class="free-credits-card">
                <div class="fcc-header">
                    <i class="fas fa-gift"></i>
                    <span>Your Free Starter Pack</span>
                </div>
                <div class="fcc-details">
                    <div class="fcc-detail">
                        <div class="fcc-num" id="freeCreditsNum"><?php echo $userCredits; ?></div>
                        <div class="fcc-label">City Searches</div>
                    </div>
                    <div class="fcc-detail">
                        <div class="fcc-num">500</div>
                        <div class="fcc-label">Leads Per City</div>
                    </div>
                    <div class="fcc-detail">
                        <div class="fcc-num">Free</div>
                        <div class="fcc-label">No Card Needed</div>
                    </div>
                </div>
            </div>

            <div class="create-first-section hidden" style="margin:16px 0 0;text-align:center;">
                <p style="color:var(--text-secondary);font-size:13px;margin:0 0 12px;">Jump straight in with a pre-filled name for this category.</p>
                <button class="btn btn-primary pulse-cue" onclick="app._openCreateModalForCategory()">
                    <i class="fas fa-plus"></i> Create List
                </button>
            </div>

            <button class="welcome-cta pulse-cue" onclick="app.openCreateModal()">
                <i class="fas fa-plus"></i> Create Your First List
            </button>

            <div class="welcome-steps">
                <div class="welcome-step">
                    <div class="ws-num">1</div>
                    <div class="ws-title">Create a list</div>
                    <div class="ws-desc">Name your list and pick the cities you want to search</div>
                </div>
                <div class="welcome-step">
                    <div class="ws-num">2</div>
                    <div class="ws-title">Find leads</div>
                    <div class="ws-desc">Search any business type and get up to 500 results per city</div>
                </div>
                <div class="welcome-step">
                    <div class="ws-num">3</div>
                    <div class="ws-title">Track outreach</div>
                    <div class="ws-desc">Mark emails, DMs, follow-ups and watch your pipeline grow</div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- DETAIL VIEW -->
<div id="detailView" class="container hidden detail-view-expanded">
    <div class="detail-header">
        <button class="back-btn" onclick="app.goBack()"><i class="fas fa-arrow-left"></i></button>
        <div class="detail-title">
            <h1 id="detailName"></h1>
            <div class="detail-sub" id="detailSub"></div>
        </div>
        <div style="display:flex;gap:8px;align-items:center;" class="detail-actions">
            <span class="credits-badge"><i class="fas fa-map-marker-alt"></i> <span id="creditsDisplay2"><?php echo number_format($userCredits); ?></span> city searches</span>
            <button class="btn btn-sm" onclick="app.openEmailTemplateModal()" style="background:var(--accent);color:#fff;font-size:12px;padding:6px 12px;border:none;" title="Email Template"><i class="fas fa-envelope"></i> Template</button>
            <button class="btn btn-sm" onclick="app.openShareModal()" style="background:var(--bg);border:1px solid var(--card-border);color:var(--text-primary);font-size:12px;padding:6px 12px;" title="Share"><i class="fas fa-share-alt"></i> Share</button>
            <button class="btn btn-primary" onclick="app.openAddLeadsModal()"><i class="fas fa-plus"></i> Add Leads</button>
            <button class="btn btn-sm admin-reenrich-btn" onclick="app.forceReenrich()" title="Re-enrich all websites in this folder"><i class="fas fa-sync-alt"></i> Re-Enrich All</button>
            <button class="btn btn-sm" onclick="app.openFolderImportLogs()" style="background:var(--bg);border:1px solid var(--card-border);color:var(--text-primary);font-size:12px;padding:6px 12px;" title="GHL Import Logs"><i class="fas fa-history"></i> Import Logs</button>
            <button class="btn btn-sm" onclick="document.getElementById('importCsvFile').click()" style="background:var(--bg);border:1px solid var(--card-border);color:var(--text-primary);font-size:12px;padding:6px 12px;" title="Import CSV"><i class="fas fa-upload"></i> Import CSV</button>
            <input type="file" id="importCsvFile" name="csv" accept=".csv,text/csv" style="display:none;" onchange="app.handleImportCSV(this)">
            <div style="position:relative;">
                <button class="btn btn-secondary" id="exportMenuBtn" onclick="app.toggleExportMenu()"><i class="fas fa-download"></i> Export</button>
                <div id="exportMenu" class="hidden" style="position:absolute;top:100%;right:0;margin-top:6px;background:var(--card-solid);border:1px solid var(--card-border);border-radius:var(--radius-xs);box-shadow:var(--shadow-lg);min-width:200px;z-index:100;padding:6px;">
                    <button class="btn btn-ghost" style="width:100%;justify-content:flex-start;" onclick="app.openExportPreview('csv')"><i class="fas fa-file-csv"></i> Export CSV</button>
                    <button class="btn btn-ghost" style="width:100%;justify-content:flex-start;" onclick="app.openGHLExport()"><i class="fas fa-paper-plane"></i> Export to GHL</button>
                </div>
            </div>
        </div>
    </div>

    <div id="searchedStatesArea" class="hidden collapsible-card">
        <div class="collapsible-header" onclick="app.toggleSearchedAreas()">
            <span class="ch-title"><i class="fas fa-map-pin"></i> Searched Areas</span>
            <div style="display:flex;align-items:center;gap:8px;">
                <span class="ch-meta" id="searchedAreasCount"></span>
                <button class="ch-toggle collapsed" id="searchedAreasToggle"><i class="fas fa-chevron-down"></i></button>
            </div>
        </div>
        <div class="collapsible-content collapsed" id="searchedAreasContent">
            <div style="padding:14px 20px;">
                <div id="searchedStates" class="searched-summary"></div>
            </div>
        </div>
    </div>

    <div id="topStatsRow"></div>

    <div id="listMapWrap" class="collapsible-card">
        <div class="collapsible-header" onclick="app.toggleListMap()">
            <span class="ch-title"><i class="fas fa-map-marked-alt"></i> Map View</span>
            <div style="display:flex;align-items:center;gap:8px;">
                <span class="ch-meta" id="listMapCount">0 locations</span>
                <button class="ch-toggle collapsed" id="listMapToggle"><i class="fas fa-chevron-down"></i></button>
            </div>
        </div>
        <div class="collapsible-content collapsed" id="listMapContainer">
            <div id="listMap" style="width:100%;height:400px;"></div>
        </div>
    </div>

    <div id="statsRow"></div>

    <div class="toolbar">
        <div class="search-box">
            <i class="fas fa-search"></i>
            <input type="text" id="leadSearch" placeholder="Search leads..." oninput="app.debounceSearch()">
        </div>
        <div class="filter-pills" id="filterPills">
            <button class="filter-pill active" data-filter="" onclick="app.filterByHas('')">All</button>
            <button class="filter-pill" data-filter="emailed" onclick="app.filterByHas('emailed')">Emailed</button>
            <button class="filter-pill" data-filter="ig_dm" onclick="app.filterByHas('ig_dm')">DM'd</button>
            <button class="filter-pill" data-filter="visited" onclick="app.filterByHas('visited')">Visited</button>
        </div>
        <button class="toggle-pill" id="hideCitiesToggle" onclick="app.toggleHideCities()" title="Toggle city column visibility">
            <i class="fas fa-map-marker-alt"></i> Hide Cities
        </button>
        <select id="perPageSelect" onchange="app.changePerPage(this.value)" style="padding:6px 10px;border:1px solid var(--card-border);border-radius:var(--radius-xs);font-size:13px;font-family:inherit;background:var(--card-solid);outline:none;">
            <option value="25">25 / page</option>
            <option value="50" selected>50 / page</option>
            <option value="100">100 / page</option>
            <option value="200">200 / page</option>
            <option value="500">500 / page</option>
        </select>
        <div class="hidden" id="bulkActions" style="display:flex;gap:6px;align-items:center;flex-wrap:wrap;">
            <span id="bulkSelectedCount" style="font-size:12px;font-weight:600;color:var(--text-secondary);"></span>
            <button class="btn btn-sm" onclick="app.bulkSetField('outreach_email', 1)" style="background:var(--purple);color:#fff;font-size:11px;padding:4px 10px;"><i class="fas fa-envelope"></i> Emailed</button>
            <button class="btn btn-sm" onclick="app.bulkSetField('outreach_instagram', 1)" style="background:var(--pink);color:#fff;font-size:11px;padding:4px 10px;"><i class="fas fa-comment-dots"></i> DM'd</button>
            <button class="btn btn-sm" onclick="app.bulkSetField('pipeline_stage', 'contacted')" style="background:var(--accent);color:#fff;font-size:11px;padding:4px 10px;"><i class="fas fa-arrow-right"></i> Contacted</button>
            <button class="btn btn-sm" onclick="app.bulkSetField('pipeline_stage', 'engaged')" style="background:var(--orange);color:#fff;font-size:11px;padding:4px 10px;"><i class="fas fa-comments"></i> Engaged</button>
            <button class="btn btn-sm" onclick="app.bulkSetField('pipeline_stage', 'client')" style="background:var(--green);color:#fff;font-size:11px;padding:4px 10px;"><i class="fas fa-handshake"></i> Client</button>
            <button class="btn btn-danger btn-sm" onclick="app.bulkDeleteLeads()" style="font-size:11px;padding:4px 10px;"><i class="fas fa-trash"></i> Delete</button>
        </div>
    </div>

    <div class="leads-table-wrap">
        <table class="leads-table" style="min-width:1100px;">
            <thead>
                <tr>
                    <th style="width:40px;"><input type="checkbox" id="selectAllCheckbox" onchange="app.toggleSelectAll(this.checked)" style="width:16px;height:16px;accent-color:var(--accent);cursor:pointer;"></th>
                    <th>Business</th>
                    <th>Location</th>
                    <th>Contact</th>
                    <th>Socials</th>
                    <th>Pipeline</th>
                    <th style="width:60px;">Score</th>
                    <th>Outreach</th>
                    <th>Follow-ups</th>
                    <th>First Contact</th>
                    <th style="width:70px;">Actions</th>
                </tr>
            </thead>
            <tbody id="leadsBody"></tbody>
        </table>
        <div id="leadsEmpty" class="empty-state hidden" style="padding:40px;">
            <i class="fas fa-users" style="font-size:40px;"></i>
            <h3 style="font-size:18px;">No leads yet</h3>
            <p>Add leads by selecting states and cities to search</p>
        </div>
    </div>
    <div id="paginationArea" class="pagination"></div>
</div>

<!-- CREATE/EDIT LIST MODAL -->
<div id="createModal" class="modal-overlay">
    <div class="modal">
        <div class="modal-header">
            <h2 id="createModalTitle">New Lead List</h2>
            <button class="btn-icon" onclick="app.closeCreateModal()"><i class="fas fa-times"></i></button>
        </div>
        <div class="modal-body">
            <div class="form-group">
                <label>List Name</label>
                <input type="text" id="listName" placeholder="e.g., Functional Medicine Doctors">
            </div>
            <div class="form-group">
                <label>Description (optional)</label>
                <textarea id="listDesc" placeholder="What kind of leads are in this list?"></textarea>
            </div>
            <div class="form-group">
                <label>Icon</label>
                <div style="display:flex;align-items:center;gap:12px;padding:4px 0;">
                    <div id="iconPreview" class="folder-icon folder-blue" style="width:48px;height:48px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:22px;margin:0;">
                        <i class="fa-solid fa-folder"></i>
                    </div>
                    <div style="display:flex;flex-direction:column;gap:6px;">
                        <button class="btn btn-sm" onclick="app.openIconPicker()" style="padding:6px 12px;font-size:12px;background:var(--bg);border:1px solid var(--card-border);color:var(--text);"><i class="fas fa-palette" style="margin-right:4px;"></i> Change Icon</button>
                        <span style="font-size:11px;color:var(--text-tertiary);">Auto-selected from category when none set</span>
                    </div>
                </div>
            </div>
            <div class="category-select-row" style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
                <div class="form-group">
                    <label>Category Group</label>
                    <select id="listCategoryGroup" onchange="app.onListCategoryGroupChange()" style="width:100%;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;font-size:14px;font-family:inherit;background:var(--card-solid);color:var(--text);outline:none;"></select>
                </div>
                <div class="form-group">
                    <label>Category</label>
                    <select id="listCategory" onchange="app.onListCategoryChange()" style="width:100%;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;font-size:14px;font-family:inherit;background:var(--card-solid);color:var(--text);outline:none;"></select>
                </div>
            </div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-secondary" onclick="app.closeCreateModal()">Cancel</button>
            <button class="btn btn-primary" id="createListBtn" onclick="app.saveList()">Create</button>
        </div>
    </div>
</div>

<!-- SHARE MODAL -->
<div id="shareModal" class="modal-overlay">
    <div class="modal" style="max-width:460px;">
        <div class="modal-header">
            <h2><i class="fas fa-share-alt" style="color:var(--accent);margin-right:8px;"></i>Share Lead List</h2>
            <button class="btn-icon" onclick="document.getElementById('shareModal').classList.remove('active')"><i class="fas fa-times"></i></button>
        </div>
        <div class="modal-body">
            <div style="display:flex;align-items:center;justify-content:space-between;padding:14px 0;border-bottom:1px solid var(--card-border);">
                <div>
                    <div style="font-weight:600;font-size:14px;">Make Public</div>
                    <div style="font-size:12px;color:var(--text-secondary);margin-top:2px;">Anyone with the link can download this list as CSV</div>
                </div>
                <label class="toggle-switch">
                    <input type="checkbox" id="shareToggle" onchange="app.toggleSharePublic(this.checked)">
                    <span class="toggle-slider"></span>
                </label>
            </div>
            <div id="shareLinkSection" class="hidden" style="margin-top:16px;">
                <label style="font-size:12px;font-weight:600;color:var(--text-secondary);display:block;margin-bottom:6px;">Share Link</label>
                <div style="display:flex;gap:8px;">
                    <input type="text" id="shareLinkInput" readonly style="flex:1;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;font-size:13px;font-family:inherit;background:var(--bg);color:var(--text-primary);outline:none;">
                    <button class="btn btn-primary" onclick="app.copyShareLink()" style="padding:10px 16px;white-space:nowrap;"><i class="fas fa-copy"></i> Copy</button>
                </div>
                <p style="font-size:11px;color:var(--text-tertiary);margin-top:8px;"><i class="fas fa-lock" style="margin-right:4px;"></i> Link uses a secure 64-character token that cannot be guessed</p>
                <div style="margin-top:16px;border-top:1px solid var(--card-border);padding-top:16px;">
                    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
                        <div style="font-weight:600;font-size:14px;display:flex;align-items:center;gap:6px;"><i class="fas fa-user-plus" style="color:var(--accent);"></i> Signups from this link</div>
                        <span id="shareClaimCount" style="font-size:12px;font-weight:700;color:var(--accent);background:var(--accent-light);padding:2px 10px;border-radius:8px;">0</span>
                    </div>
                    <div id="shareClaimsList" style="max-height:200px;overflow-y:auto;"></div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- ICON PICKER MODAL -->
<div id="iconPickerModal" class="modal-overlay" style="z-index: 3000;">
    <div class="modal">
        <div class="modal-header">
            <h2><i class="fas fa-palette" style="color:var(--accent);margin-right:8px;"></i>Choose Icon</h2>
            <button class="btn-icon" onclick="app.closeIconPicker()"><i class="fas fa-times"></i></button>
        </div>
        <div class="modal-body">
            <input type="text" id="iconSearch" class="icon-search-input" placeholder="Search icons..." oninput="app.filterIcons()">
            <div id="iconColorPicker">
                <button class="icon-color-btn active" data-color="folder-blue" onclick="app.selectIconColor('folder-blue')" style="background:linear-gradient(135deg,var(--accent),var(--accent-hover));border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Blue"></button>
                <button class="icon-color-btn" data-color="folder-green" onclick="app.selectIconColor('folder-green')" style="background:linear-gradient(135deg,#34C759,#30D158);border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Green"></button>
                <button class="icon-color-btn" data-color="folder-pink" onclick="app.selectIconColor('folder-pink')" style="background:linear-gradient(135deg,#FF2D55,#FF375F);border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Pink"></button>
                <button class="icon-color-btn" data-color="folder-red" onclick="app.selectIconColor('folder-red')" style="background:linear-gradient(135deg,#EF4444,#F87171);border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Red"></button>
                <button class="icon-color-btn" data-color="folder-teal" onclick="app.selectIconColor('folder-teal')" style="background:linear-gradient(135deg,#14B8A6,#2DD4BF);border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Teal"></button>
                <button class="icon-color-btn" data-color="folder-yellow" onclick="app.selectIconColor('folder-yellow')" style="background:linear-gradient(135deg,#EAB308,#FACC15);border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Yellow"></button>
                <button class="icon-color-btn" data-color="folder-gray" onclick="app.selectIconColor('folder-gray')" style="background:linear-gradient(135deg,#6B7280,#9CA3AF);border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Gray"></button>
                <button class="icon-color-btn" data-color="folder-gold" onclick="app.selectIconColor('folder-gold')" style="background:linear-gradient(135deg,#D97706,#F59E0B);border-radius:8px;width:32px;height:32px;border:2px solid transparent;cursor:pointer;" title="Gold"></button>
            </div>
            <div class="icon-grid-wrap" style="margin-top:12px;"><div id="iconGrid"></div></div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-secondary" onclick="app.resetIcon()">Reset to Auto</button>
            <button class="btn btn-primary" onclick="app.applyIcon()">Apply</button>
        </div>
    </div>
</div>

<!-- EMAIL TEMPLATE MODAL -->
<div id="emailTemplateModal" class="modal-overlay">
    <div class="modal" style="max-width:560px;">
        <div class="modal-header">
            <h2><i class="fas fa-envelope" style="color:var(--accent);margin-right:8px;"></i>Email Template</h2>
            <button class="btn-icon" onclick="document.getElementById('emailTemplateModal').classList.remove('active')"><i class="fas fa-times"></i></button>
        </div>
        <div class="modal-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;line-height:1.5;">Set up your email template once — every time you click an email it will auto-fill your message. Use the buttons below to insert lead info automatically.</p>

            <div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:16px;">
                <button class="btn btn-sm" style="background:var(--accent-light);color:var(--accent);border:none;font-size:11px;padding:4px 10px;border-radius:8px;" onclick="app.insertTemplateVar('subject', '{business_name}')">{business_name}</button>
                <button class="btn btn-sm" style="background:var(--accent-light);color:var(--accent);border:none;font-size:11px;padding:4px 10px;border-radius:8px;" onclick="app.insertTemplateVar('subject', '{city}')">{city}</button>
                <button class="btn btn-sm" style="background:var(--accent-light);color:var(--accent);border:none;font-size:11px;padding:4px 10px;border-radius:8px;" onclick="app.insertTemplateVar('subject', '{state}')">{state}</button>
                <button class="btn btn-sm" style="background:var(--accent-light);color:var(--accent);border:none;font-size:11px;padding:4px 10px;border-radius:8px;" onclick="app.insertTemplateVar('subject', '{my_name}')">{my_name}</button>
                <button class="btn btn-sm" style="background:var(--accent-light);color:var(--accent);border:none;font-size:11px;padding:4px 10px;border-radius:8px;" onclick="app.insertTemplateVar('subject', '{my_company}')">{my_company}</button>
            </div>

            <div style="margin-bottom:14px;">
                <label style="font-size:12px;font-weight:600;color:var(--text-secondary);display:block;margin-bottom:6px;">Your Name</label>
                <input type="text" id="etMyName" placeholder="e.g. Sarah" style="width:100%;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;font-size:14px;font-family:inherit;background:var(--bg);color:var(--text-primary);outline:none;">
            </div>
            <div style="margin-bottom:14px;">
                <label style="font-size:12px;font-weight:600;color:var(--text-secondary);display:block;margin-bottom:6px;">Your Company</label>
                <input type="text" id="etMyCompany" placeholder="e.g. Acme Marketing" style="width:100%;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;font-size:14px;font-family:inherit;background:var(--bg);color:var(--text-primary);outline:none;">
            </div>
            <div style="margin-bottom:14px;">
                <label style="font-size:12px;font-weight:600;color:var(--text-secondary);display:block;margin-bottom:6px;">Subject Line</label>
                <input type="text" id="etSubject" placeholder="e.g. Quick question for {business_name}" style="width:100%;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;font-size:14px;font-family:inherit;background:var(--bg);color:var(--text-primary);outline:none;">
            </div>
            <div style="margin-bottom:14px;">
                <label style="font-size:12px;font-weight:600;color:var(--text-secondary);display:block;margin-bottom:6px;">Email Body</label>
                <textarea id="etBody" rows="7" placeholder="Hi there!&#10;&#10;I came across {business_name} in {city} and wanted to reach out...&#10;&#10;Best,&#10;{my_name}" style="width:100%;padding:10px 12px;border:1px solid var(--card-border);border-radius:10px;font-size:14px;font-family:inherit;background:var(--bg);color:var(--text-primary);outline:none;resize:vertical;line-height:1.5;"></textarea>
            </div>

            <div style="display:flex;gap:8px;">
                <button class="btn btn-primary" onclick="app.saveEmailTemplate()" style="flex:1;"><i class="fas fa-save"></i> Save Template</button>
                <button class="btn btn-secondary" onclick="app.clearEmailTemplate()" style="padding:10px 16px;"><i class="fas fa-trash"></i></button>
            </div>
            <p style="font-size:11px;color:var(--text-tertiary);margin-top:10px;text-align:center;"><i class="fas fa-magic" style="margin-right:4px;"></i> Now when you click any email, your template will auto-fill!</p>
        </div>
    </div>
</div>

<!-- UPGRADE MODAL -->
<div id="upgradeModal" style="display:none;position:fixed;inset:0;z-index:9999;background:rgba(0,0,0,0.4);backdrop-filter:blur(8px);align-items:center;justify-content:center;">
    <div style="background:#fff;border-radius:20px;padding:36px 32px;max-width:420px;width:90%;text-align:center;box-shadow:0 24px 80px rgba(0,0,0,0.15);">
        <div style="width:56px;height:56px;border-radius:16px;background:linear-gradient(135deg,var(--accent),var(--accent-hover));display:flex;align-items:center;justify-content:center;margin:0 auto 20px;">
            <i class="fas fa-rocket" style="color:#fff;font-size:22px;"></i>
        </div>
        <h2 style="font-size:20px;font-weight:700;margin:0 0 8px;">Need More Credits</h2>
        <p style="color:#6e6e73;font-size:14px;margin:0 0 20px;line-height:1.5;">You need <strong id="upgradeNeeded">0</strong> credits but only have <strong id="upgradeHave">0</strong>. Upgrade your plan to get more credits and keep searching.</p>
        <a href="/dashboard?section=section5" class="btn btn-primary" style="display:inline-flex;align-items:center;gap:8px;padding:13px 28px;font-size:15px;border-radius:12px;text-decoration:none;font-weight:600;"><i class="fas fa-arrow-up"></i> Upgrade Plan</a>
        <div id="shareForCreditsWrap" style="margin-top:18px;padding-top:18px;border-top:1px solid #f0f0f0;<?php echo $userHasShared ? 'display:none;' : ''; ?>">
            <div style="font-size:12px;color:#86868b;margin-bottom:10px;">or</div>
            <button onclick="app.shareForCredits()" id="shareForCreditsBtn" style="display:inline-flex;align-items:center;gap:8px;padding:11px 24px;border-radius:12px;background:linear-gradient(135deg,#34C759,#30B855);color:#fff;font-size:14px;font-weight:600;border:none;cursor:pointer;box-shadow:0 4px 12px rgba(52,199,89,0.25);transition:all 0.2s;">
                <i class="fas fa-share-nodes"></i> Share &amp; Get 5 Free Credits
            </button>
        </div>
        <div style="margin-top:14px;">
            <button onclick="app.closeUpgradeModal()" style="background:none;border:none;color:#6e6e73;font-size:13px;cursor:pointer;font-family:inherit;">Maybe later</button>
        </div>
    </div>
</div>

<!-- ADD LEADS MODAL -->
<div id="addLeadsModal" class="modal-overlay">
    <div class="modal wide">
        <div class="modal-header">
            <h2>Add Leads</h2>
            <button class="btn-icon" onclick="app.closeAddLeadsModal()" title="Minimize"><i class="fas fa-minus"></i></button>
        </div>
        <div class="modal-body">
            <div class="form-group">
                <label>Search Query</label>
                <input type="text" id="scrapeQuery" placeholder="e.g., functional medicine doctors, dentists near me">
            </div>
            <div class="form-group">
                <label>Results per City</label>
                <select id="scrapeLimit">
                    <option value="20">20</option>
                    <option value="50">50</option>
                    <option value="100" selected>100</option>
                    <option value="200">200</option>
                    <option value="300">300</option>
                    <option value="400">400</option>
                    <option value="500">500</option>
                </select>
            </div>

            <div id="countryPicker" style="display:flex;gap:8px;margin-bottom:14px;flex-wrap:wrap;">
                <button class="country-pick active" data-country="US" onclick="app.switchCountry('US')">
                    <span style="font-size:22px;">🇺🇸</span>
                    <span class="country-pick-label">United States</span>
                </button>
                <button class="country-pick" data-country="UK" onclick="app.switchCountry('UK')">
                    <span style="font-size:22px;">🇬🇧</span>
                    <span class="country-pick-label">United Kingdom</span>
                </button>
                <button class="country-pick" data-country="EU" onclick="app.switchCountry('EU')">
                    <span style="font-size:22px;">🇪🇺</span>
                    <span class="country-pick-label">Europe</span>
                </button>
                <button class="country-pick" data-country="CA-LAT" onclick="app.switchCountry('CA-LAT')">
                    <span style="font-size:22px;">🌎</span>
                    <span class="country-pick-label">Canada & Latin America</span>
                </button>
                <button class="country-pick" data-country="CAR" onclick="app.switchCountry('CAR')">
                    <span style="font-size:22px;">🏝️</span>
                    <span class="country-pick-label">Caribbean</span>
                </button>
                <button class="country-pick" data-country="AF" onclick="app.switchCountry('AF')">
                    <span style="font-size:22px;">🌍</span>
                    <span class="country-pick-label">Africa</span>
                </button>
                <button class="country-pick" data-country="ME-CA" onclick="app.switchCountry('ME-CA')">
                    <span style="font-size:22px;">🏜️</span>
                    <span class="country-pick-label">Middle East & Central Asia</span>
                </button>
                <button class="country-pick" data-country="RU-CN" onclick="app.switchCountry('RU-CN')">
                    <span style="font-size:22px;">🌏</span>
                    <span class="country-pick-label">Russia, China & North Asia</span>
                </button>
                <button class="country-pick" data-country="SA-SEA-OC" onclick="app.switchCountry('SA-SEA-OC')">
                    <span style="font-size:22px;">🌏</span>
                    <span class="country-pick-label">South Asia, SE Asia & Oceania</span>
                </button>
            </div>


            <div id="topCitiesPresetPanel" data-legacy-id="topUsCitiesPanel" style="display:none;margin:0 0 14px;padding:12px 14px;border:1px solid var(--card-border);border-radius:10px;background:var(--bg-secondary);">
                <div style="display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:8px;flex-wrap:wrap;">
                    <div style="font-size:13px;font-weight:600;color:var(--text-primary);display:flex;align-items:center;gap:6px;">
                        <i class="fas fa-city" style="color:var(--accent);"></i>
                        <span id="topCitiesPresetTitle">Top US Cities (presets)</span>
                    </div>
                    <div style="font-size:11px;color:var(--text-tertiary);" id="topCitiesPresetHint">One-click load — selects states + cities automatically.</div>
                </div>
                <div style="display:flex;gap:6px;flex-wrap:wrap;">
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="100" onclick="app.selectTopCities(100)">Top 100</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="200" onclick="app.selectTopCities(200)">Top 200</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="300" onclick="app.selectTopCities(300)">Top 300</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="400" onclick="app.selectTopCities(400)">Top 400</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="500" onclick="app.selectTopCities(500)">Top 500</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="1000" onclick="app.selectTopCities(1000)">Top 1,000</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="2000" onclick="app.selectTopCities(2000)">Top 2,000</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="3000" onclick="app.selectTopCities(3000)">Top 3,000</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="5000" onclick="app.selectTopCities(5000)">Top 5,000</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="10000" onclick="app.selectTopCities(10000)">Top 10,000</button>
                    <button type="button" class="top-city-preset-pill top-us-city-pill" data-topuslimit="clear" onclick="app.selectTopCities(0)" title="Clear preset selection" style="margin-left:auto;background:transparent;color:var(--text-secondary);border-color:var(--card-border);">Clear preset</button>
                </div>
                <div id="topCitiesPresetStatus" style="margin-top:8px;font-size:12px;color:var(--text-secondary);min-height:16px;"></div>
            </div>
            <div class="selector-grid">
                <div class="selector-panel">
                    <div class="selector-header">
                        <span id="statesLabel">States</span>
                        <label class="selector-item" style="padding:0;margin:0;">
                            <input type="checkbox" id="selectAllStates" onchange="app.toggleAllStates(this.checked)">
                            <span style="font-size:12px;">All</span>
                        </label>
                    </div>
                    <div style="padding:6px 8px;border-bottom:1px solid var(--card-border);">
                        <input type="text" id="stateSearch" placeholder="Search states..." oninput="app.filterStates()" style="width:100%;padding:6px 10px;border:1px solid var(--card-border);border-radius:6px;font-size:13px;font-family:inherit;outline:none;background:var(--bg);">
                    </div>
                    <div class="selector-list" id="statesList"></div>
                </div>
                <div class="selector-panel">
                    <div class="selector-header" style="gap:6px;flex-wrap:wrap;">
                        <span>Cities <span id="citiesCount" style="color:var(--text-tertiary);font-weight:400;"></span></span>
                        <div style="display:flex;gap:3px;align-items:center;margin-left:auto;">
                            <button class="city-filter-pill active" data-cityfilter="all" onclick="app.setCityFilter('all')">All</button>
                            <button class="city-filter-pill" data-cityfilter="searched" onclick="app.setCityFilter('searched')">Searched</button>
                            <button class="city-filter-pill" data-cityfilter="unsearched" onclick="app.setCityFilter('unsearched')">New</button>
                            <label class="selector-item" style="padding:0;margin:0 0 0 4px;">
                                <input type="checkbox" id="selectAllCities" onchange="app.toggleAllCities(this.checked)">
                                <span style="font-size:11px;">Select All</span>
                            </label>
                        </div>
                        <div style="display:flex;gap:3px;align-items:center;width:100%;margin-top:4px;">
                            <span style="font-size:11px;color:var(--text-tertiary);margin-right:4px;">Sort:</span>
                            <button class="city-filter-pill active" data-citysort="name" onclick="app.setCitySort('name')">A-Z</button>
                            <button class="city-filter-pill" data-citysort="pop_desc" onclick="app.setCitySort('pop_desc')">Most Pop</button>
                            <button class="city-filter-pill" data-citysort="pop_asc" onclick="app.setCitySort('pop_asc')">Least Pop</button>
                        </div>
                    </div>
                    <div style="padding:6px 8px;border-bottom:1px solid var(--card-border);">
                        <input type="text" id="citySearch" placeholder="Search cities..." oninput="app.filterCities()" style="width:100%;padding:6px 10px;border:1px solid var(--card-border);border-radius:6px;font-size:13px;font-family:inherit;outline:none;background:var(--bg);">
                    </div>
                    <div class="selector-list" id="citiesList">
                        <div style="padding:20px;text-align:center;color:var(--text-tertiary);font-size:13px;">Select a state or region to see cities</div>
                    </div>
                </div>
            </div>

            <div style="margin-top:16px;display:flex;align-items:center;justify-content:space-between;">
                <div style="font-size:13px;color:var(--text-secondary);">
                    <span id="selectedCitiesCount">0</span> cities selected &middot;
                    Estimated cost: <strong style="color:var(--accent);"><span id="estimatedCredits">0</span> credits</strong>
                </div>
            </div>

            <div id="scrapeProgress" class="progress-container hidden">
                <div id="scrapeQueueStatus" style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px;font-size:12px;color:var(--text-secondary);"></div>
                <!-- [LANE-UI] Active Run Progress Lanes (Core-style 4 horizontal tiles).
                     Tile internals use .lane-status / .lane-fill / .lane-text so the
                     Core anchor names exist in Music too. -->
                <div id="laneProgressSection" style="margin-bottom:16px;background:var(--bg-secondary);padding:12px;border-radius:10px;border:1px solid var(--card-border);">
                    <h4 style="margin:0 0 10px;font-size:13px;font-weight:600;color:var(--text-primary);">Active Search Progress</h4>
                    <div id="laneProgressContainer"></div>
                </div>
                <div style="margin-bottom:16px;">
                    <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
                        <i class="fas fa-map-marker-alt" style="color:var(--accent);"></i>
                        <span style="font-size:13px;font-weight:600;">Step 1: Finding Leads</span>
                        <span id="scrapeStep1Status" style="margin-left:auto;font-size:12px;color:var(--text-secondary);"></span>
                    </div>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" id="scrapeProgressBar"></div>
                    </div>
                    <div class="progress-text">
                        <span id="scrapeProgressText">Starting...</span>
                        <span id="scrapeProgressCount"></span>
                    </div>
                    <div id="scrapeActivityLog" style="margin-top:10px;max-height:150px;overflow-y:auto;font-size:12px;background:var(--bg-secondary);border-radius:8px;padding:8px 10px;display:none;">
                    </div>
                </div>
                <div id="aiScrapeSection" style="opacity:0.4;">
                    <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
                        <i class="fas fa-robot" style="color:var(--purple);"></i>
                        <span style="font-size:13px;font-weight:600;">Step 2: AI Enrichment</span>
                        <span id="aiScrapeStatus" style="margin-left:auto;font-size:12px;color:var(--text-secondary);">Waiting...</span>
                    </div>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" id="aiProgressBar" style="background:var(--purple);"></div>
                    </div>
                    <div class="progress-text">
                        <span id="aiProgressText" style="font-size:12px;">Finding emails &amp; social media from each website using AI</span>
                        <span id="aiProgressCount" style="font-size:12px;"></span>
                    </div>
                </div>
            </div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-secondary" id="cancelScrapeBtn" onclick="app.closeAddLeadsModal()">Cancel</button>
            <button class="btn btn-primary" id="startScrapeBtn" onclick="app.startBulkScrape()"><i class="fas fa-rocket"></i> Start Search</button>
            <button class="btn btn-primary hidden" id="closeScrapeBtn" onclick="app.finishAndClose()"><i class="fas fa-check"></i> Done — Minimize</button>
        </div>
    </div>
</div>

<!-- LEAD DETAIL SLIDE PANEL -->
<div id="slideBackdrop" class="slide-backdrop" onclick="app.closeLeadDetail()"></div>
<div id="slidePanel" class="slide-panel">
    <div class="slide-header">
        <div>
            <div id="slideLeadName" style="font-size:20px;font-weight:700;"></div>
            <div id="slideLeadLocation" style="font-size:13px;color:var(--text-secondary);margin-top:4px;"></div>
        </div>
        <button class="btn-icon" onclick="app.closeLeadDetail()"><i class="fas fa-times"></i></button>
    </div>
    <div class="slide-body">
        <div id="slideGallerySection" class="slide-section hidden">
            <div id="slideGallery" style="display:flex;gap:6px;overflow-x:auto;padding-bottom:8px;"></div>
        </div>
        <div id="slideMapSection" class="slide-section hidden">
            <div id="slideMap" style="width:100%;height:200px;border-radius:var(--radius-xs);overflow:hidden;border:1px solid var(--card-border);"></div>
        </div>
        <div class="slide-section">
            <div class="slide-section-title">Contact Information</div>
            <div id="slideContact"></div>
        </div>
        <div class="slide-section">
            <div class="slide-section-title">Social Media</div>
            <div id="slideSocials"></div>
        </div>
        <div class="slide-section">
            <div class="slide-section-title">Notes</div>
            <textarea class="notes-area" id="slideNotes" placeholder="Add notes about this lead..."></textarea>
            <button class="btn btn-primary btn-sm" style="margin-top:8px;" onclick="app.saveNotes()"><i class="fas fa-save"></i> Save Notes</button>
        </div>
        <div class="slide-section">
            <div class="slide-section-title">Details</div>
            <div id="slideDetails"></div>
        </div>
        <div class="slide-section">
            <div class="slide-section-title">Lead Score</div>
            <div id="slideScoreWidget" style="display:flex;align-items:center;gap:14px;padding:4px 0;"></div>
            <div id="slideScoreBreakdown" style="margin-top:8px;display:none;"></div>
        </div>
        <div class="hidden">
            <select id="slidePipelineStage"></select>
            <input type="checkbox" id="slideOutreachEmail">
            <input type="checkbox" id="slideOutreachInstagram">
            <div id="slideFollowUpDots"></div>
            <span id="slideFollowUpLabel"></span>
            <div id="slideFirstContact"></div>
        </div>
    </div>
</div>

<!-- EXPORT PREVIEW MODAL -->
<div id="exportPreviewModal" class="modal-overlay">
    <div class="modal" style="max-width:640px;">
        <div class="modal-header">
            <h2 id="exportPreviewTitle">Export Preview</h2>
            <button class="btn-icon" onclick="app.closeExportPreview()"><i class="fas fa-times"></i></button>
        </div>
        <div class="modal-body" style="max-height:60vh;overflow-y:auto;">
            <div id="exportPreviewSummary" style="margin-bottom:16px;"></div>
            <div id="exportPreviewTable" style="max-height:320px;overflow-y:auto;border:1px solid var(--card-border);border-radius:var(--radius-xs);"></div>
        </div>
        <div class="modal-footer" style="flex-direction:column;gap:12px;">
            <div id="exportPreviewActions" style="display:flex;gap:8px;width:100%;justify-content:flex-end;"></div>
        </div>
    </div>
</div>

<!-- IMPORT PREVIEW MODAL -->
<div id="importPreviewModal" class="modal-overlay">
    <div class="modal" style="max-width:min(92vw,1120px);">
        <div class="modal-header">
            <h2 id="importPreviewTitle">Import CSV</h2>
            <button class="btn-icon" onclick="app.closeImportPreview()"><i class="fas fa-times"></i></button>
        </div>
        <div class="modal-body">
            <div class="import-summary-grid">
                <div class="import-summary-card">
                    <div class="import-summary-label">File</div>
                    <div class="import-summary-value" id="importFileName">-</div>
                </div>
                <div class="import-summary-card">
                    <div class="import-summary-label">Rows Found</div>
                    <div class="import-summary-value" id="importRowCount">0</div>
                </div>
                <div class="import-summary-card">
                    <div class="import-summary-label">Import Into</div>
                    <div class="import-summary-value" id="importTargetList">-</div>
                </div>
            </div>
            <div class="import-note" id="importPreviewNote">Showing the first 100 rows with all columns. The import will process all rows.</div>
            <div id="importPreviewTable" class="import-preview-table-wrap"></div>
            <div id="importProgress" class="import-status hidden">
                <div class="import-spinner"></div>
                <div>
                    <div style="font-size:14px;font-weight:700;color:var(--text);">Uploading and processing CSV...</div>
                    <div style="font-size:12px;color:var(--text-secondary);margin-top:2px;">Please wait while we process your CSV.</div>
                </div>
            </div>
            <div id="importCompletion" class="hidden"></div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-secondary" id="cancelImportBtn" onclick="app.closeImportPreview()">Cancel</button>
            <button class="btn btn-primary" id="confirmImportBtn" onclick="app.confirmImport()">
                <i class="fas fa-upload"></i> <span id="confirmImportBtnText">Import Rows</span>
            </button>
        </div>
    </div>
</div>

<!-- GHL FULL EXPORT -->
<div id="ghlExportOverlay" class="ghl-overlay">
    <div class="ghl-panel">
        <div class="ghl-panel-header">
            <div style="display:flex;align-items:center;gap:12px;">
                <button class="btn-icon" onclick="app.closeGHLExport()" title="Close"><i class="fas fa-arrow-left"></i></button>
                <div>
                    <h2 style="margin:0;font-size:18px;font-weight:700;">Export to GoHighLevel</h2>
                    <div id="ghlSubtitle" style="font-size:12px;color:var(--text-secondary);margin-top:2px;"></div>
                </div>
            </div>
            <div style="display:flex;align-items:center;gap:8px;">
                <span id="ghlConnectionBadge" style="font-size:11px;padding:4px 10px;border-radius:99px;font-weight:600;"></span>
                <button class="btn btn-sm" onclick="app.openGHLSettings()" style="font-size:12px;padding:5px 12px;"><i class="fas fa-cog"></i> Settings</button>
            </div>
        </div>

        <!-- SETUP / PICK CONNECTION SCREEN -->
        <div id="ghlSetupScreen" class="ghl-screen">
            <div style="max-width:520px;margin:40px auto;">
                <div style="text-align:center;margin-bottom:28px;">
                    <div style="width:64px;height:64px;border-radius:50%;background:linear-gradient(135deg,#FF6B35,#FF3B30);display:flex;align-items:center;justify-content:center;margin:0 auto 16px;">
                        <i class="fas fa-plug" style="font-size:24px;color:#fff;"></i>
                    </div>
                    <h2 style="margin:0 0 6px;font-size:22px;">GoHighLevel Connections</h2>
                    <p style="color:var(--text-secondary);font-size:13px;margin:0;">Select a connection or add a new one.</p>
                </div>

                <div id="ghlConnectionsList" style="margin-bottom:20px;"></div>

                <div id="ghlAddConnectionForm" class="hidden" style="background:var(--bg);border:1px solid var(--card-border);border-radius:12px;padding:20px;margin-bottom:16px;">
                    <div style="font-size:14px;font-weight:700;margin-bottom:14px;"><i class="fas fa-plus-circle" style="color:var(--accent);margin-right:6px;"></i>New Connection</div>
                    <div class="form-group" style="margin-bottom:12px;">
                        <label style="font-size:12px;font-weight:600;margin-bottom:4px;display:block;">Connection Name</label>
                        <input type="text" id="ghlSetupName" placeholder="e.g. My Agency, Client XYZ..." style="width:100%;padding:10px 14px;border:1px solid var(--card-border);border-radius:8px;font-size:14px;font-family:inherit;background:#fff;outline:none;">
                    </div>
                    <div class="form-group" style="margin-bottom:12px;">
                        <label style="font-size:12px;font-weight:600;margin-bottom:4px;display:block;">API Key</label>
                        <input type="password" id="ghlSetupKey" placeholder="eyJhbGciOi..." style="width:100%;padding:10px 14px;border:1px solid var(--card-border);border-radius:8px;font-size:14px;font-family:inherit;background:#fff;outline:none;">
                    </div>
                    <div class="form-group" style="margin-bottom:14px;">
                        <label style="font-size:12px;font-weight:600;margin-bottom:4px;display:block;">Location ID</label>
                        <input type="text" id="ghlSetupLocation" placeholder="abc123..." style="width:100%;padding:10px 14px;border:1px solid var(--card-border);border-radius:8px;font-size:14px;font-family:inherit;background:#fff;outline:none;">
                    </div>
                    <details style="margin-bottom:14px;">
                        <summary style="font-size:12px;color:var(--accent);cursor:pointer;font-weight:600;"><i class="fas fa-shield-alt" style="margin-right:4px;"></i>Required API Scopes & Setup Help</summary>
                        <div style="margin-top:8px;padding:12px;background:#fff;border:1px solid var(--card-border);border-radius:8px;">
                            <div style="display:flex;flex-wrap:wrap;gap:4px;margin-bottom:10px;">
                                <span style="padding:3px 8px;border-radius:5px;font-size:10px;font-weight:600;background:#DCFCE7;color:#166534;">contacts.readonly</span>
                                <span style="padding:3px 8px;border-radius:5px;font-size:10px;font-weight:600;background:#DCFCE7;color:#166534;">contacts.write</span>
                                <span style="padding:3px 8px;border-radius:5px;font-size:10px;font-weight:600;background:#DBEAFE;color:#1E40AF;">locations/tags.readonly</span>
                                <span style="padding:3px 8px;border-radius:5px;font-size:10px;font-weight:600;background:#DBEAFE;color:#1E40AF;">locations/tags.write</span>
                                <span style="padding:3px 8px;border-radius:5px;font-size:10px;font-weight:600;background:#FEF3C7;color:#92400E;">workflows.readonly</span>
                            </div>
                            <div style="font-size:11px;color:var(--text-secondary);line-height:1.6;">
                                <strong>1.</strong> Settings → Integrations → API Keys in GHL<br>
                                <strong>2.</strong> Create key with scopes above<br>
                                <strong>3.</strong> Location ID is in your URL: <code style="background:var(--card-border);padding:1px 4px;border-radius:3px;font-size:10px;">app.gohighlevel.com/v2/location/<strong>ID</strong>/...</code>
                            </div>
                        </div>
                    </details>
                    <div style="display:flex;gap:8px;">
                        <button class="btn btn-primary" onclick="app.connectGHL()" style="flex:1;padding:10px;font-size:14px;font-weight:600;"><i class="fas fa-bolt"></i> Connect</button>
                        <button class="btn btn-secondary" onclick="document.getElementById('ghlAddConnectionForm').classList.add('hidden')" style="padding:10px 16px;font-size:14px;">Cancel</button>
                    </div>
                </div>

                <button class="btn btn-secondary" onclick="document.getElementById('ghlAddConnectionForm').classList.remove('hidden')" style="width:100%;padding:12px;font-size:14px;border:2px dashed var(--card-border);background:transparent;"><i class="fas fa-plus"></i> Add New Connection</button>
            </div>
        </div>

        <!-- MAIN EDITOR SCREEN -->
        <div id="ghlEditorScreen" class="ghl-screen hidden">
            <div class="ghl-toolbar">
                <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
                    <select id="ghlConnectionPicker" onchange="app.switchGHLConnection()" style="padding:7px 12px;border:1px solid var(--accent);border-radius:6px;font-size:13px;font-family:inherit;background:var(--bg);outline:none;font-weight:600;color:var(--accent);max-width:180px;">
                    </select>
                    <input type="text" id="ghlSearchInput" placeholder="Search leads..." oninput="app.filterGHLLeads()" style="padding:7px 12px;border:1px solid var(--card-border);border-radius:6px;font-size:13px;font-family:inherit;width:200px;background:var(--bg);outline:none;">
                    <select id="ghlFilterSelect" onchange="app.filterGHLLeads()" style="padding:7px 12px;border:1px solid var(--card-border);border-radius:6px;font-size:13px;font-family:inherit;background:var(--bg);outline:none;">
                        <option value="all">All Leads</option>
                        <option value="has_email">Has Email</option>
                        <option value="has_phone">Has Phone</option>
                        <option value="has_both">Email & Phone</option>
                    </select>
                    <select id="ghlImportFilter" onchange="app.filterGHLLeads()" style="padding:7px 12px;border:1px solid var(--card-border);border-radius:6px;font-size:13px;font-family:inherit;background:var(--bg);outline:none;">
                        <option value="any">Any Import Status</option>
                        <option value="not_imported">Not Previously Imported</option>
                        <option value="previously_imported">Previously Imported</option>
                    </select>
                    <span id="ghlLeadCount" style="font-size:12px;color:var(--text-secondary);font-weight:600;"></span>
                </div>
                <div style="display:flex;align-items:center;gap:8px;">
                    <button class="btn btn-sm" onclick="app.ghlSelectAll()" style="font-size:12px;"><i class="fas fa-check-double"></i> Select All</button>
                    <button class="btn btn-sm" onclick="app.ghlDeselectAll()" style="font-size:12px;"><i class="fas fa-times"></i> Deselect All</button>
                </div>
            </div>

            <div class="ghl-spreadsheet-wrap">
                <table class="ghl-spreadsheet" id="ghlSpreadsheet">
                    <thead>
                        <tr>
                            <th style="width:40px;"><input type="checkbox" id="ghlSelectAllCb" onchange="app.ghlToggleSelectAll(this.checked)"></th>
                            <th>First Name</th>
                            <th>Last Name</th>
                            <th>Company</th>
                            <th>Email</th>
                            <th>Phone</th>
                            <th>City</th>
                            <th>State</th>
                            <th>Website</th>
                            <th>Socials</th>
                        </tr>
                    </thead>
                    <tbody id="ghlSpreadsheetBody"></tbody>
                </table>
            </div>

            <div class="ghl-bottom-bar">
                <div class="ghl-config-section">
                    <div class="ghl-config-group">
                        <label><i class="fas fa-tags"></i> Tags</label>
                        <div id="ghlTagsArea" style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;">
                            <div id="ghlSelectedTags" style="display:flex;flex-wrap:wrap;gap:4px;"></div>
                            <div style="position:relative;">
                                <input type="text" id="ghlTagInput" placeholder="Add tag..." oninput="app.filterGHLTags()" onfocus="app.showGHLTagDropdown()" style="padding:5px 10px;border:1px solid var(--card-border);border-radius:6px;font-size:12px;width:140px;background:var(--bg);outline:none;">
                                <div id="ghlTagDropdown" class="ghl-dropdown hidden"></div>
                            </div>
                        </div>
                    </div>
                    <div class="ghl-config-group">
                        <label><i class="fas fa-project-diagram"></i> Workflow</label>
                        <select id="ghlWorkflowSelect" style="padding:6px 10px;border:1px solid var(--card-border);border-radius:6px;font-size:12px;background:var(--bg);outline:none;min-width:200px;">
                            <option value="">No workflow</option>
                        </select>
                    </div>
                </div>
                <div style="display:flex;align-items:center;gap:12px;flex-wrap:wrap;">
                    <div id="ghlSummaryText" style="font-size:13px;color:var(--text-secondary);"></div>
                    <button class="btn btn-sm" onclick="app.openGHLDripConfig()" style="font-size:12px;" title="Drip / Schedule"><i class="fas fa-clock"></i> Drip</button>
                    <button class="btn btn-sm" onclick="app.showGHLImportLogs()" style="font-size:12px;" title="Import History"><i class="fas fa-history"></i> Logs</button>
                    <button class="btn btn-primary" id="ghlImportBtn" onclick="app.startGHLImport()" style="padding:10px 24px;font-size:14px;font-weight:700;white-space:nowrap;"><i class="fas fa-paper-plane"></i> Import to GHL</button>
                </div>
            </div>
        </div>

        <!-- IMPORTING SCREEN -->
        <div id="ghlImportingScreen" class="ghl-screen hidden">
            <div style="max-width:520px;margin:40px auto;text-align:center;">
                <div id="ghlImportSpinner" style="margin-bottom:20px;">
                    <div style="width:80px;height:80px;border-radius:50%;border:4px solid var(--card-border);border-top-color:var(--accent);animation:spin 0.8s linear infinite;margin:0 auto;"></div>
                </div>
                <h2 id="ghlImportTitle" style="margin:0 0 6px;font-size:20px;">Importing to GoHighLevel...</h2>
                <p id="ghlImportSubtitle" style="color:var(--text-secondary);margin:0 0 24px;font-size:13px;">Please wait, this may take a few minutes for large lists.</p>
                <div style="background:var(--bg);border-radius:12px;padding:16px;border:1px solid var(--card-border);">
                    <div style="display:flex;justify-content:space-between;font-size:13px;margin-bottom:8px;">
                        <span id="ghlImportProgressLabel">0 of 0</span>
                        <span id="ghlImportPct">0%</span>
                    </div>
                    <div style="height:8px;background:var(--card-border);border-radius:99px;overflow:hidden;">
                        <div id="ghlImportBar" style="height:100%;background:var(--accent);border-radius:99px;width:0%;transition:width 0.3s;"></div>
                    </div>
                    <div style="display:flex;gap:20px;margin-top:14px;justify-content:center;">
                        <div style="text-align:center;"><div id="ghlStatNew" style="font-size:20px;font-weight:700;color:var(--green);">0</div><div style="font-size:11px;color:var(--text-tertiary);">New</div></div>
                        <div style="text-align:center;"><div id="ghlStatUpdated" style="font-size:20px;font-weight:700;color:var(--blue);">0</div><div style="font-size:11px;color:var(--text-tertiary);">Updated</div></div>
                        <div style="text-align:center;"><div id="ghlStatFailed" style="font-size:20px;font-weight:700;color:var(--red);">0</div><div style="font-size:11px;color:var(--text-tertiary);">Failed</div></div>
                    </div>
                </div>
                <div style="display:flex;gap:8px;justify-content:center;margin-top:16px;">
                    <button class="btn btn-sm" id="ghlPauseBtn" onclick="app.pauseCurrentImport()" style="font-size:12px;"><i class="fas fa-pause"></i> Pause</button>
                    <button class="btn btn-sm" id="ghlCancelImportBtn" onclick="app.cancelCurrentImport()" style="font-size:12px;color:var(--red);"><i class="fas fa-stop"></i> Cancel</button>
                </div>
            </div>
        </div>

        <!-- DONE SCREEN -->
        <div id="ghlDoneScreen" class="ghl-screen hidden">
            <canvas id="confettiCanvas" style="position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:1;"></canvas>
            <div style="max-width:520px;margin:40px auto;text-align:center;position:relative;z-index:2;">
                <div style="width:80px;height:80px;border-radius:50%;background:linear-gradient(135deg,#34C759,#30D158);display:flex;align-items:center;justify-content:center;margin:0 auto 20px;">
                    <i class="fas fa-check" style="font-size:36px;color:#fff;"></i>
                </div>
                <h2 style="margin:0 0 8px;font-size:24px;">Import Complete!</h2>
                <p id="ghlDoneSubtitle" style="color:var(--text-secondary);font-size:14px;margin:0 0 28px;"></p>
                <div style="background:var(--bg);border-radius:12px;padding:20px;border:1px solid var(--card-border);text-align:left;margin-bottom:24px;">
                    <div id="ghlDoneSummary" style="font-size:14px;line-height:1.8;"></div>
                </div>
                <div id="ghlDoneErrors" class="hidden" style="background:#FFF5F5;border:1px solid #FED7D7;border-radius:12px;padding:16px;text-align:left;margin-bottom:24px;max-height:150px;overflow-y:auto;">
                    <div style="font-size:13px;font-weight:600;color:var(--red);margin-bottom:8px;"><i class="fas fa-exclamation-triangle"></i> Some contacts had errors:</div>
                    <div id="ghlDoneErrorList" style="font-size:12px;color:#666;"></div>
                </div>
                <button class="btn btn-primary" onclick="app.closeGHLExport()" style="padding:12px 32px;font-size:15px;font-weight:600;"><i class="fas fa-check"></i> Done</button>
            </div>
        </div>

        <!-- SETTINGS SLIDE -->
        <div id="ghlSettingsSlide" class="ghl-settings-slide hidden">
            <div style="padding:24px;">
                <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
                    <h3 style="margin:0;font-size:16px;"><i class="fas fa-cog" style="color:var(--accent);margin-right:6px;"></i>Manage Connections</h3>
                    <button class="btn-icon" onclick="app.closeGHLSettings()"><i class="fas fa-times"></i></button>
                </div>
                <div id="ghlSettingsConnectionsList" style="margin-bottom:16px;"></div>
                <button class="btn btn-secondary" onclick="app.showGHLScreen('ghlSetupScreen');app.closeGHLSettings();" style="width:100%;padding:10px;font-size:13px;border:2px dashed var(--card-border);background:transparent;"><i class="fas fa-plus"></i> Add Connection</button>
                <hr style="border:0;border-top:1px solid var(--card-border);margin:24px 0;">
                <div style="margin-bottom:20px;">
                    <h3 style="margin:0 0 12px;font-size:14px;font-weight:600;"><i class="fas fa-shield-alt" style="color:var(--accent);margin-right:6px;"></i>Scraper Queue Status</h3>
                    <div style="display:flex;align-items:center;justify-content:space-between;background:var(--bg);border:1px solid var(--card-border);border-radius:12px;padding:16px;">
                        <div>
                            <div style="font-size:13px;font-weight:600;" id="scraperStatusText">Loading...</div>
                            <div style="font-size:11px;color:var(--text-tertiary);margin-top:4px;" id="scraperPauseReason"></div>
                        </div>
                        <button class="btn btn-sm btn-secondary" id="btnToggleScraper" onclick="app.toggleScraper()" style="font-size:12px;padding:6px 16px;font-weight:600;">Toggle</button>
                    </div>
                </div>
            </div>
        </div>

        <!-- DRIP CONFIG SLIDE -->
        <div id="ghlDripSlide" class="ghl-settings-slide hidden">
            <div style="padding:24px;">
                <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
                    <h3 style="margin:0;font-size:16px;"><i class="fas fa-clock" style="color:var(--accent);margin-right:6px;"></i>Drip Schedule</h3>
                    <button class="btn-icon" onclick="document.getElementById('ghlDripSlide').classList.add('hidden')"><i class="fas fa-times"></i></button>
                </div>
                <p style="font-size:12px;color:var(--text-secondary);margin:0 0 16px;">Send contacts in batches over time instead of all at once. Great for large lists.</p>
                <div style="margin-bottom:16px;">
                    <label style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;cursor:pointer;">
                        <input type="checkbox" id="ghlDripEnabled" onchange="app.toggleDripFields()" style="accent-color:var(--accent);">
                        Enable drip scheduling
                    </label>
                </div>
                <div id="ghlDripFields" class="hidden">
                    <div class="form-group" style="margin-bottom:14px;">
                        <label style="font-size:12px;font-weight:600;margin-bottom:4px;display:block;">Batch Size</label>
                        <input type="number" id="ghlDripBatch" value="50" min="1" max="500" style="width:100%;padding:10px 14px;border:1px solid var(--card-border);border-radius:8px;font-size:13px;font-family:inherit;background:var(--bg);outline:none;">
                        <div style="font-size:11px;color:var(--text-tertiary);margin-top:4px;">Contacts per batch</div>
                    </div>
                    <div class="form-group" style="margin-bottom:14px;">
                        <label style="font-size:12px;font-weight:600;margin-bottom:4px;display:block;">Interval Between Batches</label>
                        <select id="ghlDripInterval" style="width:100%;padding:10px 14px;border:1px solid var(--card-border);border-radius:8px;font-size:13px;font-family:inherit;background:var(--bg);outline:none;">
                            <option value="15">Every 15 minutes</option>
                            <option value="30">Every 30 minutes</option>
                            <option value="60" selected>Every 1 hour</option>
                            <option value="120">Every 2 hours</option>
                            <option value="240">Every 4 hours</option>
                            <option value="480">Every 8 hours</option>
                            <option value="1440">Every 24 hours</option>
                        </select>
                    </div>
                    <div class="form-group" style="margin-bottom:14px;">
                        <label style="font-size:12px;font-weight:600;margin-bottom:4px;display:block;">Timezone</label>
                        <select id="ghlDripTimezone" style="width:100%;padding:10px 14px;border:1px solid var(--card-border);border-radius:8px;font-size:13px;font-family:inherit;background:var(--bg);outline:none;">
                            <option value="America/New_York">Eastern (ET)</option>
                            <option value="America/Chicago">Central (CT)</option>
                            <option value="America/Denver">Mountain (MT)</option>
                            <option value="America/Los_Angeles">Pacific (PT)</option>
                            <option value="America/Anchorage">Alaska (AKT)</option>
                            <option value="Pacific/Honolulu">Hawaii (HT)</option>
                            <option value="Europe/London">London (GMT)</option>
                            <option value="Europe/Paris">Central Europe (CET)</option>
                            <option value="Asia/Tokyo">Tokyo (JST)</option>
                            <option value="Australia/Sydney">Sydney (AEST)</option>
                        </select>
                    </div>
                    <div class="form-group" style="margin-bottom:14px;">
                        <label style="font-size:12px;font-weight:600;margin-bottom:4px;display:block;">Send Time (optional — first batch starts at this time)</label>
                        <div style="display:flex;gap:8px;">
                            <select id="ghlDripHour" style="flex:1;padding:10px 14px;border:1px solid var(--card-border);border-radius:8px;font-size:13px;background:var(--bg);outline:none;">
                                <option value="">Any time</option>
                                <option value="6">6:00 AM</option>
                                <option value="7">7:00 AM</option>
                                <option value="8">8:00 AM</option>
                                <option value="9" selected>9:00 AM</option>
                                <option value="10">10:00 AM</option>
                                <option value="11">11:00 AM</option>
                                <option value="12">12:00 PM</option>
                                <option value="13">1:00 PM</option>
                                <option value="14">2:00 PM</option>
                                <option value="15">3:00 PM</option>
                                <option value="16">4:00 PM</option>
                                <option value="17">5:00 PM</option>
                            </select>
                        </div>
                        <div style="font-size:11px;color:var(--text-tertiary);margin-top:4px;">Emails sent at proper local time for your recipients</div>
                    </div>
                </div>
                <button class="btn btn-primary" onclick="document.getElementById('ghlDripSlide').classList.add('hidden')" style="width:100%;padding:10px;font-size:14px;margin-top:8px;"><i class="fas fa-check"></i> Save Drip Settings</button>
            </div>
        </div>

        <!-- IMPORT LOGS SLIDE -->
        <div id="ghlLogsSlide" class="ghl-settings-slide hidden" style="width:520px;">
            <div style="padding:24px;">
                <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
                    <h3 style="margin:0;font-size:16px;"><i class="fas fa-history" style="color:var(--accent);margin-right:6px;"></i>Import History</h3>
                    <button class="btn-icon" onclick="document.getElementById('ghlLogsSlide').classList.add('hidden')"><i class="fas fa-times"></i></button>
                </div>
                <div id="ghlLogsContent" style="font-size:13px;">
                    <div style="text-align:center;padding:30px;color:var(--text-tertiary);"><i class="fas fa-spinner fa-spin"></i> Loading...</div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- IMPORT LOGS MODAL -->
<div id="importLogsModal" class="modal-overlay">
    <div style="background:var(--card-solid);border-radius:16px;width:90%;max-width:700px;max-height:85vh;display:flex;flex-direction:column;overflow:hidden;box-shadow:0 24px 80px rgba(0,0,0,0.25);">
        <div style="padding:16px 20px;border-bottom:1px solid var(--card-border);display:flex;align-items:center;justify-content:space-between;flex-shrink:0;">
            <div style="display:flex;align-items:center;gap:10px;">
                <i class="fas fa-history" style="color:var(--accent);font-size:18px;"></i>
                <h3 style="margin:0;font-size:16px;">GHL Import History</h3>
            </div>
            <button class="btn-icon" onclick="document.getElementById('importLogsModal').classList.remove('active')"><i class="fas fa-times"></i></button>
        </div>
        <div id="importLogsModalContent" style="flex:1;overflow-y:auto;padding:20px;">
            <div style="text-align:center;padding:30px;color:var(--text-tertiary);"><i class="fas fa-spinner fa-spin"></i> Loading...</div>
        </div>
    </div>
</div>

<!-- TOAST -->
<div id="toast" class="toast"></div>

<script>
const FOLDER_COLORS = ['folder-blue','folder-purple','folder-green','folder-orange','folder-pink','folder-red','folder-teal','folder-yellow','folder-brown','folder-gray','folder-gold'];
const FOLDER_ICONS = ['fa-briefcase','fa-heart-pulse','fa-user-doctor','fa-building','fa-store','fa-star'];
const INITIAL_CATEGORY_GROUP = <?php echo json_encode($selectedCategoryGroup); ?>;
const INITIAL_CATEGORY = <?php echo json_encode($selectedCategory); ?>;
const CATEGORY_LIST_ALIASES = {
    'Doctors': ['Doctors', 'Medical Clinics'],
    'Medical Clinics': ['Medical Clinics', 'Doctors'],
    'Law Firms': ['Law Firms', 'Lawyers'],
    'Accounting Firms': ['Accounting Firms', 'CPAs'],
    'Fire Departments': ['Fire Departments', 'Fire Station'],
    'Police Departments': ['Police Departments', 'Police Station'],
    'Gas Stations': ['Gas Stations', 'Petrol Stations'],
    'Petrol Stations': ['Petrol Stations', 'Gas Stations']
};
const HD2_CATEGORIES = {
    'Healthcare': ['Medical Clinics','Walk-in Clinics','Urgent Care','Family Medicine','Doctors','Dentists','Orthodontists','Oral Surgeons','Dermatologists','Plastic Surgeons','Optometrists','Chiropractors','Physical Therapists','Pharmacies','Med Spas','Wellness Clinics','Senior Living'],
    'Legal': ['Law Firms','Lawyers','Solo Attorneys','Personal Injury','Criminal Defense','Family Law','Immigration Law','Bankruptcy Law','Employment Law','Real Estate Law'],
    'Financial': ['Accounting Firms','CPAs','Financial Advisors','Insurance Agencies','Mortgage Brokers','Bookkeepers','Tax Preparation','Investment Firms','Credit Unions','Banks'],
    'Home Services': ['HVAC Contractors','Plumbers','Electricians','Roofers','Landscapers','Pest Control','Solar Installers','Pool Services','Cleaning Services','General Contractors','Painters','Handymen'],
    'Automotive': ['New Car Dealers','Used Car Dealers','Auto Repair Shops','Quick Lube Shops','Tire Shops','Auto Body Shops','Car Dealerships','Fleet Service Providers','Car Stereo Shops','Auto Detailers','Towing Companies','Gas Stations','Petrol Stations'],
    'Technology': ['SaaS Companies','Software Companies','MSPs','IT Services','Web Development Agencies','Mobile App Developers','Cybersecurity Firms','AI Companies','Data Centers','Cloud Providers'],
    'Professional Services': ['Recruiters','Marketing Agencies','SEO Agencies','Business Consultants','HR Consultants','Staffing Agencies','Virtual Assistants','Property Managers','Realtors','Commercial Brokers'],
    'Consumer & Retail': ['Restaurants','Cafes','Bars','Nightclubs','Gyms','Fitness Centers','Salons','Barbershops','Tattoo Studios','Smoke Shops','CBD Stores','Cannabis Businesses','Smoke Shops','Vape Shops'],
    'Government': ['Federal Agencies','State Agencies','County Governments','City Governments','Police Departments','Fire Departments','Fire Stations','Police Stations','Utility Providers','Public Works Departments','Building Departments','Transportation Authorities'],
    'Education': ['Universities','Colleges','Community Colleges','Public Schools','Private Schools','Charter Schools','Trade Schools','School Districts','Vocational Training Centers','Educational Foundations','Tutoring Centers'],
    'Religious': ['Churches','Catholic Parishes','Christian Ministries','Synagogues','Mosques','Temples','Faith-Based Schools','Religious Foundations','Religious Organizations'],
    'Manufacturing': ['Manufacturers','Factories','Fabricators','Machine Shops','Industrial Suppliers','Welding Companies','Packaging Companies','Electronics Manufacturers','GMP Manufacturers','Chemical Manufacturers'],
    'Agriculture': ['Farms','Nurseries','Greenhouses','Hemp Producers','Cannabis Cultivators','Seed Companies','Garden Centers','Agricultural Suppliers','Farm Equipment Dealers'],
    'Real Estate': ['Realtors','Property Managers','Commercial Brokers','Developers','Real Estate Investors','HOA Management Companies','Title Companies','Mortgage Brokers'],
    'Media': ['Radio Stations','Newspapers','Podcasts','Publishers','Online Media Companies','News Networks','Content Studios','PR Firms','Influencer Agencies','Marketing Agencies'],
    'Entertainment': ['Music Venues','Event Promoters','Festivals','Theaters','Concert Halls','Talent Agencies','Artist Management Companies','Production Companies','Record Labels','Booking Agencies'],
    'Construction': ['General Contractors','Civil Engineering Firms','Infrastructure Contractors','Heavy Equipment Companies','Road Construction Firms','Bridge Contractors','Excavation Companies','Concrete Contractors','Commercial Builders'],
    'Health & Fitness': ['Gyms','Fitness Centers','Salons','Hair Salons','Nail Salons','Spas','Med Spas','Wellness','Yoga Studios','Yoga','Personal Trainers','Fitness Coaches','Trainers'],
    'Pets & Animals': ['Veterinarians','Vets','Pet Clinics','Pet Stores','Pet Shops','Pet Grooming','Dog Walkers','Animal Rescues','Dog Groomers','Animal Hospitals'],
    'Wholesale & Supermarkets': ['Supermarkets','Wholesalers','Grocery Stores','Food Wholesalers','Wholesale Distributors','Supermarket Chain','Food Wholesaler']
};
const CATEGORY_HIERARCHY = {
    'Healthcare': [
        { name: 'Clinics', icon: 'fa-house-medical', categories: ['Medical Clinics', 'Walk-in Clinics', 'Urgent Care', 'Family Medicine'] },
        { name: 'GPs', icon: 'fa-user-doctor', categories: ['Doctors'] },
        { name: 'Dentists', icon: 'fa-tooth', categories: ['Dentists', 'Orthodontists', 'Oral Surgeons'] },
        { name: 'Derm', icon: 'fa-hand-sparkles', categories: ['Dermatologists', 'Plastic Surgeons'] },
        { name: 'Pharma', icon: 'fa-pills', categories: ['Pharmacies'] },
        { name: 'Specialists', icon: 'fa-stethoscope', categories: ['Optometrists', 'Chiropractors', 'Physical Therapists'] },
        { name: 'Wellness', icon: 'fa-spa', categories: ['Wellness Clinics', 'Med Spas'] },
        { name: 'Senior Living', icon: 'fa-user-nurse', categories: ['Senior Living'] }
    ],
    'Technology': [
        { name: 'IT Services', icon: 'fa-server', categories: ['MSPs', 'IT Services'] },
        { name: 'Software', icon: 'fa-code', categories: ['SaaS', 'Software Companies'] },
        { name: 'Web Dev', icon: 'fa-laptop-code', categories: ['Web Development Agencies'] },
        { name: 'Cybersecurity', icon: 'fa-shield-halved', categories: ['Cybersecurity'] }
    ],
    'Professional Services': [
        { name: 'Legal', icon: 'fa-gavel', categories: ['Law Firms'] },
        { name: 'Financial', icon: 'fa-chart-line', categories: ['Accounting', 'Financial Advisors'] },
        { name: 'HR', icon: 'fa-users-gear', categories: ['Recruiters', 'Staffing Agencies'] },
        { name: 'Security', icon: 'fa-lock', categories: ['Security Companies'] }
    ],
    'Home Services': [
        { name: 'HVAC', icon: 'fa-fan', categories: ['HVAC', 'Heating & Cooling', 'Air Conditioning'] },
        { name: 'Plumbing', icon: 'fa-faucet-drip', categories: ['Plumbers', 'Plumbing'] },
        { name: 'Electrical', icon: 'fa-plug', categories: ['Electricians', 'Electrical'] },
        { name: 'Roofing', icon: 'fa-house-chimney', categories: ['Roofers', 'Roofing'] },
        { name: 'Landscaping', icon: 'fa-leaf', categories: ['Landscapers', 'Landscaping'] },
        { name: 'Pest Control', icon: 'fa-bug', categories: ['Pest Control'] },
        { name: 'Solar', icon: 'fa-solar-panel', categories: ['Solar Installers', 'Solar'] },
        { name: 'Cleaning', icon: 'fa-broom', categories: ['Cleaning Services', 'House Cleaning'] },
        { name: 'Contractors', icon: 'fa-hammer', categories: ['General Contractors', 'Builders'] }
    ],
    'Automotive': [
        { name: 'Auto Repair', icon: 'fa-wrench', categories: ['Auto Repair', 'Mechanics'] },
        { name: 'Car Dealers', icon: 'fa-car', categories: ['Car Dealers', 'Auto Dealers'] },
        { name: 'Tire Shops', icon: 'fa-circle-notch', categories: ['Tire Shops'] },
        { name: 'Auto Body', icon: 'fa-car-burst', categories: ['Auto Body', 'Collision Repair'] },
        { name: 'Towing', icon: 'fa-truck-pickup', categories: ['Towing', 'Roadside'] },
        { name: 'Gas Stations', icon: 'fa-gas-pump', categories: ['Gas Stations', 'Petrol Stations'] }
    ],
    'Legal': [
        { name: 'Law Firms', icon: 'fa-scale-balanced', categories: ['Law Firms', 'Lawyers'] },
        { name: 'Solo Attorneys', icon: 'fa-user', categories: ['Solo Attorneys', 'Solo Lawyer'] },
        { name: 'Personal Injury', icon: 'fa-person-running', categories: ['Personal Injury'] },
        { name: 'Immigration', icon: 'fa-passport', categories: ['Immigration'] }
    ],
    'Financial': [
        { name: 'Accounting', icon: 'fa-calculator', categories: ['Accounting', 'CPAs'] },
        { name: 'Advisors', icon: 'fa-chart-line', categories: ['Financial Advisors'] },
        { name: 'Insurance', icon: 'fa-shield', categories: ['Insurance'] },
        { name: 'Mortgage', icon: 'fa-landmark', categories: ['Mortgage Brokers', 'Lenders'] },
        { name: 'Banks', icon: 'fa-building-columns', categories: ['Banks', 'Credit Unions'] }
    ],
    'Real Estate': [
        { name: 'Realtors', icon: 'fa-home', categories: ['Realtors', 'Real Estate Agents'] },
        { name: 'Property Mgmt', icon: 'fa-building', categories: ['Property Managers'] },
        { name: 'Commercial', icon: 'fa-city', categories: ['Commercial Brokers'] },
        { name: 'Developers', icon: 'fa-trowel-bricks', categories: ['Developers', 'Home Builders'] }
    ],
    'Restaurants & Food': [
        { name: 'Restaurants', icon: 'fa-utensils', categories: ['Restaurants', 'Eateries'] },
        { name: 'Cafes', icon: 'fa-mug-hot', categories: ['Cafes', 'Coffee Shops'] },
        { name: 'Bars', icon: 'fa-champagne-glasses', categories: ['Bars', 'Pubs', 'Nightclubs'] },
        { name: 'Fast Food', icon: 'fa-burger', categories: ['Fast Food', 'Quick Service'] }
    ],
    'Health & Fitness': [
        { name: 'Gyms', icon: 'fa-dumbbell', categories: ['Gyms', 'Fitness Centers'] },
        { name: 'Salons', icon: 'fa-scissors', categories: ['Salons', 'Hair Salons', 'Nail Salons'] },
        { name: 'Spas', icon: 'fa-spa', categories: ['Spas', 'Med Spas', 'Wellness'] },
        { name: 'Yoga Studios', icon: 'fa-person-walking', categories: ['Yoga Studios', 'Yoga'] },
        { name: 'Personal Trainers', icon: 'fa-heart-pulse', categories: ['Personal Trainers', 'Fitness Coaches', 'Trainers'] }
    ],
    'Marketing & Media': [
        { name: 'Marketing', icon: 'fa-megaphone', categories: ['Marketing Agencies', 'Advertising'] },
        { name: 'SEO', icon: 'fa-search', categories: ['SEO Agencies', 'Digital Marketing'] },
        { name: 'Photographers', icon: 'fa-camera', categories: ['Photographers', 'Photography'] },
        { name: 'Content Creators', icon: 'fa-video', categories: ['Content Creators', 'Influencers'] }
    ],
    'Government': [
        { name: 'Police', icon: 'fa-shield-halved', categories: ['Police Departments', 'Police Station'] },
        { name: 'Fire', icon: 'fa-fire-extinguisher', categories: ['Fire Departments', 'Fire Station'] },
        { name: 'Schools', icon: 'fa-graduation-cap', categories: ['Schools', 'Education'] },
        { name: 'Municipal', icon: 'fa-landmark', categories: ['Municipal', 'City Hall'] }
    ],
    'Travel & Hospitality': [
        { name: 'Hotels', icon: 'fa-bed', categories: ['Hotels', 'Motels', 'Resorts'] },
        { name: 'Travel Agents', icon: 'fa-suitcase-rolling', categories: ['Travel Agencies', 'Tourism'] },
        { name: 'Event Venues', icon: 'fa-ticket', categories: ['Event Venues', 'Venues'] }
    ],
    'Pets & Animals': [
        { name: 'Veterinarians', icon: 'fa-paw', categories: ['Veterinarians', 'Vets', 'Pet Clinics'] },
        { name: 'Pet Stores', icon: 'fa-dog', categories: ['Pet Stores', 'Pet Shops'] },
        { name: 'Pet Services', icon: 'fa-bone', categories: ['Pet Grooming', 'Dog Walkers'] }
    ],
    'Retail & Ecommerce': [
        { name: 'Retail Stores', icon: 'fa-store', categories: ['Retail Stores', 'Shops'] },
        { name: 'CBD & Wellness', icon: 'fa-leaf', categories: ['CBD Stores', 'Wellness Retail'] },
        { name: 'Ecommerce', icon: 'fa-cart-shopping', categories: ['Ecommerce', 'Online Stores'] }
    ],
    'Logistics': [
        { name: 'Trucking', icon: 'fa-truck', categories: ['Trucking', 'Freight'] },
        { name: 'Warehouses', icon: 'fa-warehouse', categories: ['Warehouses', 'Storage'] },
        { name: 'Moving', icon: 'fa-boxes-stacked', categories: ['Moving Companies', 'Movers'] }
    ],
    'Agriculture': [
        { name: 'Farms', icon: 'fa-tractor', categories: ['Farms', 'Ranches'] },
        { name: 'Nurseries', icon: 'fa-seedling', categories: ['Nurseries', 'Garden Centers'] }
    ],
    'Manufacturing': [
        { name: 'Manufacturers', icon: 'fa-industry', categories: ['Manufacturers', 'Factories'] },
        { name: 'Industrial', icon: 'fa-gears', categories: ['Industrial', 'Machine Shops'] }
    ],
    'Wholesale & Supermarkets': [
        { name: 'Supermarkets', icon: 'fa-store', categories: ['Supermarkets', 'Grocery Stores'] },
        { name: 'Wholesale', icon: 'fa-warehouse', categories: ['Wholesalers', 'Food Wholesalers', 'Wholesale Distributors'] }
    ]
};

const SOCIAL_PLATFORMS = [
    { name: 'Facebook', icon: 'fa-brands fa-facebook', patterns: ['facebook.com','fb.com','fb.me'] },
    { name: 'Instagram', icon: 'fa-brands fa-instagram', patterns: ['instagram.com','instagr.am'] },
    { name: 'Twitter', icon: 'fa-brands fa-x-twitter', patterns: ['twitter.com','x.com'] },
    { name: 'LinkedIn', icon: 'fa-brands fa-linkedin', patterns: ['linkedin.com'] },
    { name: 'YouTube', icon: 'fa-brands fa-youtube', patterns: ['youtube.com','youtu.be'] },
    { name: 'TikTok', icon: 'fa-brands fa-tiktok', patterns: ['tiktok.com'] }
];

class LeadListsApp {
    constructor() {
        this.lists = [];
        this.currentList = null;
        this.currentLeads = [];
        this.selectedLeads = new Set();
        this.currentPage = 1;
        this.totalPages = 1;
        this.totalLeads = 0;
        this.perPage = 50;
        this.searchQuery = '';

        this.editingListId = null;
        this.credits = <?php echo $userCredits; ?>;
        this.selectedCountry = 'US';
        this.statesCache = {};
        this.states = [];
        this.cities = [];
        this.selectedStates = new Set();
        this.selectedCities = new Set();
        this.citySortOrder = 'name';
        this.searchedCitiesForList = new Set();
        this.searchedCityStateIdsForList = new Set();
        this.importedCityNamesForList = new Set();
        this.cityFilter = 'all';
        this.scraping = false;
        this.scrapeRunId = null;
        this.scrapeCancelled = false;
        this._modalStatusPollTimer = null;
        this.enrichmentPollId = null;
        this.currentLeadDetail = null;
        this.searchDebounce = null;
        this.hasFilter = '';
        this.exportType = null;
        this.exportLeadsData = null;
        this.mapsApiUrl = 'maps_proxy.php?type=search';
        this.slideMap = null;
        this.listMap = null;
        this.listMapMarkers = [];
        this.listMapDrawnItems = null;
        this.listMapVisible = true;
        this.allMapLeads = [];
        this.activeCategoryGroup = INITIAL_CATEGORY_GROUP;
        this.activeCategory = INITIAL_CATEGORY;
        this.scrapeQueueTimer = null;

        this.emailTemplate = JSON.parse(localStorage.getItem('emailTemplate') || 'null') || { my_name: '', my_company: '', subject: '', body: '' };

        // In-memory GET cache for read-only API actions
        this._getCache = {};
        this.cacheableGetActions = new Set(['getLeads', 'getListDetail', 'getLeadDetail', 'getEnrichmentProgress', 'getStates', 'getScrapeQueueStatus', 'getCities', 'getTopCities']);


        this.init();
    }

    async init() {
        window.addEventListener('message', (event) => {
            if (event.origin !== window.location.origin || !event.data || event.data.type !== 'setLeadListCategory') return;
            this.setCategoryFilter(event.data.category_group || '', event.data.category || '');
        });
        await this.loadLists();
    }

    async api(action, params = {}, method = 'GET') {
        let url = `leadlists.php?action=${action}`;
        const opts = { headers: {}, cache: 'no-store' };
        const GET_CACHE_TTL = 4000; // 4 seconds

        if (method === 'GET') {
            Object.entries(params).forEach(([k, v]) => url += `&${k}=${encodeURIComponent(v)}`);
            // In-memory cache for safe read-only GET actions
            if (this.cacheableGetActions.has(action)) {
                const cached = this._getCache[url];
                if (cached && (Date.now() - cached.ts) < GET_CACHE_TTL) {
                    return cached.data;
                }
            }
        } else {
            opts.method = 'POST';
            opts.headers['Content-Type'] = 'application/json';
            // Clear GET cache after any mutating POST to avoid stale data
            this._getCache = {};
            opts.body = JSON.stringify(params);
        }

        try {
            const res = await fetch(url, opts);
            if (res.redirected || res.status === 302 || res.status === 303) {
                window.location.href = 'login.php';
                return { success: false, error: 'Session expired, redirecting to login' };
            }
            if (!res.ok) return { success: false, error: 'Server error ' + res.status };
            const data = await res.json();
            if (method === 'GET' && this.cacheableGetActions.has(action)) {
                this._getCache[url] = { data, ts: Date.now() };
            }
            return data;
        } catch (e) {
            return { success: false, error: e.message };
        }
    }

    toast(msg, type) {
        // Backward-compat shim: existing callsites use app.toast(msg).
        // Cheap type support: 'success' / 'error' / 'warn' / 'info' (default).
        // The CSS left-border accent + icon tell success/error/warn apart in
        // both light and dark mode (theme-aware bg+text via CSS vars). XSS-safe
        // via esc() for the message body; icons are static HTML.
        const t = document.getElementById('toast');
        if (!t) return;
        let icon = '';
        if (type === 'success') icon = '<i class="fas fa-check-circle toast-icon" aria-hidden="true"></i>';
        else if (type === 'error') icon = '<i class="fas fa-times-circle toast-icon" aria-hidden="true"></i>';
        else if (type === 'warn' || type === 'warning') icon = '<i class="fas fa-exclamation-triangle toast-icon" aria-hidden="true"></i>';
        else if (type === 'info') icon = '<i class="fas fa-info-circle toast-icon" aria-hidden="true"></i>';
        t.className = 'toast toast-' + (type || 'info');
        t.innerHTML = icon + this.esc(msg);
        t.classList.add('show');
        clearTimeout(this._toastHideTimer);
        const hideMs = type === 'error' ? 4500 : 2500;
        this._toastHideTimer = setTimeout(() => t.classList.remove('show'), hideMs);
    }

    showUpgradePrompt(needed) {
        document.getElementById('upgradeNeeded').textContent = needed;
        document.getElementById('upgradeHave').textContent = this.credits;
        document.getElementById('upgradeModal').style.display = 'flex';
    }
    closeUpgradeModal() {
        document.getElementById('upgradeModal').style.display = 'none';
    }

    async shareForCredits() {
        const url = window.location.origin + '/dashboard?section=lead_lists';
        const shareData = { title: '<?php echo APP_NAME; ?>', text: 'Check out this lead generation tool!', url };

        try {
            if (navigator.share) {
                await navigator.share(shareData);
            } else {
                await navigator.clipboard.writeText(url);
                this.toast('Link copied to clipboard!');
            }
        } catch (e) {
            await navigator.clipboard.writeText(url);
            this.toast('Link copied to clipboard!');
        }

        const res = await this.api('claimShareCredits', {}, 'POST');
        if (res.success) {
            this.credits = res.credits;
            this.updateCreditsDisplay();
            document.getElementById('shareForCreditsWrap').style.display = 'none';
            document.getElementById('upgradeHave').textContent = this.credits;
            this.toast('+5 free credits added!');
            if (window.parent !== window) {
                window.parent.postMessage({ type: 'creditUpdate', credits: this.credits }, '*');
            }
        } else if (res.error === 'Already claimed') {
            document.getElementById('shareForCreditsWrap').style.display = 'none';
            this.toast('You already claimed your share bonus');
        }
    }

    // EMAIL TEMPLATE

    openEmailTemplateModal() {
        document.getElementById('etMyName').value = this.emailTemplate.my_name || '';
        document.getElementById('etMyCompany').value = this.emailTemplate.my_company || '';
        document.getElementById('etSubject').value = this.emailTemplate.subject || '';
        document.getElementById('etBody').value = this.emailTemplate.body || '';
        document.getElementById('emailTemplateModal').classList.add('active');
    }

    insertTemplateVar(target, variable) {
        const field = target === 'subject' ? document.getElementById('etSubject') : document.getElementById('etBody');
        const start = field.selectionStart;
        const end = field.selectionEnd;
        const text = field.value;
        field.value = text.substring(0, start) + variable + text.substring(end);
        field.focus();
        field.setSelectionRange(start + variable.length, start + variable.length);
    }

    saveEmailTemplate() {
        this.emailTemplate = {
            my_name: document.getElementById('etMyName').value.trim(),
            my_company: document.getElementById('etMyCompany').value.trim(),
            subject: document.getElementById('etSubject').value.trim(),
            body: document.getElementById('etBody').value.trim()
        };
        localStorage.setItem('emailTemplate', JSON.stringify(this.emailTemplate));
        document.getElementById('emailTemplateModal').classList.remove('active');
        this.toast('Email template saved!');
    }

    clearEmailTemplate() {
        if (!confirm('Clear your email template?')) return;
        this.emailTemplate = { my_name: '', my_company: '', subject: '', body: '' };
        localStorage.removeItem('emailTemplate');
        document.getElementById('etMyName').value = '';
        document.getElementById('etMyCompany').value = '';
        document.getElementById('etSubject').value = '';
        document.getElementById('etBody').value = '';
        this.toast('Template cleared');
    }

    buildMailtoLink(email, lead) {
        const t = this.emailTemplate;
        if (!t.subject && !t.body) return `mailto:${email}`;

        const vars = {
            '{business_name}': lead?.business_name || '',
            '{city}': lead?.city || '',
            '{state}': lead?.state || '',
            '{my_name}': t.my_name || '',
            '{my_company}': t.my_company || ''
        };

        let subject = t.subject || '';
        let body = t.body || '';
        for (const [k, v] of Object.entries(vars)) {
            subject = subject.split(k).join(v);
            body = body.split(k).join(v);
        }

        let url = `mailto:${email}`;
        const parts = [];
        if (subject) parts.push(`subject=${encodeURIComponent(subject)}`);
        if (body) parts.push(`body=${encodeURIComponent(body)}`);
        if (parts.length) url += '?' + parts.join('&');
        return url;
    }

    sendTemplateEmail(email, leadId) {
        const lead = this.currentLeads?.find(l => l.id == leadId) || this.allMapLeads?.find(l => l.id == leadId) || {};
        const url = this.buildMailtoLink(email, lead);
        window.open(url, '_blank');
    }

    showEmailPopover(btnEl, leadId) {
        if (this._emailPopoverBtn === btnEl && document.getElementById('emailPopover')) return;
        this.dismissEmailPopover();
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (!lead) return;
        const emails = lead.emails || [];
        if (emails.length === 0) return;

        this._emailPopoverBtn = btnEl;
        const pop = document.createElement('div');
        pop.className = 'email-popover';
        pop.id = 'emailPopover';
        pop.onclick = (e) => e.stopPropagation();
        pop.innerHTML = emails.map(e =>
            `<div class="email-popover-item">
                <span class="ep-email" title="${this.esc(e)}">${this.esc(e)}</span>
                <div class="ep-actions">
                    <button class="ep-btn" title="Copy" onclick="navigator.clipboard.writeText('${this.esc(e)}');app.toast('Copied');"><i class="fas fa-copy"></i></button>
                    <button class="ep-btn" title="Send email" onclick="app.sendTemplateEmail('${this.esc(e)}', ${leadId});app.dismissEmailPopover();"><i class="fas fa-paper-plane"></i></button>
                </div>
            </div>`
        ).join('');

        pop.onmouseenter = () => clearTimeout(this._emailPopoverTimer);
        pop.onmouseleave = () => { this._emailPopoverTimer = setTimeout(() => this.dismissEmailPopover(), 200); };
        btnEl.onmouseleave = () => { this._emailPopoverTimer = setTimeout(() => this.dismissEmailPopover(), 200); };

        document.body.appendChild(pop);
        const rect = btnEl.getBoundingClientRect();
        pop.style.top = (rect.bottom + 6 + window.scrollY) + 'px';
        pop.style.left = Math.max(8, Math.min(rect.left + window.scrollX - 80, window.innerWidth - pop.offsetWidth - 8)) + 'px';
    }

    dismissEmailPopover() {
        const pop = document.getElementById('emailPopover');
        if (pop) pop.remove();
        this._emailPopoverBtn = null;
        clearTimeout(this._emailPopoverTimer);
    }

    showNotePopover(btnEl, leadId) {
        this.dismissNotePopover();
        this.dismissEmailPopover();
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (!lead) return;

        const pop = document.createElement('div');
        pop.className = 'note-popover';
        pop.id = 'notePopover';
        pop.onclick = (e) => e.stopPropagation();
        pop.innerHTML = `
            <div class="note-popover-header">
                <span><i class="fas fa-sticky-note" style="margin-right:6px;color:var(--orange);"></i>Notes</span>
                <button onclick="app.dismissNotePopover()" style="background:none;border:none;cursor:pointer;color:var(--text-tertiary);font-size:14px;"><i class="fas fa-times"></i></button>
            </div>
            <textarea id="notePopoverText" placeholder="Add a note...">${this.esc(lead.notes || '')}</textarea>
            <div class="note-popover-footer">
                <button class="btn btn-sm btn-secondary" onclick="app.dismissNotePopover()">Cancel</button>
                <button class="btn btn-sm btn-primary" onclick="app.saveNotePopover(${leadId})"><i class="fas fa-save"></i> Save</button>
            </div>
        `;
        document.body.appendChild(pop);

        const rect = btnEl.getBoundingClientRect();
        const popH = pop.offsetHeight;
        const spaceBelow = window.innerHeight - rect.bottom;
        if (spaceBelow < popH + 10) {
            pop.style.top = (rect.top + window.scrollY - popH - 6) + 'px';
        } else {
            pop.style.top = (rect.bottom + 6 + window.scrollY) + 'px';
        }
        pop.style.left = Math.max(8, Math.min(rect.right + window.scrollX - pop.offsetWidth, window.innerWidth - pop.offsetWidth - 8)) + 'px';

        const ta = document.getElementById('notePopoverText');
        ta.focus();
        ta.setSelectionRange(ta.value.length, ta.value.length);

        setTimeout(() => {
            this._notePopoverDismiss = (e) => {
                if (!pop.contains(e.target)) this.dismissNotePopover();
            };
            document.addEventListener('click', this._notePopoverDismiss);
        }, 0);
    }

    async saveNotePopover(leadId) {
        const notes = document.getElementById('notePopoverText')?.value || '';
        await this.api('updateLead', { id: leadId, notes }, 'POST');
        this.toast('Note saved');
        this.dismissNotePopover();
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (lead) lead.notes = notes;
        this.renderLeads();
        if (this.currentList) {
            const data = await this.api('getListDetail', { id: this.currentList.id });
            if (data.success) { this.currentList = data.list; this.renderStats(); }
        }
    }

    dismissNotePopover() {
        const pop = document.getElementById('notePopover');
        if (pop) pop.remove();
        if (this._notePopoverDismiss) {
            document.removeEventListener('click', this._notePopoverDismiss);
            this._notePopoverDismiss = null;
        }
    }

    // LIST MANAGEMENT

    async loadLists() {
                document.getElementById('folderGrid').innerHTML = `<div id="folderGrid" class="folder-grid"><div class="skeleton-folder-card"><div class="sk-icon-wrap"><div class="sk-block sk-icon"></div></div><div class="sk-block sk-title"></div><div class="sk-block sk-desc"></div><div class="sk-block sk-desc sk-desc-short"></div></div><div class="skeleton-folder-card"><div class="sk-icon-wrap"><div class="sk-block sk-icon"></div></div><div class="sk-block sk-title"></div><div class="sk-block sk-desc"></div><div class="sk-block sk-desc sk-desc-short"></div></div><div class="skeleton-folder-card"><div class="sk-icon-wrap"><div class="sk-block sk-icon"></div></div><div class="sk-block sk-title"></div><div class="sk-block sk-desc"></div><div class="sk-block sk-desc sk-desc-short"></div></div></div>`;
        const params = {};
        if (this.activeCategoryGroup && this.activeCategory) {
            params.category_group = this.activeCategoryGroup;
            params.category = this.activeCategory;
        }
        const data = await this.api('getLists', params);
        if (data.success) {
            this.lists = data.lists;
            this.renderLists();
        }
    }

    async setCategoryFilter(group, category) {
        this.activeCategoryGroup = group || '';
        this.activeCategory = category || '';
        this.currentList = null;
        const listDetail = document.getElementById('listDetail');
        if (listDetail) listDetail.classList.add('hidden');
        const mainView = document.getElementById('mainView');
        if (mainView) mainView.classList.remove('hidden');
        this.updateBreadcrumb();
        await this.loadLists();
    }

    updateBreadcrumb() {
        const nav = document.getElementById('breadcrumbNav');
        const groupEl = document.getElementById('breadcrumbGroup');
        const sepEl = document.getElementById('breadcrumbSep');
        const catEl = document.getElementById('breadcrumbCategory');
        if (!nav) return;
        if (!this.activeCategoryGroup) {
            nav.classList.add('hidden');
            return;
        }
        nav.classList.remove('hidden');
        groupEl.textContent = this.activeCategoryGroup;
        if (this.activeCategory) {
            sepEl.classList.remove('hidden');
            catEl.textContent = this.activeCategory;
        } else {
            sepEl.classList.add('hidden');
            catEl.textContent = '';
        }
    }

    renderLists() {
        const grid = document.getElementById('folderGrid');
        const mainGrid = document.getElementById('mainGrid');
        const empty = document.getElementById('emptyState');
        const catSection = document.getElementById('categoryIntelSection');
        const newListBtn = document.querySelector('.page-header .btn-primary');

        // Determine matching lists based on active category
        const activeAliases = this.activeCategory ? (CATEGORY_LIST_ALIASES[this.activeCategory] || [this.activeCategory]) : [];
        const matchingLists = this.lists.filter(list =>
            activeAliases.includes(list.category) || activeAliases.includes(list.name)
        );

        // Category intel always renders but is below the list grid
        this.renderCategoryIntel();

        // Show/hide and expand/collapse the category section
        if (catSection) {
            if (this.activeCategoryGroup) {
                catSection.classList.remove('hidden');
                catSection.classList.remove('collapsed');
                this._updateCategoryIntelToggle(false);
            } else {
                catSection.classList.add('hidden');
            }
        }

        // HIDE the old emptyState — we never route to it
        if (empty) empty.classList.add('hidden');

        // Decide what to show in the main grid
        const hasDisplayLists = this.activeCategory
            ? matchingLists.length > 0
            : this.lists.length > 0;
        const displayLists = this.activeCategory ? matchingLists : this.lists;

        // Always show main grid
        if (mainGrid) mainGrid.classList.remove('hidden');
        if (grid) grid.classList.remove('hidden');

        if (newListBtn) newListBtn.classList.remove('pulse-cue');

        if (!hasDisplayLists) {
            // Show create-card(s) instead of empty state
            grid.innerHTML = this._buildCreateCards(matchingLists, activeAliases);
            return;
        }

        // Render actual lead-list cards
        grid.innerHTML = displayLists.map((list, i) => {
            const iconData = getCategoryIconData(list.category || list.name);
            const color = (list.icon_color || null) || iconData.color;
            const icon = (list.icon_class || null) || iconData.icon;
            const total = parseInt(list.lead_count) || 0;
            const visited = parseInt(list.visited_count) || 0;
            const reachedOut = parseInt(list.reached_out_count) || 0;
            const sNew = parseInt(list.stage_new) || 0;
            const sContacted = parseInt(list.stage_contacted) || 0;
            const engaged = parseInt(list.engaged_count) || 0;
            const clients = parseInt(list.client_count) || 0;
            const sNoResp = parseInt(list.stage_no_response) || 0;
            const cities = parseInt(list.cities_searched) || 0;
            const quality = this.getLeadRating({ total, reachedOut, engaged, clients, sNoResp, cities });
            const categoryBadge = list.category_group && list.category
                ? `<div class="category-badge" title="${this.esc(list.category_group)} / ${this.esc(list.category)}"><i class="fas fa-layer-group"></i>${this.esc(list.category_group)} / ${this.esc(list.category)}</div>`
                : '';

            return `
                <div class="folder-card${this.activeCategory ? ' highlight-match' : ''}" onclick="app.openList(${list.id})" data-category="${this.esc(list.category || list.name)}">
                    <div class="folder-actions">
                        <button class="btn-icon" onclick="event.stopPropagation();app.openShareModal(${list.id})" title="Share"><i class="fas fa-share-alt" style="font-size:12px;color:var(--accent);"></i></button>
                        <button class="btn-icon" onclick="event.stopPropagation();app.openEditModal(${list.id})" title="Edit"><i class="fas fa-pencil" style="font-size:12px;"></i></button>
                        <button class="btn-icon" onclick="event.stopPropagation();app.deleteList(${list.id})" title="Delete"><i class="fas fa-trash" style="font-size:12px;color:var(--red);"></i></button>
                    </div>
                    ${list.is_public == 1 ? '<div style="position:absolute;bottom:10px;right:12px;font-size:10px;color:var(--accent);font-weight:600;display:flex;align-items:center;gap:6px;"><i class="fas fa-globe"></i> Public' + (parseInt(list.claim_count) > 0 ? ' <span style="background:var(--accent);color:#fff;padding:1px 6px;border-radius:8px;font-size:9px;">' + list.claim_count + ' claimed</span>' : '') + '</div>' : ''}
                    <div class="folder-icon ${color}"><i class="fa-solid ${icon || 'fa-folder'}"></i></div>
                    <div style="display:flex;align-items:center;justify-content:space-between;gap:10px;margin:-4px 0 8px;cursor:help;" title="Rating Breakdown:&#10;- Base: 20&#10;- Coverage: ${quality.breakdown.coverage}/35&#10;- City Depth: ${quality.breakdown.cityDepth}/10&#10;- Action Rate: ${quality.breakdown.actionRate}/20&#10;- Engagement Rate: ${quality.breakdown.engagementRate}/30&#10;- Penalty: -${quality.breakdown.penalty}/15">
                        <span class="quality-ribbon ${quality.tier}"><i class="fas fa-signal"></i>${quality.label}</span>
                        <span style="font-size:11px;font-weight:800;color:var(--text-tertiary);">${quality.score}/100</span>
                    </div>
                    <div class="name">${this.esc(list.name)}</div>
                    ${categoryBadge ? `<div style="margin:6px 0 2px;">${categoryBadge}</div>` : ''}
                    <div class="desc">${list.description ? this.esc(list.description) : 'No description'}</div>
                    <div class="meta">
                        <span><i class="fas fa-users"></i> ${total.toLocaleString()} leads</span>
                        <span><i class="fas fa-map-marker-alt"></i> ${cities} cities</span>
                    </div>
                    <div style="display:flex;align-items:center;gap:3px;margin-top:12px;padding:8px 0 2px;border-top:1px solid var(--card-border);">
                        <div style="flex:1;text-align:center;">
                            <div style="font-size:14px;font-weight:700;color:var(--text-secondary);">${sNew}</div>
                            <div style="font-size:9px;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:0.3px;">New</div>
                        </div>
                        <i class="fas fa-chevron-right" style="font-size:7px;color:var(--text-tertiary);"></i>
                        <div style="flex:1;text-align:center;">
                            <div style="font-size:14px;font-weight:700;color:var(--accent);">${sContacted}</div>
                            <div style="font-size:9px;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:0.3px;">Contacted</div>
                        </div>
                        <i class="fas fa-chevron-right" style="font-size:7px;color:var(--text-tertiary);"></i>
                        <div style="flex:1;text-align:center;">
                            <div style="font-size:14px;font-weight:700;color:var(--orange);">${engaged}</div>
                            <div style="font-size:9px;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:0.3px;">Engaged</div>
                        </div>
                        <i class="fas fa-chevron-right" style="font-size:7px;color:var(--text-tertiary);"></i>
                        <div style="flex:1;text-align:center;">
                            <div style="font-size:14px;font-weight:700;color:var(--green);">${clients}</div>
                            <div style="font-size:9px;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:0.3px;">Client</div>
                        </div>
                        <i class="fas fa-chevron-right" style="font-size:7px;color:var(--text-tertiary);"></i>
                        <div style="flex:1;text-align:center;">
                            <div style="font-size:14px;font-weight:700;color:var(--red);">${sNoResp}</div>
                            <div style="font-size:9px;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:0.3px;">No Resp</div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }

    _buildCreateCards(matchingLists, activeAliases) {
        // No lists exist at all — first-create CTA
        if (!this.activeCategoryGroup && !this.activeCategory) {
            return `
                <div class="create-card" onclick="app.openCreateModal()" style="grid-column:1/-1;min-height:200px;">
                    <div class="create-card-icon"><i class="fas fa-plus"></i></div>
                    <div class="create-card-title">Create Your First Lead List</div>
                    <div class="create-card-desc">Name your list, pick cities, and start adding leads. You have ${this.credits} city searches available.</div>
                    <button class="create-card-btn"><i class="fas fa-plus"></i> Create First List</button>
                </div>
            `;
        }

        // A specific category is selected but no matching lists exist — show Create + Search cards
        if (this.activeCategory) {
            const catGroups = CATEGORY_HIERARCHY[this.activeCategoryGroup] || [];
            const currentGroup = catGroups.find(g =>
                g.categories.includes(this.activeCategory) || (CATEGORY_LIST_ALIASES[this.activeCategory] || []).some(a => g.categories.includes(a))
            );
            const icon = currentGroup?.icon || 'fa-folder';
            const chips = currentGroup
                ? currentGroup.categories.slice(0, 4).map(c => `<span class="category-pilot-chip">${this.esc(c)}</span>`).join('')
                : `<span class="category-pilot-chip">${this.esc(this.activeCategory)}</span>`;

            return `
                <div class="create-card" onclick="app._openCreateModalForCategory()">
                    <div class="create-card-icon"><i class="fa-solid ${icon}"></i></div>
                    <div class="create-card-title">Create ${this.esc(this.activeCategory)} List</div>
                    <div class="create-card-desc">No lists found for this category. Start fresh with a prefilled template.</div>
                    <div style="display:flex;gap:6px;flex-wrap:wrap;justify-content:center;margin-bottom:12px;">${chips}</div>
                    <button class="create-card-btn"><i class="fas fa-plus"></i> Create List</button>
                </div>
                <div class="create-card" onclick="app._createAndOpenForCategory()">
                    <div class="create-card-icon" style="background:rgba(59,130,246,0.1);"><i class="fas fa-search" style="color:var(--blue);"></i></div>
                    <div class="create-card-title">Search ${this.esc(this.activeCategory)} Leads</div>
                    <div class="create-card-desc">Find leads by city. We'll create the list and populate it from city searches.</div>
                    <div style="display:flex;gap:6px;flex-wrap:wrap;justify-content:center;margin-bottom:12px;">${chips}</div>
                    <button class="create-card-btn" style="background:var(--blue);"><i class="fas fa-search-location"></i> Search Leads</button>
                </div>
            `;
        }

        // Category group selected (no subcategory) but no lists at all
        return `
            <div class="create-card" onclick="app.openCreateModal()" style="grid-column:1/-1;">
                <div class="create-card-icon"><i class="fas fa-plus"></i></div>
                <div class="create-card-title">No ${this.esc(this.activeCategoryGroup)} lists yet</div>
                <div class="create-card-desc">Create your first ${this.esc(this.activeCategoryGroup)} list — click a category card above to drill down, or create one now.</div>
                <button class="create-card-btn"><i class="fas fa-plus"></i> Create List</button>
            </div>
        `;
    }

    toggleCategoryIntel() {
        const section = document.getElementById('categoryIntelSection');
        if (!section) return;
        const collapsed = section.classList.toggle('collapsed');
        this._updateCategoryIntelToggle(collapsed);
    }

    _updateCategoryIntelToggle(collapsed) {
        const label = document.getElementById('toggleCatLabel');
        const icon = document.getElementById('toggleCatIcon');
        if (label) label.textContent = collapsed ? 'Show' : 'Hide';
        if (icon) {
            if (collapsed) {
                icon.classList.remove('fa-chevron-up');
                icon.classList.add('fa-chevron-down');
            } else {
                icon.classList.remove('fa-chevron-down');
                icon.classList.add('fa-chevron-up');
            }
        }
    }

    _createAndOpenForCategory() {
        // Create a list for the active category, then immediately open it
        const cat = this.activeCategory || '';
        const group = this.activeCategoryGroup || '';
        const iconData = getCategoryIconData(cat);
        const name = cat ? `${cat} Leads` : 'New Lead List';

        (async () => {
            const res = await this.api('createList', {
                name,
                description: `Lead list for ${cat}`,
                category_group: group,
                category: cat,
                source: 'category-nav',
                country: this.selectedCountry || 'US',
                icon_class: iconData.icon,
                icon_color: iconData.color
            }, 'POST');
            if (res.success && res.id) {
                this.toast('List created — now searching for leads...');
                await this.loadLists();
                this.openList(res.id);
            } else {
                this.toast(res.error || 'Failed to create list');
            }
        })();
    }

    renderCategoryIntel() {
        const el = document.getElementById('categoryIntel');
        if (!el) return;
        const groups = CATEGORY_HIERARCHY[this.activeCategoryGroup] || [];
        if (!this.activeCategoryGroup) {
            const groupNames = Object.keys(CATEGORY_HIERARCHY);
            el.classList.remove('hidden');
            el.innerHTML = `
                <div class="category-intel-head">
                    <div>
                        <div class="category-intel-kicker">Category Hub</div>
                        <div class="category-intel-title">Drill into lead lanes</div>
                        <div class="category-intel-sub">Start with a board-level category, then move into focused subcategories and lead types.</div>
                    </div>
                    <div class="category-intel-score">
                        <div class="num">${groupNames.length}</div>
                        <div class="label">Pilots</div>
                    </div>
                </div>
                <div class="category-card-grid">
                    ${groupNames.map(name => {
                        const first = CATEGORY_HIERARCHY[name][0]?.categories[0] || '';
                        const icon = CATEGORY_HIERARCHY[name][0]?.icon || 'fa-layer-group';
                        const count = CATEGORY_HIERARCHY[name].reduce((sum, group) => sum + group.categories.length, 0);
                        return `
                            <button type="button" class="category-pilot-card" onclick="app.setCategoryFilter('${this.esc(name)}', '${this.esc(first)}')">
                                <div class="category-pilot-card-top">
                                    <div class="category-pilot-icon"><i class="fa-solid ${icon}"></i></div>
                                    <div class="category-pilot-count">${count} types</div>
                                </div>
                                <div class="category-pilot-title">${this.esc(name)}</div>
                                <div class="category-pilot-desc">${CATEGORY_HIERARCHY[name].slice(0, 3).map(group => this.esc(group.name)).join(', ')}</div>
                            </button>
                        `;
                    }).join('')}
                </div>
            `;
            return;
        }
        if (!groups.length) {
            // Fallback for groups not in CATEGORY_HIERARCHY — show a dynamic card using the group name
            const groupName = this.activeCategoryGroup;
            const groupTotal = this.lists.reduce((sum, list) => sum + (parseInt(list.lead_count) || 0), 0);
            const groupLists = this.lists;
            const score = this.getLeadRating({
                total: groupTotal,
                reachedOut: this.lists.reduce((sum, list) => sum + (parseInt(list.reached_out_count) || 0), 0),
                engaged: this.lists.reduce((sum, list) => sum + (parseInt(list.engaged_count) || 0), 0),
                clients: this.lists.reduce((sum, list) => sum + (parseInt(list.client_count) || 0), 0),
                sNoResp: this.lists.reduce((sum, list) => sum + (parseInt(list.stage_no_response) || 0), 0),
                cities: this.lists.reduce((sum, list) => sum + (parseInt(list.cities_searched) || 0), 0)
            });
            el.classList.remove('hidden');
            el.innerHTML = `
                <div class="category-intel-head">
                    <div>
                        <div class="category-intel-kicker">Category Intelligence</div>
                        <div class="category-intel-title">${this.esc(groupName)}</div>
                        <div class="category-intel-sub">${groupLists.length} list${groupLists.length === 1 ? '' : 's'} with ${groupTotal.toLocaleString()} lead${groupTotal === 1 ? '' : 's'}. Use the cards below to explore subcategories.</div>
                    </div>
                    <div class="category-intel-score" style="cursor:help;" title="Rating Breakdown:&#10;- Base: 20&#10;- Coverage: ${score.breakdown.coverage}/35&#10;- City Depth: ${score.breakdown.cityDepth}/10&#10;- Action Rate: ${score.breakdown.actionRate}/20&#10;- Engagement Rate: ${score.breakdown.engagementRate}/30&#10;- Penalty: -${score.breakdown.penalty}/15">
                        <div class="num">${score.score}</div>
                        <div class="label">${score.label}</div>
                    </div>
                </div>
                <div class="category-card-grid">
                    ${groupLists.length > 0 ? `
                        <div class="category-pilot-card active" style="cursor:default;">
                            <div class="category-pilot-card-top">
                                <div class="category-pilot-icon"><i class="fa-solid fa-folder"></i></div>
                                <div class="category-pilot-count">${groupLists.length} list${groupLists.length === 1 ? '' : 's'}</div>
                            </div>
                            <div class="category-pilot-title">${this.esc(groupName)}</div>
                            <div class="category-pilot-desc">All ${this.esc(groupName)} lead lists</div>
                        </div>
                    ` : `
                        <div class="category-pilot-card" style="cursor:pointer;" onclick="app._openCreateModalForCategory()">
                            <div class="category-pilot-card-top">
                                <div class="category-pilot-icon"><i class="fa-solid fa-plus-circle"></i></div>
                                <div class="category-pilot-count">0 lists</div>
                            </div>
                            <div class="category-pilot-title">Create First List</div>
                            <div class="category-pilot-desc">No ${this.esc(groupName)} lists yet — get started!</div>
                            <div class="category-pilot-chips">
                                <span class="category-pilot-chip">${this.esc(groupName)}</span>
                            </div>
                        </div>
                    `}
                </div>
            `;
            return;
        }
        const listTotal = this.lists.reduce((sum, list) => sum + (parseInt(list.lead_count) || 0), 0);
        const activeAliases = this.activeCategory ? (CATEGORY_LIST_ALIASES[this.activeCategory] || [this.activeCategory]) : [];
        const activeLists = this.activeCategory
            ? this.lists.filter(list => activeAliases.includes(list.category) || activeAliases.includes(list.name))
            : this.lists;
        const score = this.getLeadRating({
            total: listTotal,
            reachedOut: this.lists.reduce((sum, list) => sum + (parseInt(list.reached_out_count) || 0), 0),
            engaged: this.lists.reduce((sum, list) => sum + (parseInt(list.engaged_count) || 0), 0),
            clients: this.lists.reduce((sum, list) => sum + (parseInt(list.client_count) || 0), 0),
            sNoResp: this.lists.reduce((sum, list) => sum + (parseInt(list.stage_no_response) || 0), 0),
            cities: this.lists.reduce((sum, list) => sum + (parseInt(list.cities_searched) || 0), 0)
        });
        el.classList.remove('hidden');
        el.innerHTML = `
            <div class="category-intel-head">
                <div>
                    <div class="category-intel-kicker">Category Intelligence</div>
                    <div class="category-intel-title">${this.esc(this.activeCategoryGroup)}${this.activeCategory ? ' / ' + this.esc(this.activeCategory) : ''}</div>
                    <div class="category-intel-sub">${activeLists.length} matching list${activeLists.length === 1 ? '' : 's'} across ${listTotal.toLocaleString()} lead${listTotal === 1 ? '' : 's'}. Use the cards below to drill into the strongest lanes.</div>
                </div>
                <div class="category-intel-score" style="cursor:help;" title="Rating Breakdown:&#10;- Base: 20&#10;- Coverage: ${score.breakdown.coverage}/35&#10;- City Depth: ${score.breakdown.cityDepth}/10&#10;- Action Rate: ${score.breakdown.actionRate}/20&#10;- Engagement Rate: ${score.breakdown.engagementRate}/30&#10;- Penalty: -${score.breakdown.penalty}/15">
                    <div class="num">${score.score}</div>
                    <div class="label">${score.label}</div>
                </div>
            </div>
            <div class="category-card-grid">
                ${groups.map(group => {
                    const categoryMatches = group.categories.filter(cat => cat === this.activeCategory || (CATEGORY_LIST_ALIASES[this.activeCategory] || []).includes(cat));
                    const relatedLists = this.lists.filter(list => group.categories.includes(list.category) || group.categories.includes(list.name));
                    return `
                        <button type="button" class="category-pilot-card ${categoryMatches.length ? 'active' : ''}" onclick="app.setCategoryFilter('${this.esc(this.activeCategoryGroup)}', '${this.esc(group.categories[0])}')">
                            <div class="category-pilot-card-top">
                                <div class="category-pilot-icon"><i class="fa-solid ${group.icon}"></i></div>
                                <div class="category-pilot-count">${relatedLists.length} list${relatedLists.length === 1 ? '' : 's'}</div>
                            </div>
                            <div class="category-pilot-title">${this.esc(group.name)}</div>
                            <div class="category-pilot-desc">${this.esc(group.categories.slice(0, 3).join(', '))}${group.categories.length > 3 ? '...' : ''}</div>
                            <div class="category-pilot-chips">
                                ${group.categories.slice(0, 3).map(cat => `<span class="category-pilot-chip">${this.esc(cat)}</span>`).join('')}
                            </div>
                        </button>
                    `;
                }).join('')}
            </div>
        `;
    }

    getLeadRating({ total = 0, reachedOut = 0, engaged = 0, clients = 0, sNoResp = 0, cities = 0 } = {}) {
        const coverage = total > 0 ? Math.min(35, Math.round(Math.log10(total + 1) * 16)) : 0;
        const actionRate = total > 0 ? Math.round((reachedOut / total) * 20) : 0;
        const engagementRate = total > 0 ? Math.round(((engaged + clients * 2) / total) * 30) : 0;
        const cityDepth = Math.min(10, cities * 2);
        const penalty = total > 0 ? Math.min(15, Math.round((sNoResp / total) * 18)) : 0;
        const score = Math.max(0, Math.min(100, coverage + actionRate + engagementRate + cityDepth - penalty + 20));
        const breakdown = { coverage, actionRate, engagementRate, cityDepth, penalty };
        if (score >= 72) return { score, tier: 'hot', label: 'Hot', breakdown };
        if (score >= 45) return { score, tier: 'warm', label: 'Warm', breakdown };
        return { score, tier: 'cold', label: 'Cold', breakdown };
    }

    openCreateModal() {
        this.editingListId = null;
        this._pendingIconClass = null;
        this._pendingIconColor = null;
        document.getElementById('createModalTitle').textContent = 'New Lead List';
        document.getElementById('createListBtn').textContent = 'Create';
        document.getElementById('listName').value = '';
        document.getElementById('listDesc').value = '';
        this.populateCategorySelectors(this.activeCategoryGroup || '', this.activeCategory || '');
        this._updateIconPreview();
        document.getElementById('createModal').classList.add('active');
        document.getElementById('listName').focus();
    }

    _openCreateModalForCategory() {
        this.editingListId = null;
        this._pendingIconClass = null;
        this._pendingIconColor = null;
        const cat = this.activeCategory || '';
        const group = this.activeCategoryGroup || '';
        document.getElementById('createModalTitle').textContent = `New ${cat} List`;
        document.getElementById('createListBtn').textContent = 'Create';
        document.getElementById('listName').value = cat ? `${cat} Leads` : '';
        document.getElementById('listDesc').value = '';
        this.populateCategorySelectors(group, cat);
        this._updateIconPreview();
        document.getElementById('createModal').classList.add('active');
        document.getElementById('listName').focus();
        const modal = document.getElementById('createModal');
        if (modal) modal.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }

    openEditModal(id) {
        const list = this.lists.find(l => l.id == id);
        if (!list) return;
        this.editingListId = id;
        this._pendingIconClass = list.icon_class || null;
        this._pendingIconColor = list.icon_color || null;
        document.getElementById('createModalTitle').textContent = 'Edit Lead List';
        document.getElementById('createListBtn').textContent = 'Save';
        document.getElementById('listName').value = list.name;
        document.getElementById('listDesc').value = list.description || '';
        this.populateCategorySelectors(list.category_group || '', list.category || '');
        this._updateIconPreview();
        document.getElementById('createModal').classList.add('active');
        document.getElementById('listName').focus();
    }

    populateCategorySelectors(groupValue = '', categoryValue = '') {
        const groupSelect = document.getElementById('listCategoryGroup');
        const categorySelect = document.getElementById('listCategory');
        if (!groupSelect || !categorySelect) return;
        const groups = Object.keys(HD2_CATEGORIES);
        groupSelect.innerHTML = '<option value="">Uncategorized</option>' + groups.map(g => `<option value="${this.esc(g)}">${this.esc(g)}</option>`).join('');
        groupSelect.value = groupValue && HD2_CATEGORIES[groupValue] ? groupValue : '';
        this.populateCategoryOptions(categoryValue);
    }

    populateCategoryOptions(categoryValue = '') {
        const groupSelect = document.getElementById('listCategoryGroup');
        const categorySelect = document.getElementById('listCategory');
        if (!groupSelect || !categorySelect) return;
        const group = groupSelect.value;
        const categories = HD2_CATEGORIES[group] || [];
        categorySelect.innerHTML = '<option value="">Select category</option>' + categories.map(c => `<option value="${this.esc(c)}">${this.esc(c)}</option>`).join('');
        categorySelect.value = categories.includes(categoryValue) ? categoryValue : '';
        categorySelect.disabled = categories.length === 0;
    }

    onListCategoryGroupChange() {
        this.populateCategoryOptions('');
        // Only reset icon preview to auto if user hasn't picked a custom icon/color yet.
        // Custom picks persist across category group changes so users can preview combinations.
        if (!this._pendingIconClass && !this._pendingIconColor) {
            this._pendingIconClass = null;
            this._pendingIconColor = null;
        }
        this._updateIconPreview();
    }

    onListCategoryChange() {
        // Only reset custom icon/color when changing category if not custom-picked yet
        if (!this._pendingIconClass && !this._pendingIconColor) {
            this._pendingIconClass = null;
            this._pendingIconColor = null;
        }
        this._updateIconPreview();
    }

    _iconList = [
        'fa-folder','fa-flask','fa-vial','fa-microscope','fa-dna','fa-atom','fa-prescription-bottle-medical',
        'fa-graduation-cap','fa-clipboard-check','fa-scale-balanced','fa-gears','fa-industry','fa-truck-fast','fa-boxes-stacked',
        'fa-box','fa-warehouse','fa-briefcase','fa-building','fa-store','fa-user-doctor','fa-heart-pulse','fa-pills',
        'fa-stethoscope','fa-code','fa-server','fa-database','fa-globe','fa-chart-line','fa-shield-halved','fa-leaf',
        'fa-bolt','fa-rocket','fa-lightbulb','fa-list-check','fa-calendar-check','fa-map-pin','fa-location-dot',
        'fa-envelope','fa-phone','fa-comments','fa-users','fa-user-gear','fa-star','fa-certificate','fa-palette','fa-pencil',
        'fa-house-medical','fa-tooth','fa-house-chimney','fa-fan','fa-faucet-drip','fa-plug','fa-bug','fa-solar-panel',
        'fa-broom','fa-hammer','fa-wrench','fa-car','fa-car-burst','fa-truck-pickup','fa-circle-notch','fa-user','fa-person-running',
        'fa-scale-balanced','fa-gavel','fa-lock','fa-chart-line','fa-users-gear','fa-laptop-code'
    ];
    _currentIconColor = 'folder-blue';
    _pendingIconClass = null;
    _pendingIconColor = null;

    _updateIconPreview() {
        const preview = document.getElementById('iconPreview');
        if (!preview) return;
        const groupSelect = document.getElementById('listCategoryGroup');
        const categorySelect = document.getElementById('listCategory');
        const catKey = categorySelect?.value || this.activeCategory || '';
        const auto = getCategoryIconData(catKey);
        const iconClass = this._pendingIconClass || auto.icon || 'fa-folder';
        const colorClass = this._pendingIconColor || auto.color || 'folder-blue';
        preview.className = `folder-icon ${colorClass}`;
        preview.style.cssText = 'width:48px;height:48px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:22px;margin:0;';
        preview.innerHTML = `<i class="fa-solid ${iconClass}"></i>`;
    }

    openIconPicker() {
        this._currentIconColor = this._pendingIconColor || getCategoryIconData(document.getElementById('listCategory')?.value || this.activeCategory || '').color || 'folder-blue';
        document.querySelectorAll('.icon-color-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.color === this._currentIconColor);
            btn.style.borderColor = btn.dataset.color === this._currentIconColor ? 'var(--text-primary)' : 'transparent';
        });
        document.getElementById('iconSearch').value = '';
        this._renderIconGrid(this._iconList);
        document.getElementById('iconPickerModal').classList.add('active');
    }

    closeIconPicker() {
        document.getElementById('iconPickerModal').classList.remove('active');
    }

    selectIconColor(color) {
        this._currentIconColor = color;
        document.querySelectorAll('.icon-color-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.color === color);
            btn.style.borderColor = btn.dataset.color === color ? 'var(--text-primary)' : 'transparent';
        });
        this._renderIconGrid(this._currentIcons || this._iconList);
    }

    _renderIconGrid(icons) {
        const grid = document.getElementById('iconGrid');
        const catKey = document.getElementById('listCategory')?.value || this.activeCategory || '';
        const selectedIcon = this._pendingIconClass || getCategoryIconData(catKey).icon || 'fa-folder';
        const cleanIcons = [...new Set((icons || []).filter(icon => /^fa-[a-z0-9-]+$/.test(icon)))];
        if (!cleanIcons.length) { grid.innerHTML = '<div class="icon-empty-state">No matching icons</div>'; return; }
        grid.innerHTML = cleanIcons.map(icon => `<button type="button" onclick="app._selectIcon('${icon}')" class="icon-option ${icon === selectedIcon ? 'selected' : ''}" title="${icon.replace('fa-','').replaceAll('-',' ')}"><i class="fa-solid ${icon}"></i></button>`).join('');
    }

    _selectIcon(iconClass) {
        this._pendingIconClass = iconClass;
        this._pendingIconColor = this._currentIconColor;
        this._renderIconGrid(this._currentIcons || this._iconList);
    }

    filterIcons() {
        const search = document.getElementById('iconSearch').value.toLowerCase().trim();
        this._currentIcons = search ? this._iconList.filter(icon => icon.includes(search)) : this._iconList;
        this._renderIconGrid(this._currentIcons);
    }

    applyIcon() {
        this.closeIconPicker();
        this._updateIconPreview();
    }

    resetIcon() {
        this._pendingIconClass = null;
        this._pendingIconColor = null;
        this.closeIconPicker();
        this._updateIconPreview();
    }

    openShareModal(listId) {
        const id = listId || (this.currentList ? this.currentList.id : null);
        if (!id) return;
        const list = this.lists.find(l => l.id == id) || this.currentList;
        if (!list) return;
        this.sharingListId = id;
        const isPublic = list.is_public == 1;
        document.getElementById('shareToggle').checked = isPublic;
        const linkSection = document.getElementById('shareLinkSection');
        if (isPublic && list.pubTok) {
            linkSection.classList.remove('hidden');
            document.getElementById('shareLinkInput').value = `<?php echo APP_URL; ?>/public_list.php?token=${list.pubTok}`;
            this.loadShareClaims(id);
        } else {
            linkSection.classList.add('hidden');
        }
        document.getElementById('shareModal').classList.add('active');
    }

    async loadShareClaims(listId) {
        const countEl = document.getElementById('shareClaimCount');
        const listEl = document.getElementById('shareClaimsList');
        countEl.textContent = '...';
        listEl.innerHTML = '<div style="text-align:center;padding:12px;color:var(--text-tertiary);font-size:12px;"><i class="fas fa-spinner fa-spin"></i></div>';
        const data = await this.api('getListClaims', { list_id: listId });
        if (!data.success || !data.claims) {
            countEl.textContent = '0';
            listEl.innerHTML = '<div style="text-align:center;padding:12px;color:var(--text-tertiary);font-size:12px;">No signups yet</div>';
            return;
        }
        countEl.textContent = data.claims.length;
        if (data.claims.length === 0) {
            listEl.innerHTML = '<div style="text-align:center;padding:12px;color:var(--text-tertiary);font-size:12px;">No signups yet — share your link to start capturing leads!</div>';
            return;
        }
        listEl.innerHTML = data.claims.map(c => {
            const d = new Date(c.created_at);
            const ago = this.timeAgo(d);
            const typeIcon = c.claim_type === 'signup' ? '<i class="fas fa-user-plus" style="color:var(--green);font-size:10px;"></i>' : '<i class="fas fa-sign-in-alt" style="color:var(--accent);font-size:10px;"></i>';
            const typeLbl = c.claim_type === 'signup' ? 'New signup' : 'Existing user';
            return `<div style="display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:8px;margin-bottom:4px;background:var(--bg);border:1px solid var(--card-border);">
                <div style="width:32px;height:32px;border-radius:50%;background:var(--accent-light);display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;color:var(--accent);flex-shrink:0;">${(c.claimed_user_name || '?')[0].toUpperCase()}</div>
                <div style="flex:1;min-width:0;">
                    <div style="font-size:13px;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${this.esc(c.claimed_user_name || 'Unknown')}</div>
                    <div style="font-size:11px;color:var(--text-tertiary);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${this.esc(c.claimed_user_email || '')}</div>
                </div>
                <div style="text-align:right;flex-shrink:0;">
                    <div style="font-size:10px;display:flex;align-items:center;gap:3px;justify-content:flex-end;">${typeIcon} ${typeLbl}</div>
                    <div style="font-size:10px;color:var(--text-tertiary);margin-top:1px;">${ago}</div>
                </div>
            </div>`;
        }).join('');
    }

    timeAgo(date) {
        const s = Math.floor((Date.now() - date.getTime()) / 1000);
        if (s < 60) return 'just now';
        if (s < 3600) return Math.floor(s/60) + 'm ago';
        if (s < 86400) return Math.floor(s/3600) + 'h ago';
        if (s < 2592000) return Math.floor(s/86400) + 'd ago';
        return date.toLocaleDateString();
    }

    async toggleSharePublic(checked) {
        const res = await this.api('togglePublic', { id: this.sharingListId, is_public: checked ? 1 : 0 }, 'POST');
        if (!res.success) { this.toast('Error updating share settings'); return; }
        const linkSection = document.getElementById('shareLinkSection');
        if (checked && res.pubTok) {
            linkSection.classList.remove('hidden');
            const url = `<?php echo APP_URL; ?>/public_list.php?token=${res.pubTok}`;
            document.getElementById('shareLinkInput').value = url;
            this.loadShareClaims(this.sharingListId);
        } else {
            linkSection.classList.add('hidden');
        }
        const list = this.lists.find(l => l.id == this.sharingListId);
        if (list) { list.is_public = checked ? 1 : 0; list.pubTok = res.pubTok; }
        if (this.currentList && this.currentList.id == this.sharingListId) {
            this.currentList.is_public = checked ? 1 : 0;
            this.currentList.pubTok = res.pubTok;
        }
        this.toast(checked ? 'List is now public' : 'List is now private');
        this.renderLists();
    }

    copyShareLink() {
        const input = document.getElementById('shareLinkInput');
        navigator.clipboard.writeText(input.value).then(() => this.toast('Link copied!'));
    }

    closeCreateModal() {
        document.getElementById('createModal').classList.remove('active');
    }

    async saveList() {
        const name = document.getElementById('listName').value.trim();
        const desc = document.getElementById('listDesc').value.trim();
        if (!name) { this.toast('Please enter a name'); return; }
        const groupSelect = document.getElementById('listCategoryGroup');
        const categorySelect = document.getElementById('listCategory');
        const category_group = groupSelect?.value || null;
        const category = categorySelect?.value || null;
        const payload = {
            name,
            description: desc,
            category_group,
            category,
            source: null,
            country: this.selectedCountry || 'US',
            icon_class: this._pendingIconClass || null,
            icon_color: this._pendingIconColor || null
        };

        if (this.editingListId) {
            await this.api('updateList', { id: this.editingListId, ...payload }, 'POST');
            this.toast('List updated');
        } else {
            await this.api('createList', payload, 'POST');
            this.toast('List created');
        }
        this.closeCreateModal();
        await this.loadLists();
    }

    async deleteList(id) {
        const list = this.lists.find(l => l.id == id);
        const count = list ? (list.total || 0) : 0;
        const msg = count > 0
            ? `Are you sure?\
\
This will permanently delete "${list.name}" and all ${count.toLocaleString()} leads inside it.\
\
This cannot be undone.`
            : `Are you sure you want to delete "${list?.name || 'this list'}"?\
\
This cannot be undone.`;
        if (!confirm(msg)) return;
        await this.api('deleteList', { id }, 'POST');
        this.toast('List deleted');
        await this.loadLists();
    }

    // DETAIL VIEW

    async openList(id) {
        const data = await this.api('getListDetail', { id });
        if (!data.success) { this.toast('Error loading list'); return; }

        this.currentList = data.list;
        this.currentPage = 1;
        this.searchQuery = '';
        this.hasFilter = '';
        this.selectedLeads.clear();
        document.getElementById('leadSearch').value = '';

        document.getElementById('listsView').classList.add('hidden');
        document.getElementById('detailView').classList.remove('hidden');
        document.getElementById('detailView').classList.add('detail-view-expanded');
        document.getElementById('detailName').textContent = this.currentList.name;
        document.getElementById('detailSub').textContent = this.currentList.description || '';

        const ppSelect = document.getElementById('perPageSelect');
        if (ppSelect) ppSelect.value = this.perPage;

        this.renderStats();
        this.renderSearchedAreas();
        await this.loadLeads();
        setTimeout(() => { this.initListMap(); this.loadMapLeads(); }, 100);

        document.querySelectorAll('#filterPills .filter-pill').forEach(p => {
            p.classList.toggle('active', p.dataset.filter === '');
        });

        this.checkEnrichmentStatus(id);
    }

    async checkEnrichmentStatus(listId) {
        const data = await this.api('getEnrichmentProgress', { list_id: listId });
        if (!data || !data.success) return;

        if (data.needs_enrichment > 0 || data.pending > 0) {
            this.enrichmentPollId = listId;
            this._recoveryAttempts = 0;
            this._totalRecoveryAttempts = 0;
            this._failedRetryDone = false;
            while (true) {
                const r = await this.api('fireAllScrapes', { list_id: listId, batch_size: 100 }, 'POST');
                if (!r.success) break;
                const fired = r.fired || 0;
                if (fired === 0 || (r.pending || 0) === 0) break;
                await new Promise(rv => setTimeout(rv, 300));
            }
            this._enrichLiveLoop(listId);
        } else if (data.processing > 0) {
            this.enrichmentPollId = listId;
            this._recoveryAttempts = 0;
            this._totalRecoveryAttempts = 0;
            this._failedRetryDone = false;
            this._enrichLiveLoop(listId);
        }
    }

    goBack() {
        this.enrichmentPollId = null;
        this._recoveryAttempts = 0;
        this._totalRecoveryAttempts = 0;
        this._failedRetryDone = false;
        this.currentList = null;
        this.currentLeads = [];
        this.allMapLeads = [];
        this.listMapMarkers = [];
        if (this.listMap) { this.listMap.remove(); this.listMap = null; }
        document.getElementById('detailView').classList.add('hidden');
        document.getElementById('detailView').classList.remove('detail-view-expanded');
        document.getElementById('listsView').classList.remove('hidden');
        this.loadLists();
    }

    renderStats() {
        const s = this.currentList?.stats || {};
        const total = parseInt(s.total) || 0;
        const visited = parseInt(s.websites_visited) || 0;
        const reachedOut = parseInt(s.reached_out_count) || 0;
        const hasPhone = parseInt(s.has_phone) || 0;
        const hasEmail = parseInt(s.has_email) || 0;
        const hasSocials = parseInt(s.has_socials) || 0;
        const hasNotes = parseInt(s.has_notes) || 0;
        const emailed = parseInt(s.emailed_count) || 0;
        const igDm = parseInt(s.ig_dm_count) || 0;
        const stageNew = parseInt(s.stage_new) || 0;
        const stageContacted = parseInt(s.stage_contacted) || 0;
        const stageEngaged = parseInt(s.stage_engaged) || 0;
        const stageClient = parseInt(s.stage_client) || 0;
        const stageNoResponse = parseInt(s.stage_no_response) || 0;
        const contacted = stageContacted + stageEngaged + stageClient + stageNoResponse;
        const responseRate = contacted > 0 ? ((stageEngaged + stageClient) / contacted * 100).toFixed(1) : '0.0';
        const conversionRate = (stageEngaged + stageClient) > 0 ? (stageClient / (stageEngaged + stageClient) * 100).toFixed(1) : '0.0';

        const hf = this.hasFilter;

        const maxStage = Math.max(stageNew, stageContacted, stageEngaged, stageClient, stageNoResponse, 1);
        const barPct = (v) => Math.max(v > 0 ? 8 : 0, (v / maxStage) * 100);

        // Top stats (above map)
        document.getElementById('topStatsRow').innerHTML = `
        <div class="stats-row" style="margin-bottom:20px;">
            <div class="stat-card accent clickable ${hf === '' ? 'active-filter' : ''}" onclick="app.clearAllFilters()"><div class="stat-value">${total.toLocaleString()}</div><div class="stat-label">Total Leads</div></div>
            <div class="stat-card clickable ${hf === 'visited' ? 'active-filter' : ''}" onclick="app.filterByHas('visited')"><div class="stat-value" style="color:var(--accent);">${visited.toLocaleString()}</div><div class="stat-label">Visited</div></div>
            <div class="stat-card clickable ${hf === 'email' ? 'active-filter' : ''}" onclick="app.filterByHas('email')"><div class="stat-value" style="color:var(--purple);">${hasEmail.toLocaleString()}</div><div class="stat-label">Have Email</div></div>
            <div class="stat-card clickable ${hf === 'socials' ? 'active-filter' : ''}" onclick="app.filterByHas('socials')"><div class="stat-value" style="color:var(--brand-blue);">${hasSocials.toLocaleString()}</div><div class="stat-label">Have Socials</div></div>
            <div class="stat-card clickable ${hf === 'phone' ? 'active-filter' : ''}" onclick="app.filterByHas('phone')"><div class="stat-value" style="color:var(--green);">${hasPhone.toLocaleString()}</div><div class="stat-label">Have Phone</div></div>
            <div class="stat-card clickable ${hf === 'notes' ? 'active-filter' : ''}" onclick="app.filterByHas('notes')"><div class="stat-value" style="color:var(--orange);">${hasNotes.toLocaleString()}</div><div class="stat-label">Have Notes</div></div>
        </div>`;

        // Pipeline + metrics (below map)
        let pipelineHtml = `<div class="pipeline-funnel" style="margin-bottom:16px;">
            <div class="pipeline-funnel-stage ${hf === 'stage_new' ? 'active-filter' : ''}" onclick="app.filterByHas('stage_new')">
                <div class="pf-count" style="color:var(--text-secondary);">${stageNew}</div>
                <div class="pf-label">New</div>
                <div class="pf-bar" style="background:var(--bg-secondary);width:${barPct(stageNew)}%;margin-left:auto;margin-right:auto;"></div>
            </div>
            <div class="pipeline-funnel-arrow"><i class="fas fa-chevron-right"></i></div>
            <div class="pipeline-funnel-stage ${hf === 'stage_contacted' ? 'active-filter' : ''}" onclick="app.filterByHas('stage_contacted')">
                <div class="pf-count" style="color:var(--accent);">${stageContacted}</div>
                <div class="pf-label">Contacted</div>
                <div class="pf-bar" style="background:var(--accent);width:${barPct(stageContacted)}%;margin-left:auto;margin-right:auto;"></div>
            </div>
            <div class="pipeline-funnel-arrow"><i class="fas fa-chevron-right"></i></div>
            <div class="pipeline-funnel-stage ${hf === 'stage_engaged' ? 'active-filter' : ''}" onclick="app.filterByHas('stage_engaged')">
                <div class="pf-count" style="color:var(--orange);">${stageEngaged}</div>
                <div class="pf-label">Engaged</div>
                <div class="pf-bar" style="background:var(--orange);width:${barPct(stageEngaged)}%;margin-left:auto;margin-right:auto;"></div>
            </div>
            <div class="pipeline-funnel-arrow"><i class="fas fa-chevron-right"></i></div>
            <div class="pipeline-funnel-stage ${hf === 'stage_client' ? 'active-filter' : ''}" onclick="app.filterByHas('stage_client')">
                <div class="pf-count" style="color:var(--green);">${stageClient}</div>
                <div class="pf-label">Client</div>
                <div class="pf-bar" style="background:var(--green);width:${barPct(stageClient)}%;margin-left:auto;margin-right:auto;"></div>
            </div>
            <div class="pipeline-funnel-arrow"><i class="fas fa-chevron-right"></i></div>
            <div class="pipeline-funnel-stage ${hf === 'stage_no_response' ? 'active-filter' : ''}" onclick="app.filterByHas('stage_no_response')">
                <div class="pf-count" style="color:var(--red);">${stageNoResponse}</div>
                <div class="pf-label">No Response</div>
                <div class="pf-bar" style="background:var(--red);width:${barPct(stageNoResponse)}%;margin-left:auto;margin-right:auto;"></div>
            </div>
            <div style="width:1px;background:var(--card-border);margin:8px 0;"></div>
            <div class="pipeline-funnel-stage" style="cursor:default;flex:0.6;">
                <div style="display:flex;gap:12px;justify-content:center;align-items:baseline;">
                    <span style="font-size:11px;color:var(--purple);font-weight:600;"><i class="fas fa-envelope" style="margin-right:3px;"></i>${emailed}</span>
                    <span style="font-size:11px;color:var(--pink);font-weight:600;"><i class="fas fa-comment-dots" style="margin-right:3px;"></i>${igDm}</span>
                </div>
                <div style="display:flex;gap:10px;justify-content:center;margin-top:6px;">
                    <span style="font-size:10px;color:var(--text-secondary);"><span style="font-weight:700;color:var(--orange);">${responseRate}%</span> resp</span>
                    <span style="font-size:10px;color:var(--text-secondary);"><span style="font-weight:700;color:var(--green);">${conversionRate}%</span> conv</span>
                </div>
            </div>
        </div>`;

        document.getElementById('statsRow').innerHTML = pipelineHtml;
    }

    renderSearchedAreas() {
        const searches = this.currentList?.state_stats || [];
        const area = document.getElementById('searchedStatesArea');
        const container = document.getElementById('searchedStates');
        const countEl = document.getElementById('searchedAreasCount');

        this.rebuildCoveredCitySets();

        if (searches.length === 0) { area.classList.add('hidden'); return; }

        area.classList.remove('hidden');
        if (countEl) countEl.textContent = `${searches.length} states`;
        container.innerHTML = searches.map(s =>
            `<span class="searched-tag"><i class="fas fa-check-circle" style="color:var(--green);margin-right:4px;"></i>${this.esc(s.state_name)} (${s.cities_searched} cities)</span>`
        ).join('');
    }

    normalizeCoverageKey(value) {
        return (value || '').toString().trim().toLowerCase();
    }

    coverageStateAliases(stateName, stateId = '') {
        const values = [stateName, stateId].map(v => this.normalizeCoverageKey(v)).filter(Boolean);
        const aliases = new Set(values);
        const countryAliases = {
            'ca': ['canada'],
            'canada': ['ca'],
            'gb': ['united kingdom', 'great britain', 'uk'],
            'uk': ['united kingdom', 'great britain', 'gb'],
            'united kingdom': ['uk', 'gb', 'great britain'],
            'us': ['united states', 'united states of america', 'usa'],
            'usa': ['us', 'united states', 'united states of america'],
            'united states': ['us', 'usa', 'united states of america']
        };
        values.forEach(value => (countryAliases[value] || []).forEach(alias => aliases.add(alias)));
        return Array.from(aliases);
    }

    rebuildCoveredCitySets() {
        this.searchedCitiesForList = new Set();
        this.searchedCityStateIdsForList = new Set();
        this.importedCityNamesForList = new Set();
        const addExact = (city, state, stateId = '') => {
            const c = this.normalizeCoverageKey(city);
            if (!c) return;
            const aliases = this.coverageStateAliases(state, stateId);
            aliases.forEach(s => this.searchedCitiesForList.add(`${c}|${s}`));
            const id = this.normalizeCoverageKey(stateId);
            if (id) this.searchedCityStateIdsForList.add(`${c}|${id}`);
            if (aliases.length === 0) this.importedCityNamesForList.add(c);
        };
        const addImported = (city, state) => {
            const c = this.normalizeCoverageKey(city);
            if (!c) return;
            const aliases = this.coverageStateAliases(state);
            // Match the server contract: imported rows with a state cover only
            // that city/state; fall back to city-only coverage only when the
            // imported row has no usable state.
            if (aliases.length === 0) {
                this.importedCityNamesForList.add(c);
            } else {
                aliases.forEach(s => this.searchedCitiesForList.add(`${c}|${s}`));
            }
        };
        (this.currentList?.searches || []).forEach(s => addExact(s.city, s.state_name, s.state_id));
        (this.currentList?.imported_cities || []).forEach(s => addImported(s.city, s.state_name));
    }

    isCityCovered(city, stateName, stateId = '') {
        const c = this.normalizeCoverageKey(city);
        if (!c) return false;
        if (this.importedCityNamesForList.has(c)) return true;
        const id = this.normalizeCoverageKey(stateId);
        if (id && this.searchedCityStateIdsForList.has(`${c}|${id}`)) return true;
        return this.coverageStateAliases(stateName, stateId).some(s => this.searchedCitiesForList.has(`${c}|${s}`));
    }

    async loadLeads() {
        if (!this.currentList) return;
        const params = {
            list_id: this.currentList.id,
            page: this.currentPage,
            per_page: this.perPage,
            search: this.searchQuery
        };
        if (this.hasFilter) params.has = this.hasFilter;
        if (this.hasFilter === 'selected') params.selected_ids = Array.from(this.selectedLeads);
        const method = this.hasFilter === 'selected' ? 'POST' : undefined;
        const data = await this.api('getLeads', params, method);
        if (data.success) {
            this.currentLeads = data.leads;
            this.totalPages = data.total_pages;
            this.totalLeads = data.total;
            this.renderLeads();
            this.renderPagination();
            this.updateSelectionUI();
            if (this.listMap) this.loadMapLeads();
        }
    }

    renderLeads() {
        const body = document.getElementById('leadsBody');
        const empty = document.getElementById('leadsEmpty');

        const addLeadsBtn = document.querySelector('.detail-header .btn-primary[onclick*="openAddLeadsModal"]');
        if (this.currentLeads.length === 0) {
            body.innerHTML = '';
            empty.classList.remove('hidden');
            if (addLeadsBtn) addLeadsBtn.classList.add('pulse-cue');
            return;
        }
        if (addLeadsBtn) addLeadsBtn.classList.remove('pulse-cue');
        empty.classList.add('hidden');

        const stageLabels = { new: 'New', contacted: 'Contacted', engaged: 'Engaged', client: 'Client', no_response: 'No Response' };

        body.innerHTML = this.currentLeads.map(lead => {
            const emails = lead.emails || [];
            const socials = lead.social_media_links || [];
            const hasEmail = emails.length > 0;
            const hasSocial = socials.length > 0;
            const hasPhone = !!lead.phone;
            const hasWeb = !!lead.website;
            const checked = this.selectedLeads.has(lead.id) ? 'checked' : '';
            const stage = lead.pipeline_stage || 'new';
            const fups = parseInt(lead.follow_up_count) || 0;
            const contactDate = lead.first_contacted_at ? new Date(lead.first_contacted_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : '';
            const eStatus = lead.enrichment_status;
            const enrichIcon = !hasWeb ? ''
                : eStatus === 'completed' ? '<span class="enrich-dot enrich-done" title="Website searched"></span>'
                : eStatus === 'processing' ? '<span class="enrich-dot enrich-working" title="Searching..."></span>'
                : eStatus === 'pending' ? '<span class="enrich-dot enrich-queued" title="Queued"></span>'
                : eStatus === 'failed' ? '<span class="enrich-dot enrich-fail" title="Search failed"></span>'
                : '<span class="enrich-dot enrich-waiting" title="Not yet searched"></span>';
            const rawScore = lead.lead_score;
            const computedScore = (rawScore !== null && rawScore !== undefined)
                ? { tier: rawScore >= 72 ? 'hot' : rawScore >= 45 ? 'warm' : 'cold', score: rawScore }
                : null;

            return `<tr>
                <td class="checkbox-wrap"><input type="checkbox" ${checked} onchange="app.toggleLeadSelect(${lead.id}, this.checked)"></td>
                <td>
                    <div class="lead-name" style="cursor:pointer;" onclick="app.openLeadDetail(${lead.id})">${this.esc(lead.business_name || 'Unknown')}</div>
                    ${lead.types ? `<div style="font-size:11px;color:var(--text-tertiary);margin-top:2px;">${this.esc(lead.types).substring(0, 50)}</div>` : ''}
                </td>
                <td><div class="lead-location">${this.esc(lead.city || '')}${lead.city && lead.state ? ', ' : ''}${this.esc(lead.state || '')}</div></td>
                <td>
                    <div class="lead-contact-icons">
                        ${hasPhone ? `<button class="contact-icon has" title="${this.esc(lead.phone)}" onclick="event.stopPropagation();navigator.clipboard.writeText('${this.esc(lead.phone)}');app.toast('Phone copied')"><i class="fas fa-phone"></i></button>` : `<span class="contact-icon none"><i class="fas fa-phone"></i></span>`}
                        ${hasEmail
                            ? `<button class="contact-icon has" onmouseenter="app.showEmailPopover(this, ${lead.id})" onclick="event.stopPropagation();" style="position:relative;"><i class="fas fa-envelope"></i>${emails.length > 1 ? `<span style="position:absolute;top:-4px;right:-4px;background:var(--accent);color:#fff;font-size:8px;font-weight:700;width:14px;height:14px;border-radius:50%;display:flex;align-items:center;justify-content:center;">${emails.length}</span>` : ''}</button>`
                        : `<span class="contact-icon none"><i class="fas fa-envelope"></i></span>`}
                        ${hasWeb ? `<button class="contact-icon ${lead.visited_website == 1 ? 'tracked' : 'has'}" title="Visit website" onclick="event.stopPropagation();app.openWebPreview('${this.esc(lead.website)}', ${lead.id})" style="position:relative;"><i class="fas fa-globe"></i>${enrichIcon}</button>` : `<span class="contact-icon none"><i class="fas fa-globe"></i></span>`}
                    </div>
                </td>
                <td>
                    <div class="lead-contact-icons">
                        ${hasSocial ? this.renderSocialIcons(lead) : `<span class="contact-icon none"><i class="fas fa-share-nodes"></i></span>`}
                    </div>
                </td>
                <td>
                    <span class="pipeline-badge stage-${stage}" onclick="event.stopPropagation();app.cyclePipelineStage(${lead.id})" title="Click to change stage">${stageLabels[stage] || 'New'}</span>
                </td>
                <td style="text-align:center;">
                    ${computedScore ? `<span class="score-pill ${computedScore.tier}" title="Score: ${rawScore} (${computedScore.tier})">${rawScore}</span>` : ''}
                </td>
                <td>
                    <div class="outreach-icons">
                        <button class="outreach-icon ${lead.outreach_email == 1 ? 'done' : 'not-done'}" title="${lead.outreach_email == 1 ? 'Email sent' : 'Mark email sent'}" onclick="event.stopPropagation();app.toggleOutreach(${lead.id}, 'outreach_email', ${lead.outreach_email == 1 ? 0 : 1})"><i class="fas fa-envelope"></i></button>
                        <button class="outreach-icon ${lead.outreach_instagram == 1 ? 'done' : 'not-done'}" title="${lead.outreach_instagram == 1 ? 'DM sent' : 'Mark DM sent'}" onclick="event.stopPropagation();app.toggleOutreach(${lead.id}, 'outreach_instagram', ${lead.outreach_instagram == 1 ? 0 : 1})"><i class="fas fa-comment-dots"></i></button>
                    </div>
                </td>
                <td>
                    <div class="followup-counter">
                        <button class="followup-btn" onclick="event.stopPropagation();app.decrementFollowUp(${lead.id})" title="Remove follow-up" ${fups === 0 ? 'disabled style="opacity:0.3;"' : ''}><i class="fas fa-minus" style="font-size:8px;"></i></button>
                        <span class="count" style="color:${fups > 0 ? 'var(--accent)' : 'var(--text-tertiary)'}">${fups}</span>
                        <button class="followup-btn" onclick="event.stopPropagation();app.incrementFollowUp(${lead.id})" title="Add follow-up" ${fups >= 4 ? 'disabled style="opacity:0.3;"' : ''}><i class="fas fa-plus" style="font-size:8px;"></i></button>
                    </div>
                </td>
                <td>
                    <span style="font-size:12px;color:${contactDate ? 'var(--text-secondary)' : 'var(--text-tertiary)'};">${contactDate || '—'}</span>
                </td>
                <td>
                    <div style="display:flex;gap:4px;">
                        <button class="btn-icon" onclick="event.stopPropagation();app.showNotePopover(this, ${lead.id})" title="${lead.notes ? 'View/edit notes' : 'Add note'}" style="position:relative;${lead.notes ? 'color:var(--orange);' : ''}"><i class="fas fa-sticky-note" style="font-size:12px;"></i>${lead.notes ? '<span style="position:absolute;top:-2px;right:-2px;width:8px;height:8px;border-radius:50%;background:var(--orange);"></span>' : ''}</button>
                        <button class="btn-icon" onclick="event.stopPropagation();app.openLeadDetail(${lead.id})" title="Details"><i class="fas fa-expand" style="font-size:12px;"></i></button>
                        <button class="btn-icon" onclick="event.stopPropagation();app.deleteLead(${lead.id})" title="Delete"><i class="fas fa-trash" style="font-size:12px;color:var(--red);"></i></button>
                    </div>
                </td>
            </tr>`;
        }).join('');
    }

    renderSocialIcons(lead) {
        const socials = lead.social_media_links || [];
        if (socials.length === 0) return '';
        const visited = lead.visited_socials || [];

        const visible = socials.slice(0, 3).map(url => {
            const platform = SOCIAL_PLATFORMS.find(p => p.patterns.some(pat => url.toLowerCase().includes(pat)));
            const icon = platform ? platform.icon : 'fas fa-link';
            const isVisited = visited.includes(url);
            return `<button class="contact-icon ${isVisited ? 'tracked' : 'has'}" title="${platform ? platform.name : 'Social'}" onclick="event.stopPropagation();app.trackSocialVisit(${lead.id}, '${this.esc(url)}')"><i class="${icon}"></i></button>`;
        }).join('');
        const moreCount = socials.length - 3;
        const moreBtn = moreCount > 0 ? `<button class="contact-icon has" style="font-size:10px;font-weight:600;min-width:24px;padding:0 4px;" title="Show ${moreCount} more" onclick="event.stopPropagation();app.expandSocials(${lead.id}, this)">+${moreCount}</button>` : '';
        return visible + moreBtn;
    }

    renderPagination() {
        const area = document.getElementById('paginationArea');
        if (this.totalPages <= 1) { area.innerHTML = ''; return; }

        let html = `<button class="page-btn" onclick="app.goToPage(${this.currentPage - 1})" ${this.currentPage <= 1 ? 'disabled' : ''}><i class="fas fa-chevron-left"></i></button>`;

        const maxVisible = 7;
        let start = Math.max(1, this.currentPage - Math.floor(maxVisible / 2));
        let end = Math.min(this.totalPages, start + maxVisible - 1);
        if (end - start < maxVisible - 1) start = Math.max(1, end - maxVisible + 1);

        if (start > 1) { html += `<button class="page-btn" onclick="app.goToPage(1)">1</button>`; if (start > 2) html += `<span style="padding:0 4px;color:var(--text-tertiary);">...</span>`; }
        for (let i = start; i <= end; i++) {
            html += `<button class="page-btn ${i === this.currentPage ? 'active' : ''}" onclick="app.goToPage(${i})">${i}</button>`;
        }
        if (end < this.totalPages) { if (end < this.totalPages - 1) html += `<span style="padding:0 4px;color:var(--text-tertiary);">...</span>`; html += `<button class="page-btn" onclick="app.goToPage(${this.totalPages})">${this.totalPages}</button>`; }

        html += `<button class="page-btn" onclick="app.goToPage(${this.currentPage + 1})" ${this.currentPage >= this.totalPages ? 'disabled' : ''}><i class="fas fa-chevron-right"></i></button>`;
        html += `<span style="margin-left:12px;font-size:13px;color:var(--text-secondary);">${this.totalLeads.toLocaleString()} leads</span>`;
        area.innerHTML = html;
    }

    async goToPage(page) {
        if (page < 1 || page > this.totalPages) return;
        this.currentPage = page;
        await this.loadLeads();
        document.querySelector('.leads-table-wrap')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    debounceSearch() {
        clearTimeout(this.searchDebounce);
        this.searchDebounce = setTimeout(() => {
            this.searchQuery = document.getElementById('leadSearch').value.trim();
            this.currentPage = 1;
            this.loadLeads();
            this.updateListMap();
        }, 300);
    }

    filterByHas(type) {
        this.hasFilter = this.hasFilter === type ? '' : type;
        this.currentPage = 1;
        document.querySelectorAll('#filterPills .filter-pill').forEach(p => p.classList.toggle('active', (p.dataset.filter || '') === this.hasFilter));
        this.renderStats();
        this.loadLeads();
        this.updateListMap();
    }

    toggleHideCities() {
        const table = document.querySelector('.leads-table');
        const btn = document.getElementById('hideCitiesToggle');
        if (!table) return;
        const hidden = table.classList.toggle('cities-hidden');
        if (btn) {
            btn.classList.toggle('active', hidden);
            btn.innerHTML = hidden ? '<i class="fas fa-map-marker-alt"></i> Show Cities' : '<i class="fas fa-map-marker-alt"></i> Hide Cities';
        }
    }

    clearAllFilters() {
        this.hasFilter = '';
        this.currentPage = 1;
        document.querySelectorAll('#filterPills .filter-pill').forEach(p => p.classList.toggle('active', p.dataset.filter === ''));
        this.renderStats();
        this.loadLeads();
        this.updateListMap();
    }

    // SELECTION

    toggleLeadSelect(id, checked) {
        if (checked) this.selectedLeads.add(id);
        else this.selectedLeads.delete(id);
        this.updateSelectionUI();
        if (this.hasFilter === 'selected') this.updateListMap();
    }

    toggleSelectAll(checked) {
        if (checked) {
            this.currentLeads.forEach(l => this.selectedLeads.add(l.id));
        } else {
            this.currentLeads.forEach(l => this.selectedLeads.delete(l.id));
        }
        this.renderLeads();
        this.updateSelectionUI();
        if (this.hasFilter === 'selected') this.updateListMap();
    }

    updateSelectionUI() {
        const cb = document.getElementById('selectAllCheckbox');
        const bulkActions = document.getElementById('bulkActions');
        const countEl = document.getElementById('bulkSelectedCount');
        if (cb) {
            const pageIds = new Set(this.currentLeads.map(l => l.id));
            const pageSelected = this.currentLeads.filter(l => this.selectedLeads.has(l.id)).length;
            cb.checked = this.currentLeads.length > 0 && pageSelected === this.currentLeads.length;
            cb.indeterminate = pageSelected > 0 && pageSelected < this.currentLeads.length;
        }
        if (this.selectedLeads.size > 0) {
            bulkActions.classList.remove('hidden');
            bulkActions.style.display = 'flex';
            const isFiltering = this.hasFilter === 'selected';
            countEl.innerHTML = `<span style="cursor:pointer;text-decoration:underline;text-underline-offset:2px;" onclick="app.filterByHas('${isFiltering ? '' : 'selected'}')" title="${isFiltering ? 'Show all leads' : 'Show only selected'}">${this.selectedLeads.size} selected</span>`;
        } else {
            bulkActions.classList.add('hidden');
            bulkActions.style.display = 'none';
        }
    }

    changePerPage(val) {
        this.perPage = parseInt(val);
        this.currentPage = 1;
        this.selectedLeads.clear();
        this.loadLeads();
    }

    async bulkDeleteLeads() {
        if (!confirm(`Delete ${this.selectedLeads.size} selected leads?`)) return;
        await this.api('deleteLeads', { ids: Array.from(this.selectedLeads) }, 'POST');
        this.selectedLeads.clear();
        this.updateSelectionUI();
        this.toast('Leads deleted');
        await this.refreshCurrentList();
    }

    async bulkSetVisited(val) {
        await this.api('bulkUpdateLeads', { ids: Array.from(this.selectedLeads), field: 'visited_website', value: val ? 1 : 0 }, 'POST');
        this.toast(`${this.selectedLeads.size} leads marked as ${val ? 'visited' : 'unvisited'}`);
        this.selectedLeads.clear();
        this.updateSelectionUI();
        await this.refreshCurrentList();
    }

    async bulkSetReachedOut(val) {
        await this.api('bulkUpdateLeads', { ids: Array.from(this.selectedLeads), field: 'reached_out', value: val ? 1 : 0 }, 'POST');
        this.toast(`${this.selectedLeads.size} leads marked as ${val ? 'reached out' : 'not reached out'}`);
        this.selectedLeads.clear();
        this.updateSelectionUI();
        await this.refreshCurrentList();
    }

    async bulkSetField(field, value) {
        await this.api('bulkUpdateLeads', { ids: Array.from(this.selectedLeads), field, value }, 'POST');
        this.toast(`${this.selectedLeads.size} leads updated`);
        this.selectedLeads.clear();
        this.updateSelectionUI();
        await this.refreshCurrentList();
    }

    async deleteLead(id) {
        if (!confirm('Delete this lead?')) return;
        await this.api('deleteLead', { id }, 'POST');
        this.toast('Lead deleted');
        await this.refreshCurrentList();
    }

    // TRACKING

    async trackWebsiteVisit(leadId, url) {
        window.open(url, '_blank');
        await this.api('updateLead', { id: leadId, visited_website: 1 }, 'POST');
        await this.refreshLeadsOnly();
    }

    async trackSocialVisit(leadId, url) {
        window.open(url, '_blank');
        const lead = this.currentLeads.find(l => l.id == leadId);
        const visited = lead ? [...new Set([...(lead.visited_socials || []), url])] : [url];
        await this.api('updateLead', { id: leadId, visited_social: 1, visited_socials: visited }, 'POST');
        if (lead) lead.visited_socials = visited;
        await this.refreshCurrentList();
    }

    expandSocials(leadId, btnEl) {
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (!lead) return;
        const socials = lead.social_media_links || [];
        if (socials.length <= 3) return;
        const extra = socials.slice(3);
        const visited = lead.visited_socials || [];
        let html = '';
        extra.forEach(url => {
            const platform = SOCIAL_PLATFORMS.find(p => p.patterns.some(pat => url.toLowerCase().includes(pat)));
            const icon = platform ? platform.icon : 'fas fa-link';
            const isVisited = visited.includes(url);
            html += `<button class="contact-icon ${isVisited ? 'tracked' : 'has'}" title="${platform ? platform.name : 'Social'}" onclick="event.stopPropagation();app.trackSocialVisit(${leadId}, '${this.esc(url)}')"><i class="${icon}"></i></button>`;
        });
        const wrap = document.createElement('span');
        wrap.innerHTML = html;
        btnEl.insertAdjacentHTML('afterend', wrap.innerHTML);
        btnEl.remove();
    }

    async toggleVisited(leadId, checked) {
        await this.api('updateLead', { id: leadId, visited_website: checked ? 1 : 0 }, 'POST');
        await this.refreshCurrentList();
    }

    async toggleReachedOut(leadId, checked) {
        await this.api('updateLead', { id: leadId, reached_out: checked ? 1 : 0 }, 'POST');
        await this.refreshCurrentList();
    }

    async refreshLeadsOnly() {
        await this.loadLeads();
        if (this.currentList) {
            const data = await this.api('getListDetail', { id: this.currentList.id });
            if (data.success) {
                this.currentList = data.list;
                this.renderStats();
            }
        }
    }

    async refreshCurrentList() {
        // Promise-safe debounce: first call creates a promise; later calls during
        // the 500ms pending window return the same promise; timer clears in finally
        if (this._refreshDebouncePromise) {
            return this._refreshDebouncePromise;
        }
        this._refreshDebouncePromise = (async () => {
            await new Promise(r => setTimeout(r, 500));
            if (this.currentList) {
                const data = await this.api('getListDetail', { id: this.currentList.id });
                if (data.success) {
                    this.currentList = data.list;
                    this.renderStats();
                    this.renderSearchedAreas();
                }
            }
            await this.loadLeads();
        })().finally(() => {
            this._refreshDebounceTimer = null;
            this._refreshDebouncePromise = null;
        });
        this._refreshDebounceTimer = setTimeout(() => {
            this._refreshDebounceTimer = null;
            this._refreshDebouncePromise = null;
        }, 500);
        return this._refreshDebouncePromise;
    }

    // LEAD DETAIL SLIDE

    async openLeadDetail(id) {
        const lead = this.currentLeads.find(l => l.id == id);
        if (!lead) return;
        this.currentLeadDetail = lead;

        document.getElementById('slideLeadName').textContent = lead.business_name || 'Unknown';
        document.getElementById('slideLeadLocation').textContent = `${lead.city || ''}${lead.city && lead.state ? ', ' : ''}${lead.state || ''}`;

        // Gallery — fetch raw_data on demand (list view no longer carries raw_data per task 5)
        const gallerySection = document.getElementById('slideGallerySection');
        const galleryEl = document.getElementById('slideGallery');
        const detail = await this.api('getLeadDetail', { id });
        let rawData = detail?.raw_data || {};
        const photos = rawData?.photos || rawData?.photos_sample || [];
        this.galleryPhotos = [];
        if (photos.length > 0) {
            photos.forEach(p => {
                const thumb = typeof p === 'string' ? p : (p.photo_url || p.src || '');
                const hd = typeof p === 'string' ? p : (p.photo_url_large || p.photo_url || p.src || '');
                if (thumb) this.galleryPhotos.push({ thumb, hd });
            });
        }
        if (this.galleryPhotos.length > 0) {
            gallerySection.classList.remove('hidden');
            galleryEl.innerHTML = this.galleryPhotos.map((p, i) =>
                `<img class="gallery-thumb" src="${this.esc(p.thumb)}" onclick="app.openLightbox(${i})" onerror="this.style.display='none'" alt="Photo">`
            ).join('');
        } else {
            gallerySection.classList.add('hidden');
            galleryEl.innerHTML = '';
        }

        // Map
        const mapSection = document.getElementById('slideMapSection');
        const mapEl = document.getElementById('slideMap');
        const lat = parseFloat(lead.latitude) || (rawData?.latitude) || null;
        const lng = parseFloat(lead.longitude) || (rawData?.longitude) || null;
        if (lat && lng) {
            mapSection.classList.remove('hidden');
            if (this.slideMap) { this.slideMap.remove(); this.slideMap = null; }
            setTimeout(() => {
                this.slideMap = L.map('slideMap').setView([lat, lng], 15);
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '&copy; OpenStreetMap'
                }).addTo(this.slideMap);
                L.marker([lat, lng]).addTo(this.slideMap).bindPopup(this.esc(lead.business_name || ''));
            }, 100);
        } else {
            mapSection.classList.add('hidden');
            if (this.slideMap) { this.slideMap.remove(); this.slideMap = null; }
        }

        // Contact Info
        const contact = [];
        if (lead.phone) contact.push(`<div class="info-row"><i class="fas fa-phone"></i><span>${this.esc(lead.phone)}</span></div>`);
        if (lead.website) contact.push(`<div class="info-row"><i class="fas fa-globe"></i><a href="#" onclick="event.preventDefault();app.openWebPreview('${this.esc(lead.website)}', ${lead.id})">${this.esc(lead.website)}</a></div>`);
        const emails = lead.emails || [];
        emails.forEach(e => contact.push(`<div class="info-row" style="justify-content:space-between;"><div style="display:flex;align-items:center;gap:10px;min-width:0;"><i class="fas fa-envelope"></i><a href="#" onclick="event.preventDefault();app.sendTemplateEmail('${this.esc(e)}', ${lead.id})" style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${this.esc(e)}</a></div><button onclick="event.preventDefault();navigator.clipboard.writeText('${this.esc(e)}');app.toast('Email copied')" style="background:none;border:none;cursor:pointer;color:var(--text-tertiary);padding:4px 6px;border-radius:6px;transition:all 0.15s;flex-shrink:0;" onmouseover="this.style.color='var(--accent)';this.style.background='var(--accent-light)'" onmouseout="this.style.color='var(--text-tertiary)';this.style.background='none'" title="Copy email"><i class="fas fa-copy" style="font-size:12px;"></i></button></div>`));
        if (lead.address) {
            const mapLink = lat && lng ? `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=16/${lat}/${lng}` : `https://www.openstreetmap.org/search?query=${encodeURIComponent(lead.address)}`;
            contact.push(`<div class="info-row"><i class="fas fa-map-marker-alt"></i><span>${this.esc(lead.address)}</span> <a href="${mapLink}" target="_blank" style="margin-left:6px;flex-shrink:0;" title="Open in map"><i class="fas fa-map" style="color:var(--accent);"></i></a></div>`);
        }
        document.getElementById('slideContact').innerHTML = contact.length ? contact.join('') : '<div style="color:var(--text-tertiary);font-size:13px;">No contact info</div>';

        // Socials
        const socials = lead.social_media_links || [];
        const visitedSocials = lead.visited_socials || [];
        if (socials.length > 0) {
            document.getElementById('slideSocials').innerHTML = socials.map(url => {
                const p = SOCIAL_PLATFORMS.find(pl => pl.patterns.some(pat => url.toLowerCase().includes(pat)));
                const isVisited = visitedSocials.includes(url);
                return `<div class="info-row"><i class="${p ? p.icon : 'fas fa-link'}" style="color:${isVisited ? 'var(--green)' : 'inherit'};"></i><a href="#" onclick="event.preventDefault();app.trackSocialVisit(${lead.id}, '${this.esc(url)}')" style="${isVisited ? 'color:var(--green);' : ''}">${this.esc(url)}</a></div>`;
            }).join('');
        } else {
            document.getElementById('slideSocials').innerHTML = '<div style="color:var(--text-tertiary);font-size:13px;">No social media found</div>';
        }

        document.getElementById('slideNotes').value = lead.notes || '';

        // Details
        const details = [];
        if (lead.rating) details.push(`<div class="info-row"><i class="fas fa-star" style="color:var(--orange);"></i><span>${lead.rating} stars (${lead.review_count || 0} reviews)</span></div>`);
        if (lead.types) details.push(`<div class="info-row"><i class="fas fa-tag"></i><span>${this.esc(lead.types)}</span></div>`);
        details.push(`<div class="info-row"><i class="fas fa-clock"></i><span>Added ${new Date(lead.created_at).toLocaleDateString()}</span></div>`);
        if (lead.website_visited_at) details.push(`<div class="info-row"><i class="fas fa-globe" style="color:var(--green);"></i><span>Website visited ${new Date(lead.website_visited_at).toLocaleDateString()}</span></div>`);
        if (lead.social_visited_at) details.push(`<div class="info-row"><i class="fas fa-share-nodes" style="color:var(--green);"></i><span>Social visited ${new Date(lead.social_visited_at).toLocaleDateString()}</span></div>`);
        if (lead.reached_out_at) details.push(`<div class="info-row"><i class="fas fa-paper-plane" style="color:var(--green);"></i><span>Reached out ${new Date(lead.reached_out_at).toLocaleDateString()}</span></div>`);
        document.getElementById('slideDetails').innerHTML = details.join('');

        // Lead Score widget in slide panel
        const rawScore = lead.lead_score;
        const scoreWidget = document.getElementById('slideScoreWidget');
        const scoreBreakdown = document.getElementById('slideScoreBreakdown');
        if (rawScore !== null && rawScore !== undefined) {
            const tier = rawScore >= 72 ? 'hot' : rawScore >= 45 ? 'warm' : 'cold';
            const tierLabel = tier.charAt(0).toUpperCase() + tier.slice(1);
            const tierColors = { hot: 'var(--red)', warm: 'var(--orange)', cold: 'var(--accent)' };
            const tierBg = { hot: 'rgba(255,59,48,0.10)', warm: 'rgba(202,148,42,0.12)', cold: 'rgba(var(--accent-rgb),0.10)' };
            scoreWidget.innerHTML = `
                <div style="display:flex;align-items:center;gap:8px;">
                    <div style="font-size:26px;font-weight:800;color:${tierColors[tier]};line-height:1;">${rawScore}</div>
                    <div style="display:flex;flex-direction:column;gap:3px;">
                        <span style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.04em;color:${tierColors[tier]};background:${tierBg[tier]};padding:2px 8px;border-radius:999px;display:inline-block;">${tierLabel}</span>
                        <span style="font-size:10px;color:var(--text-tertiary);">out of 100</span>
                    </div>
                    <button onclick="app.toggleSlideScoreBreakdown()" style="background:none;border:none;cursor:pointer;color:var(--text-tertiary);margin-left:auto;padding:4px;" title="Score breakdown">
                        <i class="fas fa-chevron-down" id="slideBreakdownToggle"></i>
                    </button>
                </div>
            `;

            // Build breakdown dimensions (mirrors PHP computeLeadScore)
            const emails = lead.emails || [];
            const hasEmail = emails.length > 0;
            const hasSocial = (lead.social_media_links || []).length > 0;
            const hasPhone = !!lead.phone;
            const hasWeb = !!lead.website;
            const contactPts = (hasEmail ? 7 : 0) + (hasPhone ? 5 : 0) + (hasWeb ? 5 : 0) + (hasSocial ? 3 : 0);
            const repPts = lead.rating ? Math.min(15, Math.round(lead.rating / 5 * 15)) : 0;
            const stageMap = { client: 25, engaged: 18, contacted: 10, no_response: 4, new: 0 };
            const stagePts = stageMap[lead.pipeline_stage || 'new'] || 0;
            const followPts = Math.min(12, (parseInt(lead.follow_up_count) || 0) * 3);
            const engagePts = stagePts + followPts;
            const outreachPts = (lead.reached_out ? 20 : 0) + (lead.outreach_email ? 5 : 0) + (lead.outreach_instagram ? 5 : 0) + (lead.first_contacted_at ? 3 : 0);
            const enrichPts = lead.enrichment_status === 'completed' ? 10 : 0;
            const enrichedAt = lead.enriched_at ? new Date(lead.enriched_at) : null;
            let enrichRecencyPts = 0, freshPts = 0;
            if (enrichedAt) {
                const daysSince = (Date.now() - enrichedAt.getTime()) / 86400000;
                if (daysSince <= 30) { enrichRecencyPts = 5; freshPts = 10; }
                else if (daysSince <= 90) { freshPts = 5; }
            }
            const dimRows = [
                ['Contact Completeness', contactPts, 20],
                ['Reputation', repPts, 15],
                ['Engagement Depth', engagePts, 37],
                ['Outreach Status', outreachPts, 33],
                ['Enrichment Quality', enrichPts + enrichRecencyPts, 15],
                ['Data Freshness', freshPts, 10]
            ];
            const maxW = 110;
            scoreBreakdown.innerHTML = `<div style="display:flex;flex-direction:column;gap:6px;padding:4px 2px;">
                ${dimRows.map(([label, pts, max]) => `
                    <div style="display:flex;align-items:center;gap:8px;">
                        <div style="font-size:11px;color:var(--text-secondary);min-width:130px;">${label}</div>
                        <div style="flex:1;height:6px;background:var(--card-border);border-radius:3px;overflow:hidden;">
                            <div style="height:100%;width:${maxW * pts / max}%;background:${pts > 0 ? 'var(--accent)' : 'var(--text-tertiary)'};border-radius:3px;transition:width 0.3s;"></div>
                        </div>
                        <div style="font-size:11px;font-weight:700;min-width:36px;text-align:right;color:var(--text-secondary);">${pts}<span style="color:var(--text-tertiary);font-weight:400;">/${max}</span></div>
                    </div>
                `).join('')}
            </div>`;
            scoreBreakdown.style.display = 'none';
        } else {
            scoreWidget.innerHTML = `<span style="font-size:12px;color:var(--text-tertiary);">Score not yet calculated</span>`;
            scoreBreakdown.innerHTML = '';
        }

        // Pipeline & Outreach fields
        document.getElementById('slidePipelineStage').value = lead.pipeline_stage || 'new';
        document.getElementById('slideOutreachEmail').checked = lead.outreach_email == 1;
        document.getElementById('slideOutreachInstagram').checked = lead.outreach_instagram == 1;
        this.slideRenderFollowUps(parseInt(lead.follow_up_count) || 0);
        const fcDate = lead.first_contacted_at ? new Date(lead.first_contacted_at).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }) : null;
        document.getElementById('slideFirstContact').innerHTML = fcDate
            ? `<i class="fas fa-calendar" style="margin-right:4px;"></i> First contacted: ${fcDate}`
            : '<i class="fas fa-calendar" style="margin-right:4px;color:var(--text-tertiary);"></i> Not yet contacted';

        document.getElementById('slideBackdrop').classList.add('open');
        document.getElementById('slidePanel').classList.add('open');
    }

    slideRenderFollowUps(count) {
        const dots = document.getElementById('slideFollowUpDots');
        const label = document.getElementById('slideFollowUpLabel');
        label.textContent = count === 0 ? 'None' : `${count} of 4`;
        dots.innerHTML = [0,1,2,3].map(i =>
            `<div style="flex:1;height:8px;border-radius:4px;background:${i < count ? 'var(--accent)' : 'var(--card-border)'};transition:background 0.2s;"></div>`
        ).join('');
    }

    async slideChangeFollowUp(delta) {
        if (!this.currentLeadDetail) return;
        const current = parseInt(this.currentLeadDetail.follow_up_count) || 0;
        const newVal = Math.max(0, Math.min(4, current + delta));
        if (newVal === current) return;
        this.currentLeadDetail.follow_up_count = newVal;
        this.slideRenderFollowUps(newVal);
        await this.api('updateLead', { id: this.currentLeadDetail.id, follow_up_count: newVal }, 'POST');
        await this.refreshCurrentList();
    }

    async updatePipelineStage(stage) {
        if (!this.currentLeadDetail) return;
        this.currentLeadDetail.pipeline_stage = stage;
        await this.api('updateLead', { id: this.currentLeadDetail.id, pipeline_stage: stage }, 'POST');
        await this.refreshCurrentList();
    }

    async updateOutreach(field, checked) {
        if (!this.currentLeadDetail) return;
        this.currentLeadDetail[field] = checked ? 1 : 0;
        const update = { id: this.currentLeadDetail.id, [field]: checked ? 1 : 0 };
        if (checked && this.currentLeadDetail.pipeline_stage === 'new') {
            update.pipeline_stage = 'contacted';
            this.currentLeadDetail.pipeline_stage = 'contacted';
            document.getElementById('slidePipelineStage').value = 'contacted';
        }
        await this.api('updateLead', update, 'POST');
        const fcEl = document.getElementById('slideFirstContact');
        if (checked && !this.currentLeadDetail.first_contacted_at) {
            this.currentLeadDetail.first_contacted_at = new Date().toISOString();
            fcEl.innerHTML = `<i class="fas fa-calendar" style="margin-right:4px;"></i> First contacted: ${new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}`;
        }
        await this.refreshCurrentList();
    }

    async toggleOutreach(leadId, field, value) {
        const update = { id: leadId, [field]: value };
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (lead) {
            lead[field] = value;
            if (value && (!lead.pipeline_stage || lead.pipeline_stage === 'new')) {
                update.pipeline_stage = 'contacted';
                lead.pipeline_stage = 'contacted';
            }
            this.renderLeads();
        }
        await this.api('updateLead', update, 'POST');
        await this.refreshCurrentList();
    }

    async cyclePipelineStage(leadId) {
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (!lead) return;
        const stages = ['new', 'contacted', 'engaged', 'client', 'no_response'];
        const current = lead.pipeline_stage || 'new';
        const idx = stages.indexOf(current);
        const next = stages[(idx + 1) % stages.length];
        lead.pipeline_stage = next;
        this.renderLeads();
        await this.api('updateLead', { id: leadId, pipeline_stage: next }, 'POST');
        await this.refreshCurrentList();
    }

    async incrementFollowUp(leadId) {
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (!lead) return;
        const current = parseInt(lead.follow_up_count) || 0;
        if (current >= 4) return;
        lead.follow_up_count = current + 1;
        this.renderLeads();
        await this.api('updateLead', { id: leadId, follow_up_count: current + 1 }, 'POST');
        await this.refreshCurrentList();
    }

    async decrementFollowUp(leadId) {
        const lead = this.currentLeads.find(l => l.id == leadId);
        if (!lead) return;
        const current = parseInt(lead.follow_up_count) || 0;
        if (current <= 0) return;
        lead.follow_up_count = current - 1;
        this.renderLeads();
        await this.api('updateLead', { id: leadId, follow_up_count: current - 1 }, 'POST');
        await this.refreshCurrentList();
    }

    closeLeadDetail() {
        document.getElementById('slideBackdrop').classList.remove('open');
        document.getElementById('slidePanel').classList.remove('open');
        this.currentLeadDetail = null;
        if (this.slideMap) { this.slideMap.remove(); this.slideMap = null; }
    }

    toggleSlideScoreBreakdown() {
        const el = document.getElementById('slideScoreBreakdown');
        const icon = document.getElementById('slideBreakdownToggle');
        if (!el) return;
        const open = el.style.display === 'block';
        el.style.display = open ? 'none' : 'block';
        if (icon) icon.className = open ? 'fas fa-chevron-down' : 'fas fa-chevron-up';
    }

    async trackWebsiteVisitSilent(leadId) {
        await this.api('updateLead', { id: leadId, visited_website: 1 }, 'POST');
    }

    async trackSocialVisitSilent(leadId) {
        await this.api('updateLead', { id: leadId, visited_social: 1 }, 'POST');
    }

    async updateTracking(leadId, field, value) {
        await this.api('updateLead', { id: leadId, [field]: value ? 1 : 0 }, 'POST');
        await this.refreshLeadsOnly();
    }

    async saveNotes() {
        if (!this.currentLeadDetail) return;
        const notes = document.getElementById('slideNotes').value;
        await this.api('updateLead', { id: this.currentLeadDetail.id, notes }, 'POST');
        this.toast('Notes saved');
        await this.refreshCurrentList();
    }

    // ADD LEADS - BULK SCRAPE

    async openAddLeadsModal() {
        document.getElementById('addLeadsModal').classList.add('active');

        // [METRICS-MODAL-FIX] If a scrape is currently running in this session, do NOT
        // wipe the progress UI / clear scrapeRunId. resetScrapeUI() hides scrapeProgress,
        // clears scrapeQueueStatus (the 4-lane pills: running/queued/completed/failed),
        // clears the activity log, AND nulls scrapeRunId — running it here would blank
        // out the modal while the backend is mid-scrape, and a cancel/refresh would
        // never see the original run again. Instead, unhide the progress area, refresh
        // the queue status from the backend, and start a lightweight read-only poll so
        // counts stay current while the modal is open. The active scrape is NOT
        // cancelled, stopped, or restarted — this path is a pure status view.
        const scrapeInProgress = !!this.scrapeRunId && this.scraping === true;
        if (scrapeInProgress) {
            document.getElementById('scrapeProgress').classList.remove('hidden');
            const aiSection = document.getElementById('aiScrapeSection');
            if (aiSection) aiSection.style.display = '';
            // [MODAL-UX] Defensive: ensure buttons reflect the active-scrape
            // state in case openAddLeadsModal was reached via the bg progress
            // 'View' button or another path that didn't go through
            // startBulkScrape (which sets these itself).
            const sBtn = document.getElementById('startScrapeBtn');
            if (sBtn) { sBtn.disabled = true; sBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Searching...'; }
            const cBtn = document.getElementById('cancelScrapeBtn');
            if (cBtn) { cBtn.textContent = 'Cancel Search'; cBtn.disabled = false; }
            const dBtn = document.getElementById('closeScrapeBtn');
            if (dBtn) dBtn.classList.add('hidden');
            // Step 1 status row stays as-is; only refresh queue pills.
            await this.refreshCredits();
            const _activeStatus = await this.refreshScrapeQueueStatus();
            // [LANE-UI] Map the backend's running jobs to the 4 lane tiles so the
            // modal shows active lanes (instead of an empty container) when the
            // user opens it mid-scrape. The local _laneSlots may not be initialized
            // here, so the status path is used.
            if (_activeStatus) this._renderLaneProgressFromStatus(_activeStatus);
            this._startModalStatusPoll();
            return;
        }

        this.resetScrapeUI();
        await this.refreshCredits();
        const scrapeQuery = document.getElementById('scrapeQuery');
        if (scrapeQuery && !scrapeQuery.value.trim()) {
            scrapeQuery.value = this.currentList?.category || this.activeCategory || '';
        }
        if (scrapeQuery && !scrapeQuery.dataset.listened) {
            scrapeQuery.dataset.listened = 'true';
            scrapeQuery.addEventListener('input', () => this.updateCityCounts());
        }
        await this.loadStatesForCountry(this.selectedCountry);
        this.renderStates();
        this.renderCities();
        this.updateCityCounts();
        this.updateTopUsCitiesPanel();
    }

    async loadStatesForCountry(country) {
        if (!this.statesCache[country]) {
            const data = await this.api('getStates', { country });
            if (data.success) this.statesCache[country] = data.states;
        }
        this.states = this.statesCache[country] || [];
    }

    resetGeoSelections() {
        this.states = [];
        this.cities = [];
        this.selectedStates = new Set();
        this.selectedCities = new Set();
        this.citySortOrder = 'name';
        this.cityFilter = 'all';

        const stateSearch = document.getElementById('stateSearch');
        if (stateSearch) stateSearch.value = '';
        const citySearch = document.getElementById('citySearch');
        if (citySearch) citySearch.value = '';
        const selectAllStates = document.getElementById('selectAllStates');
        if (selectAllStates) selectAllStates.checked = false;
        const selectAllCities = document.getElementById('selectAllCities');
        if (selectAllCities) selectAllCities.checked = false;
        document.querySelectorAll('.city-filter-pill').forEach(p => p.classList.toggle('active', p.dataset.cityfilter === 'all'));
        document.querySelectorAll('[data-citysort]').forEach(p => p.classList.toggle('active', p.dataset.citysort === 'name'));
        this.renderTopCityPresetState(0);
        const status = document.getElementById('topCitiesPresetStatus') || document.getElementById('topUsCitiesStatus');
        if (status) status.textContent = '';
    }

    async switchCountry(country) {
        if (country === this.selectedCountry) return;
        this.selectedCountry = country;
        this.resetGeoSelections();
        document.querySelectorAll('.country-pick').forEach(b => b.classList.toggle('active', b.dataset.country === country));
        // Set label based on region type
        const labels = { 'US': 'States', 'UK': 'Regions', 'EU': 'Countries', 'CA-LAT': 'Countries', 'CAR': 'Countries', 'AF': 'Countries', 'ME-CA': 'Countries', 'RU-CN': 'Countries', 'SA-SEA-OC': 'Countries' };
        document.getElementById('statesLabel').textContent = labels[country] || 'States';
        await this.loadStatesForCountry(country);
        this.renderStates();
        this.renderCities();
        this.updateCityCounts();
        this.updateTopUsCitiesPanel();
    }


    updateTopUsCitiesPanel() {
        const panel = document.getElementById('topCitiesPresetPanel') || document.getElementById('topUsCitiesPanel');
        if (!panel) return;

        const labels = {
            'US': 'Top US Cities',
            'UK': 'Top UK Cities',
            'EU': 'Top Europe Cities',
            'CA-LAT': 'Top Canada & Latin America Cities',
            'CAR': 'Top Caribbean Cities',
            'AF': 'Top Africa Cities',
            'ME-CA': 'Top Middle East & Central Asia Cities',
            'RU-CN': 'Top Russia, China & North Asia Cities',
            'SA-SEA-OC': 'Top South Asia, SE Asia & Oceania Cities'
        };

        const country = this.selectedCountry;
        const hasPreset = !!labels[country];

        panel.style.display = hasPreset ? '' : 'none';

        if (hasPreset) {
            const titleEl = document.getElementById('topCitiesPresetTitle');
            if (titleEl) {
                titleEl.textContent = `${labels[country]} (presets)`;
            }

            const hintEl = document.getElementById('topCitiesPresetHint') || document.getElementById('topUsCitiesHint');
            if (hintEl) {
                const hintLabels = {
                    'US': 'One-click load — selects states + cities automatically.',
                    'UK': 'One-click load — selects UK regions + cities automatically.',
                    'EU': 'One-click load — selects EU countries + cities automatically.',
                    'CA-LAT': 'One-click load — selects countries + cities automatically.',
                    'CAR': 'One-click load — selects countries + cities automatically.',
                    'AF': 'One-click load — selects countries + cities automatically.',
                    'ME-CA': 'One-click load — selects countries + cities automatically.',
                    'RU-CN': 'One-click load — selects countries + cities automatically.',
                    'SA-SEA-OC': 'One-click load — selects countries + cities automatically.'
                };
                hintEl.textContent = hintLabels[country] || 'One-click load — selects areas + cities automatically.';
            }
        } else {
            this.renderTopCityPresetState(0);
            const status = document.getElementById('topCitiesPresetStatus') || document.getElementById('topUsCitiesStatus');
            if (status) status.textContent = '';
        }
    }

    renderTopCityPresetState(limit) {
        document.querySelectorAll('.top-city-preset-pill, .top-us-city-pill').forEach(p => {
            const pillLimit = p.dataset.topuslimit;
            const isActive = pillLimit !== 'clear' && Number(pillLimit) === Number(limit);
            p.classList.toggle('active', isActive);
        });
    }

    async selectTopUsCities(limit) {
        return this.selectTopCities(limit);
    }

    async selectTopCities(limit) {
        const allowedLimits = [100, 200, 300, 400, 500, 1000, 2000, 3000, 5000, 10000];
        const status = document.getElementById('topCitiesPresetStatus') || document.getElementById('topUsCitiesStatus');
        const country = this.selectedCountry;

        if (limit === 0) {
            this.renderTopCityPresetState(0);
            if (status) status.textContent = 'Preset cleared. Your manual selections are untouched.';
            return;
        }

        if (!allowedLimits.includes(Number(limit))) {
            if (status) status.textContent = 'Invalid preset.';
            return;
        }

        const regionNames = {
            'US': 'US',
            'UK': 'UK',
            'EU': 'Europe',
            'CA-LAT': 'Canada & Latin America',
            'CAR': 'Caribbean',
            'AF': 'Africa',
            'ME-CA': 'Middle East & Central Asia',
            'RU-CN': 'Russia, China & North Asia',
            'SA-SEA-OC': 'South Asia, SE Asia & Oceania'
        };
        const regionName = regionNames[country] || country;
        const scopedStateIds = Array.from(this.selectedStates || []).filter(Boolean);
        const scopedStateNames = scopedStateIds.map(id => {
            const row = (this.states || []).find(s => String(s.state_id) === String(id));
            return row ? row.state_name : id;
        });
        const scopeLabel = scopedStateNames.length === 1
            ? scopedStateNames[0]
            : (scopedStateNames.length > 1 ? `${scopedStateNames.length} selected areas` : regionName);

        if (status) status.textContent = `Loading top ${limit} new ${scopeLabel} cities...`;

        const data = await this.api('getTopCities', {
            country: country,
            limit: Number(limit),
            state_ids: scopedStateIds.join(','),
            list_id: this.currentList?.id || ''
        });
        if (!data || !data.success) {
            if (status) status.textContent = (data && data.error) ? `Failed: ${data.error}` : 'Failed to load top cities.';
            return;
        }

        const loaded = (data.cities || []).map(c => {
            c.state_id = c.state_id;
            c.state_name = c.state_name;
            c.population = c.population !== null && c.population !== undefined ? parseInt(c.population) : null;
            return c;
        }).filter(c => !this.isCityCovered(c.city, c.state_name, c.state_id));

        if (loaded.length === 0) {
            this.renderTopCityPresetState(0);
            if (status) {
                // Exact full-pool covered count when the server provides it; prefix compatibility otherwise.
                const coveredTotal = data.covered_in_pool !== undefined
                    ? Number(data.covered_in_pool || 0)
                    : Number(data.skipped_covered || 0);
                const poolTotal = Number(data.pool_size ?? 0);
                const unsearchedTotal = Number(data.unsearched_in_pool ?? Math.max(0, poolTotal - coveredTotal));
                status.textContent = unsearchedTotal > 0
                    ? `No new ${scopeLabel} cities shown in ${poolTotal}: ${coveredTotal} covered and ${unsearchedTotal} new hidden by the client coverage re-check (imported-city name match).`
                    : (coveredTotal > 0
                        ? `No new ${scopeLabel} cities available in the top candidate pool; ${coveredTotal} already covered.`
                        : `No ${scopeLabel} cities available for this preset.`);
            }
            return;
        }

        // Replace current city list and selection with the preset.
        this.cities = loaded;
        this.selectedStates = new Set();
        this.selectedCities = new Set();
        loaded.forEach(c => {
            if (c.state_id) this.selectedStates.add(c.state_id);
            this.selectedCities.add(`${c.city}|${c.state_id}`);
        });

        // Make sure the states cache for the current country has every state represented so renderStates can show checkmarks.
        if (!this.statesCache) this.statesCache = {};
        if (!this.statesCache[country]) {
            this.statesCache[country] = [];
        }
        const known = new Set(this.statesCache[country].map(s => s.state_id));
        loaded.forEach(c => {
            if (!known.has(c.state_id) && c.state_name) {
                this.statesCache[country].push({ state_id: c.state_id, state_name: c.state_name });
                known.add(c.state_id);
            }
        });
        this.states = this.statesCache[country] || this.states;

        // Default the city panel to Most Pop so the user immediately sees the populated top-N order.
        this.citySortOrder = 'pop_desc';
        document.querySelectorAll('[data-citysort]').forEach(p => {
            p.classList.toggle('active', p.dataset.citysort === 'pop_desc');
        });

        this.renderTopCityPresetState(limit);
        if (status) {
            const stateCount = this.selectedStates.size;
            const labelsSingular = {
                'US': 'state', 'UK': 'region', 'EU': 'country',
                'CA-LAT': 'country', 'CAR': 'country', 'AF': 'country',
                'ME-CA': 'country', 'RU-CN': 'country', 'SA-SEA-OC': 'country'
            };
            const labelsPlural = {
                'US': 'states', 'UK': 'regions', 'EU': 'countries',
                'CA-LAT': 'countries', 'CAR': 'countries', 'AF': 'countries',
                'ME-CA': 'countries', 'RU-CN': 'countries', 'SA-SEA-OC': 'countries'
            };
            const areaLabel = stateCount === 1 ? (labelsSingular[country] || 'state') : (labelsPlural[country] || 'states');
            // MM-MATH-LIVE-FIX-001: exact, labeled quantities — scope total, full covered,
            // all new, the shown preset batch, and the client-side re-filter removals —
            // one contract: total = covered + new(all); new(all) = shown + re-filtered.
            const poolSize = Number(data.pool_size ?? loaded.length);
            const coveredInPool = Number(data.covered_in_pool ?? data.skipped_covered ?? 0);
            const unsearchedInPool = Number(data.unsearched_in_pool ?? Math.max(0, poolSize - coveredInPool));
            const serverReturned = Array.isArray(data.cities) ? data.cities.length : loaded.length;
            const reFiltered = Math.max(0, serverReturned - loaded.length);
            const reFilteredText = reFiltered > 0 ? ` | Not shown (client coverage re-check): ${reFiltered}` : '';
            status.textContent = `Total in ${scopeLabel}: ${poolSize} | Covered: ${coveredInPool} | New (all): ${unsearchedInPool} | In this preset: ${loaded.length}${reFilteredText} across ${stateCount} ${areaLabel}.`;
        }
        this.renderStates();
        this.renderCities();
        this.updateCityCounts();
    }
    async closeAddLeadsModal() {
        // [METRICS-MODAL-FIX] Stop any active modal status-poll we may have started
        // when reopening during an active scrape. We do this BEFORE the existing cancel
        // path so a no-op close (no active scrape) still clears stale timers cleanly.
        this._stopModalStatusPoll();
        const runId = this.scrapeRunId;
        this.scraping = false;
        this.scrapeCancelled = true;
        if (runId && this.currentList) {
            try {
                await this.api('cancelScrape', { list_id: this.currentList.id, run_id: runId }, 'POST');
            } catch (e) {
                console.warn('Unable to cancel scrape run', e);
            }
        }
        document.getElementById('addLeadsModal').classList.remove('active');
        this.resetScrapeUI();
    }

    _startModalStatusPoll() {
        // Read-only queue-status poll for the Add Leads modal while an active scrape is
        // running. Calls refreshScrapeQueueStatus() (which is a GET against
        // getScrapeQueueStatus — no DB writes, no API key use, no claim/complete calls).
        // Stops automatically when the scrape ends, the modal closes, or this is called
        // again (idempotent). Does NOT touch this.scraping, this.scrapeRunId, or the
        // backend queue — it only refreshes the visible 4-lane pill counts.
        this._stopModalStatusPoll();
        this._modalStatusPollTimer = setInterval(async () => {
            if (!this.scraping) {
                this._stopModalStatusPoll();
                return;
            }
            const modal = document.getElementById('addLeadsModal');
            if (!modal || !modal.classList.contains('active')) {
                this._stopModalStatusPoll();
                return;
            }
            try {
                await this.refreshScrapeQueueStatus();
            } catch (e) {
                // Silent — poll retries on next tick; never throws to user.
                console.warn('Modal status poll failed', e);
            }
        }, 2500);
    }

    _stopModalStatusPoll() {
        if (this._modalStatusPollTimer) {
            clearInterval(this._modalStatusPollTimer);
            this._modalStatusPollTimer = null;
        }
    }

    resetScrapeUI() {
        this.resetGeoSelections();
        document.getElementById('startScrapeBtn').classList.remove('hidden');
        document.getElementById('startScrapeBtn').disabled = false;
        document.getElementById('startScrapeBtn').innerHTML = '<i class="fas fa-rocket"></i> Start Search';
        document.getElementById('cancelScrapeBtn').classList.remove('hidden');
        document.getElementById('cancelScrapeBtn').disabled = false;
        document.getElementById('cancelScrapeBtn').textContent = 'Cancel';
        document.getElementById('closeScrapeBtn').classList.add('hidden');
        document.getElementById('scrapeProgress').classList.add('hidden');
        document.getElementById('aiScrapeSection').style.display = 'none';
        const queueStatus = document.getElementById('scrapeQueueStatus');
        if (queueStatus) queueStatus.innerHTML = '';
        const _al = document.getElementById('scrapeActivityLog');
        if (_al) { _al.style.display = 'none'; _al.innerHTML = ''; }
        // [LANE-UI] Clear the 4 horizontal lane tiles and reset slot state.
        const _laneContainer = document.getElementById('laneProgressContainer');
        if (_laneContainer) _laneContainer.innerHTML = '';
        this._laneSlots = null;
        this._stopModalStatusPoll();
        this.scrapeRunId = null;
        this.updateCityCounts();
    }

    showBgProgress() {
        let bar = document.getElementById('bgProgressBar');
        if (!bar) {
            const wrap = document.createElement('div');
            wrap.id = 'bgProgressBar';
            wrap.style.cssText = 'position:fixed;bottom:20px;right:20px;background:var(--card-solid);border:1px solid var(--card-border);border-radius:14px;padding:14px 18px;box-shadow:0 8px 30px rgba(0,0,0,0.12);z-index:9999;min-width:280px;font-size:13px;font-family:inherit;backdrop-filter:blur(20px);';
            wrap.innerHTML = `
                <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
                    <i class="fas fa-robot" style="color:var(--purple);"></i>
                    <span style="font-weight:600;">${this.scraping ? 'Search in Progress' : 'Enrichment Running'}</span>
                    <button onclick="app.openAddLeadsModal()" style="margin-left:auto;background:none;border:none;color:var(--accent);cursor:pointer;font-size:12px;font-weight:600;">View</button>
                </div>
                <div style="height:4px;background:var(--card-border);border-radius:99px;overflow:hidden;">
                    <div id="bgProgressFill" style="height:100%;background:var(--purple);border-radius:99px;width:0%;transition:width 0.3s;"></div>
                </div>
                <div id="bgProgressText" style="font-size:11px;color:var(--text-secondary);margin-top:6px;">Working...</div>
            `;
            document.body.appendChild(wrap);
        }
    }

    updateBgProgress(pct, text) {
        const fill = document.getElementById('bgProgressFill');
        const textEl = document.getElementById('bgProgressText');
        if (fill) fill.style.width = pct + '%';
        if (textEl) textEl.textContent = text;
    }

    hideBgProgress() {
        const bar = document.getElementById('bgProgressBar');
        if (bar) {
            bar.style.transition = 'opacity 0.3s';
            bar.style.opacity = '0';
            setTimeout(() => bar.remove(), 300);
        }
    }

    renderStates() {
        const list = document.getElementById('statesList');
        const q = (document.getElementById('stateSearch')?.value || '').toLowerCase();
        const filtered = q ? this.states.filter(s => s.state_name.toLowerCase().includes(q)) : this.states;
        list.innerHTML = filtered.map(s => {
            const searched = (this.currentList?.state_stats || []).find(ss => this.coverageStateAliases(ss.state_name, ss.state_id).includes(this.normalizeCoverageKey(s.state_name)) || this.coverageStateAliases(s.state_name, s.state_id).includes(this.normalizeCoverageKey(ss.state_name)));
            const checked = this.selectedStates.has(s.state_id) ? 'checked' : '';
            return `<label class="selector-item">
                <input type="checkbox" value="${this.esc(s.state_id)}" data-name="${this.esc(s.state_name)}" ${checked} onchange="app.onStateToggle(this)">
                <span>${this.esc(s.state_name)}</span>
                ${searched ? `<span class="searched-badge">${searched.cities_searched} searched</span>` : ''}
            </label>`;
        }).join('');
    }

    filterStates() {
        this.renderStates();
    }

    async onStateToggle(el) {
        if (el.checked) {
            this.selectedStates.add(el.value);
            const data = await this.api('getCities', { state_id: el.value, state_name: el.dataset.name || '', country: this.selectedCountry });
            if (data.success) {
                const stateName = el.dataset.name;
                data.cities.forEach(c => {
                    c.state_id = c.state_id || el.value;
                    c.state_name = c.state_name || stateName;
                    c.population = c.population ? parseInt(c.population) : null;
                });
                this.cities = [...this.cities.filter(c => c.state_id !== el.value), ...data.cities];
            }
        } else {
            this.selectedStates.delete(el.value);
            this.cities = this.cities.filter(c => c.state_id !== el.value);
            this.cities.forEach(c => { if (c.state_id === el.value) this.selectedCities.delete(`${c.city}|${el.value}`); });
        }
        this.renderCities();
        this.updateCityCounts();
    }

    renderCities() {
        const list = document.getElementById('citiesList');
        const stateFiltered = this.cities.filter(c => this.selectedStates.has(c.state_id));
        if (stateFiltered.length === 0) {
            const label = this.selectedCountry === 'UK' ? 'region' : this.selectedCountry === 'EU' ? 'country' : 'state';
            list.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-tertiary);font-size:13px;">Select a ${label} to see cities</div>`;
            document.getElementById('citiesCount').textContent = '';
            return;
        }
        const q = (document.getElementById('citySearch')?.value || '').toLowerCase();
        let filtered = q ? stateFiltered.filter(c => c.city.toLowerCase().includes(q)) : stateFiltered;

        if (this.cityFilter === 'searched') {
            filtered = filtered.filter(c => this.isCityCovered(c.city, c.state_name, c.state_id));
        } else if (this.cityFilter === 'unsearched') {
            filtered = filtered.filter(c => !this.isCityCovered(c.city, c.state_name, c.state_id));
        }

        if (this.citySortOrder === 'pop_desc') {
            filtered.sort((a, b) => (b.population || 0) - (a.population || 0));
        } else if (this.citySortOrder === 'pop_asc') {
            filtered.sort((a, b) => (a.population || 0) - (b.population || 0));
        } else {
            filtered.sort((a, b) => a.city.localeCompare(b.city));
        }

        document.getElementById('citiesCount').textContent = `(${filtered.length} of ${stateFiltered.length})`;
        list.innerHTML = filtered.map(c => {
            const key = `${c.city}|${c.state_id}`;
            const isSearched = this.isCityCovered(c.city, c.state_name, c.state_id);
            const popStr = c.population ? c.population.toLocaleString() : '—';
            return `<label class="selector-item">
                <input type="checkbox" value="${key}" ${this.selectedCities.has(key) ? 'checked' : ''} onchange="app.onCityToggle(this)">
                <span style="flex:1;">${this.esc(c.city)}</span>
                <span style="font-size:11px;color:var(--text-tertiary);margin-left:auto;min-width:60px;text-align:right;">${popStr}</span>
                ${isSearched ? `<span class="searched-badge">done</span>` : ''}
            </label>`;
        }).join('');
    }

    setCityFilter(filter) {
        this.cityFilter = filter;
        document.querySelectorAll('.city-filter-pill').forEach(p => {
            p.classList.toggle('active', p.dataset.cityfilter === filter);
        });

        const stateFiltered = this.cities.filter(c => this.selectedStates.has(c.state_id));
        const q = (document.getElementById('citySearch')?.value || '').toLowerCase();
        let filtered = q ? stateFiltered.filter(c => c.city.toLowerCase().includes(q)) : stateFiltered;
        if (filter === 'searched') {
            filtered = filtered.filter(c => this.isCityCovered(c.city, c.state_name, c.state_id));
        } else if (filter === 'unsearched') {
            filtered = filtered.filter(c => !this.isCityCovered(c.city, c.state_name, c.state_id));
        }
        filtered.forEach(c => {
            this.selectedCities.add(`${c.city}|${c.state_id}`);
        });

        this.updateCityCounts();
        this.renderCities();
    }

    setCitySort(order) {
        this.citySortOrder = order;
        document.querySelectorAll('[data-citysort]').forEach(p => {
            p.classList.toggle('active', p.dataset.citysort === order);
        });
        this.renderCities();
    }

    filterCities() {
        this.renderCities();
    }

    onCityToggle(el) {
        if (el.checked) this.selectedCities.add(el.value);
        else this.selectedCities.delete(el.value);
        this.updateCityCounts();
    }

    toggleAllStates(checked) {
        document.querySelectorAll('#statesList input[type="checkbox"]').forEach(cb => {
            if (cb.checked !== checked) { cb.checked = checked; this.onStateToggle(cb); }
        });
    }

    toggleAllCities(checked) {
        document.querySelectorAll('#citiesList input[type="checkbox"]').forEach(cb => {
            cb.checked = checked;
            if (checked) this.selectedCities.add(cb.value);
            else this.selectedCities.delete(cb.value);
        });
        this.updateCityCounts();
    }

    updateCityCounts() {
        const selectedCount = this.selectedCities.size;
        const selectedEl = document.getElementById('selectedCitiesCount');
        if (selectedEl) selectedEl.textContent = selectedCount;
        const estimatedEl = document.getElementById('estimatedCredits');
        if (estimatedEl) estimatedEl.textContent = selectedCount;
    }

    async startBulkScrape() {
        if (this.scraping) {
            this.toast('Search already in progress');
            return;
        }
        const query = document.getElementById('scrapeQuery').value.trim();
        if (!query) { this.toast('Enter a search query'); return; }
        if (this.selectedCities.size === 0) { this.toast('Select at least one city'); return; }
        if (this.credits < this.selectedCities.size) {
            this.showUpgradePrompt(this.selectedCities.size);
            return;
        }

        const runId = 'run_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        this.scraping = true;
        this.scrapeRunId = runId;
        this.scrapeCancelled = false;
        const limit = parseInt(document.getElementById('scrapeLimit').value);
        const btn = document.getElementById('startScrapeBtn');
        btn.disabled = true;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Queueing...';
        document.getElementById('closeScrapeBtn').classList.add('hidden');
        document.getElementById('scrapeProgress').classList.remove('hidden');
        document.getElementById('aiScrapeSection').style.display = 'none';
        document.getElementById('scrapeStep1Status').textContent = '';
        // [MODAL-UX] During active scrape, the Cancel button should read
        // 'Cancel Search' so the user can distinguish it from the pre-scrape
        // 'Cancel' (which still means 'close modal'). ResetScrapeUI reverts it.
        document.getElementById('cancelScrapeBtn').textContent = 'Cancel Search';
        const actLog = document.getElementById('scrapeActivityLog');
        actLog.style.display = 'block';
        actLog.innerHTML = '';

        const _logActivity = (msg, type = 'info') => {
            const colors = { info: 'var(--text-secondary)', success: '#22c55e', warn: '#f59e0b', error: '#ef4444' };
            const line = document.createElement('div');
            line.style.cssText = `padding:2px 0;color:${colors[type] || colors.info};border-bottom:1px solid rgba(255,255,255,0.04);`;
            line.textContent = msg;
            actLog.prepend(line);
        };

        const cityList = [];
        this.selectedCities.forEach(key => {
            const [cityName, stateId] = key.split('|');
            const cityObj = this.cities.find(c => c.city === cityName && c.state_id === stateId);
            if (cityObj) cityList.push(cityObj);
        });

        let completed = 0;
        const total = cityList.length;
        let totalInserted = 0;
        let totalFound = 0;

        // [LANE-UI] Initialize 4 horizontal lane slots AFTER total is declared
        // (TDZ fix — the previous order referenced `total` before its const
        // declaration, throwing ReferenceError and leaving the Start button
        // stuck on 'Queueing...'). Slots are claimed inside the
        // boundedJobs.map(...) loop below so the tiles show real active work.
        this._initLaneSlots(total);
        this._renderLaneProgress();

        const _updateBar = () => {
            const safeCompleted = Math.min(completed, total);
            const pct = Math.min(100, Math.round((safeCompleted / total) * 100));
            document.getElementById('scrapeProgressBar').style.width = pct + '%';
            document.getElementById('scrapeProgressText').textContent = `${safeCompleted} of ${total} cities (${pct}%)`;
            document.getElementById('scrapeProgressCount').textContent = `${totalFound.toLocaleString()} found · ${totalInserted.toLocaleString()} saved`;
        };

        document.getElementById('scrapeProgressText').textContent = `0 of ${total} cities (0%)`;
        const enqueue = await this.api('enqueueScrapeCities', {
            list_id: this.currentList.id,
            search_query: query,
            country: this.selectedCountry,
            cities: cityList,
            run_id: runId
        }, 'POST');
        if (!enqueue.success) {
            this.scraping = false;
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-rocket"></i> Start Search';
            this.toast(enqueue.error || 'Unable to queue searches');
            return;
        }
        _logActivity(`Queued ${enqueue.queued} city jobs${enqueue.deduped ? `, ${enqueue.deduped} already queued` : ''}`, 'success');
        await this.refreshScrapeQueueStatus();

        // [ALREADY-QUEUED-FIX] If every city was already in the queue from a previous
        // run, enqueue.queued === 0 and deduped === total. The while loop below would
        // enter, claim nothing, break immediately, and leave the button stuck on
        // "Queueing..." because btn.innerHTML = '...Searching...' is inside the
        // jobs.length > 0 branch. We exit here with a clean resolve: stop the modal
        // status poll, restore the button, set scraping = false so re-entry is safe,
        // and show a clear toast. The backend zombie-job reaper (claimScrapeCityJobs
        // reaps running jobs > 10 min old) will free any stuck slots automatically.
        if (enqueue.queued === 0 && (enqueue.deduped || 0) === total) {
            this.scraping = false;
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-rocket"></i> Start Search';
            this._stopModalStatusPoll();
            document.getElementById('addLeadsModal').classList.remove('active');
            this.resetScrapeUI();
            this.toast(`${total} cities already queued — previous search will resume automatically`);
            return;
        }

        const _queueStart = Date.now();
        let _stalled = false;
        while (this.scraping && completed < total) {
            const claim = await this.api('claimScrapeCityJobs', { list_id: this.currentList.id, run_id: runId }, 'POST');
            if (!claim.success) {
                _logActivity(claim.error || 'Queue claim failed', 'error');
                break;
            }
            const jobs = claim.jobs || [];
            if (jobs.length === 0) {
                const status = await this.refreshScrapeQueueStatus();
                if (!status || ((status.counts.queued || 0) === 0 && (status.counts.running || 0) === 0)) break;
                // Watchdog: never spin on "Queueing..." forever. If the queue makes no
                // claimable progress for 60s, stop and surface an actionable error.
                if (completed === 0 && Date.now() - _queueStart > 60000) {
                    _stalled = true;
                    _logActivity('No worker slot freed up after 60s — stale jobs may be blocking the queue. Slots self-recover; please retry shortly.', 'error');
                    break;
                }
                await new Promise(r => setTimeout(r, 1200));
                continue;
            }

            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Searching...';
            const boundedJobs = jobs.slice(0, Math.max(0, total - completed));
            await Promise.all(boundedJobs.map(async (job) => {
                // [LANE-UI] Claim a slot for this city job so the 4 horizontal lane
                // tiles reflect which worker slots are currently searching where.
                const _slotIdx = this._claimLaneSlot();
                const _lane = this._laneSlots[_slotIdx];
                _lane.busy = true;
                _lane.city = job.city;
                _lane.state = job.state_name;
                _lane.search_query = job.search_query;
                _lane._startedAt = Date.now();
                _lane._finishedAt = null;
                this._renderLaneProgress();
                const fullQuery = `${job.search_query} in ${job.city}, ${job.state_name}`;
                _logActivity(`Searching "${job.search_query}" in ${job.city}, ${job.state_name}...`);
                try {
                    const logRes = await fetch('log_api_call.php', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ credits_used: 1, scraper_model: 'google_maps', search_query: fullQuery, input_params: { limit }, status: 'pending' })
                    });
                    const logData = await logRes.json();
                    if (!logData.success) throw new Error(logData.error || 'Credit deduction failed');

                    this.credits--;
                    this.updateCreditsDisplay();

                    // [HOTFIX-20260801] Per-job ISO country code mapping.
                    // Uses country_code column from DB if available; falls back to
                    // static name→code lookup for pre-hotfix queued jobs.
                    // Malformed/missing codes fail safely without silently forcing non-US to 'us'.
                    const _COUNTRY_NAME_TO_CODE = {'afghanistan':'af', 'albania':'al', 'algeria':'dz', 'andorra':'ad', 'angola':'ao', 'antigua and barbuda':'ag', 'argentina':'ar', 'aruba':'aw', 'australia':'au', 'austria':'at', 'bahamas':'bs', 'bahrain':'bh', 'bangladesh':'bd', 'barbados':'bb', 'belarus':'by', 'belgium':'be', 'belize':'bz', 'benin':'bj', 'bhutan':'bt', 'bolivia':'bo', 'bonaire, saint eustatius and saba':'bq', 'bosnia and herzegovina':'ba', 'botswana':'bw', 'brazil':'br', 'brunei':'bn', 'bulgaria':'bg', 'burkina faso':'bf', 'burundi':'bi', 'cabo verde':'cv', 'cambodia':'kh', 'cameroon':'cm', 'canada':'ca', 'central african republic':'cf', 'chad':'td', 'chile':'cl', 'china':'cn', 'colombia':'co', 'comoros':'km', 'costa rica':'cr', 'croatia':'hr', 'cuba':'cu', 'curaçao':'cw', 'czech republic':'cz', 'democratic republic of the congo':'cd', 'denmark':'dk', 'djibouti':'dj', 'dominica':'dm', 'dominican republic':'do', 'ecuador':'ec', 'egypt':'eg', 'el salvador':'sv', 'equatorial guinea':'gq', 'eritrea':'er', 'estonia':'ee', 'eswatini':'sz', 'ethiopia':'et', 'fiji':'fj', 'finland':'fi', 'france':'fr', 'french guiana':'gf', 'gabon':'ga', 'gambia':'gm', 'germany':'de', 'ghana':'gh', 'greece':'gr', 'greenland':'gl', 'grenada':'gd', 'guadeloupe':'gp', 'guatemala':'gt', 'guinea':'gn', 'guinea-bissau':'gw', 'guyana':'gy', 'haiti':'ht', 'honduras':'hn', 'hong kong':'hk', 'hungary':'hu', 'india':'in', 'indonesia':'id', 'iran':'ir', 'iraq':'iq', 'ireland':'ie', 'israel':'il', 'italy':'it', 'ivory coast':'ci', 'jamaica':'jm', 'japan':'jp', 'jordan':'jo', 'kazakhstan':'kz', 'kenya':'ke', 'kiribati':'ki', 'kuwait':'kw', 'kyrgyzstan':'kg', 'laos':'la', 'latvia':'lv', 'lebanon':'lb', 'lesotho':'ls', 'liberia':'lr', 'libya':'ly', 'liechtenstein':'li', 'lithuania':'lt', 'luxembourg':'lu', 'macau':'mo', 'madagascar':'mg', 'malawi':'mw', 'malaysia':'my', 'maldives':'mv', 'mali':'ml', 'malta':'mt', 'marshall islands':'mh', 'martinique':'mq', 'mauritania':'mr', 'mauritius':'mu', 'mexico':'mx', 'micronesia':'fm', 'moldova':'md', 'monaco':'mc', 'mongolia':'mn', 'montenegro':'me', 'morocco':'ma', 'mozambique':'mz', 'myanmar':'mm', 'namibia':'na', 'nauru':'nr', 'nepal':'np', 'netherlands':'nl', 'new zealand':'nz', 'nicaragua':'ni', 'niger':'ne', 'nigeria':'ng', 'north korea':'kp', 'north macedonia':'mk', 'macedonia':'mk', 'norway':'no', 'oman':'om', 'pakistan':'pk', 'palau':'pw', 'palestine':'ps', 'panama':'pa', 'papua new guinea':'pg', 'paraguay':'py', 'peru':'pe', 'philippines':'ph', 'poland':'pl', 'portugal':'pt', 'puerto rico':'pr', 'qatar':'qa', 'republic of the congo':'cg', 'romania':'ro', 'russia':'ru', 'rwanda':'rw', 'saint kitts and nevis':'kn', 'saint lucia':'lc', 'saint vincent and the grenadines':'vc', 'samoa':'ws', 'san marino':'sm', 'são tomé and príncipe':'st', 'saudi arabia':'sa', 'senegal':'sn', 'serbia':'rs', 'seychelles':'sc', 'sierra leone':'sl', 'singapore':'sg', 'slovakia':'sk', 'slovenia':'si', 'solomon islands':'sb', 'somalia':'so', 'south africa':'za', 'south korea':'kr', 'south sudan':'ss', 'spain':'es', 'sri lanka':'lk', 'sudan':'sd', 'suriname':'sr', 'sweden':'se', 'switzerland':'ch', 'syria':'sy', 'taiwan':'tw', 'tajikistan':'tj', 'tanzania':'tz', 'thailand':'th', 'timor-leste':'tl', 'togo':'tg', 'tonga':'to', 'trinidad and tobago':'tt', 'tunisia':'tn', 'turkey':'tr', 'turkmenistan':'tm', 'tuvalu':'tv', 'uganda':'ug', 'ukraine':'ua', 'united arab emirates':'ae', 'united kingdom':'gb', 'united states':'us', 'uruguay':'uy', 'uzbekistan':'uz', 'vanuatu':'vu', 'vatican city':'va', 'venezuela':'ve', 'vietnam':'vn', 'yemen':'ye', 'zambia':'zm', 'zimbabwe':'zw', 'czechia':'cz', 'swaziland':'sz'};
                    const _resolveCountryCode = (job) => {
                        if (job.country_code && /^[a-z]{2}$/i.test(job.country_code)) return job.country_code.toLowerCase();
                        const nameKey = this.normalizeCoverageKey(job.state_name);
                        if (nameKey && _COUNTRY_NAME_TO_CODE[nameKey]) return _COUNTRY_NAME_TO_CODE[nameKey];
                        return '';
                    };
                    let mapsCountry = _resolveCountryCode(job);
                    if (!mapsCountry) {
                        if (this.selectedCountry === 'US') mapsCountry = 'us';
                        else if (this.selectedCountry === 'UK') mapsCountry = 'gb';
                        else {
                            _logActivity(`Skipped ${job.city}: country code unavailable for region ${this.selectedCountry} — re-enqueue required`, 'warn');
                            await this.api('completeScrapeCityJob', { job_id: job.id, run_id: runId, status: 'failed', error_message: 'Country mapping unavailable — re-enqueue after hotfix deployment' }, 'POST');
                            this._freeLaneSlot(_slotIdx, false);
                            this._renderLaneProgress();
                            return 0;
                        }
                    }
                    const res = await fetch(`${this.mapsApiUrl}&query=${encodeURIComponent(fullQuery)}&limit=${limit}&country=${mapsCountry}`);
                    const data = await res.json();
                    const results = data?.data || [];
                    totalFound += results.length;

                    if (results.length > 0) {
                        const leads = results.map(r => ({ ...r, city: job.city, state: job.state_name }));
                        const addRes = await this.api('addLeads', { list_id: this.currentList.id, leads }, 'POST');
                        if (addRes.success) {
                            totalInserted += addRes.inserted;
                            _logActivity(`+${addRes.inserted} new leads saved from ${job.city}`, 'success');
                        }
                    } else {
                        _logActivity(`No results for ${job.city}`, 'warn');
                    }

                    await this.api('logSearch', {
                        list_id: this.currentList.id,
                        search_query: job.search_query,
                        state_name: job.state_name,
                        city: job.city,
                        results_count: results.length
                    }, 'POST');
                    await this.api('completeScrapeCityJob', { job_id: job.id, run_id: runId, status: 'completed', results_count: results.length }, 'POST');
                    completed++;
                    _updateBar();
                    // [LANE-UI] Free the slot and render so the tile shows the last
                    // completed city until a new job claims it.
                    this._freeLaneSlot(_slotIdx, false);
                    this._renderLaneProgress();
                    return results.length;
                } catch (err) {
                    console.error(`Error scraping ${job.city}:`, err);
                    _logActivity(`Error: ${job.city} - ${err.message}`, 'error');
                    await this.api('completeScrapeCityJob', { job_id: job.id, run_id: runId, status: 'failed', error_message: err.message }, 'POST');
                    completed++;
                    _updateBar();
                    // [LANE-UI] Free the slot (counted as failed) and re-render.
                    this._freeLaneSlot(_slotIdx, true);
                    this._renderLaneProgress();
                    return 0;
                }
            }));
            await this.refreshScrapeQueueStatus();
            this.loadLeads();
        }

        const wasCancelled = this.scrapeCancelled;
        this.scraping = false;
        if (wasCancelled) {
            return;
        }

        // If the queue stalled with zero progress, keep the modal open showing the
        // actionable error and let the user retry — do not claim success.
        if (_stalled) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-rocket"></i> Retry Search';
            await this.refreshScrapeQueueStatus();
            return;
        }

        await this.refreshCurrentList();
        // [MODAL-UX] Tag the completion toast as 'success' so the user gets a clear
        // green-accented confirmation card when the modal auto-closes after
        // a finished scrape — the only feedback the user gets, since the
        // Done button is hidden by resetScrapeUI immediately after.
        this.toast(`${totalInserted.toLocaleString()} leads found across ${total} cities — enrichment starting in background`, 'success');

        document.getElementById('addLeadsModal').classList.remove('active');
        this.resetScrapeUI();

        this.fireAllScrapes();
    }

    async refreshScrapeQueueStatus() {
        if (!this.currentList) return null;
        const params = { list_id: this.currentList.id };
        if (this.scrapeRunId) params.run_id = this.scrapeRunId;
        const status = await this.api('getScrapeQueueStatus', params);
        const el = document.getElementById('scrapeQueueStatus');
        if (status.success && el) {
            const c = status.counts || {};
            el.innerHTML = `
                <span><strong>${c.running || 0}</strong> active / ${status.max_active} max</span>
                <span><strong>${c.queued || 0}</strong> queued</span>
                <span><strong>${c.completed || 0}</strong> completed</span>
                <span><strong>${c.failed || 0}</strong> failed</span>
            `;
            // [LANE-UI] Refresh the 4 horizontal lane tiles from backend queue status.
            // Uses the running jobs (status.jobs ordered with running first) so the
            // tiles show real active work, not fabricated progress.
            this._renderLaneProgressFromStatus(status);
        }
        return status.success ? status : null;
    }

    // [LANE-UI] Core-style 4 horizontal scrape lane tiles. Music is city-job based
    // (not keyword-lane based), so the four tiles map to the four active worker
    // slots that process city jobs in parallel. The bars and counts are derived
    // from real backend status and the local Promise.all(boundedJobs.map(...))
    // claims — no fabricated progress.
    _initLaneSlots(total) {
        this._laneSlots = [];
        const laneCount = 4;
        for (let i = 0; i < laneCount; i++) {
            this._laneSlots.push({
                busy: false,
                city: null,
                state: null,
                search_query: null,
                completed: 0,
                failed: 0,
                _total: total,
                _startedAt: null,
                _finishedAt: null
            });
        }
    }

    _claimLaneSlot() {
        if (!this._laneSlots) this._initLaneSlots(0);
        for (let i = 0; i < this._laneSlots.length; i++) {
            if (!this._laneSlots[i].busy) return i;
        }
        // All slots busy — recycle the oldest finished slot (best-effort fallback
        // when a single batch oversubscribes beyond 4 in flight).
        let oldestIdx = 0;
        let oldestTs = Infinity;
        for (let i = 0; i < this._laneSlots.length; i++) {
            const ts = this._laneSlots[i]._finishedAt || this._laneSlots[i]._startedAt || Infinity;
            if (ts < oldestTs) { oldestTs = ts; oldestIdx = i; }
        }
        return oldestIdx;
    }

    _freeLaneSlot(idx, didFail) {
        if (!this._laneSlots || !this._laneSlots[idx]) return;
        const lane = this._laneSlots[idx];
        lane.busy = false;
        lane._finishedAt = Date.now();
        if (didFail) lane.failed += 1; else lane.completed += 1;
    }

    _renderLaneProgress() {
        const container = document.getElementById('laneProgressContainer');
        if (!container || !this._laneSlots) return;
        container.innerHTML = '';
        for (let i = 0; i < this._laneSlots.length; i++) {
            container.appendChild(this._buildLaneTile(i, this._laneSlots[i]));
        }
    }

    _renderLaneProgressFromStatus(status) {
        const container = document.getElementById('laneProgressContainer');
        if (!container) return;
        // If a local scrape is in flight with live slot state, prefer that view —
        // it tracks real per-slot progress more accurately than a poll snapshot.
        if (this._laneSlots && this._laneSlots.length === 4 &&
            this._laneSlots.some(l => l.busy || l.completed > 0 || l.failed > 0)) {
            this._renderLaneProgress();
            return;
        }
        const counts = (status && status.counts) || {};
        // MM-MATH-LIVE-FIX-001: total is the sum of ALL five status groups;
        // omitting cancelled undercounted runs that had cancelled jobs.
        const total = (counts.completed || 0) + (counts.queued || 0) +
                      (counts.running || 0) + (counts.failed || 0) +
                      (counts.cancelled || 0);
        const completed = counts.completed || 0;
        const running = (status && Array.isArray(status.jobs) ? status.jobs : [])
            .filter(j => j.status === 'running').slice(0, 4);
        container.innerHTML = '';
        for (let i = 0; i < 4; i++) {
            const fakeSlot = {
                busy: !!running[i],
                city: running[i] ? running[i].city : null,
                state: running[i] ? (running[i].state_name || null) : null,
                search_query: running[i] ? running[i].search_query : null,
                completed: 0,
                failed: 0,
                _total: total,
                _fromStatus: true
            };
            container.appendChild(this._buildLaneTile(i, fakeSlot, completed, total));
        }
    }

    _buildLaneTile(idx, lane, completedOverride, totalOverride) {
        const tile = document.createElement('div');
        tile.className = 'lane-tile';
        const total = (typeof totalOverride === 'number')
            ? totalOverride
            : (lane._total || 0);
        const laneDone = (lane.completed || 0) + (lane.failed || 0);
        // Per-lane bar = this lane's share of its expected slot work.
        const expected = Math.max(1, Math.ceil(total / 4));
        const pct = Math.max(0, Math.min(100, Math.round((laneDone / expected) * 100)));
        const completedCount = (typeof completedOverride === 'number')
            ? completedOverride
            : laneDone;
        let text;
        let textColor = 'var(--text-tertiary)';
        if (lane.busy && lane.city) {
            text = `Searching ${lane.city}${lane.state ? ', ' + lane.state : ''}...`;
            textColor = 'var(--text-secondary)';
        } else if (lane.completed > 0 || lane.failed > 0) {
            const lastQ = lane.search_query ? `"${lane.search_query}" ` : '';
            if (lane.failed > 0 && lane.completed === 0) {
                text = `Last: ${lane.city || 'job'} ${lane.failed > 1 ? `(${lane.failed} errors)` : '(error)'}`;
                textColor = '#f59e0b';
            } else {
                text = `Last: ${lane.city || 'job'} ✓`;
                textColor = '#22c55e';
            }
        } else {
            text = 'Idle';
        }
        // Use class names lane-status / lane-fill / lane-text so the Core anchor
        // names exist in Music's deployed source.
        tile.innerHTML = `
            <div style="display:flex;justify-content:space-between;align-items:center;font-size:12px;font-weight:600;margin-bottom:4px;gap:6px;">
                <span style="white-space:nowrap;">Lane ${idx + 1}</span>
                <span class="lane-status" style="margin-left:auto;color:var(--text-secondary);font-weight:500;">${laneDone}/${expected}</span>
            </div>
            <div class="lane-fill-bg">
                <div class="lane-fill" style="width:${pct}%;"></div>
            </div>
            <div class="lane-text" style="color:${textColor};">${this.esc(text)}</div>
        `;
        return tile;
    }

    finishAndClose() {
        document.getElementById('addLeadsModal').classList.remove('active');
        this.resetScrapeUI();
        this.refreshCurrentList();
    }

    async fireAllScrapes() {
        if (!this.currentList) return;
        const listId = this.currentList.id;
        while (true) {
            const res = await this.api('fireAllScrapes', { list_id: listId, batch_size: 100 }, 'POST');
            if (!res.success) return;
            const fired = res.fired || 0;
            // Audit 2026-07-04 backend-worker pass: PHP no longer dispatches
            // Replicate from the request path. The backend worker (when
            // re-enabled separately) reads rows where enrichment_status IS NULL
            // OR 'failed' AND has_website=1. Surface that pending depth via
            // queued_for_worker (preferred) or needs_enrichment (fallback) and
            // keep _enrichLiveLoop running until the queue drains, instead of
            // bailing early when fired === 0.
            const queuedForWorker = (typeof res.queued_for_worker === 'number'
                ? res.queued_for_worker
                : (res.needs_enrichment || 0));
            const anyActivity =
                (res.pending || 0) > 0 ||
                (res.processing || 0) > 0 ||
                queuedForWorker > 0;
            if (fired === 0 && !anyActivity) {
                // No leads queued this round AND nothing pending/processing.
                // Safe to stop: either the queue is genuinely empty or the
                // last batch was already claimed and the worker is working.
                break;
            }
            if (fired > 0) {
                await new Promise(r => setTimeout(r, 300));
            }
        }
        this.enrichmentPollId = listId;
        this._recoveryAttempts = 0;
        this._totalRecoveryAttempts = 0;
        this._enrichLiveLoop(listId);
    }

    async _enrichLiveLoop(listId) {
        if (this.enrichmentPollId !== listId) return;

        // Audit 2026-07-04: pause live polling while the tab is hidden so
        // backgrounded tabs do not keep hammering the PHP aggregate. Resumes
        // cleanly once the tab becomes visible again via the
        // visibilitychange handler below.
        if (typeof document !== 'undefined' && document.hidden) {
            this._enrichHiddenWaiter = true;
            setTimeout(() => this._enrichLiveLoop(listId), 5000);
            return;
        }
        this._enrichHiddenWaiter = false;

        const prog = await this.api('getEnrichmentProgress', { list_id: listId });
        if (!prog || !prog.success) {
            // Error backoff: double wait up to 30s max
            const backoff = Math.min(30000, (this._enrichBackoff || 1000) * 2);
            this._enrichBackoff = backoff;
            setTimeout(() => this._enrichLiveLoop(listId), backoff);
            return;
        }
        // Reset backoff on successful response
        this._enrichBackoff = 1000;

        const { total, pending, processing, completed, failed, needs_enrichment } = prog;

        if (document.getElementById('adminEnrichPanel')) {
            this.updateAdminEnrichPanel(prog);
        }

        if (this.currentList && this.currentList.id == listId) {
            // NOTE: loadLeads() removed from poll body — use cache via api() instead.
            // loadLeads() is kept on final/success/failure/recovery paths below.
        }

        if ((processing || 0) === 0 && (pending || 0) === 0 && (needs_enrichment || 0) === 0) {
            if ((failed || 0) > 0 && !this._failedRetryDone) {
                this._failedRetryDone = true;
                this.api('retryFailedEnrichments', { list_id: listId }, 'POST').then(r => {
                    if (r && r.success && (r.recovered > 0 || r.retried > 0)) {
                        this._failedRetryDone = false;
                        this.loadLeads();
                        this._enrichLiveLoop(listId);
                    } else {
                        this.enrichmentPollId = null;
                        this.loadLeads();
                    }
                });
                return;
            }
            this._failedRetryDone = false;
            this._recoveryAttempts = 0;
            this.enrichmentPollId = null;
        } else if ((processing || 0) > 0 && (pending || 0) === 0 && (needs_enrichment || 0) === 0) {
            this._recoveryAttempts = (this._recoveryAttempts || 0) + 1;
            this._totalRecoveryAttempts = (this._totalRecoveryAttempts || 0) + 1;
            if (this._totalRecoveryAttempts >= 20) {
                this._totalRecoveryAttempts = 0;
                this._recoveryAttempts = 0;
                this._failedRetryDone = false;
                this.enrichmentPollId = null;
                this.loadLeads();
                return;
            }
            if (this._recoveryAttempts >= 3) {
                this._recoveryAttempts = 0;
                await this.api('recoverStuckEnrichments', { list_id: listId }, 'POST');
                this.loadLeads();
            }
            setTimeout(() => this._enrichLiveLoop(listId), 2000);
        } else {
            this._recoveryAttempts = 0;
            if ((pending || 0) > 0 || (needs_enrichment || 0) > 0) {
                await this.api('fireAllScrapes', { list_id: listId, batch_size: 100 }, 'POST');
            }
            setTimeout(() => this._enrichLiveLoop(listId), 3000);
        }
    }

    async adminForceReenrich() {
        return this.forceReenrich();
    }

    async forceReenrich() {
        if (!this.currentList) return;
        const listId = this.currentList.id;
        const name = this.currentList.name;
        if (!confirm(`Re-enrich ALL websites in "${name}"?\
\
This will reset every lead and re-search all websites from scratch. This can take a while for large lists.`)) return;

        const res = await this.api('forceReenrich', { list_id: listId }, 'POST');
        if (!res.success) { this.toast(res.error || 'Failed'); return; }

        const total = res.reset || 0;
        this.toast(`Reset ${total.toLocaleString()} websites — starting re-enrichment...`);

        this.showAdminEnrichPanel(total);
        this.enrichmentPollId = listId;
        this._recoveryAttempts = 0;
        this._totalRecoveryAttempts = 0;
        this._adminEnrichTotal = total;
        this._adminEnrichStart = Date.now();
        await this.loadLeads();
        await this.api('fireAllScrapes', { list_id: listId, batch_size: 100 }, 'POST');
        this._enrichLiveLoop(listId);
    }

    showAdminEnrichPanel(total) {
        let panel = document.getElementById('adminEnrichPanel');
        if (panel) panel.remove();
        panel = document.createElement('div');
        panel.id = 'adminEnrichPanel';
        panel.innerHTML = `
            <div class="aep-header"><i class="fas fa-sync-alt"></i> Re-Enrichment</div>
            <div class="aep-bar"><div class="aep-fill" id="aepFill"></div></div>
            <div class="aep-stats">
                <span><span class="num" id="aepDone">0</span> / <span id="aepTotal">${total.toLocaleString()}</span> done</span>
                <span><span class="num" id="aepEmails">0</span> emails</span>
                <span><span class="num" id="aepSocials">0</span> socials</span>
                <span id="aepTime">starting...</span>
            </div>
        `;
        document.body.appendChild(panel);
    }

    updateAdminEnrichPanel(data) {
        const panel = document.getElementById('adminEnrichPanel');
        if (!panel) return;
        const total = this._adminEnrichTotal || data.total || 1;
        const done = (data.completed || 0) + (data.failed || 0);
        const pct = Math.round((done / total) * 100);
        const fill = document.getElementById('aepFill');
        if (fill) fill.style.width = pct + '%';
        const doneEl = document.getElementById('aepDone');
        if (doneEl) doneEl.textContent = done.toLocaleString();
        const totalEl = document.getElementById('aepTotal');
        if (totalEl) totalEl.textContent = total.toLocaleString();
        const emailsEl = document.getElementById('aepEmails');
        if (emailsEl) emailsEl.textContent = (data.with_emails || 0).toLocaleString();
        const socialsEl = document.getElementById('aepSocials');
        if (socialsEl) socialsEl.textContent = (data.with_socials || 0).toLocaleString();
        const timeEl = document.getElementById('aepTime');
        if (timeEl && this._adminEnrichStart) {
            const elapsed = Math.round((Date.now() - this._adminEnrichStart) / 1000);
            const mins = Math.floor(elapsed / 60);
            const secs = elapsed % 60;
            timeEl.textContent = mins > 0 ? `${mins}m ${secs}s` : `${secs}s`;
        }
        if (done >= total) {
            if (fill) fill.style.background = 'linear-gradient(90deg, #34C759, #30D158)';
            const header = panel.querySelector('.aep-header');
            if (header) header.innerHTML = '<i class="fas fa-check-circle" style="color:#34C759;"></i> Re-Enrichment Complete!';
            setTimeout(() => {
                panel.style.transition = 'opacity 0.5s, transform 0.5s';
                panel.style.opacity = '0';
                panel.style.transform = 'translateX(-50%) translateY(20px)';
                setTimeout(() => panel.remove(), 500);
            }, 5000);
            this._adminEnrichTotal = null;
            this._adminEnrichStart = null;
        }
    }

    async refreshCredits() {
        const res = await this.api('getCredits');
        if (res && res.success) {
            this.credits = parseInt(res.credits, 10) || 0;
            this.updateCreditsDisplay();
        }
    }

    updateCreditsDisplay() {
        const creditsText = this.credits.toLocaleString();
        const creditsDisplay = document.getElementById('creditsDisplay');
        if (creditsDisplay) creditsDisplay.textContent = creditsText;
        const creditsDisplay2 = document.getElementById('creditsDisplay2');
        if (creditsDisplay2) creditsDisplay2.textContent = creditsText;
        const upgradeHave = document.getElementById('upgradeHave');
        if (upgradeHave) upgradeHave.textContent = this.credits;
        const freeCreditsNum = document.getElementById('freeCreditsNum');
        if (freeCreditsNum) freeCreditsNum.textContent = this.credits;
        if (window.parent !== window) {
            window.parent.postMessage({ type: 'creditUpdate', credits: this.credits }, '*');
        }
    }

    // LIST MAP

    initListMap() {
        if (this.listMap) { this.listMap.remove(); this.listMap = null; }
        this.listMapMarkers = [];
        const el = document.getElementById('listMap');
        if (!el) return;
        this.listMap = L.map('listMap', { closePopupOnClick: true }).setView([39.8283, -98.5795], 4);
        const streetLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '&copy; OpenStreetMap', maxZoom: 19 }).addTo(this.listMap);
        const sat = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', { attribution: '&copy; Esri', maxZoom: 19 });
        L.control.layers({ 'Street': streetLayer, 'Satellite': sat }, null, { position: 'topright' }).addTo(this.listMap);

        this.listMapDrawnItems = new L.FeatureGroup();
        this.listMap.addLayer(this.listMapDrawnItems);
        const drawControl = new L.Control.Draw({
            draw: {
                polygon: { allowIntersection: true, shapeOptions: { color: 'var(--accent)', fillColor: 'var(--accent)', fillOpacity: 0.15, weight: 2 } },
                circle: { shapeOptions: { color: 'var(--accent)', fillColor: 'var(--accent)', fillOpacity: 0.15, weight: 2 } },
                rectangle: { shapeOptions: { color: 'var(--accent)', fillColor: 'var(--accent)', fillOpacity: 0.15, weight: 2 } },
                polyline: false, marker: false, circlemarker: false
            },
            edit: { featureGroup: this.listMapDrawnItems, remove: true }
        });
        this.listMap.addControl(drawControl);
        this.listMap.on(L.Draw.Event.CREATED, (e) => {
            const layer = e.layer;
            this.listMapDrawnItems.addLayer(layer);
            this.selectLeadsInShape(layer);
            setTimeout(() => this.listMapDrawnItems.removeLayer(layer), 500);
        });
    }

    async loadMapLeads() {
        if (!this.currentList) return;
        this.allMapLeads = this.currentLeads || [];
        this.updateListMap();
    }

    selectLeadsInShape(shape) {
        let count = 0;
        if (!this.allMapLeads) return;
        this.allMapLeads.forEach(lead => {
            if (!lead.latitude || !lead.longitude) return;
            const pt = L.latLng(parseFloat(lead.latitude), parseFloat(lead.longitude));
            let inside = false;
            if (shape instanceof L.Circle) {
                inside = shape.getLatLng().distanceTo(pt) <= shape.getRadius();
            } else if (shape instanceof L.Polygon || shape instanceof L.Rectangle) {
                const poly = shape.getLatLngs()[0];
                let x = pt.lat, y = pt.lng, ii = false;
                for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
                    const xi = poly[i].lat, yi = poly[i].lng, xj = poly[j].lat, yj = poly[j].lng;
                    if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) ii = !ii;
                }
                inside = ii;
            }
            if (inside) {
                this.selectedLeads.add(lead.id);
                count++;
            }
        });
        if (count > 0) {
            this.renderLeads();
            this.updateSelectionUI();
            this.toast(`Selected ${count} leads from map`);
        }
    }

    toggleListMap() {
        this.listMapVisible = !this.listMapVisible;
        const content = document.getElementById('listMapContainer');
        const btn = document.getElementById('listMapToggle');
        if (this.listMapVisible) {
            content.classList.remove('collapsed');
            content.classList.add('expanded');
            btn.classList.remove('collapsed');
            btn.innerHTML = '<i class="fas fa-chevron-up"></i>';
        } else {
            content.classList.remove('expanded');
            content.classList.add('collapsed');
            btn.classList.add('collapsed');
            btn.innerHTML = '<i class="fas fa-chevron-down"></i>';
        }
        if (this.listMapVisible && this.listMap) {
            setTimeout(() => this.listMap.invalidateSize(), 120);
        }
    }

    toggleSearchedAreas() {
        const content = document.getElementById('searchedAreasContent');
        const btn = document.getElementById('searchedAreasToggle');
        if (!content || !btn) return;
        const isCollapsed = content.classList.contains('collapsed');
        if (isCollapsed) {
            content.classList.remove('collapsed');
            content.classList.add('expanded');
            btn.classList.remove('collapsed');
            btn.innerHTML = '<i class="fas fa-chevron-up"></i>';
        } else {
            content.classList.remove('expanded');
            content.classList.add('collapsed');
            btn.classList.add('collapsed');
            btn.innerHTML = '<i class="fas fa-chevron-down"></i>';
        }
    }

    getFilteredMapLeads() {
        if (!this.allMapLeads) return [];
        let leads = this.allMapLeads;
        if (this.hasFilter) {
            const hf = this.hasFilter;
            leads = leads.filter(lead => {
                if (hf === 'visited') return lead.visited_website == 1;
                if (hf === 'reached_out') return lead.reached_out == 1;
                if (hf === 'phone') return !!(lead.phone && lead.phone.trim());
                if (hf === 'email') return (lead.emails || []).length > 0;
                if (hf === 'socials') return (lead.social_media_links || []).length > 0;
                if (hf === 'notes') return !!(lead.notes && lead.notes.trim());
                if (hf === 'selected') return this.selectedLeads.has(lead.id);
                return true;
            });
        }
        if (this.searchQuery) {
            const q = this.searchQuery.toLowerCase().trim();
            leads = leads.filter(lead => {
                const name = (lead.business_name || '').toLowerCase();
                const addr = (lead.full_address || lead.address || '').toLowerCase();
                const phone = (lead.phone || '').toLowerCase();
                const notes = (lead.notes || '').toLowerCase();
                return name.includes(q) || addr.includes(q) || phone.includes(q) || notes.includes(q);
            });
        }
        return leads;
    }

    updateListMap() {
        if (!this.listMap || !this.allMapLeads) return;
        this.listMapMarkers.forEach(m => this.listMap.removeLayer(m));
        this.listMapMarkers = [];
        const withCoords = this.getFilteredMapLeads();
        document.getElementById('listMapCount').textContent = withCoords.length + ' locations';
        if (withCoords.length === 0) return;
        const bounds = L.latLngBounds();
        withCoords.forEach(lead => {
            const lat = parseFloat(lead.latitude), lng = parseFloat(lead.longitude);
            const emails = lead.emails || [];
            const socials = lead.social_media_links || [];
            const isSelected = this.selectedLeads.has(lead.id);
            const stars = lead.rating ? '★'.repeat(Math.round(lead.rating)) + '☆'.repeat(5 - Math.round(lead.rating)) : '';

            let popup = `<div style="min-width:260px;max-width:300px;font-family:Inter,system-ui,sans-serif;">`;
            popup += `<div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;padding-bottom:8px;border-bottom:1px solid #eee;">`;
            popup += `<input type="checkbox" ${isSelected ? 'checked' : ''} onchange="app.toggleLeadSelect(${lead.id}, this.checked)" style="width:16px;height:16px;cursor:pointer;accent-color:var(--accent);flex-shrink:0;">`;
            popup += `<div><strong style="font-size:14px;color:#1d1d1f;line-height:1.3;">${this.esc(lead.business_name || 'Unknown')}</strong>`;
            if (lead.types) popup += `<div style="font-size:11px;color:#aeaeb2;margin-top:1px;">${this.esc(lead.types).substring(0,60)}</div>`;
            popup += `</div></div>`;

            if (lead.full_address) popup += `<div style="display:flex;align-items:flex-start;gap:6px;font-size:12px;color:#6e6e73;margin-bottom:5px;"><i class="fas fa-map-marker-alt" style="color:#FF3B30;margin-top:2px;font-size:11px;flex-shrink:0;"></i>${this.esc(lead.full_address)}</div>`;
            if (lead.phone) popup += `<div style="display:flex;align-items:center;gap:6px;font-size:12px;margin-bottom:5px;"><i class="fas fa-phone" style="color:#34C759;font-size:11px;"></i><a href="tel:${lead.phone}" style="color:#1d1d1f;text-decoration:none;">${lead.phone}</a></div>`;
            if (emails.length > 0) popup += `<div style="display:flex;align-items:center;gap:6px;font-size:12px;margin-bottom:5px;"><i class="fas fa-envelope" style="color:var(--accent);font-size:11px;"></i><a href="#" onclick="event.preventDefault();app.sendTemplateEmail('${this.esc(emails[0])}', ${lead.id})" style="color:var(--accent);text-decoration:none;">${emails[0]}</a></div>`;
            if (lead.website) popup += `<div style="display:flex;align-items:center;gap:6px;font-size:12px;margin-bottom:5px;"><i class="fas fa-globe" style="color:var(--accent-hover);font-size:11px;"></i><a href="${lead.website}" target="_blank" style="color:var(--accent);text-decoration:none;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:200px;display:inline-block;">${(lead.website || '').replace(/^https?:\/\//, '')}</a></div>`;

            if (stars) popup += `<div style="display:flex;align-items:center;gap:6px;font-size:12px;margin-bottom:5px;"><span style="color:var(--accent);font-size:13px;letter-spacing:-1px;">${stars}</span><span style="color:#aeaeb2;">${lead.rating} (${lead.review_count || 0})</span></div>`;

            if (socials.length > 0) {
                popup += `<div style="display:flex;gap:8px;margin-top:6px;padding-top:6px;border-top:1px solid #eee;">`;
                socials.slice(0, 5).forEach(url => {
                    const p = SOCIAL_PLATFORMS.find(pl => pl.patterns.some(pat => url.toLowerCase().includes(pat)));
                    popup += `<a href="${url}" target="_blank" style="color:#6e6e73;font-size:14px;" title="${url}"><i class="${p ? p.icon : 'fas fa-link'}"></i></a>`;
                });
                popup += `</div>`;
            }

            const badges = [];
            if (lead.visited_website == 1) badges.push('<span style="background:rgba(var(--accent-rgb), 0.1);color:var(--accent);padding:2px 6px;border-radius:4px;font-size:10px;font-weight:600;">Visited</span>');
            if (lead.reached_out == 1) badges.push('<span style="background:#E5F8ED;color:#34C759;padding:2px 6px;border-radius:4px;font-size:10px;font-weight:600;">Reached Out</span>');
            if (badges.length) popup += `<div style="display:flex;gap:4px;margin-top:6px;">${badges.join('')}</div>`;

            popup += `</div>`;

            const marker = L.marker([lat, lng]).addTo(this.listMap);
            marker.bindPopup(popup, { maxWidth: 320 });
            this.listMapMarkers.push(marker);
            bounds.extend([lat, lng]);
        });
        this.listMap.fitBounds(bounds, { padding: [40, 40] });
    }

    // EXPORT

    toggleExportMenu() {
        document.getElementById('exportMenu').classList.toggle('hidden');
    }

    async handleImportCSV(input) {
        const file = input.files && input.files[0];
        if (!file) return;
        await this.showImportPreview(file, input);
    }

    async showImportPreview(file, input) {
        if (!this.currentList) {
            input.value = '';
            this.toast('Open a folder first.');
            return;
        }

        const modal = document.getElementById('importPreviewModal');
        const title = document.getElementById('importPreviewTitle');
        const fileName = document.getElementById('importFileName');
        const rowCount = document.getElementById('importRowCount');
        const targetList = document.getElementById('importTargetList');
        const note = document.getElementById('importPreviewNote');
        const confirmBtn = document.getElementById('confirmImportBtn');
        const cancelBtn = document.getElementById('cancelImportBtn');
        const btnText = document.getElementById('confirmImportBtnText');
        const progress = document.getElementById('importProgress');
        const completion = document.getElementById('importCompletion');

        progress.classList.add('hidden');
        completion.classList.add('hidden');
        completion.innerHTML = '';
        confirmBtn.disabled = true;
        cancelBtn.disabled = false;
        btnText.textContent = 'Preparing...';

        try {
            const text = await this.readFileAsText(file);
            const parsed = this.parseCSV(text);
            if (!parsed.headers.length) throw new Error('Missing header row');
            if (!parsed.totalRows) throw new Error('No data rows found');

            title.textContent = `Import ${file.name}`;
            fileName.textContent = file.name;
            rowCount.textContent = parsed.totalRows.toLocaleString();
            targetList.textContent = this.currentList.name || 'Current list';
            note.textContent = `Showing the first ${Math.min(100, parsed.totalRows).toLocaleString()} rows with all columns. The import will process all ${parsed.totalRows.toLocaleString()} rows.`;
            btnText.textContent = `Import ${parsed.totalRows.toLocaleString()} Rows`;
            confirmBtn.disabled = false;

            this.renderImportPreviewTable(parsed.headers, parsed.previewRows);
            this._pendingImport = { file, input, totalRows: parsed.totalRows };
            modal.classList.add('active');
        } catch (e) {
            input.value = '';
            this._pendingImport = null;
            this.showImportInlineError('Preview failed', e.message);
            modal.classList.add('active');
        }
    }

    readFileAsText(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = e => resolve(e.target.result || '');
            reader.onerror = () => reject(new Error('Could not read selected file'));
            reader.readAsText(file, 'UTF-8');
        });
    }

    parseCSV(text) {
        if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
        const records = [];
        let row = [];
        let field = '';
        let inQuotes = false;

        for (let i = 0; i < text.length; i++) {
            const ch = text[i];
            const next = text[i + 1];
            if (ch === '"') {
                if (inQuotes && next === '"') {
                    field += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch === ',' && !inQuotes) {
                row.push(field);
                field = '';
            } else if ((ch === "\n" || ch === "\r") && !inQuotes) {
                if (ch === "\r" && next === "\n") i++;
                row.push(field);
                if (row.some(cell => String(cell).trim() !== '')) records.push(row);
                row = [];
                field = '';
            } else {
                field += ch;
            }
        }

        if (field !== '' || row.length) {
            row.push(field);
            if (row.some(cell => String(cell).trim() !== '')) records.push(row);
        }

        if (!records.length) return { headers: [], previewRows: [], totalRows: 0 };
        const headers = records.shift().map(h => String(h || '').trim());
        const dataRows = records.filter(r => r.some(cell => String(cell).trim() !== ''));
        return { headers, previewRows: dataRows.slice(0, 100), totalRows: dataRows.length };
    }

    renderImportPreviewTable(headers, rows) {
        const table = document.getElementById('importPreviewTable');
        if (!rows.length) {
            table.innerHTML = '<div style="padding:22px;text-align:center;color:var(--text-secondary);">No data rows found</div>';
            return;
        }

        const headerHtml = headers.map(h => `<th>${this.esc(String(h || ''))}</th>`).join('');
        const bodyHtml = rows.map(row => {
            const cells = headers.map((_, idx) => `<td title="${this.esc(String(row[idx] || ''))}">${this.esc(String(row[idx] || ''))}</td>`).join('');
            return `<tr>${cells}</tr>`;
        }).join('');

        table.innerHTML = `<table class="import-preview-table"><thead><tr>${headerHtml}</tr></thead><tbody>${bodyHtml}</tbody></table>`;
    }

    async confirmImport() {
        const pending = this._pendingImport;
        if (!pending || !pending.file || !this.currentList) return;

        const confirmBtn = document.getElementById('confirmImportBtn');
        const cancelBtn = document.getElementById('cancelImportBtn');
        const progress = document.getElementById('importProgress');
        const completion = document.getElementById('importCompletion');

        confirmBtn.disabled = true;
        cancelBtn.disabled = true;
        progress.classList.remove('hidden');
        completion.classList.add('hidden');
        completion.innerHTML = '';

        const fd = new FormData();
        fd.append('list_id', this.currentList.id);
        fd.append('csv', pending.file, pending.file.name);

        try {
            const res = await fetch('leadlists.php?action=importCSV', { method: 'POST', body: fd, cache: 'no-store' });
            const data = await res.json();
            progress.classList.add('hidden');

            if (!data.success) {
                confirmBtn.disabled = false;
                cancelBtn.disabled = false;
                this.showImportInlineError('Import failed', data.error || 'Unknown error');
                return;
            }

            const inserted = Number(data.inserted || 0);
            const skipped = Number(data.skipped || 0);
            const errors = Number(data.errors || 0);
            completion.innerHTML = `
                <div class="import-status success">
                    <i class="fas fa-check-circle"></i>
                    <div>
                        <div style="font-size:14px;font-weight:800;">Import complete</div>
                        <div style="font-size:12px;margin-top:3px;color:var(--text);">Inserted: ${inserted.toLocaleString()} &middot; Skipped: ${skipped.toLocaleString()}${errors ? ` &middot; Errors: ${errors.toLocaleString()}` : ''}</div>
                    </div>
                </div>
            `;
            completion.classList.remove('hidden');
            if (pending.input) pending.input.value = '';

            setTimeout(async () => {
                const listId = this.currentList?.id;
                this.closeImportPreview();
                if (listId) await this.openList(listId);
            }, 1300);
        } catch (e) {
            progress.classList.add('hidden');
            confirmBtn.disabled = false;
            cancelBtn.disabled = false;
            this.showImportInlineError('Import failed', e.message);
        }
    }

    showImportInlineError(title, message) {
        const completion = document.getElementById('importCompletion');
        document.getElementById('importProgress')?.classList.add('hidden');
        completion.innerHTML = `
            <div class="import-status error">
                <i class="fas fa-exclamation-circle"></i>
                <div>
                    <div style="font-size:14px;font-weight:800;">${this.esc(title)}</div>
                    <div style="font-size:12px;margin-top:3px;color:var(--text);">${this.esc(message || 'Unknown error')}</div>
                </div>
            </div>
        `;
        completion.classList.remove('hidden');
    }

    closeImportPreview() {
        document.getElementById('importPreviewModal')?.classList.remove('active');
        const input = document.getElementById('importCsvFile');
        if (input) input.value = '';
        this._pendingImport = null;
    }

    async openExportPreview(type) {
        document.getElementById('exportMenu').classList.add('hidden');
        if (!this.currentList) return;

        this.exportType = type;
        this._csvFilters = { status: '', has: '', pipeline: '', search: '' };
        const modal = document.getElementById('exportPreviewModal');
        const title = document.getElementById('exportPreviewTitle');
        const summary = document.getElementById('exportPreviewSummary');
        const table = document.getElementById('exportPreviewTable');
        const actions = document.getElementById('exportPreviewActions');

        title.textContent = 'Export CSV';
        table.innerHTML = '';
        actions.innerHTML = '';

        const selectStyle = 'height:36px;border:1px solid var(--input-border);border-radius:8px;padding:0 10px;font-size:12px;font-family:inherit;background:#fff;min-width:0;flex:1;';
        summary.innerHTML = `
            <div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px;">
                <select id="csvFilterStatus" onchange="app.updateExportPreview()" style="${selectStyle}">
                    <option value="">All Statuses</option>
                    <option value="cold">Cold</option>
                    <option value="warm">Warm</option>
                    <option value="hot">Hot</option>
                </select>
                <select id="csvFilterHas" onchange="app.updateExportPreview()" style="${selectStyle}">
                    <option value="">All Leads</option>
                    <option value="email">Has Email</option>
                    <option value="phone">Has Phone</option>
                    <option value="has_website">Has Website</option>
                    <option value="socials">Has Socials</option>
                    <option value="notes">Has Notes</option>
                    <option value="visited">Visited Website</option>
                    <option value="reached_out">Reached Out</option>
                    <option value="emailed">Emailed</option>
                    <option value="ig_dm">IG DM'd</option>
                </select>
                <select id="csvFilterPipeline" onchange="app.updateExportPreview()" style="${selectStyle}">
                    <option value="">All Stages</option>
                    <option value="new">New</option>
                    <option value="contacted">Contacted</option>
                    <option value="engaged">Engaged</option>
                    <option value="client">Client</option>
                    <option value="no_response">No Response</option>
                </select>
            </div>
            <div id="csvExportStats" style="text-align:center;padding:12px;"><i class="fas fa-spinner fa-spin" style="color:var(--accent);"></i></div>
        `;
        modal.classList.add('active');
        await this.updateExportPreview();
    }

    async updateExportPreview() {
        const statsEl = document.getElementById('csvExportStats');
        const table = document.getElementById('exportPreviewTable');
        const actions = document.getElementById('exportPreviewActions');
        if (!statsEl) return;

        const status = document.getElementById('csvFilterStatus')?.value || '';
        const has = document.getElementById('csvFilterHas')?.value || '';
        const pipeline = document.getElementById('csvFilterPipeline')?.value || '';
        this._csvFilters = { status, has, pipeline, search: '' };

        statsEl.innerHTML = '<div style="text-align:center;padding:8px;"><i class="fas fa-spinner fa-spin" style="color:var(--accent);"></i></div>';
        table.innerHTML = '';
        actions.innerHTML = '';

        const params = { list_id: this.currentList.id };
        if (status) params.status = status;
        if (has) params.has = has;
        if (pipeline) params.pipeline = pipeline;

        const [countData, previewData] = await Promise.all([
            this.api('exportCount', params),
            this.api('exportLeads', { ...params, page: 1, per_page: 10 })
        ]);

        if (!countData.success || countData.total === 0) {
            statsEl.innerHTML = '<div style="text-align:center;padding:16px;color:var(--text-secondary);"><i class="fas fa-info-circle" style="font-size:20px;margin-bottom:6px;display:block;"></i>No leads match these filters.</div>';
            actions.innerHTML = '<button class="btn btn-secondary" onclick="app.closeExportPreview()">Close</button>';
            return;
        }

        const t = countData;
        const big = t.total > 500000;
        statsEl.innerHTML = `
            <div style="display:flex;gap:12px;flex-wrap:wrap;margin-bottom:10px;">
                <div style="flex:1;min-width:120px;padding:12px;background:var(--bg);border-radius:8px;border:1px solid var(--card-border);text-align:center;">
                    <div style="font-size:22px;font-weight:700;color:var(--accent);">${t.total.toLocaleString()}</div>
                    <div style="font-size:11px;color:var(--text-secondary);">Total Leads</div>
                </div>
                <div style="flex:1;min-width:120px;padding:12px;background:var(--bg);border-radius:8px;border:1px solid var(--card-border);text-align:center;">
                    <div style="font-size:22px;font-weight:700;color:var(--green);">${t.with_email.toLocaleString()}</div>
                    <div style="font-size:11px;color:var(--text-secondary);">With Email</div>
                </div>
                <div style="flex:1;min-width:120px;padding:12px;background:var(--bg);border-radius:8px;border:1px solid var(--card-border);text-align:center;">
                    <div style="font-size:22px;font-weight:700;color:var(--blue);">${t.with_phone.toLocaleString()}</div>
                    <div style="font-size:11px;color:var(--text-secondary);">With Phone</div>
                </div>
            </div>
            <div style="display:flex;gap:6px;flex-wrap:wrap;font-size:11px;margin-bottom:6px;">
                <span style="padding:2px 8px;background:rgba(var(--accent-rgb), 0.1);border-radius:99px;">Cold: ${t.cold.toLocaleString()}</span>
                <span style="padding:2px 8px;background:rgba(var(--accent-rgb), 0.1);border-radius:99px;">Warm: ${t.warm.toLocaleString()}</span>
                <span style="padding:2px 8px;background:#FF2D5510;border-radius:99px;">Hot: ${t.hot.toLocaleString()}</span>
                <span style="padding:2px 8px;background:#34C75910;border-radius:99px;">Socials: ${t.with_socials.toLocaleString()}</span>
                <span style="padding:2px 8px;background:rgba(var(--accent-rgb), 0.1);border-radius:99px;">Website: ${t.with_website.toLocaleString()}</span>
            </div>
            ${big ? '<div style="font-size:11px;padding:6px 10px;background:#FEF3C7;border-radius:6px;color:#92400E;margin-top:6px;"><i class="fas fa-info-circle"></i> Large export — file will download as a ZIP with multiple CSVs.</div>' : ''}
        `;

        if (previewData.success && previewData.leads.length > 0) {
            const preview = previewData.leads.slice(0, 10);
            table.innerHTML = `<table style="width:100%;font-size:12px;border-collapse:collapse;"><thead><tr style="background:var(--bg);position:sticky;top:0;">
                <th style="padding:8px;text-align:left;border-bottom:1px solid var(--card-border);">Business</th>
                <th style="padding:8px;text-align:left;border-bottom:1px solid var(--card-border);">City</th>
                <th style="padding:8px;text-align:left;border-bottom:1px solid var(--card-border);">Phone</th>
                <th style="padding:8px;text-align:left;border-bottom:1px solid var(--card-border);">Status</th>
            </tr></thead><tbody>${preview.map(l => `<tr>
                <td style="padding:6px 8px;border-bottom:1px solid var(--card-border);">${this.esc(l.business_name || '')}</td>
                <td style="padding:6px 8px;border-bottom:1px solid var(--card-border);">${this.esc(l.city || '')}</td>
                <td style="padding:6px 8px;border-bottom:1px solid var(--card-border);">${this.esc(l.phone || '—')}</td>
                <td style="padding:6px 8px;border-bottom:1px solid var(--card-border);"><span class="status-badge ${l.status}">${l.status}</span></td>
            </tr>`).join('')}
            ${t.total > 10 ? `<tr><td colspan="4" style="padding:6px;text-align:center;color:var(--text-tertiary);font-style:italic;font-size:11px;">...and ${(t.total - 10).toLocaleString()} more</td></tr>` : ''}</tbody></table>`;
        }

        actions.innerHTML = `
            <button class="btn btn-secondary" onclick="app.closeExportPreview()">Cancel</button>
            <button class="btn btn-primary" onclick="app.downloadServerCSV()"><i class="fas fa-file-csv"></i> Download CSV (${t.total.toLocaleString()} leads)</button>
        `;
    }

    closeExportPreview() {
        document.getElementById('exportPreviewModal').classList.remove('active');
    }

    downloadServerCSV() {
        if (!this.currentList) return;
        const f = this._csvFilters || {};
        const params = new URLSearchParams({ action: 'exportCSV', list_id: this.currentList.id });
        if (f.status) params.set('status', f.status);
        if (f.has) params.set('has', f.has);
        if (f.pipeline) params.set('pipeline', f.pipeline);
        if (f.search) params.set('search', f.search);
        this.closeExportPreview();
        this.toast('Starting download...');
        window.location.href = 'leadlists.php?' + params.toString();
    }

    // GHL EXPORT

    async openGHLExport(preSelectedLeads) {
        if (!this.currentList) return;
        document.getElementById('exportMenu')?.classList.add('hidden');
        const overlay = document.getElementById('ghlExportOverlay');
        overlay.classList.add('active');

        this._ghlLeads = [];
        this._ghlFiltered = [];
        this._ghlSelected = new Set();
        this._ghlTags = [];
        this._ghlSelectedTags = [];
        this._ghlWorkflows = [];
        this._ghlConnections = [];
        this._ghlActiveConn = null;
        this._ghlPreSelected = preSelectedLeads;

        document.getElementById('ghlSubtitle').textContent = this.currentList.name;

        const res = await this.api('getGHLConnections');
        this._ghlConnections = res.connections || [];

        if (this._ghlConnections.length === 0) {
            this.showGHLScreen('ghlSetupScreen');
            this.updateGHLBadge(false);
            this.renderGHLConnectionsList();
        } else {
            this._ghlActiveConn = this._ghlConnections[0];
            this.updateGHLBadge(true);
            await this.loadGHLExportData(preSelectedLeads);
        }
    }

    showGHLScreen(id) {
        ['ghlSetupScreen','ghlEditorScreen','ghlImportingScreen','ghlDoneScreen'].forEach(s => {
            document.getElementById(s).classList.toggle('hidden', s !== id);
        });
    }

    updateGHLBadge(connected) {
        const b = document.getElementById('ghlConnectionBadge');
        if (connected && this._ghlActiveConn) {
            b.innerHTML = `<i class="fas fa-check-circle"></i> ${this.esc(this._ghlActiveConn.name)}`;
            b.style.cssText = 'background:#DCFCE7;color:#166534;font-size:11px;padding:4px 10px;border-radius:99px;font-weight:600;max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;';
        } else if (connected) {
            b.innerHTML = '<i class="fas fa-check-circle"></i> Connected';
            b.style.cssText = 'background:#DCFCE7;color:#166534;font-size:11px;padding:4px 10px;border-radius:99px;font-weight:600;';
        } else {
            b.innerHTML = '<i class="fas fa-times-circle"></i> Not Connected';
            b.style.cssText = 'background:#FEE2E2;color:#991B1B;font-size:11px;padding:4px 10px;border-radius:99px;font-weight:600;';
        }
    }

    renderGHLConnectionsList() {
        const container = document.getElementById('ghlConnectionsList');
        if (!container) return;
        if (this._ghlConnections.length === 0) {
            container.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-tertiary);font-size:13px;"><i class="fas fa-unlink" style="font-size:20px;display:block;margin-bottom:8px;"></i>No connections yet</div>';
            return;
        }
        container.innerHTML = this._ghlConnections.map(c => `
            <div style="display:flex;align-items:center;gap:12px;padding:14px 16px;background:var(--bg);border:1px solid var(--card-border);border-radius:10px;margin-bottom:8px;cursor:pointer;transition:border-color 0.15s;" onclick="app.selectGHLConnection(${c.id})" onmouseenter="this.style.borderColor='var(--accent)'" onmouseleave="this.style.borderColor='var(--card-border)'">
                <div style="width:40px;height:40px;border-radius:10px;background:linear-gradient(135deg,#FF6B35,#FF3B30);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <i class="fas fa-bolt" style="color:#fff;font-size:16px;"></i>
                </div>
                <div style="flex:1;min-width:0;">
                    <div style="font-weight:600;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${this.esc(c.name)}</div>
                    <div style="font-size:11px;color:var(--text-tertiary);">Location: ${this.esc(c.location_id)}</div>
                </div>
                <div style="display:flex;gap:4px;">
                    <button class="btn-icon" onclick="event.stopPropagation();app.editGHLConnection(${c.id})" title="Edit" style="font-size:12px;"><i class="fas fa-pen"></i></button>
                    <button class="btn-icon" onclick="event.stopPropagation();app.deleteGHLConnection(${c.id})" title="Delete" style="font-size:12px;color:var(--red);"><i class="fas fa-trash"></i></button>
                </div>
                <i class="fas fa-chevron-right" style="color:var(--text-tertiary);font-size:12px;"></i>
            </div>`).join('');
    }

    async selectGHLConnection(connId) {
        this._ghlActiveConn = this._ghlConnections.find(c => c.id == connId);
        this.updateGHLBadge(true);
        await this.loadGHLExportData(this._ghlPreSelected);
    }

    async editGHLConnection(connId) {
        const conn = this._ghlConnections.find(c => c.id == connId);
        if (!conn) return;
        const name = prompt('Connection name:', conn.name);
        if (!name) return;
        const loc = prompt('Location ID:', conn.location_id);
        if (!loc) return;
        const key = prompt('API Key (leave blank to keep current):');
        await this.api('saveGHLConnection', {
            connection_id: connId,
            name,
            api_key: key || conn._apiKey || 'KEEP_EXISTING',
            location_id: loc
        }, 'POST');
        const res = await this.api('getGHLConnections');
        this._ghlConnections = res.connections || [];
        this.renderGHLConnectionsList();
        this.renderGHLSettingsConnections();
        this.toast('Connection updated');
    }

    async deleteGHLConnection(connId) {
        if (!confirm('Delete this connection? This cannot be undone.')) return;
        await this.api('deleteGHLConnection', { connection_id: connId }, 'POST');
        const res = await this.api('getGHLConnections');
        this._ghlConnections = res.connections || [];
        if (this._ghlActiveConn?.id == connId) this._ghlActiveConn = this._ghlConnections[0] || null;
        this.renderGHLConnectionsList();
        this.renderGHLSettingsConnections();
        this.updateGHLBadge(!!this._ghlActiveConn);
        if (this._ghlConnections.length === 0) this.showGHLScreen('ghlSetupScreen');
        this.toast('Connection deleted');
    }

    async connectGHL() {
        const name = document.getElementById('ghlSetupName').value.trim();
        const key = document.getElementById('ghlSetupKey').value.trim();
        const loc = document.getElementById('ghlSetupLocation').value.trim();
        if (!name) { this.toast('Give this connection a name'); return; }
        if (!key || !loc) { this.toast('API Key and Location ID are required'); return; }

        const saveRes = await this.api('saveGHLConnection', { name, api_key: key, location_id: loc }, 'POST');
        if (!saveRes.success) { this.toast('Failed to save: ' + (saveRes.error || '')); return; }

        const test = await this.api('ghlProxy', { method: 'GET', endpoint: `/locations/${loc}/tags`, connection_id: saveRes.connection_id }, 'POST');
        if (!test.success) {
            await this.api('deleteGHLConnection', { connection_id: saveRes.connection_id }, 'POST');
            this.toast('Connection failed — check your API key and Location ID');
            return;
        }

        const res = await this.api('getGHLConnections');
        this._ghlConnections = res.connections || [];
        this._ghlActiveConn = this._ghlConnections.find(c => c.id == saveRes.connection_id) || this._ghlConnections[0];

        document.getElementById('ghlSetupName').value = '';
        document.getElementById('ghlSetupKey').value = '';
        document.getElementById('ghlSetupLocation').value = '';
        document.getElementById('ghlAddConnectionForm').classList.add('hidden');

        this.updateGHLBadge(true);
        this.toast('Connected to GoHighLevel!');
        await this.loadGHLExportData(this._ghlPreSelected);
    }

    async switchGHLConnection() {
        const picker = document.getElementById('ghlConnectionPicker');
        const connId = picker.value;
        this._ghlActiveConn = this._ghlConnections.find(c => c.id == connId) || null;
        this.updateGHLBadge(!!this._ghlActiveConn);
        if (this._ghlActiveConn) {
            this._ghlTags = [];
            this._ghlSelectedTags = [];
            this._ghlWorkflows = [];
            this.renderGHLTagChips();
            await this.loadGHLTagsAndWorkflows();
        }
    }

    async loadGHLTagsAndWorkflows() {
        if (!this._ghlActiveConn) return;
        const connId = this._ghlActiveConn.id;
        const locId = this._ghlActiveConn.location_id;

        let tagsData, workflowsData;
        for (let attempt = 0; attempt < 2; attempt++) {
            [tagsData, workflowsData] = await Promise.all([
                this.api('ghlProxy', { method: 'GET', endpoint: `/locations/${locId}/tags`, connection_id: connId }, 'POST'),
                this.api('ghlProxy', { method: 'GET', endpoint: `/workflows/?locationId=${locId}`, connection_id: connId }, 'POST')
            ]);
            if (tagsData?.success && tagsData?.data?.tags) break;
            if (attempt === 0) await new Promise(r => setTimeout(r, 1000));
        }

        const rawTags = tagsData?.data?.tags || tagsData?.data?.Tags || tagsData?.tags || [];
        this._ghlTags = rawTags.map(t => String(typeof t === 'object' ? (t.name ?? t.Name ?? '') : t)).filter(t => t.trim() !== '');
        const rawWorkflows = workflowsData?.data?.workflows || workflowsData?.data?.Workflows || [];
        this._ghlWorkflows = rawWorkflows;

        if (!this._ghlTags.length && tagsData && !tagsData.success) {
            this.toast('Could not load tags — check your GHL connection');
        }

        const wfSelect = document.getElementById('ghlWorkflowSelect');
        wfSelect.innerHTML = '<option value="">No workflow</option>' +
            this._ghlWorkflows.map(w => `<option value="${w.id}">${this.esc(w.name)}</option>`).join('');
    }

    renderConnectionPicker() {
        const picker = document.getElementById('ghlConnectionPicker');
        if (!picker) return;
        picker.innerHTML = this._ghlConnections.map(c =>
            `<option value="${c.id}" ${this._ghlActiveConn?.id == c.id ? 'selected' : ''}>${this.esc(c.name)}</option>`
        ).join('');
    }

    async loadGHLExportData(preSelectedLeads) {
        this.showGHLScreen('ghlEditorScreen');
        this.renderConnectionPicker();
        document.getElementById('ghlSpreadsheetBody').innerHTML = '<tr><td colspan="10" style="text-align:center;padding:40px;color:var(--text-tertiary);"><i class="fas fa-spinner fa-spin"></i> Loading...</td></tr>';

        if (!this._ghlActiveConn) { this.toast('No connection selected'); return; }
        const connId = this._ghlActiveConn.id;
        const locId = this._ghlActiveConn.location_id;

        this._ghlPage = 1;
        this._ghlPerPage = 50;
        this._ghlTotalLeads = 0;
        this._ghlTotalPages = 1;

        const [leadsData, tagsWorkflows] = await Promise.all([
            this.api('exportLeads', { list_id: this.currentList.id, page: 1, per_page: this._ghlPerPage }),
            this._loadGHLTagsWorkflows(connId, locId)
        ]);

        if (!leadsData.success) { this.toast('Failed to load leads'); return; }

        this._ghlTotalLeads = leadsData.total || 0;
        this._ghlTotalPages = leadsData.total_pages || 1;
        this._ghlLeads = this._mapLeadsToGHL(leadsData.leads);
        this._ghlSelected = new Set(this._ghlLeads.map((_, i) => i));

        this.renderGHLSpreadsheet();
        this.updateGHLSummary();
    }

    _mapLeadsToGHL(leads) {
        return leads.map(l => {
            const emails = l.emails || [];
            return {
                _leadId: l.id, firstName: '', lastName: '',
                companyName: l.business_name || '', email: emails[0] || '', emails: emails,
                phone: l.phone || '', city: l.city || '', state: l.state || '',
                website: l.website || '', address: l.address || '',
                socials: l.social_media_links || [], ghl_contact_id: l.ghl_contact_id || null,
                _selected: true
            };
        });
    }

    async _loadGHLTagsWorkflows(connId, locId) {
        let tagsData, workflowsData;
        for (let attempt = 0; attempt < 2; attempt++) {
            [tagsData, workflowsData] = await Promise.all([
                this.api('ghlProxy', { method: 'GET', endpoint: `/locations/${locId}/tags`, connection_id: connId }, 'POST'),
                this.api('ghlProxy', { method: 'GET', endpoint: `/workflows/?locationId=${locId}`, connection_id: connId }, 'POST')
            ]);
            if (tagsData?.success && tagsData?.data?.tags) break;
            if (attempt === 0) await new Promise(r => setTimeout(r, 1000));
        }
        const rawTags = tagsData?.data?.tags || tagsData?.data?.Tags || tagsData?.tags || [];
        this._ghlTags = rawTags.map(t => String(typeof t === 'object' ? (t.name ?? t.Name ?? '') : t)).filter(t => t.trim() !== '');
        this._ghlWorkflows = workflowsData?.data?.workflows || workflowsData?.data?.Workflows || [];
        if (!this._ghlTags.length && tagsData && !tagsData.success) this.toast('Could not load GHL tags — try refreshing or check your connection');
        const wfSelect = document.getElementById('ghlWorkflowSelect');
        wfSelect.innerHTML = '<option value="">No workflow</option>' + this._ghlWorkflows.map(w => `<option value="${w.id}">${this.esc(w.name)}</option>`).join('');
    }

    async ghlGoToPage(page, forceRefresh) {
        if (page < 1) return;
        if (!forceRefresh && (page > this._ghlTotalPages || page === this._ghlPage)) return;
        this._ghlPage = page;
        document.getElementById('ghlSpreadsheetBody').innerHTML = '<tr><td colspan="10" style="text-align:center;padding:20px;color:var(--text-tertiary);"><i class="fas fa-spinner fa-spin"></i></td></tr>';

        const params = { list_id: this.currentList.id, page, per_page: this._ghlPerPage };
        const search = (document.getElementById('ghlSearchInput')?.value || '');
        const filter = document.getElementById('ghlFilterSelect')?.value || 'all';
        const importFilter = document.getElementById('ghlImportFilter')?.value || 'any';
        if (search) params.search = search;
        if (filter === 'has_email') params.has = 'email';
        else if (filter === 'has_phone') params.has = 'phone';
        else if (filter === 'has_both') params.has = 'email';

        const data = await this.api('exportLeads', params);
        if (!data.success) return;

        let leads = this._mapLeadsToGHL(data.leads);

        if (filter === 'has_both') leads = leads.filter(l => l.email && l.phone);
        if (importFilter === 'not_imported') leads = leads.filter(l => !l.ghl_contact_id);
        else if (importFilter === 'previously_imported') leads = leads.filter(l => !!l.ghl_contact_id);

        this._ghlTotalLeads = data.total;
        this._ghlTotalPages = data.total_pages;
        this._ghlLeads = leads;
        this._ghlSelected = new Set(leads.map((_, i) => i));
        this.renderGHLSpreadsheet();
        this.updateGHLSummary();
    }

    filterGHLLeads() {
        this._ghlPage = 0;
        this.ghlGoToPage(1, true);
    }

    renderGHLSpreadsheet() {
        const body = document.getElementById('ghlSpreadsheetBody');
        const leads = this._ghlLeads;

        const socialIcon = (url) => {
            const u = url.toLowerCase();
            if (u.includes('facebook') || u.includes('fb.')) return 'fab fa-facebook';
            if (u.includes('instagram')) return 'fab fa-instagram';
            if (u.includes('twitter') || u.includes('x.com')) return 'fab fa-twitter';
            if (u.includes('linkedin')) return 'fab fa-linkedin';
            if (u.includes('youtube') || u.includes('youtu.be')) return 'fab fa-youtube';
            if (u.includes('tiktok')) return 'fab fa-tiktok';
            if (u.includes('yelp')) return 'fab fa-yelp';
            return 'fas fa-link';
        };

        body.innerHTML = leads.map((l, idx) => {
            const checked = this._ghlSelected.has(idx) ? 'checked' : '';
            const emailOptions = l.emails.length > 0
                ? l.emails.map(e => `<option value="${this.esc(e)}" ${e === l.email ? 'selected' : ''}>${this.esc(e)}</option>`).join('') + '<option value="__custom">+ Add email...</option>'
                : '<option value="">No email</option><option value="__custom">+ Add email...</option>';
            const socialsHtml = (l.socials || []).slice(0, 4).map(s => `<a href="${this.esc(s)}" target="_blank" title="${this.esc(s)}"><i class="${socialIcon(s)}"></i></a>`).join('');

            const impBadge = l.ghl_contact_id ? '<span style="display:inline-block;width:6px;height:6px;border-radius:50%;background:#34C759;margin-left:4px;" title="In GHL"></span>' : '';

            return `<tr style="${!this._ghlSelected.has(idx) ? 'opacity:0.4;' : ''}">
                <td><input type="checkbox" ${checked} onchange="app.ghlToggleOne(${idx}, this.checked)" style="accent-color:var(--accent);"></td>
                <td><input class="ghl-cell-input" value="${this.esc(l.firstName)}" onchange="app._ghlLeads[${idx}].firstName=this.value" placeholder="First"></td>
                <td><input class="ghl-cell-input" value="${this.esc(l.lastName)}" onchange="app._ghlLeads[${idx}].lastName=this.value" placeholder="Last"></td>
                <td><div style="display:flex;align-items:center;"><input class="ghl-cell-input" value="${this.esc(l.companyName)}" onchange="app._ghlLeads[${idx}].companyName=this.value" style="font-weight:600;">${impBadge}</div></td>
                <td><div class="ghl-email-cell"><select class="ghl-email-select" onchange="app.ghlEmailChange(${idx}, this)">${emailOptions}</select></div></td>
                <td><input class="ghl-cell-input" value="${this.esc(l.phone)}" onchange="app._ghlLeads[${idx}].phone=this.value"></td>
                <td><input class="ghl-cell-input" value="${this.esc(l.city)}" onchange="app._ghlLeads[${idx}].city=this.value"></td>
                <td><input class="ghl-cell-input" value="${this.esc(l.state)}" onchange="app._ghlLeads[${idx}].state=this.value" style="width:50px;"></td>
                <td><input class="ghl-cell-input" value="${this.esc(l.website)}" onchange="app._ghlLeads[${idx}].website=this.value" style="font-size:11px;"></td>
                <td><div class="ghl-socials-cell">${socialsHtml || '<span style="color:var(--text-tertiary);font-size:11px;">—</span>'}</div></td>
            </tr>`;
        }).join('');

        const tp = this._ghlTotalPages || 1;
        const cp = this._ghlPage || 1;
        let pagHtml = '';
        if (tp > 1) {
            pagHtml = `<div style="display:flex;align-items:center;justify-content:center;gap:6px;padding:10px 0;font-size:12px;">
                <button class="btn btn-ghost" onclick="app.ghlGoToPage(${cp - 1})" ${cp <= 1 ? 'disabled' : ''} style="padding:4px 10px;font-size:12px;"><i class="fas fa-chevron-left"></i></button>
                <span style="color:var(--text-secondary);">Page ${cp} of ${tp}</span>
                <button class="btn btn-ghost" onclick="app.ghlGoToPage(${cp + 1})" ${cp >= tp ? 'disabled' : ''} style="padding:4px 10px;font-size:12px;"><i class="fas fa-chevron-right"></i></button>
                <span style="margin-left:8px;color:var(--text-tertiary);">${(this._ghlTotalLeads || 0).toLocaleString()} total</span>
            </div>`;
        }
        document.getElementById('ghlLeadCount').innerHTML = `${(this._ghlTotalLeads || leads.length).toLocaleString()} leads` + pagHtml;
    }

    ghlEmailChange(idx, select) {
        if (select.value === '__custom') {
            const newEmail = prompt('Enter email address:');
            if (newEmail && newEmail.includes('@')) {
                this._ghlLeads[idx].emails.push(newEmail);
                this._ghlLeads[idx].email = newEmail;
            }
            this.renderGHLSpreadsheet();
        } else {
            this._ghlLeads[idx].email = select.value;
        }
    }

    ghlToggleOne(idx, checked) {
        if (checked) this._ghlSelected.add(idx);
        else this._ghlSelected.delete(idx);
        this.renderGHLSpreadsheet();
        this.updateGHLSummary();
    }

    ghlToggleSelectAll(checked) {
        this._ghlLeads.forEach((_, idx) => {
            if (checked) this._ghlSelected.add(idx);
            else this._ghlSelected.delete(idx);
        });
        this.renderGHLSpreadsheet();
        this.updateGHLSummary();
    }

    ghlSelectAll() {
        this._ghlLeads.forEach((_, idx) => {
            this._ghlSelected.add(idx);
        });
        this.renderGHLSpreadsheet();
        this.updateGHLSummary();
    }

    ghlDeselectAll() {
        this._ghlSelected.clear();
        this.renderGHLSpreadsheet();
        this.updateGHLSummary();
    }

    updateGHLSummary() {
        const sel = this._ghlTotalLeads || this._ghlSelected.size;
        const tags = this._ghlSelectedTags.length;
        const wf = document.getElementById('ghlWorkflowSelect')?.value;
        const wfName = wf ? document.getElementById('ghlWorkflowSelect').selectedOptions[0]?.textContent : '';

        let parts = [`<strong>${sel.toLocaleString()}</strong> contacts selected`];
        if (tags > 0) parts.push(`${tags} tag${tags > 1 ? 's' : ''}`);
        if (wfName) parts.push(`workflow: ${wfName}`);
        document.getElementById('ghlSummaryText').innerHTML = parts.join(' · ');
    }

    showGHLTagDropdown() {
        const dropdown = document.getElementById('ghlTagDropdown');
        dropdown.classList.remove('hidden');
        this.filterGHLTags();
        setTimeout(() => {
            const handler = (e) => {
                if (!e.target.closest('#ghlTagsArea')) { dropdown.classList.add('hidden'); document.removeEventListener('click', handler); }
            };
            document.addEventListener('click', handler);
        }, 10);
    }

    filterGHLTags() {
        const q = (document.getElementById('ghlTagInput')?.value || '').toLowerCase();
        const dropdown = document.getElementById('ghlTagDropdown');
        const existing = new Set(this._ghlSelectedTags);
        const filtered = this._ghlTags.filter(t => !existing.has(t) && t.toLowerCase().includes(q));

        let html = filtered.slice(0, 30).map(t => `<div class="ghl-tag-option" onclick="app.addGHLTag('${this.esc(t)}')">${this.esc(t)}</div>`).join('');
        if (q && !this._ghlTags.some(t => t.toLowerCase() === q) && !existing.has(q)) {
            html = `<div class="ghl-tag-option" onclick="app.addGHLTag('${this.esc(q)}')"><i class="fas fa-plus" style="color:var(--accent);"></i> Create "${this.esc(q)}"</div>` + html;
        }
        if (!html) html = '<div style="padding:12px;text-align:center;color:var(--text-tertiary);font-size:12px;">No tags found</div>';
        dropdown.innerHTML = html;
    }

    addGHLTag(tag) {
        if (!this._ghlSelectedTags.includes(tag)) this._ghlSelectedTags.push(tag);
        document.getElementById('ghlTagInput').value = '';
        document.getElementById('ghlTagDropdown').classList.add('hidden');
        this.renderGHLTagChips();
        this.updateGHLSummary();
    }

    removeGHLTag(tag) {
        this._ghlSelectedTags = this._ghlSelectedTags.filter(t => t !== tag);
        this.renderGHLTagChips();
        this.updateGHLSummary();
    }

    renderGHLTagChips() {
        document.getElementById('ghlSelectedTags').innerHTML = this._ghlSelectedTags.map(t =>
            `<span class="ghl-tag-chip">${this.esc(t)}<button onclick="app.removeGHLTag('${this.esc(t)}')">&times;</button></span>`
        ).join('');
    }

    closeGHLExport() {
        document.getElementById('ghlExportOverlay').classList.remove('active');
        document.getElementById('ghlSettingsSlide').classList.add('hidden');
        document.getElementById('ghlDripSlide').classList.add('hidden');
        document.getElementById('ghlLogsSlide').classList.add('hidden');
        if (this.currentList) { this.loadLeads(); this.refreshCurrentList(); }
    }

    openGHLSettings() {
        this.renderGHLSettingsConnections();
        this.updateScraperStatusUI();
        document.getElementById('ghlSettingsSlide').classList.remove('hidden');
    }

    updateScraperStatusUI() {
        fetch('leadlists.php?action=getWorkerStatus')
            .then(res => res.json())
            .then(res => {
                if (!res.success) return;
                const statusText = document.getElementById('scraperStatusText');
                const reasonText = document.getElementById('scraperPauseReason');
                const btn = document.getElementById('btnToggleScraper');
                if (res.worker_paused) {
                    statusText.innerHTML = '<span style="color:var(--red);"><i class="fas fa-pause"></i> Worker Paused</span>';
                    reasonText.innerHTML = 'Reason: ' + (res.pause_reason || 'Manual') + (res.paused_at ? ' at ' + res.paused_at : '');
                    btn.innerHTML = '<i class="fas fa-play"></i> Resume';
                    btn.className = 'btn btn-sm btn-primary';
                } else {
                    statusText.innerHTML = '<span style="color:var(--green);"><i class="fas fa-running"></i> Worker Active</span>';
                    reasonText.innerHTML = 'Polling background enrichment queue...';
                    btn.innerHTML = '<i class="fas fa-pause"></i> Pause';
                    btn.className = 'btn btn-sm btn-secondary';
                }
                this._workerPaused = res.worker_paused;
            })
            .catch(err => console.error(err));
    }

    toggleScraper() {
        const nextState = !this._workerPaused;
        const payload = {
            worker_paused: nextState,
            pause_reason: nextState ? 'manual' : ''
        };
        fetch('leadlists.php?action=toggleWorkerPause', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(payload)
        })
        .then(res => res.json())
        .then(res => {
            if (res.success) {
                this.toast(nextState ? 'Worker paused successfully' : 'Worker resumed successfully');
                this.updateScraperStatusUI();
            } else {
                this.toast('Error toggling worker: ' + res.error);
            }
        })
        .catch(err => {
            this.toast('Error toggling worker');
            console.error(err);
        });
    }

    renderGHLSettingsConnections() {
        const container = document.getElementById('ghlSettingsConnectionsList');
        if (!container) return;
        if (this._ghlConnections.length === 0) {
            container.innerHTML = '<div style="text-align:center;padding:16px;color:var(--text-tertiary);font-size:12px;">No connections</div>';
            return;
        }
        container.innerHTML = this._ghlConnections.map(c => {
            const isActive = this._ghlActiveConn?.id == c.id;
            return `<div style="display:flex;align-items:center;gap:10px;padding:12px;background:${isActive ? 'rgba(var(--accent-rgb), 0.06)' : 'var(--bg)'};border:1px solid ${isActive ? 'var(--accent)' : 'var(--card-border)'};border-radius:8px;margin-bottom:6px;">
                <div style="width:32px;height:32px;border-radius:8px;background:linear-gradient(135deg,#FF6B35,#FF3B30);display:flex;align-items:center;justify-content:center;flex-shrink:0;"><i class="fas fa-bolt" style="color:#fff;font-size:12px;"></i></div>
                <div style="flex:1;min-width:0;">
                    <div style="font-weight:600;font-size:13px;">${this.esc(c.name)}${isActive ? ' <span style="font-size:10px;color:var(--accent);">(active)</span>' : ''}</div>
                    <div style="font-size:10px;color:var(--text-tertiary);">Location: ${this.esc(c.location_id)}</div>
                </div>
                <button class="btn-icon" onclick="app.editGHLConnection(${c.id})" title="Edit" style="font-size:11px;"><i class="fas fa-pen"></i></button>
                <button class="btn-icon" onclick="app.deleteGHLConnection(${c.id})" title="Delete" style="font-size:11px;color:var(--red);"><i class="fas fa-trash"></i></button>
            </div>`;
        }).join('');
    }

    closeGHLSettings() {
        document.getElementById('ghlSettingsSlide').classList.add('hidden');
    }

    toggleDripFields() {
        document.getElementById('ghlDripFields').classList.toggle('hidden', !document.getElementById('ghlDripEnabled').checked);
    }

    openGHLDripConfig() {
        document.getElementById('ghlDripSlide').classList.remove('hidden');
    }

    getDripConfig() {
        const enabled = document.getElementById('ghlDripEnabled')?.checked;
        if (!enabled) return null;
        const hour = document.getElementById('ghlDripHour')?.value;
        return {
            enabled: true,
            batch_size: parseInt(document.getElementById('ghlDripBatch')?.value || '50'),
            interval_minutes: parseInt(document.getElementById('ghlDripInterval')?.value || '60'),
            timezone: document.getElementById('ghlDripTimezone')?.value || 'America/New_York',
            send_hour: hour !== '' ? parseInt(hour) : null,
            send_minute: 0
        };
    }

    async startGHLImport() {
        const totalToImport = this._ghlTotalLeads || this._ghlLeads.length;
        if (totalToImport === 0) { this.toast('No leads to import'); return; }

        const tags = this._ghlSelectedTags;
        const wfId = document.getElementById('ghlWorkflowSelect')?.value || '';
        const wfName = wfId ? document.getElementById('ghlWorkflowSelect').selectedOptions[0]?.textContent : '';
        const drip = this.getDripConfig();

        const filters = {
            has: document.getElementById('ghlFilterSelect')?.value || '',
            search: document.getElementById('ghlSearchInput')?.value || '',
            import_filter: document.getElementById('ghlImportFilter')?.value || ''
        };

        const summary = [`Import ${totalToImport.toLocaleString()} contacts to GoHighLevel`];
        if (tags.length) summary.push(`Tags: ${tags.join(', ')}`);
        if (wfName) summary.push(`Workflow: ${wfName}`);
        if (drip) summary.push(`Drip: ${drip.batch_size} per batch, every ${drip.interval_minutes} min`);
        if (!confirm(summary.join('\
') + '\
\
Proceed?')) return;

        this.showGHLScreen('ghlImportingScreen');
        document.getElementById('ghlImportBar').style.width = '0%';
        document.getElementById('ghlImportPct').textContent = '0%';
        document.getElementById('ghlImportProgressLabel').textContent = `0 of ${totalToImport}`;
        document.getElementById('ghlStatNew').textContent = '0';
        document.getElementById('ghlStatUpdated').textContent = '0';
        document.getElementById('ghlStatFailed').textContent = '0';

        const createRes = await this.api('ghlCreateImportFromList', {
            list_id: this.currentList?.id,
            tags,
            workflow_id: wfId,
            workflow_name: wfName,
            connection_id: this._ghlActiveConn?.id || 0,
            drip,
            filters
        }, 'POST');

        if (!createRes.success) { this.toast('Failed to create import: ' + (createRes.error || '')); this.showGHLScreen('ghlEditorScreen'); return; }

        this._currentImportId = createRes.import_id;
        const importTotal = createRes.total || totalToImport;

        if (createRes.mode === 'drip' && drip?.send_hour !== null) {
            this.showGHLDoneScreen(0, 0, 0, [], tags, wfName, true, createRes);
            return;
        }

        await this.processGHLImport(createRes.import_id, importTotal, tags, wfName);
    }

    async processGHLImport(importId, total, tags, wfName) {
        let done = false;
        while (!done) {
            const statusCheck = await this.api('ghlGetImportStatus', { import_id: importId });
            if (statusCheck.success && statusCheck.log?.status === 'paused') {
                await new Promise(r => setTimeout(r, 2000));
                continue;
            }
            if (statusCheck.success && statusCheck.log?.status === 'cancelled') { done = true; break; }

            const res = await this.api('ghlProcessBatch', { import_id: importId }, 'POST');
            if (!res.success) { this.toast('Batch error: ' + (res.error || '')); break; }

            if (res.totals) {
                const t = res.totals;
                const processed = parseInt(t.processed || 0);
                const pct = total > 0 ? Math.round((processed / total) * 100) : 0;
                document.getElementById('ghlImportBar').style.width = pct + '%';
                document.getElementById('ghlImportPct').textContent = pct + '%';
                document.getElementById('ghlImportProgressLabel').textContent = `${processed} of ${total}`;
                document.getElementById('ghlStatNew').textContent = t.imported || 0;
                document.getElementById('ghlStatUpdated').textContent = t.updated || 0;
                document.getElementById('ghlStatFailed').textContent = t.failed || 0;
            }

            if (res.waiting) {
                const t = res.totals || {};
                this.showGHLDoneScreen(
                    parseInt(t.imported || 0),
                    parseInt(t.updated || 0),
                    parseInt(t.failed || 0),
                    [], tags, wfName, false, null,
                    { remaining: res.remaining, waitSeconds: res.wait_seconds, nextBatchAt: res.drip_next_batch_at, importId }
                );
                return;
            }

            done = res.done;
        }

        const finalStatus = await this.api('ghlGetImportStatus', { import_id: importId });
        const fl = finalStatus.log || {};
        this.showGHLDoneScreen(
            parseInt(fl.imported || 0),
            parseInt(fl.updated || 0),
            parseInt(fl.failed || 0),
            fl.errors || [],
            tags, wfName, false, null
        );
    }

    showGHLDoneScreen(imported, updated, failed, errors, tags, wfName, isDripScheduled, createRes, dripProgress) {
        this.showGHLScreen('ghlDoneScreen');

        if (isDripScheduled) {
            document.getElementById('ghlDoneSubtitle').textContent = 'Drip import scheduled';
            let summaryHtml = `<div style="text-align:center;margin-bottom:16px;">
                <div style="width:60px;height:60px;border-radius:50%;background:linear-gradient(135deg,var(--accent),var(--accent-hover));display:flex;align-items:center;justify-content:center;margin:0 auto 12px;">
                    <i class="fas fa-clock" style="font-size:24px;color:#fff;"></i>
                </div>
                <div style="font-size:15px;font-weight:600;">Contacts queued for drip delivery</div>
                <div style="font-size:13px;color:var(--text-secondary);margin-top:4px;">First batch will send at the scheduled time.</div>
            </div>`;
            if (tags.length) summaryHtml += `<div style="margin-bottom:6px;"><strong>Tags:</strong> ${tags.map(t => `<span class="ghl-tag-chip" style="font-size:10px;">${this.esc(t)}</span>`).join(' ')}</div>`;
            if (wfName) summaryHtml += `<div><strong>Workflow:</strong> ${this.esc(wfName)}</div>`;
            document.getElementById('ghlDoneSummary').innerHTML = summaryHtml;
            document.getElementById('ghlDoneErrors').classList.add('hidden');
            return;
        }

        if (dripProgress) {
            const total = imported + updated + failed;
            document.getElementById('ghlDoneSubtitle').textContent = 'Batch complete — drip in progress';
            const waitMin = Math.ceil((dripProgress.waitSeconds || 0) / 60);
            let summaryHtml = `<div style="display:flex;gap:20px;margin-bottom:12px;">
                <div><span style="font-size:24px;font-weight:700;color:var(--green);">${imported}</span><div style="font-size:11px;color:var(--text-tertiary);">New contacts</div></div>
                <div><span style="font-size:24px;font-weight:700;color:var(--blue);">${updated}</span><div style="font-size:11px;color:var(--text-tertiary);">Updated</div></div>
                <div><span style="font-size:24px;font-weight:700;color:var(--red);">${failed}</span><div style="font-size:11px;color:var(--text-tertiary);">Failed</div></div>
            </div>`;
            summaryHtml += `<div style="padding:12px 16px;background:#EDE9FE;border-radius:10px;margin-bottom:12px;">
                <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px;">
                    <i class="fas fa-clock" style="color:#5B21B6;"></i>
                    <strong style="color:#5B21B6;">Next batch in ~${waitMin} min</strong>
                </div>
                <div style="font-size:12px;color:#6B21A8;">${dripProgress.remaining} contacts remaining — check Import Logs for live status</div>
            </div>`;
            if (tags.length) summaryHtml += `<div style="margin-bottom:6px;"><strong>Tags applied:</strong> ${tags.map(t => `<span class="ghl-tag-chip" style="font-size:10px;">${this.esc(t)}</span>`).join(' ')}</div>`;
            if (wfName) summaryHtml += `<div><strong>Workflow:</strong> ${this.esc(wfName)}</div>`;
            document.getElementById('ghlDoneSummary').innerHTML = summaryHtml;
            document.getElementById('ghlDoneErrors').classList.add('hidden');
            this.fireConfetti();
            return;
        }

        const total = imported + updated + failed;
        document.getElementById('ghlDoneSubtitle').textContent = `${total.toLocaleString()} contacts processed`;

        let summaryHtml = `<div style="display:flex;gap:20px;margin-bottom:12px;">
            <div><span style="font-size:24px;font-weight:700;color:var(--green);">${imported}</span><div style="font-size:11px;color:var(--text-tertiary);">New contacts</div></div>
            <div><span style="font-size:24px;font-weight:700;color:var(--blue);">${updated}</span><div style="font-size:11px;color:var(--text-tertiary);">Updated</div></div>
            <div><span style="font-size:24px;font-weight:700;color:var(--red);">${failed}</span><div style="font-size:11px;color:var(--text-tertiary);">Failed</div></div>
        </div>`;
        if (tags.length) summaryHtml += `<div style="margin-bottom:6px;"><strong>Tags applied:</strong> ${tags.map(t => `<span class="ghl-tag-chip" style="font-size:10px;">${this.esc(t)}</span>`).join(' ')}</div>`;
        if (wfName) summaryHtml += `<div><strong>Workflow:</strong> ${this.esc(wfName)}</div>`;
        document.getElementById('ghlDoneSummary').innerHTML = summaryHtml;

        if (errors.length > 0) {
            document.getElementById('ghlDoneErrors').classList.remove('hidden');
            document.getElementById('ghlDoneErrorList').innerHTML = errors.slice(0, 20).map(e => `<div style="margin-bottom:4px;">\u2022 ${this.esc(e)}</div>`).join('');
        } else {
            document.getElementById('ghlDoneErrors').classList.add('hidden');
        }

        this.fireConfetti();
    }

    async showGHLImportLogs() {
        document.getElementById('ghlLogsSlide').classList.remove('hidden');
        const content = document.getElementById('ghlLogsContent');
        content.innerHTML = '<div style="text-align:center;padding:30px;color:var(--text-tertiary);"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';

        const res = await this.api('ghlGetImportLogs', { list_id: this.currentList?.id || 0 });
        if (!res.success || !res.logs?.length) {
            content.innerHTML = '<div style="text-align:center;padding:30px;color:var(--text-tertiary);"><i class="fas fa-inbox" style="font-size:24px;margin-bottom:8px;display:block;"></i>No imports yet</div>';
            return;
        }

        content.innerHTML = res.logs.map(log => {
            const pct = log.total_contacts > 0 ? Math.round((log.processed / log.total_contacts) * 100) : 0;
            const date = new Date(log.created_at).toLocaleString();
            const tags = (log.tags || []).slice(0, 3);
            const isActive = ['running','pending','paused'].includes(log.status);

            return `<div class="ghl-log-card" onclick="app.openImportLogDetail(${log.id})">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
                    <span style="font-weight:600;">${this.esc(log.list_name || 'List #' + log.list_id)}</span>
                    <span class="ghl-log-status ${log.status}">${log.status}</span>
                </div>
                <div style="display:flex;gap:16px;font-size:12px;color:var(--text-secondary);margin-bottom:4px;">
                    <span><i class="fas fa-users"></i> ${log.total_contacts}</span>
                    <span style="color:var(--green);"><i class="fas fa-plus"></i> ${log.imported}</span>
                    <span style="color:var(--blue);"><i class="fas fa-sync"></i> ${log.updated}</span>
                    <span style="color:var(--red);"><i class="fas fa-times"></i> ${log.failed}</span>
                </div>
                <div style="font-size:11px;color:var(--text-tertiary);">${date}${log.connection_name ? ' · <i class="fas fa-bolt"></i> ' + this.esc(log.connection_name) : ''}${log.drip_enabled ? ' · <i class="fas fa-clock"></i> Drip' : ''}</div>
                ${log.drip_enabled && log.drip_next_batch_at && log.status === 'pending' ? (() => { const ms = new Date(log.drip_next_batch_at + 'Z').getTime() - Date.now(); const m = Math.max(0, Math.ceil(ms/60000)); return '<div style="font-size:11px;color:#5B21B6;margin-top:4px;padding:4px 8px;background:#EDE9FE;border-radius:6px;display:inline-block;"><i class="fas fa-clock"></i> Next batch in ~' + m + ' min</div>'; })() : ''}
                ${tags.length ? '<div style="margin-top:6px;">' + tags.map(t => `<span class="ghl-tag-chip" style="font-size:9px;">${this.esc(t)}</span>`).join(' ') + '</div>' : ''}
                ${isActive || pct < 100 ? `<div class="ghl-log-progress"><div class="ghl-log-progress-bar" style="width:${pct}%;"></div></div>` : ''}
            </div>`;
        }).join('');
    }

    async openImportLogDetail(importId) {
        const res = await this.api('ghlGetImportStatus', { import_id: importId });
        if (!res.success || !res.log) { this.toast('Could not load import details'); return; }
        const log = res.log;
        const pct = log.total_contacts > 0 ? Math.round((log.processed / log.total_contacts) * 100) : 0;
        const isActive = ['running','pending','paused'].includes(log.status);
        const date = new Date(log.created_at).toLocaleString();
        const tags = log.tags || [];
        const errors = log.errors || [];

        let actions = '';
        if (log.status === 'running' || log.status === 'pending') {
            actions += `<button class="btn btn-sm" onclick="app.pauseGHLImport(${importId})" style="font-size:12px;"><i class="fas fa-pause"></i> Pause</button>`;
            actions += `<button class="btn btn-sm" onclick="app.cancelGHLImport(${importId})" style="font-size:12px;color:var(--red);"><i class="fas fa-stop"></i> Cancel</button>`;
        }
        if (log.status === 'paused') {
            actions += `<button class="btn btn-sm" onclick="app.resumeGHLImport(${importId})" style="font-size:12px;"><i class="fas fa-play"></i> Resume</button>`;
            actions += `<button class="btn btn-sm" onclick="app.cancelGHLImport(${importId})" style="font-size:12px;color:var(--red);"><i class="fas fa-stop"></i> Cancel</button>`;
        }

        document.getElementById('ghlLogsContent').innerHTML = `
            <button class="btn btn-sm" onclick="app.showGHLImportLogs()" style="margin-bottom:12px;font-size:12px;"><i class="fas fa-arrow-left"></i> Back</button>
            <div style="background:var(--bg);border:1px solid var(--card-border);border-radius:10px;padding:16px;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                    <span style="font-weight:700;font-size:15px;">Import #${log.id}</span>
                    <span class="ghl-log-status ${log.status}">${log.status}</span>
                </div>
                <div style="font-size:12px;color:var(--text-secondary);margin-bottom:12px;">${date}</div>
                <div style="display:flex;gap:16px;margin-bottom:12px;">
                    <div style="text-align:center;"><div style="font-size:20px;font-weight:700;">${log.total_contacts}</div><div style="font-size:10px;color:var(--text-tertiary);">Total</div></div>
                    <div style="text-align:center;"><div style="font-size:20px;font-weight:700;color:var(--green);">${log.imported}</div><div style="font-size:10px;color:var(--text-tertiary);">New</div></div>
                    <div style="text-align:center;"><div style="font-size:20px;font-weight:700;color:var(--blue);">${log.updated}</div><div style="font-size:10px;color:var(--text-tertiary);">Updated</div></div>
                    <div style="text-align:center;"><div style="font-size:20px;font-weight:700;color:var(--red);">${log.failed}</div><div style="font-size:10px;color:var(--text-tertiary);">Failed</div></div>
                </div>
                <div class="ghl-log-progress" style="margin-bottom:12px;"><div class="ghl-log-progress-bar" style="width:${pct}%;"></div></div>
                <div style="font-size:12px;color:var(--text-secondary);margin-bottom:12px;">${log.processed} / ${log.total_contacts} processed (${pct}%)</div>
                ${log.drip_enabled ? `<div style="font-size:12px;margin-bottom:12px;padding:8px 12px;background:#EDE9FE;border-radius:8px;"><i class="fas fa-clock" style="color:#5B21B6;"></i> <strong>Drip:</strong> ${log.drip_batch_size} per batch, every ${log.drip_interval_minutes} min (${log.drip_timezone})</div>` : ''}
                ${tags.length ? '<div style="margin-bottom:12px;">' + tags.map(t => `<span class="ghl-tag-chip" style="font-size:10px;">${this.esc(t)}</span>`).join(' ') + '</div>' : ''}
                ${log.connection_name ? `<div style="font-size:12px;margin-bottom:12px;"><i class="fas fa-bolt" style="color:var(--accent);"></i> <strong>Connection:</strong> ${this.esc(log.connection_name)}</div>` : ''}
                ${log.workflow_name ? `<div style="font-size:12px;margin-bottom:12px;"><strong>Workflow:</strong> ${this.esc(log.workflow_name)}</div>` : ''}
                ${actions ? `<div style="display:flex;gap:8px;margin-bottom:12px;">${actions}</div>` : ''}
                ${errors.length ? `<div style="background:#FFF5F5;border:1px solid #FED7D7;border-radius:8px;padding:12px;max-height:150px;overflow-y:auto;">
                    <div style="font-size:12px;font-weight:600;color:var(--red);margin-bottom:6px;"><i class="fas fa-exclamation-triangle"></i> Errors (${errors.length})</div>
                    ${errors.slice(0, 20).map(e => `<div style="font-size:11px;color:#666;margin-bottom:3px;">• ${this.esc(String(e))}</div>`).join('')}
                </div>` : ''}
            </div>`;
    }

    async pauseGHLImport(importId) {
        await this.api('ghlPauseImport', { import_id: importId }, 'POST');
        this.toast('Import paused');
        this.openImportLogDetail(importId);
    }

    async resumeGHLImport(importId) {
        await this.api('ghlResumeImport', { import_id: importId }, 'POST');
        this.toast('Import resumed');
        this.openImportLogDetail(importId);
    }

    async cancelGHLImport(importId) {
        if (!confirm('Cancel this import? Remaining contacts will not be sent.')) return;
        await this.api('ghlCancelImport', { import_id: importId }, 'POST');
        this.toast('Import cancelled');
        this.openImportLogDetail(importId);
    }

    async pauseCurrentImport() {
        if (!this._currentImportId) return;
        if (this._dripTimer) { clearTimeout(this._dripTimer); this._dripTimer = null; }
        await this.api('ghlPauseImport', { import_id: this._currentImportId }, 'POST');
        this.toast('Import paused — you can resume from Import Logs');
    }

    async cancelCurrentImport() {
        if (!this._currentImportId) return;
        if (!confirm('Cancel this import? Remaining contacts will not be sent.')) return;
        if (this._dripTimer) { clearTimeout(this._dripTimer); this._dripTimer = null; }
        await this.api('ghlCancelImport', { import_id: this._currentImportId }, 'POST');
        this.toast('Import cancelled');
        this.closeGHLExport();
    }

    async openFolderImportLogs() {
        const modal = document.getElementById('importLogsModal');
        modal.classList.add('active');
        const content = document.getElementById('importLogsModalContent');
        content.innerHTML = '<div style="text-align:center;padding:30px;color:var(--text-tertiary);"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';

        const res = await this.api('ghlGetImportLogs', { list_id: this.currentList?.id || 0 });
        if (!res.success || !res.logs?.length) {
            content.innerHTML = '<div style="text-align:center;padding:40px;color:var(--text-tertiary);"><i class="fas fa-inbox" style="font-size:28px;margin-bottom:10px;display:block;"></i><div style="font-size:14px;">No imports yet for this folder</div><div style="font-size:12px;margin-top:4px;">Export leads to GoHighLevel to see import history here.</div></div>';
            return;
        }

        content.innerHTML = res.logs.map(log => {
            const pct = log.total_contacts > 0 ? Math.round((log.processed / log.total_contacts) * 100) : 0;
            const date = new Date(log.created_at).toLocaleString();
            const tags = (log.tags || []).slice(0, 3);
            const isActive = ['running','pending','paused'].includes(log.status);
            const errors = log.errors || [];

            let actions = '';
            if (log.status === 'running' || log.status === 'pending') {
                actions = `<div style="display:flex;gap:6px;margin-top:8px;">
                    <button class="btn btn-sm" onclick="event.stopPropagation();app.pauseImportFromFolder(${log.id})" style="font-size:11px;"><i class="fas fa-pause"></i> Pause</button>
                    <button class="btn btn-sm" onclick="event.stopPropagation();app.cancelImportFromFolder(${log.id})" style="font-size:11px;color:var(--red);"><i class="fas fa-stop"></i> Cancel</button>
                </div>`;
            } else if (log.status === 'paused') {
                actions = `<div style="display:flex;gap:6px;margin-top:8px;">
                    <button class="btn btn-sm" onclick="event.stopPropagation();app.resumeImportFromFolder(${log.id})" style="font-size:11px;"><i class="fas fa-play"></i> Resume</button>
                    <button class="btn btn-sm" onclick="event.stopPropagation();app.cancelImportFromFolder(${log.id})" style="font-size:11px;color:var(--red);"><i class="fas fa-stop"></i> Cancel</button>
                </div>`;
            }

            return `<div class="ghl-log-card">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
                    <span style="font-weight:600;">Import #${log.id}</span>
                    <span class="ghl-log-status ${log.status}">${log.status}</span>
                </div>
                <div style="display:flex;gap:16px;font-size:12px;color:var(--text-secondary);margin-bottom:4px;">
                    <span><i class="fas fa-users"></i> ${log.total_contacts} contacts</span>
                    <span style="color:var(--green);"><i class="fas fa-plus"></i> ${log.imported} new</span>
                    <span style="color:var(--blue);"><i class="fas fa-sync"></i> ${log.updated} updated</span>
                    ${log.failed > 0 ? `<span style="color:var(--red);"><i class="fas fa-times"></i> ${log.failed} failed</span>` : ''}
                </div>
                <div style="font-size:11px;color:var(--text-tertiary);">${date}${log.connection_name ? ' · <i class="fas fa-bolt"></i> ' + this.esc(log.connection_name) : ''}${log.drip_enabled ? ' · <i class="fas fa-clock"></i> Drip (' + log.drip_batch_size + '/batch, ' + log.drip_interval_minutes + 'min)' : ''}${log.workflow_name ? ' · <i class="fas fa-project-diagram"></i> ' + this.esc(log.workflow_name) : ''}</div>
                ${log.drip_enabled && log.drip_next_batch_at && log.status === 'pending' ? (() => { const ms = new Date(log.drip_next_batch_at + 'Z').getTime() - Date.now(); const m = Math.max(0, Math.ceil(ms/60000)); return '<div style="font-size:11px;color:#5B21B6;margin-top:4px;padding:4px 8px;background:#EDE9FE;border-radius:6px;display:inline-block;"><i class="fas fa-clock"></i> Next batch in ~' + m + ' min</div>'; })() : ''}
                ${tags.length ? '<div style="margin-top:6px;">' + tags.map(t => `<span class="ghl-tag-chip" style="font-size:9px;">${this.esc(t)}</span>`).join(' ') + '</div>' : ''}
                ${isActive || pct < 100 ? `<div class="ghl-log-progress"><div class="ghl-log-progress-bar" style="width:${pct}%;"></div></div><div style="font-size:11px;color:var(--text-tertiary);margin-top:3px;">${log.processed} / ${log.total_contacts} (${pct}%)</div>` : ''}
                ${errors.length ? `<details style="margin-top:8px;"><summary style="font-size:11px;color:var(--red);cursor:pointer;font-weight:600;">${errors.length} error(s)</summary><div style="font-size:11px;color:#666;margin-top:4px;max-height:80px;overflow-y:auto;">${errors.slice(0, 10).map(e => `<div>• ${this.esc(String(e))}</div>`).join('')}</div></details>` : ''}
                ${actions}
            </div>`;
        }).join('');
    }

    async pauseImportFromFolder(importId) {
        await this.api('ghlPauseImport', { import_id: importId }, 'POST');
        this.toast('Import paused');
        this.openFolderImportLogs();
    }

    async resumeImportFromFolder(importId) {
        await this.api('ghlResumeImport', { import_id: importId }, 'POST');
        this.toast('Import resumed');
        this.openFolderImportLogs();
    }

    async cancelImportFromFolder(importId) {
        if (!confirm('Cancel this import?')) return;
        await this.api('ghlCancelImport', { import_id: importId }, 'POST');
        this.toast('Import cancelled');
        this.openFolderImportLogs();
    }

    fireConfetti() {
        const canvas = document.getElementById('confettiCanvas');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        canvas.width = canvas.offsetWidth;
        canvas.height = canvas.offsetHeight;
        const particles = [];
        const colors = ['#FF3B30','var(--accent)','#FFCC00','#34C759','var(--accent)','var(--accent)','#FF2D55'];
        for (let i = 0; i < 150; i++) {
            particles.push({
                x: canvas.width / 2 + (Math.random() - 0.5) * 200,
                y: canvas.height / 2,
                vx: (Math.random() - 0.5) * 12,
                vy: -Math.random() * 12 - 4,
                w: Math.random() * 8 + 4,
                h: Math.random() * 6 + 3,
                color: colors[Math.floor(Math.random() * colors.length)],
                rot: Math.random() * Math.PI * 2,
                rv: (Math.random() - 0.5) * 0.3,
                gravity: 0.15 + Math.random() * 0.05,
                alpha: 1
            });
        }
        let frame = 0;
        const animate = () => {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            let alive = false;
            particles.forEach(p => {
                p.x += p.vx;
                p.vy += p.gravity;
                p.y += p.vy;
                p.rot += p.rv;
                if (frame > 60) p.alpha -= 0.01;
                if (p.alpha <= 0) return;
                alive = true;
                ctx.save();
                ctx.translate(p.x, p.y);
                ctx.rotate(p.rot);
                ctx.globalAlpha = Math.max(0, p.alpha);
                ctx.fillStyle = p.color;
                ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
                ctx.restore();
            });
            frame++;
            if (alive && frame < 200) requestAnimationFrame(animate);
            else ctx.clearRect(0, 0, canvas.width, canvas.height);
        };
        animate();
    }

    openWebPreview(url, leadId) {
        if (leadId) this.api('updateLead', { id: leadId, visited_website: 1 }, 'POST').then(() => this.refreshCurrentList());

        const noIframeDomains = ['facebook.com','fb.com','fb.me','instagram.com','instagr.am','twitter.com','x.com','linkedin.com','youtube.com','youtu.be','tiktok.com'];
        const isSocial = (u) => noIframeDomains.some(d => u.toLowerCase().includes(d));

        const toSafe = (u) => {
            if (u.startsWith('http://')) return u.replace('http://', 'https://');
            if (!u.startsWith('https://')) return 'https://' + u;
            return u;
        };
        const toOriginal = (u) => u.startsWith('http') ? u : 'https://' + u;

        const lead = leadId ? (this.currentLeads.find(l => l.id == leadId) || this.currentLeadDetail) : null;

        const socialLinks = [];
        let websiteLink = null;
        if (lead) {
            (lead.social_media_links || []).forEach(surl => {
                const p = SOCIAL_PLATFORMS.find(pl => pl.patterns.some(pat => surl.toLowerCase().includes(pat)));
                socialLinks.push({ url: surl, icon: p ? p.icon : 'fas fa-link', name: p ? p.name : 'Link' });
            });
            if (lead.website) {
                websiteLink = { url: lead.website, icon: 'fas fa-globe', name: 'Website' };
            }
        }

        const visitedSocials = lead ? (lead.visited_socials || []) : [];
        const socialBtns = socialLinks.map(l => {
            const isVisited = visitedSocials.includes(l.url);
            return `<button class="preview-link-btn ${isVisited ? 'visited' : ''}" onclick="app.trackSocialVisit(${leadId}, '${this.esc(l.url)}')" title="${l.name}" style="${isVisited ? 'color:var(--green);' : ''}"><i class="${l.icon}"></i></button>`;
        }).join('');
        const websiteBtn = websiteLink
            ? `<button class="preview-link-btn active" onclick="app.switchPreviewUrl(this, '${this.esc(websiteLink.url)}')" title="Website"><i class="fas fa-globe"></i></button>`
            : '';
        const leadEmails = lead ? (lead.emails || []) : [];
        const emailBtn = leadEmails.length > 0
            ? `<button class="preview-link-btn" onclick="app.sendTemplateEmail('${this.esc(leadEmails[0])}', ${leadId})" title="Email ${this.esc(leadEmails[0])}" style="color:var(--accent);"><i class="fas fa-envelope"></i></button>`
            : '';
        const hasBar = socialLinks.length > 0 || websiteLink || emailBtn;

        if (isSocial(url) && !lead) {
            window.open(toOriginal(url), '_blank');
            return;
        }

        const existing = document.querySelector('.web-preview-overlay');
        if (existing) existing.remove();

        const iframeUrl = isSocial(url) && websiteLink ? toSafe(websiteLink.url) : toSafe(url);
        const displayUrl = isSocial(url) && websiteLink ? websiteLink.url : url;

        if (isSocial(url) && !websiteLink) {
            window.open(toOriginal(url), '_blank');
            return;
        }

        const overlay = document.createElement('div');
        overlay.className = 'web-preview-overlay';
        overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };
        overlay.innerHTML = `
            <div class="web-preview-window">
                <div class="web-preview-titlebar">
                    <div class="titlebar-dots">
                        <button class="titlebar-dot dot-close" onclick="this.closest('.web-preview-overlay').remove()"></button>
                        <button class="titlebar-dot dot-minimize" onclick="this.closest('.web-preview-overlay').remove()"></button>
                        <button class="titlebar-dot dot-maximize" onclick="window.open('${toOriginal(displayUrl)}','_blank')"></button>
                    </div>
                    <div class="titlebar-url" id="previewUrlBar">${displayUrl}</div>
                    <div style="display:flex;align-items:center;gap:4px;">
                        ${hasBar ? `<div class="preview-links-bar">${emailBtn}${emailBtn && (socialBtns || websiteBtn) ? '<div style="width:1px;height:20px;background:#d5d5d5;margin:0 2px;"></div>' : ''}${socialBtns}${socialBtns && websiteBtn ? '<div style="width:1px;height:20px;background:#d5d5d5;margin:0 2px;"></div>' : ''}${websiteBtn}</div>` : ''}
                        <div class="titlebar-actions">
                            <button class="titlebar-btn" id="previewNewTabBtn" onclick="window.open('${toOriginal(displayUrl)}','_blank')" title="Open in new tab"><i class="fas fa-external-link-alt"></i></button>
                            <button class="titlebar-btn" onclick="this.closest('.web-preview-overlay').remove()" title="Close"><i class="fas fa-times"></i></button>
                        </div>
                    </div>
                </div>
                <iframe id="previewIframe" src="${iframeUrl}" sandbox="allow-same-origin allow-scripts allow-popups allow-forms"></iframe>
                <div class="iframe-fallback hidden" id="previewFallback" style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;gap:12px;color:var(--text-secondary);">
                    <i class="fas fa-globe" style="font-size:40px;color:var(--accent);"></i>
                    <p>This site can't be embedded</p>
                    <a href="${toOriginal(displayUrl)}" target="_blank" class="btn btn-primary" id="previewFallbackLink">Open in New Tab <i class="fas fa-external-link-alt"></i></a>
                </div>
            </div>
        `;
        document.body.appendChild(overlay);
    }

    switchPreviewUrl(btn, url) {
        const safeUrl = url.startsWith('http://') ? url.replace('http://', 'https://') : (url.startsWith('https://') ? url : 'https://' + url);
        const originalUrl = url.startsWith('http') ? url : 'https://' + url;

        document.querySelectorAll('.preview-link-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const iframe = document.getElementById('previewIframe');
        const fallback = document.getElementById('previewFallback');
        if (iframe) { iframe.src = safeUrl; iframe.style.display = ''; }
        if (fallback) fallback.classList.add('hidden');
        document.getElementById('previewUrlBar').textContent = url;
        document.getElementById('previewNewTabBtn').onclick = () => window.open(originalUrl, '_blank');
        const fallbackLink = document.getElementById('previewFallbackLink');
        if (fallbackLink) fallbackLink.href = originalUrl;
    }

    openLightbox(index) {
        if (!this.galleryPhotos || this.galleryPhotos.length === 0) return;
        this.lbIndex = index;
        const existing = document.querySelector('.gallery-lightbox');
        if (existing) existing.remove();

        const lb = document.createElement('div');
        lb.className = 'gallery-lightbox';
        lb.id = 'galleryLightbox';
        lb.onclick = (e) => { if (e.target === lb) lb.remove(); };

        const total = this.galleryPhotos.length;
        const thumbsHtml = total > 1 ? `<div class="lb-thumbstrip">${this.galleryPhotos.map((p, i) =>
            `<img class="lb-thumb ${i === index ? 'active' : ''}" src="${this.esc(p.thumb)}" onclick="event.stopPropagation();app.lbGoTo(${i})" onerror="this.style.display='none'">`
        ).join('')}</div>` : '';

        lb.innerHTML = `
            <button class="lb-close" onclick="event.stopPropagation();this.closest('.gallery-lightbox').remove()"><i class="fas fa-times"></i></button>
            ${total > 1 ? `<button class="lb-nav lb-prev" onclick="event.stopPropagation();app.lbPrev()"><i class="fas fa-chevron-left"></i></button>` : ''}
            <img id="lbMainImg" src="${this.esc(this.galleryPhotos[index].hd)}" alt="Photo">
            ${total > 1 ? `<button class="lb-nav lb-next" onclick="event.stopPropagation();app.lbNext()"><i class="fas fa-chevron-right"></i></button>` : ''}
            ${thumbsHtml}
            ${total > 1 ? `<div class="lb-counter"><span id="lbCounter">${index + 1}</span> / ${total}</div>` : ''}
        `;
        document.body.appendChild(lb);

        document.addEventListener('keydown', this._lbKeyHandler = (e) => {
            if (e.key === 'Escape') { lb.remove(); document.removeEventListener('keydown', this._lbKeyHandler); }
            if (e.key === 'ArrowLeft') this.lbPrev();
            if (e.key === 'ArrowRight') this.lbNext();
        });
    }

    lbGoTo(index) {
        if (!this.galleryPhotos) return;
        this.lbIndex = index;
        const img = document.getElementById('lbMainImg');
        const counter = document.getElementById('lbCounter');
        if (img) img.src = this.galleryPhotos[index].hd;
        if (counter) counter.textContent = index + 1;
        document.querySelectorAll('.lb-thumb').forEach((t, i) => t.classList.toggle('active', i === index));
    }

    lbPrev() {
        if (!this.galleryPhotos) return;
        this.lbGoTo(this.lbIndex <= 0 ? this.galleryPhotos.length - 1 : this.lbIndex - 1);
    }

    lbNext() {
        if (!this.galleryPhotos) return;
        this.lbGoTo(this.lbIndex >= this.galleryPhotos.length - 1 ? 0 : this.lbIndex + 1);
    }

    // UTILS

    esc(str) {
        if (!str) return '';
        const d = document.createElement('div');
        d.textContent = str;
        return d.innerHTML;
    }
}

document.addEventListener('DOMContentLoaded', () => { window.app = new LeadListsApp(); });

// Audit 2026-07-04: when the tab transitions hidden → visible and the
//_enrichLiveLoop was previously paused on a hidden tab, kick one immediate
// poll so the user sees a fresh progress value rather than waiting for the
// 5s paused loop to fire.
document.addEventListener('visibilitychange', () => {
    if (!document.hidden && window.app && window.app.enrichmentPollId) {
        window.app._enrichLiveLoop(window.app.enrichmentPollId);
    }
});

document.addEventListener('click', (e) => {
    const menu = document.getElementById('exportMenu');
    const btn = document.getElementById('exportMenuBtn');
    if (menu && !menu.contains(e.target) && !btn.contains(e.target)) {
        menu.classList.add('hidden');
    }
});
</script>
</body>
</html>
