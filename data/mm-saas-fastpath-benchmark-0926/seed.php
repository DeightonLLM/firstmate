<?php
/**
 * Music Metrics benchmark data seeder
 * Seeds ~50,000 synthetic lead_list_items for performance testing.
 * Run: php seed.php
 */

// PDO connection to MariaDB (use host IP for docker networking)
$dbHost = getenv('DB_HOST') ?: '172.17.0.3';
$dsn = "mysql:host={$dbHost};port=3306;dbname=musicmetrics;charset=utf8mb4";
$pdo = new PDO($dsn, 'root', 'benchrootpass', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
]);

echo "Connected to MariaDB.\n";

// Create test user
$pdo->exec("DELETE FROM users WHERE email = 'benchmark@test.local'");
$pdo->exec("INSERT INTO users (id, email, credits, shared_for_credits) VALUES (1, 'benchmark@test.local', 500, 0)
    ON DUPLICATE KEY UPDATE id=id");
$userId = 1;
echo "User created.\n";

// Create 5 lead lists
$pdo->exec("DELETE FROM lead_list_items WHERE user_id = $userId");
$pdo->exec("DELETE FROM lead_lists WHERE user_id = $userId");

$categories = [
    ['Doctors', 'Medical', 'Medical Clinics'],
    ['Law Firms', 'Legal', 'Law Firms'],
    ['Accounting Firms', 'Finance', 'Accounting Firms'],
    ['Gas Stations', 'Automotive', 'Gas Stations'],
    ['Fire Departments', 'Emergency', 'Fire Departments'],
];
$states = ['CA','TX','FL','NY','IL','PA','OH','GA','NC','MI'];
$cities = ['Los Angeles','Houston','Miami','New York','Chicago','Philadelphia','Columbus','Atlanta','Charlotte','Detroit'];
$statuses = ['cold','warm','hot'];
$pipelineStages = ['new','contacted','engaged','no_response','client'];

$listIds = [];
foreach ($categories as $i => $cat) {
    $stmt = $pdo->prepare("INSERT INTO lead_lists (user_id, name, description, category_group, category) VALUES (?, ?, ?, ?, ?)");
    $stmt->execute([$userId, $cat[0], $cat[2] . ' - Benchmark Data', $cat[1], $cat[0]]);
    $listIds[] = $pdo->lastInsertId();
}
echo "Created " . count($listIds) . " lead lists.\n";

// Seed lead_list_searches (10 per list)
foreach ($listIds as $listId) {
    for ($s = 0; $s < 10; $s++) {
        $si = $s % count($states);
        $ci = $s % count($cities);
        $stmt = $pdo->prepare("INSERT INTO lead_list_searches (list_id, user_id, search_query, state_name, city, results_count) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->execute([$listId, $userId, $categories[0][0], $states[$si], $cities[$ci], rand(50, 500)]);
    }
}
echo "Created lead_list_searches.\n";

// Seed ~50,000 lead_list_items in batches of 1000
$targetRows = 50000;
$batchSize = 1000;
$inserted = 0;

echo "Seeding $targetRows lead_list_items...\n";

while ($inserted < $targetRows) {
    $batch = min($batchSize, $targetRows - $inserted);
    $values = [];
    $params = [];
    for ($i = 0; $i < $batch; $i++) {
        $listId = $listIds[array_rand($listIds)];
        $state = $states[array_rand($states)];
        $city = $cities[array_rand($cities)];
        $status = $statuses[array_rand($statuses)];
        $pipeline = $pipelineStages[array_rand($pipelineStages)];
        $hasEmail = rand(0, 1);
        $hasPhone = rand(0, 1);
        $hasWebsite = rand(0, 1);
        $hasSocials = rand(0, 1);
        $rating = (rand(0, 100) / 20); // 0-5 in 0.05 increments
        $visitedWebsite = rand(0, 1);
        $reachedOut = rand(0, 1);
        $enrichStatus = rand(0, 2) === 0 ? 'completed' : null;
        $leadScore = rand(0, 100);
        $values[] = "(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
        $params = array_merge($params, [
            $listId, $userId,
            'Biz-' . ($inserted + $i + 1),
            $city . ' ' . $state . ' Business ' . ($inserted + $i + 1),
            "$i $city St, $state",
            $city, $state,
            rand(1000000000, 9999999999),
            "https://example{$inserted}{$i}.com",
            $rating, rand(0, 500),
            $status, $visitedWebsite, rand(0,1), $reachedOut,
            $hasEmail, $hasPhone, $hasWebsite, $hasSocials,
            $pipeline, $leadScore, $enrichStatus
        ]);
    }

    $sql = "INSERT INTO lead_list_items
        (list_id, user_id, business_id, business_name, address, city, state, phone, website,
         rating, review_count, status, visited_website, visited_social, reached_out,
         has_email, has_phone, has_website, has_socials, pipeline_stage, lead_score, enrichment_status)
        VALUES " . implode(',', $values) . "
        ON DUPLICATE KEY UPDATE id=id";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $inserted += $batch;
    echo sprintf("  Inserted %d / %d rows\n", $inserted, $targetRows);
}

// Backfill has_email/has_socials flags properly
$pdo->exec("UPDATE lead_list_items SET has_email = 1 WHERE emails IS NOT NULL AND JSON_LENGTH(COALESCE(emails, '[]')) > 0");
$pdo->exec("UPDATE lead_list_items SET has_socials = 1 WHERE social_media_links IS NOT NULL AND JSON_LENGTH(COALESCE(social_media_links, '[]')) > 0");

// Count rows
$count = $pdo->query("SELECT COUNT(*) FROM lead_list_items")->fetchColumn();
echo "Total lead_list_items: $count\n";
echo "Seeding complete.\n";
