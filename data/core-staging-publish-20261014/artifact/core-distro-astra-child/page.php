<?php
/**
 * Staging template for the eleven non-home routes of the private Core-Distro
 * site.
 *
 * The homepage is NOT served here: theme/front-page.php keeps rendering the
 * preserved public snapshot unchanged. Every other route renders as a real,
 * editable WordPress page — this template only supplies the document shell
 * (head, preview notice, header, footer) and prints the page's own content.
 *
 * Safety properties enforced here:
 *   - noindex,nofollow on every page, canonicalised to the private preview
 *   - all navigation is local; no production URL is emitted
 *   - no chatbot/widget script of any kind is loaded
 *   - newsletter, contact and registration controls stay inert (see
 *     tools/extract-route-content.py)
 *
 * @package core-distro-stage
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$cd_assets      = esc_url( get_stylesheet_directory_uri() . '/assets/' );
$cd_preview_url = esc_url( home_url( '/' ) );
$cd_route_slug  = sanitize_html_class( (string) get_post_field( 'post_name', get_the_ID() ) );
$cd_canonical   = esc_url( get_permalink() );
$cd_doc_title   = (string) get_post_meta( get_the_ID(), '_cd_document_title', true );
$cd_description = (string) get_post_meta( get_the_ID(), '_cd_meta_description', true );
if ( '' === $cd_description ) {
	$cd_description = 'Private staging preview of the Core Distro pharmaceutical supply site.';
}
?><!doctype html>
<html lang="en">
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="description" content="<?php echo esc_attr( $cd_description ); ?>">
	<meta name="robots" content="noindex,nofollow">
	<meta property="og:title" content="<?php echo esc_attr( $cd_doc_title ); ?>">
	<meta property="og:description" content="<?php echo esc_attr( $cd_description ); ?>">
	<meta property="og:url" content="<?php echo $cd_preview_url; ?>">
	<meta property="og:site_name" content="Core Distro">
	<meta property="og:type" content="website">
	<link rel="canonical" href="<?php echo $cd_canonical; ?>">
	<link rel="icon" href="<?php echo $cd_assets; ?>favicon.ico">
	<link rel="preconnect" href="https://fonts.googleapis.com" referrerpolicy="no-referrer">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" referrerpolicy="no-referrer">
	<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@400;600;700;800&amp;family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&amp;family=JetBrains+Mono:wght@400;500&amp;display=swap" referrerpolicy="no-referrer">
	<?php wp_head(); ?>
</head>
<body <?php body_class( 'cd-stage cd-stage-page cd-route-' . $cd_route_slug ); ?>>
<?php wp_body_open(); ?>

<?php // Audit M2: no route had a skip link, so every page load required tabbing past the notice, logo, nav, phone link, quote button and menu toggle before reaching content. First focusable element in the document; clipped until focused by .cd-skip-link in assets/stage-compat.css, so normal rendering is unchanged. Target is the <main id="cd-main"> below. ?>
<a class="cd-skip-link" href="#cd-main">Skip to main content</a>

<p class="cd-preview-notice" role="note">
	<strong>Private staging preview</strong> &mdash; not indexed, forms are disabled and nothing you type is sent or stored.
</p>

<div id="cd-sticky-quote-bar" class="sticky-quote-bar hidden" aria-hidden="true">
	<div class="container flex items-center justify-between">
		<div class="flex items-center gap-3">
			<span class="w-2 h-2 rounded-full animate-pulse" style="background-color:oklch(0.78 0.22 148)"></span>
			<span class="font-display font-bold text-white text-sm hidden sm:inline" style="letter-spacing:0.05em">CORE DISTRO</span>
			<span class="text-xs hidden md:inline" style="color:oklch(0.65 0.04 148)">Pharmaceutical Supply Solutions for 503A &amp; 503B</span>
		</div>
		<div class="flex items-center gap-3">
			<a href="tel:+18338484257" class="text-xs font-mono-spec hidden sm:inline" style="color:oklch(0.78 0.22 148);letter-spacing:0.08em">(833) 84-VIALS / (833) 848-4257</a>
			<a href="<?php echo esc_url( home_url( '/contact/' ) ); ?>" class="flex items-center gap-2 px-4 py-2 rounded-sm font-display font-bold text-xs uppercase tracking-widest transition-all duration-160" style="background-color:oklch(0.78 0.22 148);color:oklch(0.12 0.05 148);letter-spacing:0.12em">Request a Quote</a>
		</div>
	</div>
</div>

<?php get_template_part( 'partials/cd-page-header' ); ?>

<main id="cd-main" class="cd-page-content" style="background-color:oklch(0.97 0.005 148)">
	<?php
	while ( have_posts() ) :
		the_post();
		?>
		<article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
			<?php the_content(); ?>
		</article>
		<?php
	endwhile;
	?>
</main>

<?php get_template_part( 'partials/cd-page-footer' ); ?>

<?php wp_footer(); ?>
</body>
</html>