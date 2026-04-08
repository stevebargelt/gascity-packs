# Gas City Packs

Collection of reusable agent packs for Gas City.

## Packs

### Gasworks
Product development workflow pack.

**Agents**:
- **Product Manager (PM)**: Singleton, writes PRDs, coordinates research
- **Product Researcher**: Pool (max 4), parallel research tasks

**Usage**: For complex work requiring strategic planning before implementation.

See [gasworks/README.md](gasworks/README.md) for details.

### Gastown
Domain-specific coding workflow pack.

**Agents**:
- **Mayor**: Global coordinator (city-scoped)
- **Deacon**: Town-wide patrol executor (city-scoped)
- **Boot**: Deacon watchdog (city-scoped, ephemeral)
- **Witness**: Per-rig worker monitor (rig-scoped)
- **Refinery**: Merge queue processor (rig-scoped)
- **Polecat**: Transient worker pool (rig-scoped)
- **Dog**: Infrastructure utility workers (city-scoped pool)

**Usage**: Full multi-agent orchestration for coding workflows.

See [gastown/pack.toml](gastown/pack.toml) for configuration.

## Installation

### In city.toml

```toml
# Reference packs from this repo
[packs.gasworks]
source = "https://github.com/stevebargelt/gascity-packs.git"
ref = "main"
path = "gasworks"

[packs.gastown]
source = "https://github.com/stevebargelt/gascity-packs.git"
ref = "main"
path = "gastown"

# Apply to rigs
[[rigs]]
name = "my-rig"
path = "/path/to/rig"
includes = ["packs/gasworks", "packs/gastown"]
```

### Local Development

Clone this repo and reference locally:

```toml
[[rigs]]
name = "my-rig"
includes = ["../path/to/gascity-packs/gasworks"]
```

## Pack Versioning

Use git tags for version pinning:

```toml
[packs.gasworks]
source = "https://github.com/stevebargelt/gascity-packs.git"
ref = "v0.1.0"  # or "main" for latest
path = "gasworks"
```

## Contributing

Each pack is self-contained in its directory with:
- `pack.toml` - Agent definitions
- `prompts/` - Agent prompt templates
- `namepools/` - Agent name pools (optional)
- `overlays/` - Claude settings overlays (optional)
- `scripts/` - Setup/utility scripts (optional)
- `formulas/` - Workflow formulas (optional)
- `README.md` - Pack documentation

## License

MIT
