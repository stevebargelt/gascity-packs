# Gasworks Pack

Product development workflow pack for Gas City. Adds a strategic planning layer — PM, Researcher, Architect — between human intent and polecat execution.

**Repo**: [github.com/stevebargelt/gascity-packs](https://github.com/stevebargelt/gascity-packs)
**Current version**: 0.2.0

---

## Agents

### Product Manager (PM)
- **Type**: Singleton per rig
- **Trigger**: Bead assigned to `<rig>/pm` with `needs-prd` label
- **Role**: Understands request, coordinates research, writes PRD, mails crew for review
- **Outputs**: `docs/prds/<bead-id>.md`

### Product Researcher
- **Type**: Pool (min=0, max=4) per rig
- **Trigger**: Child bead assigned to pool via `--label pool:<rig>/product-researcher`
- **Role**: Focused research on a single question; writes findings to bead notes + `docs/research/<bead-id>.md`
- **Namepool**: Famous scientists (einstein, curie, tesla, etc.)

### Architect
- **Type**: Singleton per rig
- **Trigger**: Crew manually assigns PRD-approved bead to `<rig>/architect`
- **Role**: Reads approved PRD + research docs, designs system architecture, produces architecture doc with Mermaid diagrams, mails crew for review
- **Outputs**: `docs/architecture/<bead-id>.md`

---

## Human-in-the-Loop Gates

| Gate | After | Before | Who reviews |
|------|-------|--------|-------------|
| PRD Review | PM writes PRD | Architect receives work | Crew + human |
| Architecture Review | Architect writes arch doc | Polecats execute | Crew + human |

Gates are enforced by convention: agents mail crew and wait. No work auto-advances past a gate.

---

## Workflow

### Route work to the PM

```bash
# Create a bead describing the work
bd create "Feature: real-time notifications" -t feature \
  -d "Users need instant updates without polling..." \
  --label needs-prd

# Assign to PM and nudge to wake it
gc sling <rig>/pm <bead-id>
gc nudge <rig>/pm "New PRD assignment: <bead-id>"
```

### PM → Crew (PRD review)
PM sends mail + nudge to crew automatically when PRD is complete.

### Crew approves PRD → Architect
```bash
# Assign to architect and nudge
bd update <bead-id> --assignee <rig>/architect
gc nudge <rig>/architect "PRD approved, architecture needed: <bead-id>"
```

### Architect → Crew (architecture review)
Architect sends mail + nudge to crew automatically when architecture doc is complete.

### Crew approves architecture → Polecats
```bash
# Create child beads from work breakdown, sling to polecats
bd create "Implement SSE endpoint" --parent <bead-id> -t task
gc sling <rig>/polecat <child-bead-id>
```

---

## Adding to a Rig

In `city.toml`, include both gastown (required base) and gasworks:

```toml
[[rigs]]
name = "my-rig"
path = "/path/to/rig"
includes = ["packs/gastown", "packs/gasworks"]
```

---

## Output Directories

| Path | Written by | Contents |
|------|-----------|----------|
| `docs/prds/` | PM | PRD documents |
| `docs/research/` | Product Researchers | Research findings |
| `docs/architecture/` | Architect | Architecture documents with Mermaid diagrams |

---

## Picking Up Pack Updates

The gasworks pack lives in a separate git repo (`packs/`) that is independent of the city repo. When the pack is updated, rigs must explicitly pull and restart to pick up changes.

### Step 1 — Pull latest pack changes

```bash
cd /path/to/your-city/packs
git pull
```

Verify what changed:
```bash
git log --oneline -10
git diff HEAD~1 HEAD -- gasworks/
```

### Step 2 — Identify what needs restarting

| What changed | What to restart |
|-------------|----------------|
| Prompt templates only (`prompts/*.md.tmpl`) | Only affected agents |
| `pack.toml` (new agents, config changes) | Entire rig |
| Overlay settings (`overlays/`) | Entire rig |

### Step 3a — Restart individual agents (prompt-only changes)

```bash
# Restart just the PM
gc agent restart <rig>/pm

# Restart just the architect
gc agent restart <rig>/architect
```

Agents pick up the new prompt template on their next session start.

### Step 3b — Restart entire rig (pack.toml or overlay changes)

```bash
# Kill all rig agents — reconciler restarts them automatically
gc rig restart <rig-name>
```

This restarts all agents in the rig (pm, architect, researchers, polecats, witness, refinery). The reconciler picks up on its next tick and starts them fresh with the updated config.

### Step 4 — Verify

```bash
gc rig status <rig-name>
```

Agents should show `running` within a few seconds of the reconciler tick.

### Notes

- **In-flight work is safe**: Restarting agents does not affect beads or bead state. Agents resume from their hook/mail on restart.
- **pack.toml new agents**: If `pack.toml` adds a new agent type (e.g., a new role), a full rig restart is required. The reconciler reads pack.toml at startup.
- **Overlay changes**: If hook config in `overlays/` changed, a full restart is required for new hooks to take effect.
- **Multiple rigs**: If multiple rigs include `packs/gasworks`, repeat the restart for each affected rig.

---

## Versioning

Pack version is in `pack.toml` under `[pack] version`. Changes follow semver:
- **Patch** (0.2.x): Prompt improvements, bug fixes — restart agents
- **Minor** (0.x.0): New agents or significant workflow changes — restart rig
- **Major** (x.0.0): Breaking changes to workflow or agent interfaces — review release notes before pulling
