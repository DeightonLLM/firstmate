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

printf( "\nSUMMARY failures=%d\n", $failures );
exit( $failures ? 1 : 0 );
