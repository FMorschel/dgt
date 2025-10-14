<!-- markdownlint-disable MD040 -->
# DGT MVP Implementation Plan

## Overview

This plan outlines the steps to build a Minimum Viable Product (MVP) for DGT - a CLI tool that lists local Git branches with their Gerrit review status.

## Core MVP Features

- List all local Git branches
- Extract Change-IDs from commit messages
- Query Gerrit REST API for change status
- Display branch name, status, Change-ID, local hash, local date, Gerrit hash, and Gerrit date
- Map Gerrit API responses to user-friendly statuses (WIP, Active, Merge conflict, Merged)
- Color-coded terminal output for better visual distinction of statuses

---

## Implementation Steps

### Phase 1: Project Setup

- [x] Set up basic CLI structure in `bin/dgt.dart`
- [x] Add command-line argument parsing using `args` package
- [x] Implement `--help` and `--version` flags
- [x] Create main entry point that handles the `list` command (default)

### Phase 2: Terminal Output Abstraction

- [x] Create `lib/terminal.dart` for colored terminal output
- [x] Add `ansicolor` package dependency for colored terminal output
- [x] Implement `Terminal` class with static methods for colored output:
  - `Terminal.info()` - Default/white text
  - `Terminal.success()` / `Terminal.green()` - Green text (for Active status)
  - `Terminal.warning()` / `Terminal.yellow()` - Yellow text (for WIP status)
  - `Terminal.error()` / `Terminal.red()` - Red text (for Merge conflict status)
  - `Terminal.cyan()` / `Terminal.blue()` - Cyan/Blue text (for Merged status)
- [x] Update existing `print()` calls in `bin/dgt.dart` to use `Terminal` methods

### Phase 3: Git Integration

- [x] Create `lib/git_service.dart` for Git operations
- [x] Implement function to get list of all local branches
- [x] Implement function to get current branch name
- [x] Implement function to get commit hash for a given branch
- [x] Implement function to get commit date for a given branch
- [x] Implement function to get commit message for a given branch
- [x] Create function to extract Change-ID from commit message (regex: `Change-Id: I[a-f0-9]{40}`)
- [x] Create `GerritBranchConfig` class to hold Gerrit metadata from Git config
- [x] Implement function to read `.git/config` and extract Gerrit metadata per branch:
  - `gerritissue` - The Gerrit change/issue number
  - `gerritserver` - The Gerrit server URL
  - `gerritpatchset` - The current patchset number
  - `gerritsquashhash` - Hash of the squashed commit in Gerrit
  - `last-upload-hash` - Hash of the last uploaded commit

### Phase 4: Gerrit API Integration

- [x] Create `lib/gerrit_service.dart` for Gerrit API interactions
- [x] Define data model for Gerrit change response (can be a simple class or Map)
- [x] Implement function to construct Gerrit API URL for change lookup by Change-ID
- [x] Implement function to construct Gerrit API URL for change lookup by issue number
- [x] Implement HTTP GET request to Gerrit API using issue number (`https://dart-review.googlesource.com/changes/{issue}`)
- [x] Implement HTTP GET request to Gerrit API (`https://dart-review.googlesource.com/changes/`)
- [x] Handle Gerrit's XSSI protection prefix (`)]}'\n`) in JSON responses
- [x] Parse JSON response to extract:
  - Change status (`NEW`, `MERGED`, etc.)
  - `work_in_progress` flag
  - `mergeable` flag
  - `updated` timestamp
  - Current revision hash
- [x] Implement status mapping logic:
  - WIP: `work_in_progress == true`
  - Active: `status == "NEW"` and `work_in_progress == false`
  - Merge conflict: `mergeable == false`
  - Merged: `status == "MERGED"`

### Phase 5: Branch Status Collection

- [x] Create `lib/branch_info.dart` to define BranchInfo data structure
- [x] BranchInfo should contain:
  - Branch name
  - Local commit hash
  - Local commit date
  - Change-ID (nullable)
  - Gerrit configuration from Git config (`GerritBranchConfig`)
  - Gerrit status (nullable)
  - Gerrit commit hash (nullable)
  - Gerrit updated date (nullable)
- [x] Create main orchestration logic to:
  - Get all local branches
  - For each branch, get local commit info
  - Read Gerrit configuration from `.git/config` for the branch
  - Extract Change-ID from commit message (for display)
  - **UPDATED**: If Gerrit config exists (has `gerritissue` and `gerritserver`), query Gerrit API using issue number
  - Populate BranchInfo object
  - Handle branches without Gerrit configuration gracefully

### Phase 6: Output Formatting

- [x] Create `lib/output_formatter.dart` for displaying results
- [x] Implement table header formatting
- [x] Implement table row formatting for each branch
- [x] Use `Terminal` class for color coding statuses:
  - WIP: Yellow
  - Active: Green
  - Merge conflict: Red
  - Merged: Blue/Cyan
- [x] Calculate column widths dynamically or use fixed widths
- [x] Format dates consistently (e.g., `yyyy-MM-dd HH:mm`)
- [x] Display "-" for missing values (branches without Gerrit changes)
- [x] Truncate long Change-IDs with ellipsis for readability
- [x] Add separator line between header and data

### Phase 7: Error Handling

- [x] Add try-catch blocks for Git command execution
- [x] Handle case when not in a Git repository
- [x] Handle network errors when querying Gerrit API
- [x] Display user-friendly error messages
- [x] Allow partial success (show branches even if some Gerrit queries fail)

### Phase 8: Hash/Date Difference Highlighting

- [x] Enhance `Terminal` class with string-returning color methods:
  - `Terminal.greenText()` - Returns green-colored string
  - `Terminal.yellowText()` - Returns yellow-colored string
  - `Terminal.redText()` - Returns red-colored string
  - `Terminal.cyanText()` - Returns cyan-colored string
  - `Terminal.blueText()` - Returns blue-colored string
- [x] Modify `OutputFormatter._printBranchRow()` to detect hash/date differences:
  - Compare local hash vs Gerrit hash (truncated)
  - Compare local date vs Gerrit date (formatted)
- [x] Implement mixed-color row highlighting:
  - Highlight Gerrit hash in yellow when it differs from local hash
  - Highlight Gerrit date in yellow when it differs from local date
  - Use status color for remaining columns
- [x] Remove unused `_printColoredRow()` method
- [x] **IMPROVEMENT**: Fix difference detection logic to use Git config metadata:
  - [x] Add `lastUploadHash` field to `GerritBranchConfig` class
  - [x] Parse `last-upload-hash` from `.git/config` in `GitService.getGerritConfig()`
  - [x] Update `BranchInfo` to expose methods for checking sync state:
    - `hasLocalChanges()`: Compare local HEAD with `last-upload-hash`
    - `hasRemoteChanges()`: Compare `gerritsquashhash` with Gerrit's `current_revision`
  - [x] Update `OutputFormatter._printBranchRow()` to use new detection methods:
    - Highlight local hash in yellow when `hasLocalChanges()` is true
    - Highlight Gerrit hash in yellow when `hasRemoteChanges()` is true
  - [x] Update highlighting logic to provide clearer visual feedback:
    - Local hash and date yellow = "You have unpushed changes"
    - Gerrit hash and date yellow = "Gerrit has updates you don't have locally"
  - [x] Handle edge cases:
    - Missing `last-upload-hash` in config (treat as no local changes)
    - Missing `gerritsquashhash` in config (fall back to current comparison)
    - Null Gerrit change (no highlighting needed)

### Phase 9: Performance Optimization

- [x] Batch Gerrit API queries if possible (single query with multiple Change-IDs)
- [x] Add basic caching to avoid redundant Git commands
- [x] Consider parallel API requests for multiple branches (using Future.wait)
  - Implemented parallel Git operations using Future.wait for all branches
  - Added isolate-based JSON decoding to avoid blocking the main isolate

### Phase 10: Accurate Sync State Detection

**Problem**: The current implementation compares local HEAD hash directly with Gerrit's current revision, which doesn't accurately represent whether you have local changes to upload or remote changes to pull.

**Solution**: Use Git config metadata (`last-upload-hash` and `gerritsquashhash`) to accurately detect sync state.

**Implementation Steps**:

- [x] Extend `GerritBranchConfig` to include `lastUploadHash` field
- [x] Parse `last-upload-hash` from Git config in `GitService.getGerritConfig()`
- [x] Add sync state detection methods to `BranchInfo`:
  - `hasLocalChanges()`: Returns true when local HEAD ≠ last-upload-hash
  - `hasRemoteChanges()`: Returns true when gerritsquashhash ≠ Gerrit current_revision
- [x] Update `OutputFormatter` to highlight based on sync state:
  - Yellow local hash and date = unpushed local changes exist
  - Yellow Gerrit hash and date = Gerrit has updates not in local branch
- [x] Handle edge cases (missing config fields, null values)

**Expected Behavior**:

| Scenario | Local Hash/Date Color | Gerrit Hash/Date Color | Meaning |
|----------|----------------------|------------------------|---------|
| In sync | Normal | Normal | No changes either side |
| Local changes | **Yellow** | Normal | Need to upload |
| Remote changes | Normal | **Yellow** | Need to pull/rebase |
| Both changed | **Yellow** | **Yellow** | Diverged state |

### Phase 11: Documentation

- [x] Add code comments for complex logic
- [x] Document Gerrit API endpoints used
- [x] Document expected Git configuration
- [x] Add example output to README.md

### Phase 12: Performance Timing (Optional Feature)

- [x] Add `--timing` / `-t` flag to CLI argument parser
- [x] Create `lib/performance_tracker.dart` to track operation timings
- [x] Implement `PerformanceTracker` class with methods:
  - `startTimer(String operationName)` - Start timing an operation
  - `endTimer(String operationName)` - End timing and record duration
  - `getTimings()` - Return map of operation names to durations
  - `getTotalTime()` - Return total execution time
  - `reset()` - Clear all timings
- [x] Track timings for key operations:
  - Branch discovery (`GitService.getAllBranches()`)
  - Git operations (parallel `Future.wait` for all branches)
  - Gerrit API queries (`GerritService.getBatchChangesByIssueNumbers()`)
  - Result processing (creating `BranchInfo` objects)
- [x] Add timing summary output to `OutputFormatter`:
  - `displayPerformanceSummary(PerformanceTracker tracker)` method
  - Format: "Performance Summary:" header with breakdown
  - Display each operation with aligned millisecond values
  - Show total execution time
- [x] Update `runListCommand()` to:
  - Create `PerformanceTracker` instance when `--timing` flag is set
  - Wrap key operations with start/end timer calls
  - Call `OutputFormatter.displayPerformanceSummary()` at the end
- [x] Update documentation with timing flag examples

### Phase 13: Filtering

- [x] Add filtering CLI flags to `bin/dgt.dart`:
  - `--status <status>` to filter by status (can be specified multiple times for multiple statuses)
  - `--since <date>` to filter branches by commit date (show only branches with commits after this date)
  - `--before <date>` to filter branches by commit date (show only branches with commits before this date)
  - `--diverged` to show only branches with local or remote differences
- [x] Validate filter input values and provide helpful error messages for invalid inputs
- [x] Add computed property `diverged` to `BranchInfo`: returns true when `hasLocalChanges() || hasRemoteChanges()`
- [x] Implement filtering logic:
  - Create `applyFilters(List<BranchInfo> branches, FilterOptions filters)` function
  - Apply status filter(s) first, then date filters, then `--diverged` filter
  - Ensure filters are chainable and performant
- [x] Integrate filtering into the output pipeline before formatting
- [x] Extend `ConfigService` to save/load filter defaults (status, date ranges, diverged flag)
- [x] Extend `config` command to support filter options:
  - `dgt config --status Active --diverged` (save filter defaults)
  - `dgt config --no-status --no-diverged` (clear specific filter defaults)
  - Load saved filter configuration automatically on each run (unless overridden by CLI flags)
  - CLI flags always take precedence over config defaults
- [x] Update `--help` text with filtering examples:
  - `dgt --status Active --since 2025-10-01`
  - `dgt --diverged`
  - `dgt --status WIP --status Active --before 2025-10-10`
  - `dgt config --status Active --diverged` (save as default)
- [x] Update `README.md` with filtering usage examples
- [x] Support adding this flag to the configuration file

### Phase 14: Sorting

- [x] Add sorting CLI flags to `bin/dgt.dart`:
  - `--sort <field>` where `<field>` is one of: `local-date`, `gerrit-date`, `status`, `divergences`, `name`
  - `--asc` to sort in ascending order (default if `--sort` is used without direction)
  - `--desc` to sort in descending order
- [x] Validate sort field input and provide helpful error messages for invalid values
- [x] Ensure `BranchInfo` exposes fields needed for sorting: `localDate`, `gerritDate`, `status`, `name`
- [x] Implement sorting logic:
  - Create `applySort(List<BranchInfo> branches, SortOptions sortOptions)` function
  - Provide stable sorting using `List.sort()` with comparator functions for each field
  - For `divergences` sort, compute a score: 2 = both diverged, 1 = one side diverged, 0 = in sync
- [x] Integrate sorting into the output pipeline (after filtering, before formatting)
- [x] Add sorting indicator in output header when `--sort` is used (e.g., `Sorted by: status (desc)`)
- [x] Extend `ConfigService` to save/load sort defaults (field and direction)
- [x] Extend `config` command to support sort options:
  - `dgt config --sort local-date --desc` (save sort defaults)
  - `dgt config --no-sort` (clear sort defaults)
  - Load saved sort configuration automatically on each run (unless overridden by CLI flags)
  - CLI flags always take precedence over config defaults
- [x] Update `--help` text with sorting examples:
  - `dgt --sort local-date --desc`
  - `dgt --sort status`
  - `dgt --status Active --sort divergences --desc`
  - `dgt config --sort local-date --asc` (save as default)
  - `dgt config --no-sort` (clear saved sort)
- [x] Update `README.md` with sorting usage examples
- [x] Support adding this flag to the configuration file

### Phase 15: Gerrit URL Column

- [x] Add `--url` CLI flag to `bin/dgt.dart` to enable URL column display
- [x] Extend `BranchInfo` class to include a `gerritUrl` property
- [x] Implement URL construction logic in `GerritService`:
  - [x] Create `getChangeUrl(String server, int issueNumber)` method
  - [x] Return formatted URL like `https://dart-review.googlesource.com/c/project/+/issueNumber`
- [x] Update `OutputFormatter` to support URL column:
  - [x] Add URL column to table header when `--url` flag is enabled
  - [x] Add URL column to table rows with clickable links (when available)
  - [x] Handle branches without Gerrit changes (display empty or placeholder)
  - [x] Adjust column widths dynamically to accommodate URL column
- [x] Integrate URL generation into branch processing pipeline:
  - [x] Populate `gerritUrl` in `BranchInfo` when Gerrit config exists
  - [x] Use `gerritserver` and `gerritissue` from Git config to construct URLs
- [x] Update `--help` text with URL column examples:
  - [x] `dgt --url` (show URL column)
  - [x] `dgt --status Active --url` (combine with other flags)
- [x] Update `README.md` with URL column usage examples
- [x] Support adding this flag to the configuration file

---

## MVP Scope Exclusions

- ❌ Unit tests (can be added post-MVP)
- ❌ Integration tests
- ❌ Configuration file support
- ❌ Notification system

### Phase 16: Centralized Flag Resolution

**Goal**: Reduce duplication in flag precedence handling by centralizing the resolution logic into a reusable helper method in `ConfigService`.

**Current Problem**: Flag precedence logic (CLI flags > Config file > Built-in defaults) is duplicated across multiple flags in `bin/dgt.dart`, making the code verbose and harder to maintain.

**Implementation Steps**:

- [x] Persisted config lives in the user's config file (for example, `~/.dgt/.config`)
- [ ] Add centralized flag resolution helper to `ConfigService`:
  - [ ] Create `resolveFlag(ArgResults argResults, String flagName, bool defaultValue)` method
    - Returns: CLI flag value if explicitly provided, else config file value, else default value
  - [ ] Create `resolveOption(ArgResults argResults, String optionName, T? defaultValue)` method
    - Returns: CLI option value if explicitly provided, else config file value, else default value
  - [ ] Create `resolveMultiOption(ArgResults argResults, String optionName, List<T> defaultValue)` method
    - Returns: CLI multi-option values if explicitly provided, else config file values, else default value
- [ ] Refactor `bin/dgt.dart` to use centralized helpers:
  - [ ] Replace precedence code for `--timing` flag with `config.resolveFlag(argResults, 'timing', false)`
  - [ ] Replace precedence code for `--url` flag with `config.resolveFlag(argResults, 'url', false)`
  - [ ] Replace precedence code for `--diverged` flag with `config.resolveFlag(argResults, 'diverged', false)`
  - [ ] Replace precedence code for `--sort` option with `config.resolveOption(argResults, 'sort', null)`
  - [ ] Replace precedence code for `--asc`/`--desc` with `config.resolveFlag(argResults, 'asc'/'desc', false)`
  - [ ] Replace precedence code for `--status` multi-option with `config.resolveMultiOption(argResults, 'status', [])`
  - [ ] Replace precedence code for `--since`/`--before` options with `config.resolveOption()`
- [ ] Ensure resolution logic handles wasExplicitlyProvided check correctly:
  - CLI flags/options should only override config when user explicitly provides them
  - Use `argResults.wasParsed(flagName)` to detect explicit CLI usage
- [ ] Add helper method documentation with examples
- [ ] Test precedence behavior:
  - [ ] CLI flag overrides config value
  - [ ] Config value used when no CLI flag provided
  - [ ] Built-in default used when neither CLI nor config provided

**Benefits**:

- Eliminates code duplication across flag handling
- Makes it trivial to add new configurable flags in the future
- Centralizes precedence rules in one maintainable location
- Keeps `bin/dgt.dart` cleaner and more readable

### Phase 17: Enhanced Configuration Management and Status Filtering

**Goal**: Provide comprehensive configuration management capabilities and support for filtering by all status types including local-only branches.

**Implementation Steps**:

- [x] Add ability to remove specific config options:
  - [x] Implement `--no-status` flag to clear all status filters from config
  - [x] Ensure all existing config options support removal via `--no-<option>` flags
  - [x] Add validation to ensure removal flags work correctly
- [x] Add config inspection command:
  - [x] Implement `dgt config --show` or `dgt config show` to display current config file contents
  - [x] Format output to show all current settings in a readable format
  - [x] Handle case where config file doesn't exist
- [x] Add config reset functionality:
  - [x] Implement `dgt config --clean` or `dgt config clean` to reset config to defaults
  - [x] Add confirmation prompt before cleaning (or `--force` flag to skip)
  - [x] Document what "clean" means (empty config vs. default values)
- [x] Enhance status filtering:
  - [x] Add `--status gerrit` support as an alias for all accepted Gerrit statuses
  - [x] Define "all" as: `[WIP, Active, Merge conflict, Merged, Abandoned]`
  - [x] Add `--status local` support for branches without Gerrit configuration
  - [x] Implement detection logic for local-only branches (no `gerritissue` in Git config)
  - [x] Ensure `--status` can accept multiple values including combinations like `--status local --status Active`
- [x] Update filtering logic in `lib/filtering.dart`:
  - [x] Expand `applyFilters()` to handle `local` and `all` status values
  - [x] When `all` is specified, include all Gerrit statuses but respect other filters
  - [x] When `local` is specified, include branches where `gerritConfig == null`
  - [x] Ensure filters are chainable and work correctly with saved config
- [x] Update precedence rules:
  - [x] Ensure CLI `--status` flags always override config file status settings
  - [x] Ensure removal flags (`--no-status`) work correctly to override config for single run
  - [x] Document precedence clearly: CLI flags > Config file > Built-in defaults
- [x] Extend `ConfigService`:
  - [x] Add methods: `showConfig()`, `cleanConfig()`, `removeOption(String key)`
  - [x] Ensure all config write operations validate inputs
  - [x] Add clear error messages for invalid operations
- [x] Update `config` command in `bin/dgt.dart`:
  - [x] Add subcommand support: `show` and `clean`
  - [x] Add `--no-status` flag to remove all status filters
  - [x] Update help text with examples of all new config operations
- [x] Update `--help` text with new examples:
  - [x] `dgt config show` (view current config)
  - [x] `dgt config clean` (reset config to defaults)
  - [x] `dgt config --no-status` (remove all status filters)
  - [x] `dgt --status gerrit` (show all Gerrit statuses)
  - [x] `dgt --status local` (show only local branches)
  - [x] `dgt --status local --status active` (show local and active branches)
- [ ] Update `README.md` with configuration management documentation:
  - [ ] Document all config commands and flags
  - [ ] Provide examples of common workflows
  - [ ] Explain precedence rules clearly

**Expected Behavior**:

| Command | Effect |
|---------|--------|
| `dgt config --status active` | Save Active as default status filter |
| `dgt config --no-status` | Remove all status filters from config |
| `dgt config show` | Display current config file contents |
| `dgt config clean` | Reset config to empty/default state |
| `dgt --status gerrit` | Show all Gerrit statuses (WIP, Active, etc.) |
| `dgt --status local` | Show only branches without Gerrit config |
| `dgt --status local --status active` | Show local + Active branches |
| `dgt --no-status` | Temporarily ignore config status filters |

**Validation**:

- [ ] Test that `--status gerrit` expands correctly to all Gerrit statuses
- [ ] Test that `--status local` only shows branches without `gerritissue`
- [ ] Test that multiple status filters combine correctly (OR logic)
- [ ] Test that config removal flags work without affecting other settings
- [ ] Test that `show` and `clean` commands work as expected
- [ ] Test precedence: CLI overrides config overrides defaults

---

## Key Technical Details

### Gerrit API Endpoint

```
GET https://dart-review.googlesource.com/changes/?q=change:{CHANGE_ID}
```

### Expected Git Commands

```bash
git branch --list                    # List all branches
git rev-parse <branch>              # Get commit hash
git log -1 --format=%ci <branch>    # Get commit date
git log -1 --format=%B <branch>     # Get commit message
```

### Status Priority (when multiple conditions match)

1. Merged (highest priority)
2. Abandoned
3. Merge conflict
4. WIP
5. Active

---

## Success Criteria

- ✅ Tool runs without errors in a Git repository
- ✅ Displays all local branches
- ✅ Shows correct Gerrit status for branches with Change-IDs
- ✅ Handles branches without Change-IDs gracefully
- ✅ Execution completes in < 3 seconds
- ✅ Clear error messages for common failure cases
