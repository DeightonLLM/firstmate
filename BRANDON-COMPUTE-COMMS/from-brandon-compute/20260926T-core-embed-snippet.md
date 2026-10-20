# CORE Distro Assistant — Embedded Chat Widget Snippet

**Saved:** 2026-09-26T20:18 BST
**From:** brandon-compute (AnythingLLM controller `hd2stack-anythingllm`)
**Mission:** hd2stack-anythingllm branding worker

## Snippet (paste into target page `<body>` end, before `</body>`)

```html
<script
  data-cfasync="false"
  data-embed-id="EMBED_ID_PENDING"
  data-base-api-url="https://agents.elevatesci.com/api/embed"
  data-assistant-name="Core Distro Assistant"
  data-brand-image-url="https://core-distro.com/core-distro-logo-white_ce3460b1.webp"
  src="https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js"
></script>
```

## Attributes

| Attribute | Value | Purpose |
|-----------|-------|---------|
| `data-embed-id` | `EMBED_ID_PENDING` | Replace with the per-workspace AnythingLLM embed slug once provisioned. |
| `data-base-api-url` | `https://agents.elevatesci.com/api/embed` | AnythingLLM embed API base on this controller. |
| `data-assistant-name` | `Core Distro Assistant` | Display name shown in the chat header. |
| `data-brand-image-url` | `https://core-distro.com/core-distro-logo-white_ce3460b1.webp` | Brand logo URL injected as the assistant icon. |
| `src` | `https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js` | Patched client widget (rebranded to HD2.ai). |

## Notes

- The served widget script (`anythingllm-chat-widget.min.js`) has been patched in place on `hd2stack-anythingllm`; visible branding now reads "Powered by HD2.ai" and the assistant defaults to "HD2.ai Chat Assistant".
- Lowercase internal identifiers (`anythingllm-chat-widget.min.js`, `EmbeddedAnythingLLM`, sponsorLink URL, event names like `___anythingllm-chat-widget-open___`) were intentionally NOT renamed — they are file paths and runtime symbols, not user-visible branding. Renaming them would break the embed.
- Once `EMBED_ID_PENDING` is replaced with the actual embed slug from the Core Distro AnythingLLM workspace, the snippet is production-ready.
- This controller serves multiple client bots from the same AnythingLLM instance via distinct `data-embed-id` values. The widget itself is shared; only the embed ID and brand attributes differ per client.
