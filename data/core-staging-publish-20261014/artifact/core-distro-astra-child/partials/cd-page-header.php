<?php
/**
 * Shared staging page header for the eleven non-home routes.
 *
 * The homepage is untouched: it is served by theme/front-page.php from the
 * preserved public snapshot. This shell reproduces the same public header —
 * logo, primary navigation, phone, "Request a Quote" — but points every link at
 * a local staging route and deliberately omits the public site's "Ask Questions"
 * chatbot trigger, which must not load in staging.
 *
 * @package core-distro-stage
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$cd_assets = esc_url( get_stylesheet_directory_uri() . '/assets/' );
$cd_home   = esc_url( home_url( '/' ) );

/*
 * Resolve the menu through the registered theme location rather than by menu
 * slug: the seeder creates "Primary Navigation" (slug "primary-navigation"),
 * while the location registered in functions.php is "primary". Looking the menu
 * up by slug silently renders an empty header.
 */
$cd_locations = get_nav_menu_locations();
$cd_menu_id   = isset( $cd_locations['primary'] ) ? (int) $cd_locations['primary'] : 0;
$cd_items     = $cd_menu_id ? wp_get_nav_menu_items( $cd_menu_id ) : array();
$cd_items     = is_array( $cd_items ) ? $cd_items : array();
$cd_here      = trim( (string) get_page_uri( get_queried_object_id() ), '/' );
?>
<header class="fixed top-0 left-0 right-0 z-50 transition-all duration-300"
	style="background-color:transparent;backdrop-filter:none;border-bottom:none">
	<div class="container">
		<div class="flex items-center justify-between h-18 py-3 gap-4">
			<a href="<?php echo $cd_home; ?>" class="flex items-center gap-3 group shrink-0">
				<img src="<?php echo $cd_assets; ?>core-distro-logo.webp" alt="Core Distro" class="h-10 w-auto">
				<span class="hidden xl:block">
					<span class="font-display font-bold text-xl tracking-widest text-white leading-none" style="display:block;letter-spacing:0.15em">CORE DISTRO</span>
					<span class="text-xs tracking-widest" style="display:block;color:oklch(0.78 0.22 148);font-family:var(--font-mono);letter-spacing:0.2em">PHARMACEUTICAL DISTRIBUTION</span>
				</span>
			</a>
			<nav class="hidden lg:flex items-center gap-5 ml-6" aria-label="Primary">
				<?php
				foreach ( (array) $cd_items as $cd_nav_item ) {
					$cd_nav_url = wp_make_link_relative( $cd_nav_item->url );
					$cd_nav_top = trim( (string) wp_parse_url( $cd_nav_item->url, PHP_URL_PATH ), '/' );
					$cd_nav_on  = ( $cd_nav_top === $cd_here );
					echo '<a href="' . esc_url( $cd_nav_url ) . '"' . ( $cd_nav_on ? ' aria-current="page"' : '' ) . '>';
					echo '<span class="font-display text-xs tracking-widest uppercase transition-colors duration-200 whitespace-nowrap" style="letter-spacing:0.1em;color:' . ( $cd_nav_on ? 'oklch(0.78 0.22 148)' : 'oklch(0.88 0.04 148)' ) . ';font-family:var(--font-display);font-weight:600">';
					echo esc_html( $cd_nav_item->title );
					echo '</span></a>' . "\n";
				}
				?>
			</nav>
			<div class="hidden lg:flex items-center gap-3 shrink-0">
				<a href="tel:+18338484257" class="flex items-center gap-1.5 transition-colors duration-200 whitespace-nowrap"
					style="color:oklch(0.78 0.22 148);font-family:var(--font-mono);font-size:0.7rem">
					<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg>
					(833) 84-VIALS / (833) 848-4257
				</a>
				<a href="<?php echo esc_url( home_url( '/contact/' ) ); ?>" class="btn-cd-primary">Request a Quote</a>
			</div>
			<button type="button" class="lg:hidden text-white p-2" aria-label="Toggle menu" aria-expanded="false" aria-controls="cd-mobile-nav">
				<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="4" x2="20" y1="12" y2="12"></line><line x1="4" x2="20" y1="6" y2="6"></line><line x1="4" x2="20" y1="18" y2="18"></line></svg>
			</button>
		</div>
	</div>
</header>

<?php // Mobile menu. Shipped closed and inert: opacity/pointer-events take it away from the eye and the mouse, and `inert` + aria-hidden take it out of the tab order and the accessibility tree, which neither of those two properties does. assets/stage-interactions.js removes both on open and restores them on close. `hidden` is deliberately NOT used — assets/site.css resolves it to display:none !important, which would kill the 300ms open/close transition. ?>
<nav id="cd-mobile-nav" aria-label="Mobile" inert aria-hidden="true" class="cd-mobile-nav fixed inset-0 z-40 lg:hidden transition-all duration-300" style="opacity:0;pointer-events:none">
	<div class="absolute inset-0" style="background-color:oklch(0.18 0.065 148 / 0.98)"></div>
	<div class="absolute top-0 right-0 w-72 h-full flex flex-col pt-24 px-8 gap-6 overflow-y-auto" style="background-color:oklch(0.18 0.065 148)">
		<?php
		foreach ( (array) $cd_items as $cd_m_item ) {
			$cd_m_url = wp_make_link_relative( $cd_m_item->url );
			$cd_m_top = trim( (string) wp_parse_url( $cd_m_item->url, PHP_URL_PATH ), '/' );
			$cd_m_on  = ( $cd_m_top === $cd_here );
			echo '<a href="' . esc_url( $cd_m_url ) . '"' . ( $cd_m_on ? ' aria-current="page"' : '' ) . '><span class="font-display font-bold text-2xl tracking-widest uppercase block" style="letter-spacing:0.12em;color:oklch(0.88 0.04 148)">' . esc_html( $cd_m_item->title ) . '</span></a>' . "\n";
		}
		?>
		<a href="<?php echo esc_url( home_url( '/register/' ) ); ?>"><span class="font-display font-bold text-2xl tracking-widest uppercase block" style="letter-spacing:0.12em;color:oklch(0.78 0.22 148)">Register</span></a>
	</div>
</nav>