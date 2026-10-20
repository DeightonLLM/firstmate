<?php
/**
 * Shared staging page footer for the eleven non-home routes.
 *
 * Mirrors the public footer's four columns, quick links, contact details,
 * certification badges and baseline line. Every href is a local staging route.
 *
 * @package core-distro-stage
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$cd_assets = esc_url( get_stylesheet_directory_uri() . '/assets/' );
?>
<footer class="hex-pattern" style="background-color:oklch(0.14 0.055 148);color:oklch(0.88 0.04 148)">
	<div class="container py-16">
		<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-10">
			<div>
				<div class="flex items-center gap-3 mb-5">
					<img src="<?php echo $cd_assets; ?>core-distro-logo.webp" alt="Core Distro" class="h-9 w-auto">
					<span class="font-display font-bold text-lg tracking-widest text-white" style="letter-spacing:0.12em">CORE DISTRO</span>
				</div>
				<p class="text-sm leading-relaxed" style="color:oklch(0.72 0.03 148)">
					Direct Distribution Infrastructure for 503A and 503B compounding pharmacies.
				</p>
			</div>

			<div>
				<h2 class="font-display font-bold text-sm tracking-widest uppercase mb-4" style="color:oklch(0.78 0.22 148);letter-spacing:0.12em">Products</h2>
				<ul class="space-y-2 text-sm">
					<li><a href="<?php echo esc_url( home_url( '/products/glass-vials/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Glass Vials</a></li>
					<li><a href="<?php echo esc_url( home_url( '/products/rubber-stoppers/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Rubber Stoppers</a></li>
					<li><a href="<?php echo esc_url( home_url( '/products/aluminum-seals/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Aluminum Seals</a></li>
					<li><a href="<?php echo esc_url( home_url( '/products/' ) ); ?>#automation" style="color:oklch(0.72 0.03 148)">Automation Equipment</a></li>
				</ul>
			</div>

			<div>
				<h2 class="font-display font-bold text-sm tracking-widest uppercase mb-4" style="color:oklch(0.78 0.22 148);letter-spacing:0.12em">Company</h2>
				<ul class="space-y-2 text-sm">
					<li><a href="<?php echo esc_url( home_url( '/about/' ) ); ?>" style="color:oklch(0.72 0.03 148)">About Core Distro</a></li>
					<li><a href="<?php echo esc_url( home_url( '/compliance/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Compliance &amp; Quality</a></li>
					<li><a href="<?php echo esc_url( home_url( '/about/' ) ); ?>#global" style="color:oklch(0.72 0.03 148)">Global Footprint</a></li>
					<li><a href="<?php echo esc_url( home_url( '/about/' ) ); ?>#process" style="color:oklch(0.72 0.03 148)">How We Work</a></li>
					<li><a href="<?php echo esc_url( home_url( '/resources/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Resources</a></li>
					<li><a href="<?php echo esc_url( home_url( '/blog/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Blog</a></li>
					<li><a href="<?php echo esc_url( home_url( '/faq/' ) ); ?>" style="color:oklch(0.72 0.03 148)">FAQ</a></li>
					<li><a href="<?php echo esc_url( home_url( '/register/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Client Registration</a></li>
				</ul>
			</div>

			<div>
				<h2 class="font-display font-bold text-sm tracking-widest uppercase mb-4" style="color:oklch(0.78 0.22 148);letter-spacing:0.12em">Contact</h2>
				<ul class="space-y-2 text-sm">
					<li><a href="tel:+18338484257" class="font-mono-spec text-xs" style="color:oklch(0.72 0.03 148)">(833) 84-VIALS / (833) 848-4257</a></li>
					<li><a href="mailto:info@core-distro.com" class="font-mono-spec text-xs" style="color:oklch(0.72 0.03 148)">info@core-distro.com</a></li>
					<li><a href="<?php echo esc_url( home_url( '/contact/' ) ); ?>" style="color:oklch(0.72 0.03 148)">Contact Us</a></li>
				</ul>
			</div>
		</div>

		<div class="flex flex-wrap gap-3 mt-12 pt-8" style="border-top:1px solid oklch(0.30 0.07 148 / 0.6)">
			<span class="px-3 py-1 rounded-sm font-mono-spec text-xs" style="border:1px solid oklch(0.78 0.22 148 / 0.4);color:oklch(0.78 0.22 148)">FDA-Registered Importer</span>
			<span class="px-3 py-1 rounded-sm font-mono-spec text-xs" style="border:1px solid oklch(0.78 0.22 148 / 0.4);color:oklch(0.78 0.22 148)">ISO 8362-1 Vials</span>
			<span class="px-3 py-1 rounded-sm font-mono-spec text-xs" style="border:1px solid oklch(0.78 0.22 148 / 0.4);color:oklch(0.78 0.22 148)">GMP Compliant</span>
			<span class="px-3 py-1 rounded-sm font-mono-spec text-xs" style="border:1px solid oklch(0.78 0.22 148 / 0.4);color:oklch(0.78 0.22 148)">ISO 13485</span>
		</div>

		<div class="flex flex-col md:flex-row items-center justify-between gap-3 mt-8 text-xs" style="color:oklch(0.60 0.03 148)">
			<span>&copy; 2026 Core Distro. All rights reserved.</span>
			<span style="letter-spacing:0.1em">Direct Distribution Infrastructure</span>
		</div>
	</div>
</footer>