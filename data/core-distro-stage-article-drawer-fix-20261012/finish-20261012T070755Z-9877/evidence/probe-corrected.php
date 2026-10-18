<?php
/**
 * EVIDENCE HELPER - NOT APPLIED TO THE PROJECT.
 * Independent behavioural probe of core_distro_stage_lighthouse_content_fixes().
 * Verifies idempotency, unchanged input, canonical 11 fixtures, header /
 * unrelated / open panel isolation, protected-duplicate NEW-transform exclusion,
 * and probes how broad the saved drawer matcher really is.
 */
require __DIR__ . '/../corrected/theme/stage-content-fixes.php';

$AB  = 'https://stage.example.test/assets/';
$out = array();
$ok  = 0; $bad = 0;
function rec( $name, $pass, $detail = '' ) {
	global $out, $ok, $bad;
	$pass ? $ok++ : $bad++;
	$out[] = ( $pass ? 'PASS ' : 'FAIL ' ) . $name . ( '' !== $detail ? ' :: ' . $detail : '' );
}

$DRAWER_OPEN  = '<div class="fixed inset-0 z-40 lg:hidden transition-all duration-300" style="opacity:0;pointer-events:none">';
$DRAWER_INERT = '<div inert aria-hidden="true" class="fixed inset-0 z-40 lg:hidden transition-all duration-300" style="opacity:0;pointer-events:none">';

$page = $DRAWER_OPEN
	. '<div class="absolute inset-0" style="background-color:oklch(0.18 0.065 148 / 0.98)"></div>'
	. '<div class="absolute top-0 right-0 w-72 h-full flex flex-col pt-24 px-8 gap-6"><a href="/"><span>Home</span></a></div></div>'
	. '<div class="container relative z-10"><nav aria-label="Breadcrumb" class="flex items-center gap-1.5 flex-wrap"><span><a href="/"><span>Home</span></a></span></nav>'
	. '<h1>About</h1><p>Body copy.</p></div>';

// ---- unchanged input -------------------------------------------------
$before = $page;
$r1 = core_distro_stage_lighthouse_content_fixes( $page, 'about', $AB );
rec( 'input string not mutated in place', $page === $before, 'strlen before=' . strlen( $before ) . ' after=' . strlen( $page ) );

// ---- primary fix -----------------------------------------------------
rec( 'closed drawer receives inert + aria-hidden', false !== strpos( $r1, $DRAWER_INERT ) );
rec( 'exclusion applied exactly once',
	1 === substr_count( $r1, 'inert aria-hidden="true"' ) && 1 === substr_count( $r1, '<div inert' ) );
rec( 'drawer panel + links preserved, not stripped',
	false !== strpos( $r1, 'class="absolute top-0 right-0 w-72 h-full flex flex-col pt-24 px-8 gap-6"><a href="/"><span>Home</span></a>' )
	&& false !== strpos( $r1, 'background-color:oklch(0.18 0.065 148 / 0.98)' ) );
rec( 'header breadcrumb nav untouched', false !== strpos( $r1, '<nav aria-label="Breadcrumb" class="flex items-center gap-1.5 flex-wrap">' ) && false === strpos( $r1, '<nav inert' ) );
rec( 'body copy verbatim', false !== strpos( $r1, '<h1>About</h1><p>Body copy.</p>' ) );

// ---- idempotency (3 passes) -----------------------------------------
$r2 = core_distro_stage_lighthouse_content_fixes( $r1, 'about', $AB );
$r3 = core_distro_stage_lighthouse_content_fixes( $r2, 'about', $AB );
rec( 'idempotent across 3 render passes',
	$r1 === $r2 && $r2 === $r3 && 1 === substr_count( $r3, 'inert aria-hidden="true"' ) );

// ---- open panel ------------------------------------------------------
$open = '<div class="fixed inset-0 z-40 lg:hidden transition-all duration-300" style="opacity:1;pointer-events:auto"><a href="/"><span>Home</span></a></div>';
$ro  = core_distro_stage_lighthouse_content_fixes( $open, 'about', $AB );
rec( 'open panel receives no exclusion', $ro === $open && false === strpos( $ro, 'inert' ) );

// ---- unrelated hidden overlay ---------------------------------------
$unrel = '<div class="absolute inset-0 hex-pattern opacity-40"></div>' . $page;
$ru = core_distro_stage_lighthouse_content_fixes( $unrel, 'about', $AB );
rec( 'unrelated overlay excluded? (expect NO)',
	false === strpos( $ru, '<div inert aria-hidden="true" class="absolute' ) && 1 === substr_count( $ru, 'hex-pattern opacity-40' ) );

// ---- canonical 11 fixtures ------------------------------------------
$slugs = array( 'about','aluminum-seals','blog','compliance','contact','faq','glass-vials','products','register','resources','rubber-stoppers' );
$canon_detail = array();
foreach ( $slugs as $s ) {
	$frag = file_get_contents( __DIR__ . '/../corrected/build/pages/' . $s . '.html' );
	$ren  = core_distro_stage_lighthouse_content_fixes( $frag, $s, $AB );
	$hit  = 1 === substr_count( $ren, '<div inert aria-hidden="true" class="fixed inset-0 z-40 lg:hidden transition-all duration-300"' )
		&& 1 === substr_count( $ren, 'inert aria-hidden="true"' );
	rec( 'canonical ' . $s . ' excludes closed drawer exactly once', $hit );
	$revert = str_replace( '<div inert aria-hidden="true" class=', '<div class=', $ren );
	$canon_detail[] = $s . ':revert_clean=' . ( $revert === $frag ? 'yes' : 'no(other-fixes)' );
}
rec( 'canonical 11 count verified', count( $slugs ) === 11, implode( ' ', $canon_detail ) );

// ---- protected duplicates: NO NEW transform --------------------------
$dups = array( 'glass-vials-2','rubber-stoppers-2','aluminum-seals-2','glass-vials-3','rubber-stoppers-3','aluminum-seals-3','glass-vials-4','rubber-stoppers-4','aluminum-seals-4' );
$src  = array( 'glass-vials','rubber-stoppers','aluminum-seals' );
foreach ( $dups as $i => $d ) {
	$frag = file_get_contents( __DIR__ . '/../corrected/build/pages/' . $src[ $i % 3 ] . '.html' );
	$ren  = core_distro_stage_lighthouse_content_fixes( $frag, $d, $AB );
	rec( 'protected duplicate ' . $d . ' gets NO new drawer transform',
		false === strpos( $ren, 'inert' ) && false === strpos( $ren, 'aria-hidden' ) );
}

// ---- MATCHER BREADTH PROBES (informational, then decided) ----------
echo "=== BEHAVIOUR VERDICT ===\n";
echo implode( "\n", $out ) . "\n";
echo "SUMMARY pass=$ok fail=$bad\n";

// B1: a different fixed hidden overlay that appears BEFORE the drawer.
$b1 = '<div class="fixed bottom-4 right-4 z-50" style="opacity:0;pointer-events:none"><a href="/terms"><span>Terms</span></a></div>' . $page;
$r_b1 = core_distro_stage_lighthouse_content_fixes( $b1, 'about', $AB );
echo "\n=== BREADTH PROBE B1: unrelated hidden 'fixed' overlay BEFORE the drawer ===\n";
echo 'banner_excluded=' . ( false !== strpos( $r_b1, '<div inert aria-hidden="true" class="fixed bottom-4 right-4 z-50"' ) ? 'YES' : 'no' ) . "\n";
echo 'drawer_excluded=' . ( false !== strpos( $r_b1, $DRAWER_INERT ) ? 'YES' : 'NO' ) . "\n";

// B2: class token merely CONTAINS the substring "fixed".
$b2 = '<div class="not-fixed-overlay" style="opacity:0;pointer-events:none"></div>' . $page;
$r_b2 = core_distro_stage_lighthouse_content_fixes( $b2, 'about', $AB );
echo "\n=== BREADTH PROBE B2: class token containing 'fixed' as a substring ===\n";
echo 'substring_class_excluded=' . ( false !== strpos( $r_b2, '<div inert aria-hidden="true" class="not-fixed-overlay"' ) ? 'YES' : 'no' ) . "\n";
echo 'drawer_excluded=' . ( false !== strpos( $r_b2, $DRAWER_INERT ) ? 'YES' : 'NO' ) . "\n";

// B3: multi-property style carrying the hidden pair.
$b3 = '<div class="fixed top-0" style="z-index:9;opacity:0;pointer-events:none;color:red"></div>' . $page;
$r_b3 = core_distro_stage_lighthouse_content_fixes( $b3, 'about', $AB );
echo "\n=== BREADTH PROBE B3: hidden pair inside a multi-property style ===\n";
echo 'multiprop_excluded=' . ( false !== strpos( $r_b3, '<div inert aria-hidden="true" class="fixed top-0"' ) ? 'YES' : 'no' ) . "\n";
echo 'drawer_excluded=' . ( false !== strpos( $r_b3, $DRAWER_INERT ) ? 'YES' : 'NO' ) . "\n";

// B4: does the shipped change reach any NON-canonical route at all?
$b4 = core_distro_stage_lighthouse_content_fixes( $DRAWER_OPEN . '</div>', 'home', $AB );
echo "\n=== BREADTH PROBE B4: non-canonical route ===\n";
echo 'non_canonical_route_excluded=' . ( false !== strpos( $b4, 'inert' ) ? 'YES' : 'no' ) . "\n";

exit( $bad ? 1 : 0 );