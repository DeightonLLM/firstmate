<?php
/**
 * Stub for includes/auth.php
 * Provides isLoggedIn() for benchmark harness.
 */
if (!function_exists('isLoggedIn')) {
    function isLoggedIn(): bool {
        return isset($_SESSION['user_id']) && $_SESSION['user_id'] > 0;
    }
}
