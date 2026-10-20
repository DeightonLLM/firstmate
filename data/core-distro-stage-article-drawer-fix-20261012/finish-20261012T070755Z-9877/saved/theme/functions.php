<?php
/**
 * Core Distro private staging child theme.
 * No live chatbot, analytics, form processing, or production API calls; page interactions run locally.
 */
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

require_once __DIR__ . '/stage-content-fixes.php';

add_action( 'wp_enqueue_scripts', function () {
    $uri = get_stylesheet_directory_uri();

    /*
     * The public stylesheet is the design authority for this site.
     * assets/site.css is a Tailwind v4 build, and Tailwind emits its utilities
     * inside CSS cascade layers. Astra's frontend stylesheet and the inline CSS
     * attached to it are *unlayered* global rules, so they win over layered
     * utilities no matter the order they load in, and they restyle the
     * headings, buttons, logo and header of every staged page.
     *
     * Every page here renders public-site markup, so Astra's frontend styling is
     * dropped site-wide. Dropping it on the custom homepage only was enough
     * while the other eleven routes did not exist; it is not enough now.
     */
    wp_dequeue_style( 'astra-theme-css' );
    wp_deregister_style( 'astra-theme-css' );

    wp_enqueue_style( 'core-distro-live-reference-css', $uri . '/assets/site.css', array(), '2026-10-09' );
    wp_enqueue_style( 'core-distro-astra-tokens', $uri . '/astra-tokens.css', array( 'core-distro-live-reference-css' ), '2026-10-09' );
    wp_enqueue_style( 'core-distro-stage-skin', $uri . '/style.css', array( 'core-distro-astra-tokens' ), '1.1.0' );

    /*
     * The additional staging pages reuse the public source markup, which uses a
     * small number of Tailwind utilities the homepage-only build never emitted.
     * stage-compat.css completes exactly those utilities; it restyles nothing.
     *
     * It now loads on every route including the homepage, because it also
     * carries the site-wide staging hooks (.cd-preview-notice, .cd-inert-form)
     * and the homepage renders those too. The homepage-specific layout rule it
     * adds is scoped to `header.fixed` under `.cd-stage-page`, a body class the
     * homepage does not have, so the preserved public homepage keeps its
     * transparent overlay header.
     */
    wp_enqueue_style( 'core-distro-stage-compat', $uri . '/assets/stage-compat.css', array( 'core-distro-astra-tokens' ), '1.0.5' );

    wp_enqueue_script( 'core-distro-stage-interactions', $uri . '/assets/stage-interactions.js', array(), '2026-10-10', true );
}, 20 );

/*
 * Origin-correct asset URLs for the two staging origins.
 *
 * The stage is reachable through two origins that front the SAME WordPress
 * instance:
 *   private : http://100.106.6.22:8087               (Tailnet-only, plain HTTP)
 *   public  : https://brandon-compute.tailddbb4d.ts.net   (Tailscale Funnel, HTTPS)
 *
 * WP_HOME/WP_SITEURL are pinned to the private origin (compose.yaml
 * WORDPRESS_CONFIG_EXTRA), and WordPress runs every generated URL through
 * set_url_scheme(). Funnel terminates TLS and forwards with
 * X-Forwarded-Proto: https, so is_ssl() returns true and the scheme is
 * upgraded in place, producing:
 *   https://100.106.6.22:8087/wp-content/themes/...
 *
 * That URL is wrong twice over when the page was requested through the Funnel:
 *   1. Port 8087 is a plain-HTTP listener, so https:// against it fails in the
 *      browser with ERR_SSL_PROTOCOL_ERROR before any CSS is parsed.
 *   2. 100.106.6.22 is a Tailscale CGNAT address that is not routable from the
 *      public internet, so even the correct scheme would not load.
 *
 * The CSS itself is fine and is deliberately not touched here; this is purely
 * an origin-prefix correction.
 *
 * Trust model — deliberately narrow:
 *   - Only the two exact hostnames below are ever rewritten, compared as an
 *     exact, case-normalised host[:port] match.
 *   - Anything else is left exactly as WordPress generated it. An arbitrary
 *     Host or X-Forwarded-Host cannot steer this to an attacker origin; it
 *     can only fail to match, in which case no rewrite happens at all.
 *   - The scheme is chosen by which allow-listed host was presented, never by
 *     trusting a forwarded scheme header. A private request stays on HTTP even
 *     if something sends X-Forwarded-Proto: https to it, which is what stops
 *     the original ERR_SSL_PROTOCOL_ERROR from recurring.
 *
 * Scope is limited to the two theme-directory URI filters. Those are what
 * build every app-owned asset URL on these routes: this theme's stylesheets,
 * scripts and images via get_stylesheet_directory_uri() (including the
 * __CD_STAGE_ASSET__ placeholder substitution and the favicon), and the Astra
 * parent's frontend script via get_template_directory_uri(). Nothing else —
 * canonical links, feeds, REST URLs, DB home/siteurl, wp-config, DNS, proxy
 * config and Tailscale settings — is modified here.
 */
function core_distro_stage_request_origin() {
    static $origin = null;

    if ( null !== $origin ) {
        return $origin;
    }

    $private_host = '100.106.6.22:8087';
    $funnel_host  = 'brandon-compute.tailddbb4d.ts.net';

    $presented = array();
    foreach ( array( 'HTTP_X_FORWARDED_HOST', 'HTTP_HOST' ) as $key ) {
        if ( ! empty( $_SERVER[ $key ] ) && is_string( $_SERVER[ $key ] ) ) {
            // X-Forwarded-Host may be a comma list; the first entry is the host the client asked for.
            $first = trim( explode( ',', $_SERVER[ $key ] )[0] );
            $presented[] = strtolower( $first );
        }
    }

    if ( in_array( $funnel_host, $presented, true ) ) {
        $origin = 'https://' . $funnel_host;
    } elseif ( in_array( $private_host, $presented, true ) ) {
        $origin = 'http://' . $private_host;
    } else {
        $origin = ''; // Unknown host: make no change rather than trust it.
    }

    return $origin;
}

/** Swap only the exact staging-origin prefix of a theme asset URL. */
function core_distro_stage_asset_origin( $url ) {
    $origin = core_distro_stage_request_origin();

    if ( '' === $origin || ! is_string( $url ) || '' === $url ) {
        return $url;
    }

    foreach ( array( 'http://100.106.6.22:8087', 'https://100.106.6.22:8087' ) as $prefix ) {
        if ( 0 !== strpos( $url, $prefix ) ) {
            continue;
        }

        // Require an exact origin boundary so a longer host such as
        // 100.106.6.22:80870 is never treated as a match.
        $rest = substr( $url, strlen( $prefix ) );
        if ( '' === $rest || '/' === $rest[0] ) {
            return $origin . $rest;
        }
    }

    return $url;
}

add_filter( 'stylesheet_directory_uri', 'core_distro_stage_asset_origin' );
add_filter( 'template_directory_uri', 'core_distro_stage_asset_origin' );

/*
 * wp-includes carries one more app-owned asset on these routes: the emoji
 * support script, wp-emoji-release.min.js. Core injects it from JavaScript at
 * runtime, so it is absent from the served HTML and a markup-only asset check
 * cannot see it — a real browser load is what surfaced it still resolving to
 * https://100.106.6.22:8087/wp-includes/... on the Funnel and failing with
 * ERR_SSL_PROTOCOL_ERROR, the same defect as above in a different directory.
 *
 * includes_url() is filtered rather than site_url(), which keeps the change
 * scoped to wp-includes asset URLs and leaves REST, wp-admin, login and
 * redirect URLs untouched.
 */
add_filter( 'includes_url', 'core_distro_stage_asset_origin' );

/*
 * Canonical URL and home_url correction for the Funnel origin.
 *
 * When accessed via the Funnel origin (https://brandon-compute.tailddbb4d.ts.net),
 * WordPress generates URLs using the private origin (http://100.106.6.22:8087) because
 * WP_HOME/WP_SITEURL are pinned to the private origin. This causes:
 *   - Canonical links to point to the private IP instead of the Funnel host
 *   - home_url() to return the wrong origin
 *
 * This filter corrects WordPress-generated URLs to use the correct staging origin
 * based on the Host header presented in the request, following the same exact-host
 * trust model as the asset origin fix.
 *
 * Scope is limited to front-end URLs only (not wp-admin, REST, or login).
 */
function core_distro_stage_home_url( $url, $path, $scheme, $blog_id ) {
    // Skip admin URLs
    if ( is_admin() || ( defined( 'REST_REQUEST' ) && REST_REQUEST ) ) {
        return $url;
    }

    $origin = core_distro_stage_request_origin();

    if ( '' === $origin || ! is_string( $url ) || '' === $url ) {
        return $url;
    }

    // Handle both http:// and https:// private origin prefixes
    foreach ( array( 'http://100.106.6.22:8087', 'https://100.106.6.22:8087' ) as $prefix ) {
        if ( 0 !== strpos( $url, $prefix ) ) {
            continue;
        }

        $rest = substr( $url, strlen( $prefix ) );
        if ( '' === $rest || '/' === $rest[0] ) {
            // Reconstruct with correct scheme/host from the presented origin
            // Only preserve port from the original URL if the target origin also has a port
            $parsed = parse_url( $origin );
            $parsed_orig = parse_url( $url );
            $correct_scheme = $parsed['scheme'] ?? 'https';
            $correct_host = $parsed['host'] ?? '';
            // Only include port if target origin has one (Funnel doesn't)
            $port = '';
            if ( isset( $parsed['port'] ) ) {
                $port = ':' . $parsed['port'];
            }
            return $correct_scheme . '://' . $correct_host . $port . $rest;
        }
    }

    return $url;
}
add_filter( 'home_url', 'core_distro_stage_home_url', 20, 4 );

/*
 * Also fix post permalink URLs (the_permalink, post_link filters) so navigation
 * links generated by WordPress stay on the correct Funnel origin.
 */
function core_distro_stage_post_url( $url, $post, $leavename ) {
    // Skip admin/rest contexts
    if ( is_admin() || ( defined( 'REST_REQUEST' ) && REST_REQUEST ) ) {
        return $url;
    }

    $origin = core_distro_stage_request_origin();

    if ( '' === $origin || ! is_string( $url ) || '' === $url ) {
        return $url;
    }

    foreach ( array( 'http://100.106.6.22:8087', 'https://100.106.6.22:8087' ) as $prefix ) {
        if ( 0 !== strpos( $url, $prefix ) ) {
            continue;
        }

        $rest = substr( $url, strlen( $prefix ) );
        if ( '' === $rest || '/' === $rest[0] ) {
            $parsed = parse_url( $origin );
            $correct_scheme = $parsed['scheme'] ?? 'https';
            $correct_host = $parsed['host'] ?? '';
            // Only include port if target origin has one (Funnel doesn't)
            $port = '';
            if ( isset( $parsed['port'] ) ) {
                $port = ':' . $parsed['port'];
            }
            return $correct_scheme . '://' . $correct_host . $port . $rest;
        }
    }

    return $url;
}
add_filter( 'post_link', 'core_distro_stage_post_url', 20, 3 );
add_filter( 'the_permalink', 'core_distro_stage_post_url', 20, 3 );

add_theme_support( 'title-tag' );

/*
 * The homepage keeps the exact public document title. Every other route uses the
 * title seeded from tools/routes.manifest.json, which is copied verbatim from the
 * read-only audits so tests/multipage-smoke.mjs matches without being weakened.
 */
add_filter( 'pre_get_document_title', function () {
    if ( is_front_page() ) {
        return 'Core Distro | Pharmaceutical Supply Distribution';
    }

    $seeded = get_post_meta( get_the_ID(), '_cd_document_title', true );
    if ( is_string( $seeded ) && '' !== $seeded ) {
        return $seeded;
    }

    return '';
} );

/*
 * Seeded page content stores __CD_STAGE_ASSET__/ placeholders instead of absolute
 * URLs, so a staged page can never point at a production asset. Swap them for the
 * local theme asset directory on output.
 */
add_filter( 'the_content', function ( $content ) {
    if ( is_admin() || false === strpos( $content, '__CD_STAGE_ASSET__/' ) ) {
        return $content;
    }

    return str_replace(
        '__CD_STAGE_ASSET__/',
        esc_url( get_stylesheet_directory_uri() . '/assets/' ),
        $content
    );
}, 20 );

/**
 * Give every disabled form control on a staged page an accessible name.
 *
 * The route extractor (tools/extract-route-content.py) binds labels to the
 * controls the public markup actually labels. The public newsletter block ships
 * no <label> at all, so on /blog/ the extractor still assigned stable ids
 * (cd-preview-field-1/2) but had no label to bind, leaving placeholder-only
 * controls with no accessible name. Placeholders are not labels: they vanish on
 * focus and are not reliably exposed to assistive technology.
 *
 * This is a render-time fix on purpose. The alternative — re-seeding the content
 * — is a database write, which this remediation is not authorised to perform.
 *
 * The inserted <label> uses the sr-only utility, so the control gains a real
 * accessible name with no visible layout change: nothing is added to the box
 * model, and the label is removed from both the visual and accessibility trees
 * beyond naming its control. A control that already has a bound label, an
 * aria-label or an aria-labelledby is left untouched, so the seven fully
 * labelled controls on /register/ and the six on /contact/ are unaffected.
 */
add_filter( 'the_content', function ( $content ) {
    if ( is_admin() || false === strpos( $content, '<form' ) ) {
        return $content;
    }

    // Controls that already have an accessible name, by any of the three routes.
    $named = array();
    if ( preg_match_all( '/<label\b[^>]*\bfor\s*=\s*["\']([^"\']+)["\']/i', $content, $m ) ) {
        $named = array_flip( $m[1] );
    }
    if ( preg_match_all( '/<(?:input|textarea|select)\b[^>]*\baria-label(?:ledby)?\s*=\s*["\'][^"\']+["\']/i', $content, $m ) ) {
        foreach ( $m[0] as $tag ) {
            if ( preg_match( '/\bid\s*=\s*["\']([^"\']+)["\']/i', $tag, $id ) ) {
                $named[ $id[1] ] = true;
            }
        }
    }

    $next = 0;

    return preg_replace_callback(
        '/<(input|textarea|select)\b([^>]*)>/i',
        function ( $tag ) use ( &$next, $named ) {
            $attrs = $tag[2];

            $id = preg_match( '/\bid\s*=\s*["\']([^"\']+)["\']/i', $attrs, $m ) ? $m[1] : '';
            if ( '' !== $id && isset( $named[ $id ] ) ) {
                return $tag[0]; // already named
            }

            // Derive the name from the control's own placeholder copy.
            $text = '';
            if ( preg_match( '/\bplaceholder\s*=\s*["\']([^"\']*)["\']/i', $attrs, $m ) ) {
                $text = trim( $m[1] );
            }
            if ( '' === $text ) {
                $type   = preg_match( '/\btype\s*=\s*["\']([^"\']*)["\']/i', $attrs, $m ) ? strtolower( $m[1] ) : 'text';
                $text   = array(
                    'email' => 'Email address',
                    'tel'   => 'Phone number',
                    'text'  => 'Text field',
                )[ $type ] ?? ucfirst( $type ) . ' field';
            }

            $next++;
            if ( '' === $id ) {
                $id              = 'cd-preview-labelled-' . $next;
                $attrs          .= ' id="' . esc_attr( $id ) . '"';
                $named[ $id ]    = true;
            }

            return '<label class="sr-only" for="' . esc_attr( $id ) . '">' . esc_html( $text ) . '</label>'
                . '<' . $tag[1] . $attrs . '>';
        },
        $content
    );
}, 21 );

/*
 * Correct Lighthouse-confirmed markup at render time without writing any
 * post_content. This also keeps the current private preview correct until a
 * Captain-reviewed seed update is intentionally applied.
 */
add_filter( 'the_content', function ( $content ) {
    if ( is_admin() ) {
        return $content;
    }

    $route = (string) get_post_field( 'post_name', get_the_ID() );
    $assets = get_stylesheet_directory_uri() . '/assets/';

    return core_distro_stage_lighthouse_content_fixes( $content, $route, $assets );
}, 22 );

/*
 * Astra emits <div id="ast-scroll-top"> in wp_footer via
 * Astra_Scroll_To_Top_Loader::html_markup_loader().
 * Remove it on the custom homepage only — the public page has no such element.
 * Uses the same remove_action() pattern Astra uses in its own AMP compatibility
 * (inc/compatibility/class-astra-amp.php:77).
 */
add_action( 'wp', function () {
    if ( is_front_page() ) {
        remove_action(
            'wp_footer',
            array( Astra_Scroll_To_Top_Loader::get_instance(), 'html_markup_loader' )
        );
    }
} );

/*
 * The custom homepage intentionally omits Astra's scroll-to-top markup, but
 * Astra's frontend bundle uses this localized flag to decide whether it may
 * query and attach handlers to #ast-scroll-top. Keep the bundle and disable
 * only that absent control on the homepage to avoid getComputedStyle(null).
 */
add_filter( 'astra_theme_js_localize', function ( $settings ) {
    return core_distro_stage_astra_localize_js( $settings, is_front_page() );
} );

/*
 * The staging header and footer partials render the primary menu themselves so
 * they keep the public site's markup. Registering the location makes the menu
 * editable in wp-admin instead of being hardcoded.
 */
add_action( 'after_setup_theme', function () {
    register_nav_menus( array(
        'primary' => __( 'Primary Navigation', 'core-distro-stage' ),
    ) );
} );

/*
 * Both staging templates print their own head metadata BEFORE calling wp_head():
 *   - theme/front-page.php:23  <meta name="robots" content="noindex,nofollow">
 *   - theme/front-page.php:28  <link rel="canonical" href="<home_url('/')>">
 *   - theme/page.php:39        <meta name="robots" content="noindex,nofollow">
 *   - theme/page.php:45        <link rel="canonical" href="<get_permalink()>">
 *
 * WordPress core independently attaches its own emitters of exactly those two
 * tags to the same wp_head action:
 *   - wp_robots()     on wp_head, priority 1
 *   - rel_canonical() on wp_head, priority 10
 *
 * wp_head() runs after those template lines, so every one of the 12 staged
 * routes was rendering TWO robots meta tags and TWO canonical links. Core's
 * serialisation differs in formatting from the templates' (single quotes, a
 * space after the comma), so the duplicate was not byte-identical — two
 * different renderings of the same directive. Search engines treat conflicting
 * canonical/robots pairs as unreliable machine-readable signal, so the
 * duplicate is removed rather than reconciled.
 *
 * This removes core's wp_head emitters only. The explicit template tags and
 * their values are untouched and remain the single source of the staged
 * noindex,nofollow policy and the staged canonical URL, which is what
 * tests/head-metadata.mjs asserts.
 *
 * init runs after every plugin and the parent theme have been loaded but long
 * before wp_head fires, so this cannot be undone by a later registration.
 * Verified against the Astra 4.14.0 source in themes/astra/astra: it adds
 * pingback and layout callbacks to wp_head, never rel_canonical or wp_robots.
 * Scope is deliberately global — every staged route renders through one of the
 * two templates, so there is no route this leaves unprotected.
 *
 * The explicit priority on wp_robots is load-bearing. remove_action() defaults
 * to priority 10, which is where core registers rel_canonical, so the canonical
 * removal works with no argument. Core registers wp_robots at priority 1
 * (wp-includes/default-filters.php, confirmed against the running WordPress
 * 7.1.3 hook table), and a bare remove_action( 'wp_head', 'wp_robots' ) would
 * search priority 10, find nothing there, and silently remove nothing while
 * still looking like a successful fix.
 */
add_action( 'init', function () {
    remove_action( 'wp_head', 'rel_canonical', 10 );
    remove_action( 'wp_head', 'wp_robots', 1 );
} );

/*
 * Private staging must never be indexed, including the WordPress-generated
 * feeds and any archive output.
 *
 * Note: with wp_robots() no longer attached to wp_head above, this filter no
 * longer drives the served meta tag — the explicit template tags do. It is
 * retained deliberately as the guard for the policy if the wp_head action is
 * ever re-attached by a plugin or theme.
 */
add_filter( 'wp_robots', function ( $robots ) {
    $robots['noindex']  = true;
    $robots['nofollow'] = true;
    unset( $robots['max-snippet'] );

    return $robots;
} );

/*
 * Belt-and-braces: even if a plugin or theme ever prints a robots directive, the
 * staged origin never advertises itself as indexable.
 */
add_filter( 'wp_sitemaps_enabled', '__return_false' );