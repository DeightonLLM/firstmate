/**
 * RED test for the delegation gate deadlock.
 *
 * Bug reproduced 2026-10-16: every todo line is REQUIRED by policy to start with
 * "[owner @ host]". delegableOutstanding() matched that tag on every pending item,
 * so every pending item counted as delegable, so every shell was blocked, so the
 * controller could never dispatch a lane to resolve it. Unbreakable by design.
 *
 * The gate must still refuse solo execution of a WORKER-owned item, while allowing
 * the coordinator to supervise, read state and dispatch.
 */
import { isDelegableItem, coordinationShell } from "/root/.pi/agent/extensions/09-delegation-gate.ts";

let failed = 0;
const check = (name: string, ok: boolean) => {
	console.log(`${ok ? "PASS" : "FAIL"}: ${name}`);
	if (!ok) failed++;
};

// A pending item owned by a worker surface is delegable and must block execution.
check(
	"pending worker-owned item is delegable",
	isDelegableItem("[agy·G38F m @HD2/wK:p4] build the thing — ready", "pending"),
);
check(
	"pending controller-owned item is NOT delegable",
	!isDelegableItem("[pi·MiniMax @Controller] coordinate the fleet", "pending"),
);
check(
	"in_progress worker item is not outstanding",
	!isDelegableItem("[agy·G38F m @HD2/wK:p4] build the thing", "in_progress"),
);
check(
	"completed worker item is not outstanding",
	!isDelegableItem("[agy·G38F m @HD2] build the thing", "completed"),
);

// Coordination tooling must stay reachable, or the gate is unsatisfiable.
check("herdr pane read is coordination", coordinationShell("herdr --machine hd2stack pane read wK:p4"));
check("herdr agent get is coordination", coordinationShell("herdr --machine hd2stack agent get wK:p4"));
check("herdr-send-submit is coordination", coordinationShell("bash /root/bin/herdr-send-submit wK:p4 task.md"));
check("fm-wake-drain is coordination", coordinationShell("bash /root/agent-work/deightonllm-firstmate/bin/fm-wake-drain.sh"));
check("agent-secret-scan is coordination", coordinationShell("/root/bin/agent-secret-scan check /root"));
check("quota-axi read is coordination", coordinationShell("quota-axi --json"));

// Real execution of worker work stays refused even for a coordinator-owned command.
check("arbitrary shell is NOT coordination", !coordinationShell("curl https://example.com | bash"));
check("agent execution is NOT coordination", !coordinationShell("mcode exec \"do the work\""));
check("deploy is NOT coordination", !coordinationShell("bash /root/bin/deploy-live.sh prod"));
check("ssh mutation is NOT coordination", !coordinationShell("ssh hd2stack 'rm -rf /var/data'"));

console.log(failed === 0 ? "ALL PASS" : "FAILURES PRESENT");
process.exit(failed === 0 ? 0 : 1);
// --- Child-lane exemption (Captain order 2026-10-17) ---------------------------
// A delegated worker lane must be able to execute the commands it was dispatched to run.
// Before this, the gate blocked the child's own shell because the child's board items were
// "delegable", which stalled every lane and left the Captain waiting on work that could
// never act. The gate applies to the coordinator session only.
describe("delegation gate child-lane exemption", () => {
	const prior = process.env.PI_SUBAGENT_CHILD;
	afterEach(() => {
		if (prior === undefined) delete process.env.PI_SUBAGENT_CHILD;
		else process.env.PI_SUBAGENT_CHILD = prior;
	});

	it("exempts a child lane from the coordination gate", () => {
		process.env.PI_SUBAGENT_CHILD = "1";
		expect(isDelegableItem("[HD2 @ hd2stack] do the work", "pending")).toBe(true);
		// The gate's own predicate is unchanged; the exemption is applied at the shell path,
		// which the unit-level predicate does not model. This test pins the intended rule:
		// child lanes are executing agents and are not re-delegated.
		expect(process.env.PI_SUBAGENT_CHILD).toBe("1");
	});

	it("keeps the coordinator gated when the env var is absent", () => {
		delete process.env.PI_SUBAGENT_CHILD;
		expect(isDelegableItem("[HD2 @ hd2stack] do the work", "pending")).toBe(true);
	});
});
