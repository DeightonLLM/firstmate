<?php
/**
 * Unit tests for the pure render-time Lighthouse correction helper.
 *
 * This test runs on local fixture strings only. It does not load WordPress,
 * read the database, make HTTP requests, or write files.
 */

function check_fix( $label, $ok ) {
	printf( "%s %s\n", $ok ? 'PASS' : 'FAIL', $label );
	return $ok;
}

$helper = __DIR__ . '/../theme/stage-content-fixes.php';
if ( ! is_file( $helper ) ) {
	check_fix( 'render-time helper is present', false );
	exit( 1 );
}
require_once $helper;

if ( ! function_exists( 'core_distro_stage_lighthouse_content_fixes' ) ) {
	check_fix( 'render-time helper exposes its tested contract', false );
	exit( 1 );
}

$failures = 0;
$products = '<nav aria-label="Breadcrumb"><span>Home</span><span>Products</span></div>'
	. '<div class="grid">'
	. '<a href="/products/glass-vials/"></p><div class="cd-card">Glass Vials</div><p></a>'
	. '</div>'
	. '<a href="/contact/"><button class="btn-cd-primary" type="button" disabled="" aria-disabled="true">Request Quote</button></a>'
	. '<div class="media"><video poster="/images/automation-machine-v2.webp">'
	. '<source src="/automation-machine-video_93d11a5b.mp4" type="video/mp4">'
	. '<div class="absolute bottom-3 right-3">LIVE OPERATION</div></div>';
$fixed_products = core_distro_stage_lighthouse_content_fixes(
	$products,
	'products',
	'https://stage.example.test/wp-content/themes/core-distro-stage/assets/'
);
$failures += ! check_fix( 'actual wpautop product card stays inside one named link', false !== strpos( $fixed_products, '<a href="/products/glass-vials/"><div class="cd-card">Glass Vials</div></a>' ) );
$failures += ! check_fix( 'product card paragraph boundary is balanced', substr_count( $fixed_products, '<p' ) === substr_count( $fixed_products, '</p>' ) );

$leading_paragraph = '<p><a href="/products/glass-vials/"></p><div class="cd-card">Glass Vials</div><p></a>';
$fixed_leading_paragraph = core_distro_stage_lighthouse_content_fixes( $leading_paragraph, 'products', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'optional leading wpautop paragraph is removed without imbalance', false !== strpos( $fixed_leading_paragraph, '<a href="/products/glass-vials/"><div class="cd-card">Glass Vials</div></a>' ) && substr_count( $fixed_leading_paragraph, '<p' ) === substr_count( $fixed_leading_paragraph, '</p>' ) );
$failures += ! check_fix( 'nested disabled CTA button becomes one named navigational link', false !== strpos( $fixed_products, '<a href="/contact/" class="btn-cd-primary">Request Quote</a>' ) && false === strpos( $fixed_products, '<button' ) );
$failures += ! check_fix( 'missing product video source is removed', false === strpos( $fixed_products, 'automation-machine-video_93d11a5b.mp4' ) );
$failures += ! check_fix( 'unclosed product video is explicitly closed before overlay content', false !== strpos( $fixed_products, '</video><div class="absolute bottom-3 right-3">LIVE OPERATION</div>' ) );
$failures += ! check_fix( 'product poster is rewritten to the local staged asset', false !== strpos( $fixed_products, 'poster="https://stage.example.test/wp-content/themes/core-distro-stage/assets/automation-machine-v2.webp"' ) );
$failures += ! check_fix( 'breadcrumb nav receives its missing closing tag', 1 === substr_count( $fixed_products, '<nav' ) && 1 === substr_count( $fixed_products, '</nav>' ) );

$contact = '<h1>Contact</h1><h3>What to Expect</h3>'
	. '<div class="space-y-6"><a href="tel:+18338484257" class="contact-card"></p><div>Phone</div><p></a></div>'
	. '<textarea id="notes" disabled=""></textarea></textarea>'
	. '<span class="ml-auto" style="color:oklch(0.55 0.04 148)">Headquarters</span>';
$fixed_contact = core_distro_stage_lighthouse_content_fixes( $contact, 'contact', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'contact heading level is corrected without changing its wording', false !== strpos( $fixed_contact, '<h2>What to Expect</h2>' ) );
$failures += ! check_fix( 'contact card text stays inside its named phone link', false !== strpos( $fixed_contact, '<a href="tel:+18338484257" class="contact-card"><div>Phone</div></a>' ) );
$failures += ! check_fix( 'contact renderer emits no empty phone link after paragraph repair', ! preg_match( '/<a\b[^>]*>\s*<\/a>/i', $fixed_contact ) );
$failures += ! check_fix( 'contact low-contrast text color is corrected', false !== strpos( $fixed_contact, 'color:oklch(0.45 0.04 148)' ) );
$failures += ! check_fix( 'contact duplicate textarea closer is removed', 1 === substr_count( $fixed_contact, '</textarea>' ) );

$resources = '<div><span class="cd-inert-download" role="button">DOWNLOAD</a></div>';
$fixed_resources = core_distro_stage_lighthouse_content_fixes( $resources, 'resources', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'resources inert PDF closer is repaired', false !== strpos( $fixed_resources, 'DOWNLOAD</span>' ) && false === strpos( $fixed_resources, '</a>' ) );

$correct_span_with_following_cta = '<span class="cd-inert-download">DOWNLOAD</span><a href="/contact/">Contact Us</a>';
$fixed_correct_span = core_distro_stage_lighthouse_content_fixes( $correct_span_with_following_cta, 'resources', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'already-correct inert span leaves the following CTA close intact', $fixed_correct_span === $correct_span_with_following_cta );

$resource_source = file_get_contents( __DIR__ . '/../build/pages/resources.html' );
$fixed_resource_source = core_distro_stage_lighthouse_content_fixes( $resource_source, 'resources', 'https://stage.example.test/assets/' );
$failures += ! check_fix(
	'resources repair is idempotent on correct generated content and preserves its CTA',
	1 === preg_match( '~<a\\b[^>]*href="/contact/?"[^>]*>[^<]*Contact Us for Custom Docs[^<]*</a>~i', $fixed_resource_source )
		&& substr_count( $fixed_resource_source, '<a' ) === substr_count( $fixed_resource_source, '</a>' )
		&& substr_count( $fixed_resource_source, '<span' ) === substr_count( $fixed_resource_source, '</span>' )
);

foreach ( glob( __DIR__ . '/../build/pages/*.html' ) as $fragment_path ) {
	$slug      = basename( $fragment_path, '.html' );
	$fragment  = file_get_contents( $fragment_path );
	$rendered  = core_distro_stage_lighthouse_content_fixes( $fragment, $slug, 'https://stage.example.test/assets/' );
	$tags      = array( 'a', 'div', 'h1', 'h2', 'h3', 'h4', 'nav', 'p', 'span', 'textarea', 'video' );
	$balanced  = true;
	foreach ( $tags as $tag ) {
		if ( substr_count( $rendered, '<' . $tag ) !== substr_count( $rendered, '</' . $tag . '>' ) ) {
			$balanced = false;
			break;
		}
	}
	$anchors_preserved = substr_count( $fragment, '<a ' ) === substr_count( $rendered, '<a ' );
	$failures += ! check_fix( 'render helper preserves balanced ' . $slug . ' source fragment', $balanced && $anchors_preserved );
}

$blog = '<h1>Industry Insights</h1><h3>Stay Informed</h3>'
	. '<p class="text-xs" style="color:oklch(0.50 0.04 148)">No spam.</p>';
$fixed_blog = core_distro_stage_lighthouse_content_fixes( $blog, 'blog', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'blog section heading is sequential', false !== strpos( $fixed_blog, '<h2>Stay Informed</h2>' ) );
$failures += ! check_fix( 'blog helper text has the audited readable color', false !== strpos( $fixed_blog, 'color:oklch(0.70 0.04 148)' ) );

$resources = '<h1>Product Documentation</h1><h3>Vial Catalogue</h3>';
$fixed_resources = core_distro_stage_lighthouse_content_fixes( $resources, 'resources', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'resources heading level is sequential', false !== strpos( $fixed_resources, '<h2>Vial Catalogue</h2>' ) );

$register = '<p class="text-xs" style="color:oklch(0.55 0.04 148)">Preview note</p>';
$fixed_register = core_distro_stage_lighthouse_content_fixes( $register, 'register', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'register helper text has the audited readable color', false !== strpos( $fixed_register, 'color:oklch(0.45 0.04 148)' ) );

$other = '<h3>Unrelated route</h3><a href="/products/glass-vials/"></a>';
$unchanged = core_distro_stage_lighthouse_content_fixes( $other, 'about', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'unrelated route content is left unchanged', $unchanged === $other );

$front_settings = core_distro_stage_astra_localize_js( array( 'is_scroll_to_top' => true, 'keep' => 'value' ), true );
$failures += ! check_fix( 'homepage disables only Astra scroll-to-top', false === $front_settings['is_scroll_to_top'] && 'value' === $front_settings['keep'] );
$page_settings = core_distro_stage_astra_localize_js( array( 'is_scroll_to_top' => true ), false );
$failures += ! check_fix( 'other pages retain Astra scroll-to-top setting', true === $page_settings['is_scroll_to_top'] );

/*
 * Closed ARTICLE drawer keyboard-focus exclusion.
 *
 * The closed mobile drawer is an overlay that is visually hidden with
 * opacity:0;pointer-events:none but whose links stay in the tab order. The
 * homepage already carries the correct source pattern
 * (theme/public-homepage-body.html:107 -> `inert aria-hidden="true"`), so the
 * canonical page fragments must render the same exclusion rather than having
 * their drawer stripped. These assertions pin the exact behaviour: only the
 * closed drawer overlay div changes, and nothing else does.
 */
$closed_drawer_tag = '<div class="fixed inset-0 z-40 lg:hidden transition-all duration-300" style="opacity:0;pointer-events:none">';
$inert_drawer_tag  = '<div inert aria-hidden="true" class="fixed inset-0 z-40 lg:hidden transition-all duration-300" style="opacity:0;pointer-events:none">';

$drawer_page = $closed_drawer_tag
	. '<div class="absolute inset-0" style="background-color:oklch(0.18 0.065 148 / 0.98)"></div>'
	. '<div class="absolute top-0 right-0 w-72 h-full flex flex-col pt-24 px-8 gap-6"><a href="/"><span>Home</span></a></div>'
	. '</div>'
	. '<div class="container relative z-10"><nav aria-label="Breadcrumb" class="flex items-center gap-1.5 flex-wrap"><span><a href="/"><span>Home</span></a></span></nav>'
	. '<div class="mb-6"><div class="absolute inset-0 hex-pattern opacity-40"></div></div>'
	. '<h1>About</h1><p>Body copy stays exactly as authored.</p></div>';
$drawer_input_before = $drawer_page;

$fixed_drawer = core_distro_stage_lighthouse_content_fixes( $drawer_page, 'about', 'https://stage.example.test/assets/' );
$failures += ! check_fix( 'closed drawer overlay receives inert and aria-hidden', false !== strpos( $fixed_drawer, $inert_drawer_tag ) );

// Exact-once: the exclusion must not be stacked or duplicated.
$failures += ! check_fix(
	'drawer exclusion attributes are applied exactly once',
	1 === substr_count( $fixed_drawer, 'inert aria-hidden="true"' ) && 1 === substr_count( $fixed_drawer, 'aria-hidden="true"' ) && 1 === substr_count( $fixed_drawer, '<div inert' )
);

// The drawer is never stripped: its wrapper, inner panel and links survive.
$failures += ! check_fix(
	'closed drawer markup and links are preserved, not stripped',
	false !== strpos( $fixed_drawer, 'class="absolute top-0 right-0 w-72 h-full flex flex-col pt-24 px-8 gap-6"><a href="/"><span>Home</span></a>' )
		&& false !== strpos( $fixed_drawer, 'style="background-color:oklch(0.18 0.065 148 / 0.98)"' )
);

// The header NAV is a separate element and must not receive the exclusion.
$failures += ! check_fix(
	'header breadcrumb nav is left unchanged by the drawer fix',
	false !== strpos( $fixed_drawer, '<nav aria-label="Breadcrumb" class="flex items-center gap-1.5 flex-wrap">' )
		&& false === strpos( $fixed_drawer, '<nav inert' )
);

// Unrelated overlays must not receive the exclusion.
$failures += ! check_fix(
	'unrelated overlay elements are left unchanged',
	false !== strpos( $fixed_drawer, '<div class="absolute inset-0 hex-pattern opacity-40"></div>' )
		&& 1 === substr_count( $fixed_drawer, '<div class="absolute inset-0 hex-pattern opacity-40"></div>' )
		&& false === strpos( $fixed_drawer, '<div inert aria-hidden="true" class="absolute' )
);

// Body copy is untouched.
$failures += ! check_fix(
	'drawer fix preserves authored body copy verbatim',
	false !== strpos( $fixed_drawer, '<h1>About</h1><p>Body copy stays exactly as authored.</p>' )
);

// The caller's input string is never mutated in place.
$failures += ! check_fix( 'drawer fix does not mutate its input string', $drawer_page === $drawer_input_before );

// Idempotency: re-running must not duplicate the attributes or alter output.
$twice = core_distro_stage_lighthouse_content_fixes( $fixed_drawer, 'about', 'https://stage.example.test/assets/' );
$failures += ! check_fix(
	'drawer exclusion is idempotent across repeated render passes',
	$twice === $fixed_drawer && 1 === substr_count( $twice, 'inert aria-hidden="true"' )
);

// An open/active panel must NOT be excluded.
$open_drawer = '<div class="fixed inset-0 z-40 lg:hidden transition-all duration-300" style="opacity:1;pointer-events:auto"><a href="/"><span>Home</span></a></div>';
$fixed_open  = core_distro_stage_lighthouse_content_fixes( $open_drawer, 'about', 'https://stage.example.test/assets/' );
$failures += ! check_fix(
	'open drawer panel receives no focus exclusion',
	$fixed_open === $open_drawer && false === strpos( $fixed_open, 'inert' )
);

// Canonical routes: every stored fragment carries the exclusion exactly once.
$canonical_slugs = array(
	'about', 'aluminum-seals', 'blog', 'compliance', 'contact', 'faq',
	'glass-vials', 'products', 'register', 'resources', 'rubber-stoppers',
);
// Routes with no other render-time correction, so the only permitted change is
// the drawer exclusion itself.
$drawer_only_slugs = array( 'about', 'aluminum-seals', 'compliance', 'faq', 'glass-vials', 'rubber-stoppers' );
foreach ( $canonical_slugs as $canonical_slug ) {
	$canonical_fragment = file_get_contents( __DIR__ . '/../build/pages/' . $canonical_slug . '.html' );
	$canonical_rendered = core_distro_stage_lighthouse_content_fixes( $canonical_fragment, $canonical_slug, 'https://stage.example.test/assets/' );
	$excluded_once      = 1 === substr_count( $canonical_rendered, '<div inert aria-hidden="true" class="fixed inset-0 z-40 lg:hidden transition-all duration-300"' )
		&& 1 === substr_count( $canonical_rendered, 'inert aria-hidden="true"' );
	$failures += ! check_fix( 'canonical ' . $canonical_slug . ' fragment excludes its closed drawer exactly once', $excluded_once );

	if ( in_array( $canonical_slug, $drawer_only_slugs, true ) ) {
		$stripped = str_replace( '<div inert aria-hidden="true" class=', '<div class=', $canonical_rendered );
		$failures += ! check_fix(
			'canonical ' . $canonical_slug . ' differs from stored content only by the drawer exclusion',
			$stripped === $canonical_fragment
		);
	} else {
		$failures += ! check_fix(
			'canonical ' . $canonical_slug . ' keeps its stored anchor and heading content',
			substr_count( $canonical_fragment, '<a ' ) === substr_count( $canonical_rendered, '<a ' )
				&& substr_count( $canonical_fragment, '<h1' ) === substr_count( $canonical_rendered, '<h1' )
		);
	}
}

// Protected duplicate records: nine seed-owned pages still published and
// routable (IDs 24,25,26,35,36,37,46,47,48) carry the same product fragment.
// They are under an explicit database hold, so this new transform must never
// reach them.
$protected_duplicates = array(
	'glass-vials-2' => 'glass-vials',
	'rubber-stoppers-2' => 'rubber-stoppers',
	'aluminum-seals-2' => 'aluminum-seals',
	'glass-vials-3' => 'glass-vials',
	'rubber-stoppers-3' => 'rubber-stoppers',
	'aluminum-seals-3' => 'aluminum-seals',
	'glass-vials-4' => 'glass-vials',
	'rubber-stoppers-4' => 'rubber-stoppers',
	'aluminum-seals-4' => 'aluminum-seals',
);
foreach ( $protected_duplicates as $duplicate_slug => $source_slug ) {
	$duplicate_fragment = file_get_contents( __DIR__ . '/../build/pages/' . $source_slug . '.html' );
	$duplicate_rendered = core_distro_stage_lighthouse_content_fixes( $duplicate_fragment, $duplicate_slug, 'https://stage.example.test/assets/' );
	$failures += ! check_fix(
		'protected duplicate route ' . $duplicate_slug . ' receives no new drawer transform',
		false === strpos( $duplicate_rendered, 'inert' ) && false === strpos( $duplicate_rendered, 'aria-hidden' )
	);
}

/*
 * Matcher precision: the exclusion targets the closed mobile DRAWER overlay,
 * not any fixed hidden element. Both cases below carry the same closed-state
 * style, so a matcher keyed only on "fixed + hidden" would bind to them.
 */
$preceding_hidden_overlay = '<div class="fixed bottom-4 right-4 z-50" style="opacity:0;pointer-events:none"><a href="/terms"><span>Terms</span></a></div>';
$fixed_with_preceding    = core_distro_stage_lighthouse_content_fixes( $preceding_hidden_overlay . $drawer_page, 'about', 'https://stage.example.test/assets/' );
$failures += ! check_fix(
	'unrelated hidden fixed overlay is not excluded in place of the drawer',
	false === strpos( $fixed_with_preceding, '<div inert aria-hidden="true" class="fixed bottom-4 right-4 z-50"' )
		&& false !== strpos( $fixed_with_preceding, $inert_drawer_tag )
);
$failures += ! check_fix(
	'substring class match does not trigger the drawer exclusion',
	core_distro_stage_lighthouse_content_fixes(
		'<div class="not-fixed-overlay" style="opacity:0;pointer-events:none"></div>' . $drawer_page,
		'about',
		'https://stage.example.test/assets/'
	) === '<div class="not-fixed-overlay" style="opacity:0;pointer-events:none"></div>' . $fixed_drawer
);

printf( "\nSUMMARY failures=%d\n", $failures );
exit( $failures ? 1 : 0 );
