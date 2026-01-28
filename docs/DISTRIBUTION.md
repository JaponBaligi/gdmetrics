## Distribution Preparation

This project ships as a zip that contains the plugin, documentation, and an
example configuration. CI builds the release artifact on version tags.

### Release Contents

The release package includes:
- `addons/gdscript_complexity/`
- Documentation files in `docs/`
- `README.md`, `LICENSE`
- `complexity_config.example.json`

For the full list, see `release/manifest.txt`.

### Version Tagging

Use semantic version tags:
- `vMAJOR.MINOR.PATCH` (example: `v1.0.0`)

Tagging triggers the release job in CI, which creates a zip artifact.

### Example Config

Use `complexity_config.example.json` as a starting point for end users.

### Installation

Installation steps are in `docs/USER_GUIDE.md`.
