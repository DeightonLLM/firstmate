# Surface topology — what every surface must know

Captain order, 2026-10-17. **This is the standing answer to "where does it run" and it applies to every
coding surface, including any agent on any machine.** If a surface disagrees with this file, the surface
is wrong and this file wins.

## The four surfaces

| Surface | Identity | Role |
|---|---|---|
| **Controller** | `vmi3196300` | The Captain's surface. **Coordinator only.** Home of the todo tracker, the dashboard and the visuals. Does not execute client work. |
| **HD2Stack** | Contabo, herdr machine `hd2stack` | **Primary firstmate and the execution surface.** Holds the queue, spawns the lanes, owns Hetz's traffic end to end, and produces the artifacts. |
| **Hetz / Brandon** | `100.106.6.22`, herdr machine `7151b9a32844b4c733749d5d353397ff` | Owns Core-Distro staging and elevatesci. Works from his own queue, instructed by HD2. |
| **Elevate VPS** | `srv1137994-elevatesci`, alias `elevatesci-vps` | Being provisioned as an additional **coding surface**. Hostinger. |

## The one rule

**HD2Stack is the firstmate. The Controller is the Captain's surface and nothing else.**

- Hetz's traffic routes to **HD2Stack**, never to the Controller.
- The Controller dispatches nothing and reports nothing it has not read.
- Any agent on any surface that needs to know where something runs reads this file first, and if its
  local docs disagree, this file is authoritative.

## Layout standard on every surface

Standard blast is **four lanes, 2x2**. Fewer only when there is genuinely less work.

```
4 lanes  ->  2x2 equal grid, split ratio 0.5 exactly
2 lanes  ->  side by side, left/right, ratio 0.5
1 lane   ->  single full-size pane
never 3, never 5+
never stacked pairs
never a lane held open just to fill a grid
```

On a surface whose only live panes are the **firstmate** and the **quota-axi window**, that is a
**1x1** arrangement — firstmate full size, quota-axi alongside. Do not invent panes to reach four.

## Open, in the Captain's order

1. Elevate VPS (`srv1137994-elevatesci`) provisioned as a coding surface.
2. KVM1 revisited — the Captain does the logins personally.
3. HD2Stack surface made presentable: the firstmate and the quota-axi window preserved exactly as the
   Captain has them, documented so they survive.
4. HD2Stack's main task goes to the top of the queue: spawn four agents as the standard blast.

## Standing rules that travel with this

- A named agent for every lane. No anonymous fan-out.
- Artifact plus `VERDICT:` before anything is called done.
- Independent review before a completed item is reported as done.
- Measurement gates believing; review gates reporting.
- Never assert a fact about a host, service, path or screen without reading it live.
- No spending, no DNS, no credential mutation, no production deploy without the Captain.

VERDICT: PASS this file is the topology answer every surface must carry; a surface that disagrees is
the defect.