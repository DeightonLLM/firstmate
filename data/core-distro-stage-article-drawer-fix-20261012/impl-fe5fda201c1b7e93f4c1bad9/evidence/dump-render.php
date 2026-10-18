<?php
/**
 * Evidence-only renderer dumper. Runs the named helper in its own process and
 * prints its rendered output for one route/fragment pair, so the original and
 * the modified helper can be diffed byte-for-byte.
 *
 * This is NOT a changed deliverable file. It exists only to prove that the nine
 * held duplicate routes receive no new transform.
 *
 * usage: php dump-render.php <helper.php> <fragment.html> <route>
 */
$helper   = $argv[1];
$fragment = $argv[2];
$route    = $argv[3];

require_once $helper;

echo core_distro_stage_lighthouse_content_fixes(
	file_get_contents( $fragment ),
	$route,
	'https://stage.example.test/assets/'
);