import assert from "node:assert/strict";
import { cpSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import test from "node:test";

const repo = process.cwd();
const extensionSource = join(repo, ".pi/extensions/fm-primary-turnend-guard.ts");

async function fixture() {
  const dir = mkdtempSync(join(tmpdir(), "fm-stop-handoff-"));
  const extDir = join(dir, ".pi/extensions");
  const binDir = join(dir, "bin");
  const home = join(dir, "home");
  const state = join(home, "state");
  const data = join(home, "data");
  mkdirSync(join(extDir, "lib"), { recursive: true });
  mkdirSync(binDir, { recursive: true });
  mkdirSync(state, { recursive: true });
  mkdirSync(data, { recursive: true });
  cpSync(extensionSource, join(extDir, "fm-primary-turnend-guard.ts"));
  cpSync(join(repo, ".pi/extensions/lib/fm-operational-input.ts"), join(extDir, "lib/fm-operational-input.ts"));
  cpSync(join(repo, "bin/fm-operational-input.sh"), join(binDir, "fm-operational-input.sh"));
  for (const script of ["fm-arm-pretool-check.sh", "fm-cd-pretool-check.sh"]) {
    writeFileSync(join(binDir, script), "#!/bin/sh\nexit 0\n", { mode: 0o700 });
  }
  const handoff = join(data, "HANDOFF-AUTO.md");
  const handoffLog = join(dir, "handoff.log");
  const attestLog = join(dir, "attest.log");
  const helper = join(binDir, "auto-handoff");
  writeFileSync(helper, `#!/bin/sh\nprintf '%s\\n' "$1" >> "$FM_HANDOFF_LOG"\nprintf '# Current handoff\\nReason: %s\\n' "$1" > "$FM_HANDOFF_PATH"\nmkdir -p "$FM_HOME/state/attestations"\nprintf '1\\t1\\tFIRED\\twrite\\n' >> "$FM_HOME/state/attestations/auto-handoff.tsv"\n`, { mode: 0o700 });
  const attest = join(binDir, "guard-attest");
  writeFileSync(attest, `#!/bin/sh\nprintf '%s\\t%s\\n' "$2" "$3" >> "$FM_ATTEST_LOG"\n`, { mode: 0o700 });
  const previous = new Map<string, string | undefined>();
  for (const [key, value] of Object.entries({
    FM_HOME: home,
    FM_AUTO_HANDOFF_PATH: helper,
    FM_HANDOFF_PATH: handoff,
    FM_HANDOFF_LOG: handoffLog,
    FM_GUARD_ATTEST_PATH: attest,
    FM_ATTEST_LOG: attestLog,
  })) {
    previous.set(key, process.env[key]);
    process.env[key] = value;
  }
  const handlers = new Map<string, (...args: any[]) => any>();
  const mod = await import(`${pathToFileURL(join(extDir, "fm-primary-turnend-guard.ts")).href}?fixture=${Date.now()}-${Math.random()}`);
  mod.default({ on: (name: string, handler: (...args: any[]) => any) => handlers.set(name, handler) });
  return {
    dir, home, state, data, handoff, handoffLog, attestLog, handlers,
    async close() {
      for (const [key, value] of previous) {
        if (value === undefined) delete process.env[key]; else process.env[key] = value;
      }
      rmSync(dir, { recursive: true, force: true });
    },
  };
}

async function settle(f: Awaited<ReturnType<typeof fixture>>) {
  await f.handlers.get("agent_settled")?.({ type: "agent_settled" }, {});
}

function handoffCount(path: string): number {
  return existsSync(path) ? readFileSync(path, "utf8").trim().split("\n").length : 0;
}

test("turn-end persists current handoff for each real in-flight source", async () => {
  const cases: Array<[string, (f: Awaited<ReturnType<typeof fixture>>) => void]> = [
    ["tracked lane", (f) => { writeFileSync(join(f.state, ".factory-lanes.tsv"), "lane-1\tcontroller\tp1\n"); }],
    ["open inbox ticket", (f) => { mkdirSync(join(f.home, "INBOX")); writeFileSync(join(f.home, "INBOX/1.md"), "open\n"); }],
    ["FIRED guard", (f) => { mkdirSync(join(f.state, "attestations")); writeFileSync(join(f.state, "attestations/factory-queue.tsv"), "1\t1\tFIRED\ttrip\n"); }],
    ["ready unlanded artifact", (f) => { mkdirSync(join(f.data, "imports-20261015/a"), { recursive: true }); writeFileSync(join(f.data, "imports-20261015/a/report.md"), "VERDICT: PASS\n"); }],
  ];
  for (const [name, addState] of cases) {
    const f = await fixture();
    try {
      addState(f);
      await settle(f);
      assert.ok(existsSync(f.handoff), `${name} should write handoff`);
      assert.match(readFileSync(f.handoff, "utf8"), /Reason:/);
      assert.match(readFileSync(f.attestLog, "utf8"), /turn-end-handoff\tFIRED/, `${name} should attest the invocation`);
    } finally { await f.close(); }
  }
});

test("idle turn-end writes no handoff and still attests its invocation", async () => {
  const f = await fixture();
  try {
    await settle(f);
    assert.equal(existsSync(f.handoff), false);
    assert.match(readFileSync(f.attestLog, "utf8"), /CLEAR/);
  } finally { await f.close(); }
});

test("changed underlying state refreshes an existing handoff", async () => {
  const f = await fixture();
  try {
    mkdirSync(join(f.home, "INBOX"));
    writeFileSync(join(f.home, "INBOX/1.md"), "first\n");
    await settle(f);
    const first = readFileSync(f.handoff, "utf8");
    await settle(f);
    assert.equal(handoffCount(f.handoffLog), 1, "unchanged state should not rewrite the handoff");
    writeFileSync(join(f.home, "INBOX/1.md"), "changed\n");
    await settle(f);
    assert.equal(handoffCount(f.handoffLog), 2);
    assert.notEqual(readFileSync(f.handoff, "utf8"), first);
  } finally { await f.close(); }
});

test("degradation trip-wire writes handoff before returning a block", async () => {
  const f = await fixture();
  try {
    const handler = f.handlers.get("tool_call");
    assert.ok(handler);
    const event = { type: "tool_call", toolName: "bash", input: { command: "printf same" } };
    assert.deepEqual(await handler(event), {});
    assert.deepEqual(await handler(event), {});
    const blocked = await handler(event);
    assert.equal(blocked.block, true);
    assert.ok(existsSync(f.handoff), "handoff must exist before block returns");
    assert.match(blocked.reason, /hand back control/i);
    assert.match(readFileSync(f.attestLog, "utf8"), /FIRED/);
  } finally { await f.close(); }
});
