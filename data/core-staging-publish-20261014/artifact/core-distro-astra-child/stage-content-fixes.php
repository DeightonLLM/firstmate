<?php
/**
 * Pure, private-staging markup fixes driven by the Lighthouse baseline.
 *
 * These corrections intentionally operate at render time so they do not write
 * to the staging WordPress database. The same source-content corrections are
 * mirrored in the extractor/build fragments for future idempotent seeding.
 */
function core_distro_stage_lighthouse_content_fixes( $content, $route, $asset_base ) {
	if ( ! is_string( $content ) || '' === $content ) {
		return $content;
	}

	$route = is_string( $route ) ? $route : '';

	// wpautop wraps block-level product/contact anchors in paragraph fragments,
	// which the browser turns into empty duplicate links. Remove the optional
	// surrounding paragraph and restore each complete anchor before parsing.
	if ( in_array( $route, array( 'products', 'contact' ), true ) ) {
		$content = preg_replace( '/(?:<p>\s*)?(<a\b[^>]*>)\s*<\/p>\s*/i', '$1', $content );
		$content = preg_replace( '/\s*<p>\s*<\/a>/i', '</a>', $content );
	}

	// A disabled button nested in a link is invalid and creates confusing
	// accessibility-tree nodes. Promote the button's visual class/style to the
	// existing navigational anchor and retain its text as the link name.
	$content = preg_replace_callback(
		'~<a\b([^>]*)>\s*<button\b([^>]*)>([\\s\\S]*?)</button>\s*</a>~i',
		function ( $match ) {
			$anchor_attrs = $match[1];
			$button_attrs = $match[2];

			if ( preg_match( '/\\bclass\\s*=\\s*"([^"]*)"/i', $button_attrs, $button_class ) ) {
				$classes = trim( $button_class[1] );
				if ( preg_match( '/\\bclass\\s*=\\s*"([^"]*)"/i', $anchor_attrs, $anchor_class ) ) {
					$combined = trim( $anchor_class[1] . ' ' . $classes );
					$anchor_attrs = preg_replace(
						'/\\bclass\\s*=\\s*"([^"]*)"/i',
						'class="' . htmlspecialchars( $combined, ENT_QUOTES, 'UTF-8' ) . '"',
						$anchor_attrs,
						1
					);
				} else {
					$anchor_attrs .= ' class="' . htmlspecialchars( $classes, ENT_QUOTES, 'UTF-8' ) . '"';
				}
			}

			if ( preg_match( '/\\bstyle\\s*=\\s*"([^"]*)"/i', $button_attrs, $button_style ) ) {
				$style = $button_style[1];
				if ( preg_match( '/\\bstyle\\s*=\\s*"([^"]*)"/i', $anchor_attrs, $anchor_style ) ) {
					$combined = trim( $anchor_style[1], "; \\t\\n" ) . ';' . $style;
					$anchor_attrs = preg_replace(
						'/\\bstyle\\s*=\\s*"([^"]*)"/i',
						'style="' . htmlspecialchars( $combined, ENT_QUOTES, 'UTF-8' ) . '"',
						$anchor_attrs,
						1
					);
				} else {
					$anchor_attrs .= ' style="' . htmlspecialchars( $style, ENT_QUOTES, 'UTF-8' ) . '"';
				}
			}

			return '<a' . $anchor_attrs . '>' . $match[3] . '</a>';
		},
		$content
	);


	// The private stage has no local automation MP4. Keep its existing poster,
	// but resolve that image through the theme asset directory and drop the 404.
	if ( 'products' === $route ) {
		$asset_base = rtrim( (string) $asset_base, '/' ) . '/';
		$poster_url = htmlspecialchars( $asset_base . 'automation-machine-v2.webp', ENT_QUOTES, 'UTF-8' );
		$content    = str_replace(
			'poster="/images/automation-machine-v2.webp"',
			'poster="' . $poster_url . '"',
			$content
		);
		$content = preg_replace(
			'~<source\b(?=[^>]*\bsrc\s*=\s*(["\'])/automation-machine-video_93d11a5b\.mp4\1)[^>]*>\s*~i',
			'',
			$content
		);
		// The prior extractor omitted this closing tag from the stored fragment.
		// Close before its overlay sibling, matching the original public markup.
		$content = preg_replace(
			'~(<video\b[^>]*>)(?=<div\b[^>]*class="[^"]*absolute[^"]*bottom-3[^"]*right-3)~i',
			'$1</video>',
			$content,
			1
		);
	}

	// The existing stored fragments also contain an unclosed breadcrumb nav;
	// close it before its surrounding layout div, as the source extractor now does.
	if ( preg_match( '/<nav\b[^>]*aria-label="Breadcrumb"/i', $content ) && ! preg_match( '/<\/nav\s*>/i', $content ) ) {
		$content = preg_replace(
			'~(<nav\b[^>]*aria-label="Breadcrumb"[^>]*>[\\s\\S]*?)(</div>)~i',
			'$1</nav>$2',
			$content,
			1
		);
	}

	// Existing contact/registration content contains duplicate textarea closers
	// from the prior extractor; keep exactly the single closer WordPress needs.
	if ( in_array( $route, array( 'contact', 'register' ), true ) ) {
		$content = preg_replace( '/<\\/textarea>\\s*<\\/textarea>/i', '</textarea>', $content );
	}

	// Old resource records contain inert-download spans with the former anchor
	// closer. Repair only an unclosed span; never consume a later real page link.
	if ( 'resources' === $route ) {
		$content = preg_replace(
			'~(<span\\b(?=[^>]*\\bclass="[^"]*\\bcd-inert-download\\b[^"]*")[^>]*>(?:(?!</span>)[\\s\\S])*?)</a>~i',
			'$1</span>',
			$content
		);
	}

	// These page bodies contain section headings that jump from H1 to H3. Their
	// current extracted fragments have no intervening H2, so promote those H3s.
	if ( in_array( $route, array( 'contact', 'blog', 'resources' ), true ) ) {
		$content = preg_replace( '/<h3\b([^>]*)>/i', '<h2$1>', $content );
		$content = preg_replace( '/<\/h3\s*>/i', '</h2>', $content );
	}

	// Improve only the audited low-contrast inline text values on their known
	// light/dark route backgrounds. These replacements do not change copy.
	if ( 'blog' === $route ) {
		$content = str_replace( 'color:oklch(0.50 0.04 148)', 'color:oklch(0.70 0.04 148)', $content );
	}
	if ( in_array( $route, array( 'contact', 'register' ), true ) ) {
		$content = str_replace( 'color:oklch(0.55 0.04 148)', 'color:oklch(0.45 0.04 148)', $content );
	}

	// The closed mobile drawer overlay is visually hidden with
	// opacity:0;pointer-events:none, yet its links stayed in the keyboard tab
	// order. The homepage already carries the correct source pattern
	// (theme/public-homepage-body.html), so the canonical route fragments render
	// the same focus exclusion here instead of having the drawer stripped. Only
	// the two attributes are added to that one already-closed overlay div: its
	// markup, panel and links are untouched, the header nav and any open panel
	// are left alone, and an element that already carries `inert` is skipped so
	// repeated render passes stay idempotent. Scoped to the canonical slugs, so
	// the nine held duplicate records are never newly transformed.
	//
	// The element is identified by the drawer's own class signature rather than
	// by "any fixed hidden element": each class token is matched whole, inside
	// the quoted class attribute, so a class that merely contains `fixed` as a
	// substring cannot match, and another closed fixed overlay that happens to
	// appear earlier in the fragment cannot consume the single replacement and
	// leave the drawer itself focusable.
	$canonical_routes = array(
		'about',
		'aluminum-seals',
		'blog',
		'compliance',
		'contact',
		'faq',
		'glass-vials',
		'products',
		'register',
		'resources',
		'rubber-stoppers',
	);
	if ( in_array( $route, $canonical_routes, true ) ) {
		$content = preg_replace(
			'~<div\b(?![^>]*\binert\b)(?=[^>]*\bclass="(?:[^"]*\s)?fixed(?:\s|"))(?=[^>]*\bclass="(?:[^"]*\s)?inset-0(?:\s|"))(?=[^>]*\bclass="(?:[^"]*\s)?z-40(?:\s|"))(?=[^>]*\bclass="(?:[^"]*\s)?lg:hidden(?:\s|"))(?=[^>]*\bstyle="[^"]*\bopacity:0;pointer-events:none")([^>]*)>~i',
			'<div inert aria-hidden="true"$1>',
			$content,
			1
		);
	}

	return $content;
}

/** Keep Astra's frontend bundle but disable its scroll-to-top handler on the
 * custom homepage, where the corresponding Astra markup is intentionally absent.
 */
function core_distro_stage_astra_localize_js( $settings, $is_front_page ) {
	if ( ! is_array( $settings ) ) {
		return $settings;
	}

	if ( $is_front_page ) {
		$settings['is_scroll_to_top'] = false;
	}

	return $settings;
}
