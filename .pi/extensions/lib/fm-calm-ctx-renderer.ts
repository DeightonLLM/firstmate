// Firstmate Calm's quiet presentation for the lean-ctx ctx_* tool surface.
//
// Calm hides routine built-in tool rows by wrapping the built-in tool
// definitions. The lean-ctx ctx_* tools are registered by a different
// extension, so Calm reaches them through the supported resolver API
// (pi.registerToolRenderer) instead of wrapping definitions it does not own.
//
// This module changes presentation only. Tool definitions, execution,
// model-visible results, events, and lean-ctx's cache, compression, tool
// definitions and permission enforcement are untouched. An errored result is
// never hidden: errors and refusals stay visible so they remain discoverable.
import { Container } from "@earendil-works/pi-tui";
import type { ToolRenderers } from "@earendil-works/pi-coding-agent";
import { calmPresentationHides } from "./fm-calm-visibility.ts";

// The lean-ctx tool surface, matched exactly as lean-ctx matches it itself
// when it lists its own active tools.
export function isCalmCtxToolName(toolName: string): boolean {
  return toolName.startsWith("ctx_") || toolName === "lean_ctx";
}

export type CalmCtxRendererState = {
  // Calm's own local export-rendering flag, the same one the built-in
  // wrappers check before they hide a row.
  exportRendering: boolean;
};

// Returns the renderers Calm uses for one ctx_* tool.
// `inherited` is what the remaining resolvers, then the registered tool, would
// have used; it is returned unchanged whenever Calm must not hide the row.
export function createCalmCtxToolRenderers(
  inherited: ToolRenderers | undefined,
  state: CalmCtxRendererState,
): ToolRenderers | undefined {
  if (state.exportRendering) return inherited;
  if (!calmPresentationHides("assistant-tool-call")) return inherited;

  return {
    // The tool renders its own framing, so an empty component leaves no row
    // behind at all, exactly like the hidden built-in rows.
    renderShell: "self",
    renderCall: () => new Container(),
    renderResult: (result, options, theme, context) => {
      if (context?.isError) {
        if (!inherited?.renderResult) {
          // Pi falls back to its own generic result rendering when a result
          // renderer fails, so the error stays visible instead of being hidden.
          throw new Error("Firstmate Calm: no inherited renderer for an errored ctx_* result");
        }
        return inherited.renderResult(result, options, theme, context);
      }
      return new Container();
    },
  };
}
