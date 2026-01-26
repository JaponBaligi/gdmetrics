# GDScript Complexity Analyzer

A Godot EditorPlugin that analyzes GDScript code complexity using Cyclomatic Complexity (CC) and Cognitive Complexity (C-COG) metrics.

## Features

- **Cyclomatic Complexity (CC)**: Measures the number of linearly independent paths through code
- **Cognitive Complexity (C-COG)**: Measures code readability and maintainability
- **Multi-version Support**: Works with Godot 3.5 LTS and Godot 4.2+
- **CLI Mode**: Run analysis from command line for CI/CD integration
- **Editor Integration**: Visual complexity warnings in the script editor
- **JSON Reports**: Export detailed analysis reports
- **Configurable Thresholds**: Set custom complexity limits

## Installation

### Choose Your Branch

This repository uses separate branches for different Godot versions:

- **Godot 3.x**: Use the `main` branch (default)
- **Godot 4.x**: Use the `godot4` branch

### Installation Steps

**For Godot 3.x:**
```bash
git clone <repo-url>
cd godot_cc
# Already on main branch, or: git checkout main
```

**For Godot 4.x:**
```bash
git clone <repo-url>
cd godot_cc
git checkout godot4
```

Then:
1. Copy the `addons/gdscript_complexity` folder to your Godot project's `addons/` directory
2. Open your project in Godot
3. Go to **Project > Project Settings > Plugins**
4. Enable "GDScript Complexity Analyzer"

> **Note**: See [Branch Strategy](docs/BRANCH_STRATEGY.md) for details on why separate branches are used.

## Usage

### Editor Plugin

1. Open the dock panel (should appear automatically when plugin is enabled)
2. Click "Analyze Project" to analyze all GDScript files
3. View results in the dock panel
4. Click on files/functions to see detailed metrics
5. Use "Configure" button to adjust thresholds and settings

### CLI Mode

**Godot 4.x:**
```bash
godot --headless --script cli/ci_test.gd -- --project-path . --output report.json
```

**Godot 3.5:**
```bash
godot --script cli/ci_test.gd -- --project-path . --output report.json
```

The report will be written to `report.json`. On Godot 3.5, a fallback copy is also written to `user://ci_report_fallback.json` (see `OS.get_user_data_dir()` for location).

## Configuration

Create a `complexity_config.json` file in your project root (or refactor `complexity_config.example.json` ):

```json
{
  "include": ["res://**/*.gd"],
  "exclude": ["res://addons/**", "res://tests/**"],
  "cc": {
    "count_logical_operators": true,
    "threshold_warn": 10,
    "threshold_fail": 20
  },
  "cog": {
    "nesting_penalty": 1,
    "threshold_warn": 15,
    "threshold_fail": 30
  },
  "parser": {
    "parser_mode": "balanced",
    "max_expected_errors_per_100_lines": 5
  },
  "performance": {
    "enable_caching": true,
    "cache_path": ".gdcomplexity_cache",
    "incremental_analysis": true
  }
}
```

### Caching System

The analyzer includes a content-based caching system to speed up subsequent analyses:

- **Content-based hashing**: Files are hashed by content (not modification time), so cache remains valid even if files are copied or moved
- **Config-aware**: Cache automatically invalidates when configuration changes
- **Incremental analysis**: Only changed files are re-analyzed, significantly reducing analysis time on large projects
- **Automatic cleanup**: Orphaned cache entries (for deleted files) are automatically removed
- **Disableable**: Set `"enable_caching": false` in the `performance` section to disable

Cache is stored in `.gdcomplexity_cache/` by default (configurable via `cache_path`).

## Supported Versions

| Godot Version | Support Level | Notes |
|---------------|---------------|-------|
| 3.5 LTS | ✅ Full | Primary 3.x target |
| 3.0-3.4 | ⚠️ Best-effort | Should work, not fully tested |
| 4.2 | ✅ Full | Primary 4.x target |
| 4.0-4.1 | ✅ Full | Should work identically |
| 4.3+ | ⚠️ Forward compatibility | Tested as released |

See [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) for detailed compatibility information.

## Complexity Metrics

### Cyclomatic Complexity (CC)

Formula: `CC = 1 (base) + number of decision points`

Decision points include:
- `if`, `elif`, `for`, `while` statements
- `match`/`case` statements (Godot 4.x only)
- Logical operators (`and`, `or`, `not`)

### Cognitive Complexity (C-COG)

Formula: `C-COG = sum of (1 + nesting_depth) for each control structure`

- Each control structure adds +1 base
- Each nesting level adds +1 to the contribution
- `case` statements add +1 regardless of nesting depth

## Report Format

Reports are generated in JSON format:

```json
{
  "project": "my_project",
  "engine_version": "4.2.1",
  "timestamp": "2026-01-26T10:30:00Z",
  "totals": {
    "files_analyzed": 42,
    "total_cc": 342,
    "total_cog": 725,
    "average_cc": 8.14,
    "average_cog": 17.26
  },
  "files": [
    {
      "file": "res://player.gd",
      "confidence": 0.93,
      "file_cc": 16,
      "file_cog": 24,
      "functions": [...]
    }
  ]
}
```

## Testing

Run unit tests:

```bash
# Tokenizer tests
godot --headless --script tests/test_tokenizer_unit.gd

# CC calculator tests
godot --headless --script tests/test_cc_calculator.gd

# C-COG calculator tests
godot --headless --script tests/test_cog_calculator.gd

# Confidence calculator tests
godot --headless --script tests/test_confidence_calculator.gd

# Verify fixtures
godot --headless --script tests/verify_cc_cog.gd
```

## Known Limitations

- **Parser Accuracy**: Block-oriented parser, not full AST. Typical accuracy: 90-93% (Godot 4.x), 85-90% (Godot 3.x)
- **Confidence Cap**: Godot 3.x confidence scores capped at 0.90 maximum
- **Match Statements**: Not supported in Godot 3.x (language limitation)
- **Expression Parsing**: Shallow parsing (by design, sufficient for complexity metrics)

## License

See [LICENSE](LICENSE) file for details.

## Contributing

This is a pre-Phase 5 project. Core functionality is complete, but testing and polish work continues. See [docs/PROGRESS.md](docs/PROGRESS.md) for current status.

## Documentation

- [Branch Strategy](docs/BRANCH_STRATEGY.md) - Branch structure and version support
- [Progress Tracking](docs/PROGRESS.md) - Implementation status
- [Compatibility Matrix](docs/COMPATIBILITY.md) - Version support details
- [Before Phase 5](docs/before5.md) - Pre-Phase 5 roadmap
