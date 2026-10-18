// Elevate Life Sciences - Pure Vanilla JS Client Logic
(function() {
  'use strict';

  // --- Research Gate ---
  function initGate() {
    var gate = document.getElementById('research-gate');
    if (!gate) return;
    if (sessionStorage.getItem('els_gate_dismissed')) {
      gate.style.display = 'none';
      return;
    }
    var cage = document.getElementById('gate-check-age');
    var c1 = document.getElementById('gate-check-1');
    var c2 = document.getElementById('gate-check-2');
    var btn = document.getElementById('gate-enter-btn');
    if (!cage || !c1 || !c2 || !btn) return;
    function update() {
      btn.disabled = !(cage.checked && c1.checked && c2.checked);
    }
    cage.addEventListener('change', update);
    c1.addEventListener('change', update);
    c2.addEventListener('change', update);
    btn.addEventListener('click', function() {
      if (cage.checked && c1.checked && c2.checked) {
        sessionStorage.setItem('els_gate_dismissed', 'true');
        gate.style.display = 'none';
      }
    });
  }

  // --- Mobile Menu ---
  function initMobileMenu() {
    var btn = document.getElementById('mobile-menu-btn');
    var menu = document.getElementById('mobile-menu');
    if (!btn || !menu) return;
    btn.addEventListener('click', function() {
      menu.classList.toggle('open');
    });
  }

  // --- Toast Notification ---
  window.showToast = function(msg) {
    var toast = document.getElementById('toast-notice');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'toast-notice';
      toast.className = 'toast-notice';
      document.body.appendChild(toast);
    }
    toast.textContent = msg;
    toast.classList.add('show');
    clearTimeout(window._toastTimeout);
    window._toastTimeout = setTimeout(function() {
      toast.classList.remove('show');
    }, 4000);
  };

  // --- Cart Store ---
  var CART_KEY = 'els_quote_cart';
  function getCart() {
    try {
      return JSON.parse(localStorage.getItem(CART_KEY)) || [];
    } catch(e) {
      return [];
    }
  }
  function saveCart(cart) {
    localStorage.setItem(CART_KEY, JSON.stringify(cart));
    renderCart();
  }

  window.addToCart = function(slug, name, size, price) {
    var cart = getCart();
    var existing = null;
    for (var i = 0; i < cart.length; i++) {
      if (cart[i].productSlug === slug && cart[i].size === size) {
        existing = cart[i];
        break;
      }
    }
    if (existing) {
      existing.quantity += 1;
    } else {
      cart.push({ productSlug: slug, productName: name, size: size, unitPrice: Number(price), quantity: 1 });
    }
    saveCart(cart);
    window.showToast('Added ' + name + ' (' + size + ') to quote request.');
    openCart();
  };

  window.updateCartQty = function(slug, size, delta) {
    var cart = getCart();
    var newCart = [];
    for (var i = 0; i < cart.length; i++) {
      var it = cart[i];
      if (it.productSlug === slug && it.size === size) {
        it.quantity += delta;
        if (it.quantity > 0) newCart.push(it);
      } else {
        newCart.push(it);
      }
    }
    saveCart(newCart);
  };

  window.removeCartItem = function(slug, size) {
    var cart = getCart();
    var newCart = cart.filter(function(it) { return !(it.productSlug === slug && it.size === size); });
    saveCart(newCart);
  };

  window.clearCart = function() { saveCart([]); };

  function openCart() {
    var dr = document.getElementById('cart-drawer');
    var ov = document.getElementById('drawer-overlay');
    if (dr && ov) { dr.classList.add('open'); ov.classList.add('open'); }
  }
  window.openCart = openCart;

  function closeCart() {
    var dr = document.getElementById('cart-drawer');
    var ov = document.getElementById('drawer-overlay');
    if (dr && ov) { dr.classList.remove('open'); ov.classList.remove('open'); }
  }
  window.closeCart = closeCart;

  function renderCart() {
    var cart = getCart();
    var totalCount = 0;
    var totalPrice = 0;
    for (var i = 0; i < cart.length; i++) {
      totalCount += cart[i].quantity;
      totalPrice += (cart[i].unitPrice * cart[i].quantity);
    }

    document.querySelectorAll('.cart-badge-count').forEach(function(el) {
      el.textContent = totalCount > 99 ? '99+' : totalCount;
      el.style.display = totalCount > 0 ? 'flex' : 'none';
    });

    var itemsContainer = document.getElementById('drawer-cart-items');
    var emptyNotice = document.getElementById('drawer-cart-empty');
    var footer = document.getElementById('drawer-cart-footer');
    var totalDisplay = document.getElementById('drawer-cart-total');

    if (itemsContainer && emptyNotice && footer) {
      if (cart.length === 0) {
        itemsContainer.innerHTML = '';
        emptyNotice.style.display = 'flex';
        footer.style.display = 'none';
      } else {
        emptyNotice.style.display = 'none';
        footer.style.display = 'block';
        if (totalDisplay) totalDisplay.textContent = '$' + totalPrice.toLocaleString();

        var html = '';
        cart.forEach(function(item) {
          html += '<div style="display:flex; gap:0.75rem; border-bottom:1px solid #E2E8F0; padding-bottom:0.75rem; margin-bottom:0.75rem;">' +
            '<div style="width:48px; height:58px; background:linear-gradient(180deg,#10192e,#060d1a); border-radius:4px; display:flex; flex-direction:column; align-items:center; justify-content:center; color:#fff; padding:2px; text-align:center; flex-shrink:0;">' +
            '<span style="font-size:8px; font-weight:700; line-height:1.1;">' + item.productName + '</span>' +
            '<span style="font-size:7px; opacity:0.6;">' + item.size + '</span>' +
            '</div>' +
            '<div style="flex:1; min-width:0;">' +
            '<div style="display:flex; justify-content:space-between; gap:0.5rem;">' +
            '<a href="/product/' + item.productSlug + '" style="font-size:13px; font-weight:500; color:#00388F; text-decoration:none; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">' + item.productName + '</a>' +
            '<button onclick="window.removeCartItem(\'' + item.productSlug + '\', \'' + item.size + '\')" style="color:#94a3b8; font-size:12px; cursor:pointer;" title="Remove">CX</button>' +
            '</div>' +
            '<div style="font-size:11px; color:#64748B; margin-bottom:0.35rem;">' + item.size + ' · $' + item.unitPrice + ' each</div>' +
            '<div style="display:flex; justify-content:space-between; align-items:center;">' +
            '<div style="display:inline-flex; border:1px solid #CBD5E1; border-radius:4px;">' +
            '<button onclick="window.updateCartQty(\'' + item.productSlug + '\', \'' + item.size + '\', -1)" style="padding:2px 8px; font-size:12px; color:#00388F;">-</button>' +
            '<span style="padding:2px 8px; font-size:11px; font-weight:600; color:#00388F;">' + item.quantity + '</span>' +
            '<button onclick="window.updateCartQty(\'' + item.productSlug + '\', \'' + item.size + '\', 1)" style="padding:2px 8px; font-size:12px; color:#00388F;">+</button>' +
            '</div>' +
            '<span style="font-size:13px; font-weight:600; color:#00388F;">$' + (item.unitPrice * item.quantity) + '</span>' +
            '</div>' +
            '</div>' +
          '</div>';
        });
        itemsContainer.innerHTML = html;
      }
    }

    var quoteReview = document.getElementById('quote-page-items');
    if (quoteReview) {
      if (cart.length === 0) {
        quoteReview.innerHTML = '<p style="color:#64748B; font-size:14px;">No items selected. <a href="/shop" style="color:#00388F; text-decoration:underline;">Browse the catalog</a> to add products.</p>';
        var submitBtn = document.getElementById('quote-submit-btn');
        if (submitBtn) submitBtn.disabled = true;
      } else {
        var qHtml = '<div style="margin-bottom:1.5rem;">';
        cart.forEach(function(item) {
          qHtml += '<div style="display:flex; justify-content:space-between; align-items:center; padding:0.6rem 0; border-bottom:1px solid #E2E8F0; font-size:14px;">' +
            '<div><strong>' + item.productName + '</strong> (' + item.size + ') × ' + item.quantity + '</div>' +
            '<div style="font-weight:600; color:#00388F;">$' + (item.unitPrice * item.quantity) + '</div>' +
          '</div>';
        });
        qHtml += '<div style="display:flex; justify-content:space-between; align-items:center; padding:0.75rem 0; font-weight:700; font-size:16px; color:#00388F;">' +
          '<span>Estimated Total:</span>' +
          '<span>$' + totalPrice.toLocaleString() + '</span>' +
        '</div></div>';
        quoteReview.innerHTML = qHtml;
        var submitBtn = document.getElementById('quote-submit-btn');
        if (submitBtn) submitBtn.disabled = false;
      }
    }
  }

  function initHandlers() {
    var staticNoticeMsg = 'Static preview mode: online submission is disabled in this export. Please email info@elevatesci.com directly.';

    var nl = document.getElementById('newsletter-box-action');
    if (nl) {
      nl.addEventListener('submit', function(e) {
        e.preventDefault();
        var res = document.getElementById('newsletter-result');
        if (res) {
          res.innerHTML = '<div style="font-size:13px; color:#00388F; background:#EFFAFA; border:1px solid rgba(0,56,143,0.15); border-radius:6px; padding:0.75rem; text-align:center;"><strong>Static Catalog Preview:</strong> Email updates are disabled in this export. Inquire directly at <a href="mailto:info@elevatesci.com" style="color:var(--color-teal); font-weight:600;">info@elevatesci.com</a>.</div>';
          res.style.display = 'block';
        }
        nl.style.display = 'none';
        window.showToast(staticNoticeMsg);
      });
    }

    var cf = document.getElementById('contact-box-action');
    if (cf) {
      cf.addEventListener('submit', function(e) {
        e.preventDefault();
        var res = document.getElementById('contact-result');
        if (res) {
          res.innerHTML = '<div style="background:#FFFBEB; border:1px solid #FCD34D; border-radius:8px; padding:2rem; text-align:center; max-width:600px; margin:0 auto;"><div style="font-size:32px; margin-bottom:1rem; color:#D97706;">&#8505;</div><h2 style="font-size:1.5rem; color:#92400E; margin-bottom:0.75rem;">Static Catalog Preview</h2><p style="font-size:14.5px; color:#78350F; line-height:1.7; margin-bottom:1.5rem;">Direct online submission is disabled in this static distribution export. No backend endpoint is connected. Please transmit inquiries directly to our team at <a href="mailto:info@elevatesci.com" style="color:#92400E; font-weight:700; text-decoration:underline;">info@elevatesci.com</a> or call <a href="tel:+18556663383" style="color:#92400E; font-weight:700; text-decoration:underline;">+1 (855) 666-3383</a>.</p><a href="/shop" class="btn-primary" style="font-size:13.5px; padding:0.65rem 1.5rem;">Browse Catalog</a></div>';
          res.style.display = 'block';
        }
        cf.style.display = 'none';
        window.showToast(staticNoticeMsg);
      });
    }

    var qf = document.getElementById('quote-box-action');
    if (qf) {
      qf.addEventListener('submit', function(e) {
        e.preventDefault();
        var res = document.getElementById('quote-result');
        if (res) {
          res.innerHTML = '<div style="background:#FFFBEB; border:1px solid #FCD34D; border-radius:8px; padding:2rem; text-align:center; max-width:600px; margin:0 auto;"><div style="font-size:32px; margin-bottom:1rem; color:#D97706;">&#8505;</div><h2 style="font-size:1.5rem; color:#92400E; margin-bottom:0.75rem;">Static Catalog Preview</h2><p style="font-size:14.5px; color:#78350F; line-height:1.7; margin-bottom:1.5rem;">Online quote processing is disabled in this static distribution export. Please email your selected items, compound specifications, and required quantities directly to <a href="mailto:info@elevatesci.com" style="color:#92400E; font-weight:700; text-decoration:underline;">info@elevatesci.com</a> or call <a href="tel:+18556663383" style="color:#92400E; font-weight:700; text-decoration:underline;">+1 (855) 666-3383</a>.</p><a href="/shop" class="btn-primary" style="font-size:13.5px; padding:0.65rem 1.5rem;">Browse Catalog</a></div>';
          res.style.display = 'block';
        }
        qf.style.display = 'none';
        window.showToast(staticNoticeMsg);
      });
    }

    var wf = document.getElementById('wholesale-box-action');
    if (wf) {
      wf.addEventListener('submit', function(e) {
        e.preventDefault();
        var res = document.getElementById('wholesale-result');
        if (res) {
          res.innerHTML = '<div style="background:#FFFBEB; border:1px solid #FCD34D; border-radius:8px; padding:2rem; text-align:center; max-width:600px; margin:0 auto;"><div style="font-size:32px; margin-bottom:1rem; color:#D97706;">&#8505;</div><h2 style="font-size:1.5rem; color:#92400E; margin-bottom:0.75rem;">Static Catalog Preview</h2><p style="font-size:14.5px; color:#78350F; line-height:1.7; margin-bottom:1.5rem;">Wholesale application submission is disabled in this static distribution export. Verified research organizations should submit credentials, institutional affiliations, and compound volume requirements directly to <a href="mailto:info@elevatesci.com" style="color:#92400E; font-weight:700; text-decoration:underline;">info@elevatesci.com</a> or call <a href="tel:+18556663383" style="color:#92400E; font-weight:700; text-decoration:underline;">+1 (855) 666-3383</a>.</p><a href="/shop" class="btn-primary" style="font-size:13.5px; padding:0.65rem 1.5rem;">Browse Catalog</a></div>';
          res.style.display = 'block';
        }
        wf.style.display = 'none';
        window.showToast(staticNoticeMsg);
      });
    }
  }

  function initFAQ() {
    document.querySelectorAll('.faq-question-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var item = this.parentElement;
        var answer = item.querySelector('.faq-answer');
        var icon = this.querySelector('.faq-toggle-icon');
        if (answer.style.display === 'block') {
          answer.style.display = 'none';
          if (icon) icon.textContent = '+';
        } else {
          answer.style.display = 'block';
          if (icon) icon.textContent = '−';
        }
      });
    });
  }

  function initShopFilter() {
    var filterBtns = document.querySelectorAll('.category-filter-btn');
    var cards = document.querySelectorAll('.product-grid-item');
    if (!filterBtns.length || !cards.length) return;

    filterBtns.forEach(function(btn) {
      btn.addEventListener('click', function() {
        filterBtns.forEach(function(b) { b.classList.remove('active'); });
        this.classList.add('active');
        var cat = this.getAttribute('data-category');
        cards.forEach(function(card) {
          if (cat === 'all' || card.getAttribute('data-category') === cat) {
            card.style.display = 'flex';
          } else {
            card.style.display = 'none';
          }
        });
      });
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    initGate();
    initMobileMenu();
    initHandlers();
    initFAQ();
    initShopFilter();
    renderCart();

    var openBtn = document.getElementById('cart-open-btn');
    if (openBtn) openBtn.addEventListener('click', openCart);
    var closeBtn = document.getElementById('cart-close-btn');
    if (closeBtn) closeBtn.addEventListener('click', closeCart);
    var overlay = document.getElementById('drawer-overlay');
    if (overlay) overlay.addEventListener('click', closeCart);
  });

  window.renderCart = renderCart;
})();
