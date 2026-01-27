# Compatibility Matrix and Version-Specific Limitations

## Supported Versions

| Godot Version | Support Level | CLI Mode | Editor Plugin | Annotations | Confidence Cap |
|--------------|---------------|----------|---------------|-------------|---------------|
| 3.0 - 3.4    | Smoke Test    | +       | x+ Limited    | x+ Limited  | 0.90 max      |
| 3.5 (LTS)    | Full          | +       | +            | +          | 0.90 max      |
| 4.0 - 4.2    | Full          | +       | +            | +          | 1.0           |
| 4.3+         | Full          | +       | +            | +          | 1.0           |

**Legend:**
-  Fully supported
-  Limited support (best-effort, may have issues)
-  Not supported

## Version-Specific Features

### Godot 3.x (3.0 - 3.5)

**Supported:**
- Cyclomatic Complexity (CC) calculation
- Cognitive Complexity (C-COG) calculation
- CLI mode analysis
- JSON report generation
- Basic editor plugin UI
- Editor annotations via `set_error()` API (3.x)

**Limitations:**
- `match`/`case` statements not supported (not available in GDScript 3.x)
- Maximum confidence score capped at 0.90 (hard limit)
- Parser accuracy: 85-90% typical (best-effort)
- Some advanced syntax features may not be parsed correctly
- Editor annotations use older `set_error()` API (no severity levels)

**Known Issues:**
- Complex string interpolation may reduce parse accuracy
- Nested lambdas may not be fully analyzed
- Some edge cases in class inheritance may be missed

### Godot 4.x (4.0+)

**Supported:**
- All features from 3.x
- `match`/`case` statement analysis
- `await` keyword recognition
- Editor annotations via `add_error_annotation()` API (4.x)
- Maximum confidence score: 1.0 (no cap)
- Parser accuracy: 90-93% typical, 95% in best cases

**Limitations:**
- Parser accuracy: 90-93% typical (best-effort)
- Complex string interpolation may reduce parse accuracy
- Nested lambdas may not be fully analyzed

**Note:** `yield` keyword is recognized but deprecated in favor of `await` in 4.x.

## Parser Architecture Limitations

### Block-Oriented Parsing

The parser is **block-oriented and control-flow focused**, not a full AST:

- + **Parsed**: Function boundaries, class definitions, control structures (`if`, `for`, `while`, `match`)
- x+ **Limited**: Expression parsing (sufficient for complexity calculation only)
- x **Not Parsed**: Full expression trees, type information, semantic analysis

### Rationale

Complexity metrics require control flow structure, not complete semantic understanding. The parser focuses on:
1. Identifying decision points (if, elif, for, while, match, case, logical operators)
2. Tracking nesting depth for C-COG calculation
3. Determining function and class boundaries

## Confidence Scoring

### Godot 3.x
- **Maximum**: 0.90 (hard cap)
- **Typical Range**: 0.75 - 0.90
- **Reason**: Best-effort support, known limitations

### Godot 4.x
- **Maximum**: 1.0 (no cap)
- **Typical Range**: 0.85 - 0.95
- **Reason**: Better parser support, more accurate detection

### Confidence Components

Confidence score is calculated from:
- Token coverage (40% weight)
- Indentation consistency (20% weight)
- Block balance (20% weight)
- Parse errors (20% weight)

## Editor Integration Differences

### Godot 3.x
- Uses `ScriptEditor.set_error(script_path, line, message)` API
- No severity levels (warnings prepended with "[WARNING]")
- Dock panel uses `Label.AUTOWRAP_WORD_SMART` enum
- Plugin lifecycle: `_enter_tree()`, `_exit_tree()`

### Godot 4.x
- Uses `ScriptEditor.add_error_annotation(script_path, line, severity, message)` API
- Supports severity levels (error, warning, info)
- Dock panel uses `Label.AUTOWRAP_WORD_SMART` enum (same as 3.x for compatibility)
- Plugin lifecycle: `_enter_tree()`, `_exit_tree()` (same as 3.x)

## Smoke Test Requirements (Godot 3.0-3.4)

For versions 3.0-3.4, smoke tests verify:

**Required (Must Pass):**
- + CLI mode works (`cli/analyze.gd` and `cli/ci_test.gd`)
- + CC calculation works correctly
- + Basic file analysis completes without crashes
- + JSON report generation works

**Optional/Unsupported:**
- x+ UI may be limited or unavailable
- x+ Editor annotations may not work
- x+ Advanced features may be disabled

**Success Criteria**: Core analysis functionality (CLI + CC) works; UI/annotations are optional.

## Testing Checklist

### Godot 3.5 (LTS) - Full Functionality
- [ ] Plugin loads without errors
- [ ] Dock panel displays correctly
- [ ] Analysis runs successfully
- [ ] Editor annotations appear in script editor
- [ ] Configuration dialog works
- [ ] Export functionality works
- [ ] CLI mode works

### Godot 3.0-3.4 - Smoke Tests
- [ ] CLI mode works
- [ ] CC calculation works
- [ ] Basic file analysis completes
- [ ] JSON report generation works
- [ ] No crashes during analysis

### Godot 4.0-4.2 - Full Functionality
- [ ] Plugin loads without errors
- [ ] Dock panel displays correctly
- [ ] Analysis runs successfully
- [ ] Editor annotations appear in script editor
- [ ] Configuration dialog works
- [ ] Export functionality works
- [ ] CLI mode works
- [ ] `match`/`case` statements are detected
- [ ] `await` keyword is recognized

## Migration Notes

### From Godot 3.x to 4.x
- `match`/`case` statements will now be included in complexity calculations
- Confidence scores may increase (removal of 0.90 cap)
- Editor annotations will use severity levels
- `yield` is deprecated in favor of `await` (both recognized)

### From Godot 4.x to 3.x
- `match`/`case` statements will be ignored (not available in 3.x)
- Confidence scores will be capped at 0.90
- Editor annotations will use simpler API (no severity levels)
- `await` is not available (use `yield` instead)

## Known Limitations Summary

1. **Parser Accuracy**: Best-effort, not guaranteed. Typical accuracy: 85-90% (3.x), 90-93% (4.x)
2. **Complex Syntax**: String interpolation, nested lambdas may reduce accuracy
3. **Edge Cases**: Some unusual code patterns may not be parsed correctly
4. **Godot 3.x**: Maximum confidence cap of 0.90, best-effort support
5. **No Full AST**: Parser is block-oriented, not a complete semantic analyzer

## Reporting Issues

When reporting compatibility issues, please include:
- Godot version (full version string from `Engine.get_version_info()`)
- Plugin version
- Error messages or unexpected behavior
- Sample code that triggers the issue (if applicable)
- Whether CLI mode or editor plugin is affected

