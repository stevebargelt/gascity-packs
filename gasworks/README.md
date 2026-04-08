# Gasworks Pack

Product development workflow pack for Gas City.

## Overview

Gasworks adds a strategic planning layer between human/crew and execution (polecats). Instead of going directly from idea to implementation, complex work flows through product management for requirements gathering and PRD creation.

## Agents

### Product Manager (PM)
- **Type**: Singleton per rig
- **Role**: Writes PRDs, coordinates research, defines work breakdown
- **Workflow**: Receives beads labeled `needs-prd`, spawns researchers, writes PRD, hands off to crew

### Product Researcher
- **Type**: Pool (max 4)
- **Role**: Executes focused research tasks in parallel
- **Workflow**: Picks up research beads from pool, investigates, reports findings, exits
- **Namepool**: Famous scientists (einstein, curie, tesla, etc.)

## Usage

### In city.toml

```toml
[[rigs]]
name = "my-rig"
path = "/path/to/rig"
includes = ["packs/gasworks"]
```

### Workflow

**Simple work** (direct to polecats):
```bash
bd create "Fix typo in README" -t task
bd update ga-123 --label pool:my-rig/polecat
```

**Complex work** (needs PRD):
```bash
# 1. Create bead for feature
bd create "Add real-time notifications" -t feature -d "Users need instant updates..."

# 2. Assign to PM
bd update ga-456 --assignee my-rig/pm --label needs-prd

# 3. Nudge PM to start
gc nudge my-rig/pm "New PRD assignment: ga-456"

# 4. PM researches (spawns product-researcher pool if needed)
# 5. PM writes PRD to docs/prds/ga-456.md
# 6. PM mails crew for review

# 7. Crew reviews PRD with human
# 8. If approved, crew creates child beads from work breakdown
bd create "Implement SSE endpoint" --parent ga-456 -t task
bd create "Add EventSource client" --parent ga-456 -t task
# ... more tasks ...

# 9. Sling tasks to polecats
bd update ga-457 --label pool:my-rig/polecat
bd update ga-458 --label pool:my-rig/polecat
```

## PRD Structure

PRDs are written to `docs/prds/{bead-id}.md` with:
- Problem statement
- Goals & success metrics
- Solution overview
- Research findings (if applicable)
- Work breakdown (specific tasks)
- Acceptance criteria
- Open questions
- Out of scope

## Research Output

Researchers write dual output:
- **Bead notes**: 2-4 sentence summary
- **Markdown file**: `docs/research/{bead-id}.md` with detailed findings

## Integration with Gastown

Gasworks is designed to complement Gastown (polecats, witness, refinery):
- **PM** writes PRDs → **Crew** creates beads → **Polecats** implement
- **Product Researchers** investigate → **PM** synthesizes → **Crew** decides → **Polecats** execute

## Version

Current: 0.1.0

## Future Additions

- **Architect**: Receives PRDs needing architectural decisions, outputs architecture docs
- **Tech Lead**: (TBD)
- **QA**: (TBD)
