"use client";

import Script from "next/script";

export default function ChatWidgetLoader() {
  return (
    <>
      {/* AnythingLLM Chat Widget — CSS positioning for landing page visibility */}
      <style
        dangerouslySetInnerHTML={{
          __html: `
            #anything-llm-chat-widget-button {
              position: fixed !important;
              bottom: 20px !important;
              right: 20px !important;
              z-index: 9999 !important;
            }
            #anythingllm-chat-widget-window,
            [id^="anythingllm-chat-widget"] {
              max-width: 100vw !important;
              max-height: 100dvh !important;
              right: 0 !important;
              bottom: 0 !important;
              z-index: 9998 !important;
              overflow: hidden !important;
            }
            @media (max-width: 768px) {
              #anythingllm-chat-widget-window,
              [id^="anythingllm-chat-widget"] {
                width: 100vw !important;
                left: 0 !important;
                border-radius: 0 !important;
              }
            }
          `,
        }}
      />
      {/* AnythingLLM Chat Widget — loaded after page is interactive */}
      <Script
        id="anything-llm-embed"
        data-cfasync="false"
        data-embed-id="0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2"
        data-base-api-url="https://llm.hd2.ai/api/embed"
        data-assistant-name="Core Distro Assistant"
        data-brand-image-url="https://core-distro.com/core-distro-mark-green.png"
        data-assistant-icon="https://core-distro.com/core-distro-mark-green.png"
        data-chat-icon="chatBubble"
        data-user-bg-color="#00d455"
        data-sponsor-text="Powered by HD2.ai"
        data-sponsor-link="https://hd2.ai"
        src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js"
        strategy="afterInteractive"
      />
    </>
  );
}
