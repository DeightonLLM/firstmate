<?php
/**
 * Staging-only shell for the current public homepage snapshot.
 * Public copy and markup are preserved; scripts, forms, links, and assets are locally constrained.
 */
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

$assets = esc_url( get_stylesheet_directory_uri() . '/assets/' );
$preview_url = esc_url( home_url( '/' ) );
$public_markup = file_get_contents( __DIR__ . '/public-homepage-body.html' );
if ( false === $public_markup ) {
    wp_die( 'The private staging homepage snapshot is missing.' );
}
$public_markup = str_replace( '__CD_STAGE_ASSET__/', $assets, $public_markup );
?><!doctype html>
<html lang="en">
<head>
  <meta charset="<?php bloginfo( 'charset' ); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Core Distro is a premier distributor of pharmaceutical supplies for 503A and 503B compounding pharmacies — sterile glass vials, stoppers, seals, and automated fill-finish equipment.">
  <meta name="robots" content="noindex,nofollow">
  <meta property="og:title" content="Core Distro | Pharmaceutical Supply Distribution">
  <meta property="og:description" content="Premier distributor of pharmaceutical supplies for 503A and 503B compounding pharmacies. ISO-compliant glass vials, rubber stoppers, aluminum seals, and fill-finish equipment.">
  <meta property="og:url" content="<?php echo $preview_url; ?>">
  <meta property="og:site_name" content="Core Distro">
  <link rel="canonical" href="<?php echo $preview_url; ?>">
  <link rel="icon" href="<?php echo $assets; ?>favicon.ico">
  <link rel="preconnect" href="https://fonts.googleapis.com" referrerpolicy="no-referrer">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" referrerpolicy="no-referrer">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@400;600;700;800&amp;family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&amp;family=JetBrains+Mono:wght@400;500&amp;display=swap" referrerpolicy="no-referrer">
  <?php wp_head(); ?>
</head>
<body <?php body_class( 'cd-stage cd-stage-front' ); ?>>
<?php wp_body_open(); ?>

<?php // Same notice the eleven page-template routes print; see theme/page.php. ?>
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
      <?php // One interactive element only: the button-in-anchor nesting is invalid and ambiguous for keyboard and screen-reader users. Same classes/style as page.php:68. ?>
      <a href="#contact" class="flex items-center gap-2 px-4 py-2 rounded-sm font-display font-bold text-xs uppercase tracking-widest transition-all duration-160" style="background-color:oklch(0.78 0.22 148);color:oklch(0.12 0.05 148);letter-spacing:0.12em">Request a Quote<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14"></path><path d="m12 5 7 7-7 7"></path></svg></a>
    </div>
  </div>
</div>
<?php // This is a sanitized, reviewed public snapshot with local asset placeholders only. ?>
<?php echo $public_markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
<?php wp_footer(); ?>
</body>
</html>
