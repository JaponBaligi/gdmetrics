# GDScript Complexity Analyzer

**gdmetrics is a static analyzer that measures code complexity and maintainability metrics for Godot (GDScript) projects.**

> ***bad code, target PCs / optimized code, target electricity.***

A Godot EditorPlugin that analyzes GDScript code complexity using Cyclomatic Complexity (CC) and Cognitive Complexity (C-COG) metrics.

## Who Is This For?

- **Godot developers** working on medium to large projects
- **Developers preparing for refactoring** who need metrics to guide prioritization
- **Anyone tracking CC / CCOG-style complexity metrics** as part of code quality standards
- **CI/CD pipelines** that want to enforce complexity thresholds

## Why Use This?

- **Identify risky scripts** before refactoring (find high-complexity code early)
- **Measure technical debt growth** over time with automated reports
- **Use metrics as part of code review** to guide refactoring efforts
- **Set complexity thresholds** to prevent complexity regression in your codebase

## Features

- **Cyclomatic Complexity (CC)**: Measures the number of linearly independent paths through code
- **Cognitive Complexity (C-COG)**: Measures code readability and maintainability
- **Multi-version Support**: Works with Godot 3.5 LTS and Godot 4.2+
- **CLI Mode**: Run analysis from command line for CI/CD integration
- **Editor Integration**: Visual complexity warnings in the script editor
- **JSON Reports**: Export detailed analysis reports
- **CSV Reports**: Export per-function metrics
- **Configurable Thresholds**: Set custom complexity limits

## Installation

### Choose Your Branch

This repository uses separate branches for different Godot versions:

- **Godot 3.x**: Use the `main` branch (default)
- **Godot 4.x**: Use the `godot4` branch

### Installation Steps

**For Godot 3.x:**
```bash
git clone https://github.com/JaponBaligi/gdmetrics
cd gdmetrics
# Already on main branch, or: git checkout main
```

**For Godot 4.x:**
```bash
git clone https://github.com/JaponBaligi/gdmetrics
cd gdmetrics
git checkout godot4
```

Then:
1. Copy the `addons/gdscript_complexity` folder to your Godot project's `addons/` directory
2. Open your project in Godot
3. Go to **Project > Project Settings > Plugins**
4. Enable "GDScript Complexity Analyzer"

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
godot --headless --script cli/ci_test.gd -- --project-path . --output report.json --csv-output report.csv
```

**Godot 3.5:**
```bash
godot --script cli/ci_test.gd -- --project-path . --output report.json --csv-output report.csv
```

The report will be written to `report.json`. On Godot 3.5, a fallback copy is also written to `user://ci_report_fallback.json` (see `OS.get_user_data_dir()` for location).

## Example Output

### Console Output

When analysis completes, you'll see output like:

```
[GDScript Complexity Analyzer] Analysis completed
Files analyzed: 42
Total CC: 342 (avg: 8.14)
Total C-COG: 725 (avg: 17.26)
High complexity files: 3
```

### JSON Report Format

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
      "functions": [
        {
          "name": "_process",
          "line": 45,
          "cc": 8,
          "cog": 12
        }
      ]
    }
  ]
}
```

### Usage Examples

- Analyze a project and export JSON + CSV:
```bash
godot --headless --script cli/ci_test.gd -- --project-path . --output report.json --csv-output report.csv
```
- Enable auto export in config:
```json
{
  "report": {
    "formats": ["json", "csv"],
    "output_path": "res://complexity_report.json",
    "csv_output_path": "res://complexity_report.csv",
    "auto_export": true
  }
}
```

## Configuration

Create a `complexity_config.json` file in your project root (or copy `complexity_config.example.json`):

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
  "report": {
    "formats": ["json", "csv"],
    "output_path": "res://complexity_report.json",
    "csv_output_path": "res://complexity_report.csv",
    "auto_export": false
  },
  "performance": {
    "enable_caching": true,
    "cache_path": ".gdcomplexity_cache",
    "incremental_analysis": true
  }
}
```

### Configuration Reference (Common Fields)

- `include`: file patterns to analyze (default: `["res://**/*.gd"]`)
- `exclude`: file patterns to skip
- `cc.threshold_warn` / `cc.threshold_fail`: CC warning/fail thresholds
- `cog.threshold_warn` / `cog.threshold_fail`: C-COG warning/fail thresholds
- `report.formats`: list of report outputs (`json`, `csv`)
- `report.output_path`: JSON output path
- `report.csv_output_path`: CSV output path
- `report.auto_export`: auto write after analysis
- `performance.enable_caching`: enable incremental caching
- `performance.cache_path`: cache directory

For full options, see `complexity_config.example.json`.

## Known Issues

- **Editor shutdown leak warnings**: Godot may print `ObjectDB instances leaked at exit` with `GDScript` resources (e.g. `logger.gd`, `batch_analyzer.gd`). These are engine-level script cache artifacts seen in the editor after plugin use. They do not affect analysis output. If needed, run the editor with `--verbose` and capture the shutdown log for investigation.

### Caching System

The analyzer includes a content-based caching system to speed up subsequent analyses:

- **Content-based hashing**: Files are hashed by content (not modification time), so cache remains valid even if files are copied or moved
- **Config-aware**: Cache automatically invalidates when configuration changes
- **Incremental analysis**: Only changed files are re-analyzed, significantly reducing analysis time on large projects
- **Automatic cleanup**: Orphaned cache entries (for deleted files) are automatically removed
- **Disableable**: Set `"enable_caching": false` in the `performance` section to disable

Cache is stored in `.gdcomplexity_cache/` by default (configurable via `cache_path`).

### Auto Export

Set `"report.auto_export": true` to automatically write reports after analysis. Formats are controlled by `"report.formats"` (e.g., `["json", "csv"]`).

## Troubleshooting

- **No editor annotations**: Godot 3.x does not support editor annotations. On Godot 4.x, if annotations are unavailable, the plugin logs warnings to the console.
- **CSV not generated**: Ensure `report.formats` includes `csv`, set `report.csv_output_path`, or pass `--csv-output` in CLI mode.
- **Files analyzed: 0**: Check `include`/`exclude` patterns and confirm the project contains `.gd` files under `res://`.
- **Stale results**: Disable caching (`performance.enable_caching = false`) or delete the cache directory.
- **Low confidence scores**: The parser is block-oriented and not a full AST; review `Known Limitations` and `Confidence Scores`.

## FAQ

- **Does it modify my scripts?** No. It only reads `.gd` files and generates reports.
- **Why is Godot 3.x less accurate?** Godot 3.x has fewer parser hooks and a different grammar; the analyzer uses heuristics.
- **Which branch should I use?** `main` for Godot 3.x, `godot4` for Godot 4.x.
- **Can I disable editor warnings?** Yes. Set `report.annotate_editor` to `false`.

## Supported Versions

| Godot Version | Support Level | Notes |
|---------------|---------------|-------|
| 3.5 LTS | ✅ Full | Primary 3.x target |
| 3.0-3.4 | ⚠️ Best-effort | Should work, not fully tested |
| 4.2 | ✅ Full | Primary 4.x target |
| 4.0-4.1 | ✅ Full | Should work identically |
| 4.3+ | ⚠️ Forward compatibility | Tested as released |

See [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) for detailed compatibility information.

## Godot 3.x vs 4.x: Key Differences

### Godot 4.x (Supported via `godot4` branch)

✅ **Full support**
- All metrics available (CC, C-COG)
- `match`/`case` statements supported
- Annotation-based editor integration
- Highest accuracy (90-93%)

### Godot 3.x (Supported via `main` branch)

⚠️ **Best-effort support**
- All core metrics work (CC, C-COG)
- No `match` statement support (language limitation)
- Limited editor integration
- Lower accuracy due to block-oriented parser (85-90%)
- Confidence scores capped at 0.90 max

**Recommendation**: For new projects, use Godot 4.x. For Godot 3.5 LTS projects, this tool provides useful metrics with reasonable accuracy.

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

# Annotation manager tests
godot --headless --script tests/test_annotation_manager.gd

# Verify fixtures
godot --headless --script tests/verify_cc_cog.gd

# CSV export
godot --headless --script tests/test_csv_export.gd

# Advanced C-COG rules
godot --headless --script tests/test_cog_advanced.gd

# Confidence validation/tuning (optional)
godot --headless --script tests/validate_confidence.gd -- --step 0.1
godot --headless --script tests/validate_confidence.gd -- --step 0.1 --apply
```

## Known Limitations

This tool is a **static analyzer**, not a runtime profiler. Understand its limitations:

### Technical Limitations

- **Parser Accuracy**: Block-oriented parser, not full AST
  - Godot 4.x: 90-93% accuracy
  - Godot 3.x: 85-90% accuracy
- **GDScript Only**: Does not analyze C#, C++, or other Godot languages
- **Metrics are Heuristic-Based**: CC and C-COG are approximations based on control flow patterns, not execution traces
- **Confidence Cap**: Godot 3.x confidence scores capped at 0.90 maximum
- **Match Statements**: Not supported in Godot 3.x (language limitation)
- **Expression Parsing**: Shallow parsing (by design, sufficient for complexity metrics)

### Scope Limitations

- Not a performance profiler (doesn't measure execution time or memory)
- Not a linter (doesn't check code style or conventions)
- Not a runtime debugger
- Cannot detect all logic errors or anti-patterns
- Metrics reflect code structure, not actual complexity of algorithms

### Practical Limitations

- Large files (10k+ lines) may have slower analysis
- Cache requires disk space (.gdcomplexity_cache/)
- CLI mode requires running Godot in headless mode

## Confidence Scores

Confidence scores estimate parse reliability. Use `tests/validate_confidence.gd` to compute r² against fixtures and optionally write tuned weights to `complexity_config.json`. Default weights are tuned via this tool.

## Roadmap

### Current Release
- ✅ CC and C-COG metrics
- ✅ JSON and CSV export
- ✅ Godot 3.x and 4.x support
- ✅ Caching system
- ✅ CLI integration

### Planned Features
- 🔲 HTML report generation with charts
- 🔲 Real-time complexity warnings in editor
- 🔲 GitHub Actions integration template
- 🔲 Complexity trend tracking over time
- 🔲 Custom metric plugins

### Under Consideration
- Halstead Metrics
- Maintainability Index calculation
- IDE integration for other engines (Godot 5.x when stable)

## License

Licensed under the **MIT License**. See [LICENSE](LICENSE) file for full details.

Permission is granted to use, copy, modify, and distribute this software in accordance with the MIT License.

## Documentation

- [User Guide](docs/USER_GUIDE.md) - Installation, configuration, usage, troubleshooting
- [Technical Documentation](docs/TECHNICAL.md) - Architecture and parser details
- [Compatibility Matrix](docs/COMPATIBILITY.md) - Version support details
- [Breaking Changes Log](docs/BREAKING_CHANGES.md) - Release-impacting changes
- [Error Codes](docs/ERROR_CODES.md) - Standardized error codes and severities
- [Distribution Guide](docs/DISTRIBUTION.md) - Release packaging and tags
- [Changelog Template](docs/CHANGELOG_TEMPLATE.md) - Release notes format


## Special Thanks

***Special thanks to r2d2meuleu for starring my project — this is my first star***