import assert from "node:assert/strict";
import { existsSync } from "node:fs";

const extensionPath = "/root/.pi/agent/extensions/herdr-lane-status.ts";
assert.ok(existsSync(extensionPath), "global Herdr lane-status extension must be installed");

process.env.HERDR_PANE_ID = "wBF:p99";
process.env.HERDR_SESSION = "lane-test";

const { default: register } = await import(`file://${extensionPath}`);
const handlers = new Map();
register({ on: (event, handler) => handlers.set(event, handler) });

for (const event of ["session_start", "model_select", "turn_start", "turn_end"]) {
	assert.equal(typeof handlers.get(event), "function", `${event} handler is registered`);
}

const statuses = [];
const titles = [];
const ctx = {
	model: { provider: "zai", id: "glm-5.3-flash" },
	ui: {
		theme: { fg: (color, text) => `<${color}>${text}` },
		setStatus: (key, text) => statuses.push({ key, text }),
		setTitle: (title) => titles.push(title),
	},
};

await handlers.get("session_start")({}, ctx);
assert.match(statuses.at(-1).text, /GLM53/);
assert.match(statuses.at(-1).text, /wBF:p99/);
assert.match(statuses.at(-1).text, /accent/);

await handlers.get("turn_start")({}, ctx);
assert.match(statuses.at(-1).text, /RUNNING/);

await handlers.get("turn_end")({}, ctx);
assert.match(statuses.at(-1).text, /READY/);
assert.match(statuses.at(-1).text, /success/);
assert.match(titles.at(-1), /GLM53/);

ctx.model = { provider: "minimax", id: "MiniMax-M3" };
await handlers.get("turn_start")({}, ctx);
assert.match(statuses.at(-1).text, /M3/);
assert.match(statuses.at(-1).text, /warning/);

await handlers.get("model_select")({ model: { provider: "google", id: "gemini-3.8-flash-medium" } }, ctx);
assert.match(statuses.at(-1).text, /AGY/);
assert.match(statuses.at(-1).text, /success/);

console.log("PASS pi-lane-status: model, pane, state, color, and title evidence");
