/* mm-widget-think-shim — masks <think>...</think> blocks in widget text
 * Appended to anythingllm-chat-widget.min.js. Self-contained, ES5, never throws.
 */
;(function () {
  try {
    var THINK_OPEN = '<think>';
    var THINK_CLOSE = '</think>';
    var THINK_CLOSE_LEN = THINK_CLOSE.length;
    var SKIP_TAGS = { SCRIPT: 1, STYLE: 1, TEXTAREA: 1, INPUT: 1, CODE: 1, PRE: 1 };
    var scheduled = false;
    var pendingNodes = [];

    function isElement(node) {
      return !!node && node.nodeType === 1;
    }

    function shouldSkip(node) {
      var p = node && node.parentNode;
      while (isElement(p)) {
        if (SKIP_TAGS[p.nodeName]) return true;
        p = p.parentNode;
      }
      return false;
    }

    function processTextNode(node) {
      if (!node || node.nodeType !== 3) return false;
      var text = node.nodeValue;
      if (!text || text.indexOf(THINK_OPEN) === -1) return false;
      if (shouldSkip(node)) return false;
      var beforeLen = text.length;
      var result = '';
      var cursor = 0;
      while (cursor < text.length) {
        var openIdx = text.indexOf(THINK_OPEN, cursor);
        if (openIdx === -1) {
          result += text.substring(cursor);
          break;
        }
        result += text.substring(cursor, openIdx);
        var closeIdx = text.indexOf(THINK_CLOSE, openIdx + THINK_OPEN.length);
        if (closeIdx === -1) {
          break; // unclosed — drop everything from here on
        }
        cursor = closeIdx + THINK_CLOSE_LEN;
      }
      node.nodeValue = result;
      return result.length < beforeLen;
    }

    function collectTargets(root) {
      if (!root) return;
      if (root.nodeType === 3) {
        pendingNodes.push(root);
        return;
      }
      var w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
        acceptNode: function (n) {
          if (!n.nodeValue || n.nodeValue.indexOf(THINK_OPEN) === -1) {
            return NodeFilter.FILTER_REJECT;
          }
          if (shouldSkip(n)) return NodeFilter.FILTER_REJECT;
          return NodeFilter.FILTER_ACCEPT;
        }
      });
      var n;
      while ((n = w.nextNode())) pendingNodes.push(n);
    }

    function flush() {
      scheduled = false;
      var nodes = pendingNodes;
      pendingNodes = [];
      for (var i = 0; i < nodes.length; i++) {
        try { processTextNode(nodes[i]); } catch (_e) { /* swallow per node */ }
      }
    }

    function schedule(root) {
      if (root) collectTargets(root);
      if (scheduled) return;
      scheduled = true;
      setTimeout(flush, 200);
    }

    function startObserver() {
      if (!document.body) {
        var bt = setInterval(function () {
          if (document.body) { clearInterval(bt); startObserver(); }
        }, 50);
        return;
      }
      try {
        var mo = new MutationObserver(function (muts) {
          for (var i = 0; i < muts.length; i++) {
            var m = muts[i];
            if (m.addedNodes && m.addedNodes.length) {
              for (var j = 0; j < m.addedNodes.length; j++) {
                schedule(m.addedNodes[j]);
              }
            }
            if (m.type === 'characterData' && m.target) {
              schedule(m.target);
            }
          }
        });
        mo.observe(document.body, { childList: true, subtree: true, characterData: true });
      } catch (_e) { /* no observer — fall back to full scan */ }
      schedule(document.body);
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', startObserver, { once: true });
    } else {
      startObserver();
    }
  } catch (_e) {
    /* never break the widget */
  }
})();
