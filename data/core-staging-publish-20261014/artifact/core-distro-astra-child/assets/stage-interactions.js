(() => {
  "use strict";

  const init = () => {
    const header = document.querySelector("header.fixed");
    const updateHeader = () => {
      if (!header) return;
      const scrolled = window.scrollY > 40;
      header.style.backgroundColor = scrolled ? "oklch(0.18 0.065 148 / 0.97)" : "transparent";
      header.style.backdropFilter = scrolled ? "blur(12px)" : "none";
      header.style.borderBottom = scrolled ? "1px solid oklch(0.78 0.22 148 / 0.15)" : "none";
    };
    updateHeader();
    window.addEventListener("scroll", updateHeader, { passive: true });

    const quoteBar = document.getElementById("cd-sticky-quote-bar");
    const updateQuoteBar = () => {
      if (!quoteBar) return;
      const visible = window.scrollY > 0.85 * window.innerHeight;
      quoteBar.classList.toggle("hidden", !visible);
      quoteBar.setAttribute("aria-hidden", String(!visible));
    };
    updateQuoteBar();
    window.addEventListener("scroll", updateQuoteBar, { passive: true });
    window.addEventListener("resize", updateQuoteBar, { passive: true });

    const menuButton = document.querySelector('button[aria-label="Toggle menu"]');
    const menuPanel = document.querySelector(".cd-mobile-nav");
    const setMenuOpen = (open) => {
      if (!menuButton || !menuPanel) return;
      menuPanel.style.opacity = open ? "1" : "0";
      menuPanel.style.pointerEvents = open ? "auto" : "none";
      menuButton.setAttribute("aria-expanded", String(open));
      /*
       * opacity:0 + pointer-events:none hide the closed panel from the eye and
       * the mouse, but neither removes its 13 focusable descendants from the
       * tab order or from the accessibility tree — a closed menu that still
       * swallows Tab. `inert` does both, and aria-hidden states the same
       * thing to assistive technology. Both are restored on open.
       *
       * `hidden` would be the wrong tool: assets/site.css resolves it to
       * display:none !important, which would also destroy the 300ms open/close
       * transition the mobile menu relies on. inert changes no rendering.
       */
      menuPanel.toggleAttribute("inert", !open);
      menuPanel.setAttribute("aria-hidden", String(!open));
      const icon = menuButton.querySelector("svg");
      if (icon) {
        icon.classList.toggle("lucide-menu", !open);
        icon.classList.toggle("lucide-x", open);
        icon.innerHTML = open
          ? '<line x1="18" x2="6" y1="6" y2="18"></line><line x1="6" x2="18" y1="6" y2="18"></line>'
          : '<line x1="4" x2="20" y1="12" y2="12"></line><line x1="4" x2="20" y1="6" y2="6"></line><line x1="4" x2="20" y1="18" y2="18"></line>';
      }
    };
    if (menuButton && menuPanel) {
      menuButton.setAttribute("aria-expanded", "false");
      menuButton.addEventListener("click", () => {
        setMenuOpen(menuButton.getAttribute("aria-expanded") !== "true");
      });
      menuPanel.querySelectorAll("a").forEach((link) => link.addEventListener("click", () => setMenuOpen(false)));
      document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") setMenuOpen(false);
      });
    }

    const fadeItems = document.querySelectorAll(".fade-in-up");
    /*
     * .fade-in-up starts at opacity:0 and only becomes visible once the
     * observer fires, so with reduced motion requested the content must be
     * shown immediately rather than translated into place. assets/site.css
     * also neutralises the transition itself under the same media query.
     */
    const prefersReducedMotion = !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    if (prefersReducedMotion || !("IntersectionObserver" in window)) {
      fadeItems.forEach((item) => item.classList.add("visible"));
    } else if ("IntersectionObserver" in window) {
      const fadeObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("visible");
          observer.unobserve(entry.target);
        });
      }, { threshold: 0.1 });
      fadeItems.forEach((item) => fadeObserver.observe(item));
    }

    const metricCards = Array.from(document.querySelectorAll("#global .text-center"));
    const metrics = [
      { value: 99.9, suffix: "%", decimals: 1 },
      { value: 48, suffix: "hr", decimals: 0 },
      { value: 97, suffix: "%", decimals: 0 },
      { value: 4, suffix: "", decimals: 0 },
    ];
    const animateMetric = (card, metric) => {
      const display = card.querySelector(".font-display.font-bold");
      if (!display) return;
      const reducedMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (reducedMotion || !("requestAnimationFrame" in window)) {
        display.textContent = metric.decimals > 0
          ? metric.value.toFixed(metric.decimals) + metric.suffix
          : String(Math.round(metric.value)) + metric.suffix;
        return;
      }
      const started = performance.now();
      const tick = (now) => {
        const progress = Math.min((now - started) / 2200, 1);
        const eased = (1 - Math.pow(1 - progress, 3)) * metric.value;
        display.textContent = metric.decimals > 0
          ? parseFloat(eased.toFixed(metric.decimals)).toFixed(metric.decimals) + metric.suffix
          : String(Math.round(eased)) + metric.suffix;
        if (progress < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    };
    if (metricCards.length === metrics.length) {
      if ("IntersectionObserver" in window) {
        const counterObserver = new IntersectionObserver((entries, observer) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting) return;
            const index = metricCards.indexOf(entry.target);
            if (index >= 0) animateMetric(entry.target, metrics[index]);
            observer.unobserve(entry.target);
          });
        }, { threshold: 0.3 });
        metricCards.forEach((card) => counterObserver.observe(card));
      } else {
        metricCards.forEach((card, index) => animateMetric(card, metrics[index]));
      }
    }

    document.addEventListener("submit", (event) => {
      if (!(event.target instanceof HTMLFormElement)) return;
      event.preventDefault();
      event.stopImmediatePropagation();
    }, true);

    initFaq();
  };

  /**
   * FAQ accordion (theme/page.php route only).
   *
   * The answers ship expanded in the markup so they are readable with JS
   * disabled and to crawlers; this wires the toggles and keeps `aria-expanded`
   * truthful. It also wires the category chips. Both are pure client-side
   * interactions: no request is made, nothing is stored.
   */
  const initFaq = () => {
    const items = Array.from(document.querySelectorAll("[data-cd-faq-panel]"));
    if (items.length === 0) return;

    const panelFor = (index) => document.getElementById(`cd-faq-panel-${index}`);
    const triggerFor = (index) => document.getElementById(`cd-faq-trigger-${index}`);

    items.forEach((panel) => {
      const index = panel.getAttribute("data-cd-faq-panel");
      const trigger = triggerFor(index);
      if (!trigger) return;

      const setExpanded = (open) => {
        trigger.setAttribute("aria-expanded", String(open));
        panel.style.maxHeight = open ? "none" : "0px";
        panel.style.opacity = open ? "1" : "0";
        /*
         * max-height:0 + opacity:0 still leave the answer in the accessibility
         * tree and any link inside it in the tab order, so a collapsed answer
         * reads as expanded while aria-expanded claims it is collapsed.
         * `inert` removes the panel's descendants from both without touching
         * the max-height transition, and aria-hidden states it to assistive
         * technology. `hidden` is not used because site.css resolves it to
         * display:none !important, which would break that transition.
         */
        panel.toggleAttribute("inert", !open);
        panel.setAttribute("aria-hidden", String(!open));
      };

      // Markup is expanded by default; mirror that into the inline style.
      setExpanded(trigger.getAttribute("aria-expanded") !== "false");

      trigger.addEventListener("click", () => {
        setExpanded(trigger.getAttribute("aria-expanded") !== "true");
      });
    });

    const chips = Array.from(document.querySelectorAll("[data-cd-faq-filter]"));
    const rows = Array.from(document.querySelectorAll(".cd-faq-item"));
    if (chips.length === 0 || rows.length === 0) return;

    chips.forEach((chip) => {
      const wanted = chip.getAttribute("data-cd-faq-filter") || "";
      const paint = (active) => {
        /*
         * The three inline colours below are the only thing that used to mark
         * the active chip, so the filter state was conveyed by colour alone.
         * aria-pressed states it programmatically; it changes no rendering.
         */
        chip.setAttribute("aria-pressed", String(active));
        chip.style.backgroundColor = active ? "oklch(0.18 0.065 148)" : "transparent";
        chip.style.color = active ? "oklch(0.78 0.22 148)" : "oklch(0.40 0.04 148)";
        chip.style.borderColor = active ? "oklch(0.30 0.07 148)" : "oklch(0.88 0.02 148)";
      };

      chip.addEventListener("click", () => {
        rows.forEach((row) => {
          const category = row.getAttribute("data-cd-faq-category") || "";
          row.hidden = !(wanted === "" || category === wanted);
        });
        chips.forEach((other) => paint(other === chip));
      });

      /*
       * Give every chip an initial pressed state. Only the default chip is
       * repainted, exactly as before: the inactive chips keep whatever the
       * seeded page content styled them as, which this remediation must not
       * change. Their aria-pressed is set without touching their colours.
       */
      chip.setAttribute("aria-pressed", String(wanted === ""));
      if (wanted === "") paint(true);
    });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
