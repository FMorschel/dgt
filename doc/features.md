# Features Documentation

## Overview

This document provides detailed information about all features available in the DGT (Dart Gerrit Tool), including usage examples, configuration options, and expected behavior.

## Core Features

### 1. Branch Listing

The primary feature of DGT is listing all local Git branches along with their Gerrit code review status.

#### Basic Usage

```bash
# List all branches with default settings
dgt
# or
dgt list
```

#### Example Output

```text
Branch Name          | Status          | Local Hash   | Local Date        | Gerrit Hash  | Gerrit Date
----------------------------------------------------------------------------------------------------------------------------
main                 | -               | a1b2c3d4     | 2025-10-09 10:15  | -            | -
feature/new-api      | Active          | e5f6a7b8     | 2025-10-09 14:30  | e5f6a7b8     | 2025-10-09 14:30
bugfix/memory-leak   | WIP             | c9d0e1f2     | 2025-10-08 16:45  | c9d0e1f2     | 2025-10-08 16:45
refactor/cleanup     | Merged          | g3h4i5j6     | 2025-10-07 09:20  | g3h4i5j6     | 2025-10-07 11:00
hotfix/crash         | Merge conflict  | k7l8m9n0     | 2025-10-09 08:00  | k7l8m9n0     | 2025-10-09 08:00

Total: 5 branches
```

#### Status Values

| Status | Color | Description |
|--------|-------|-------------|
| `Active` | Green | Change ready for review (NEW status, not WIP) |
| `WIP` | Yellow | Work in Progress (marked as WIP in Gerrit) |
| `Merged` | Cyan | Successfully merged into target branch |
| `Abandoned` | Gray | Change has been abandoned |
| `Merge conflict` | Red | Change cannot be merged, needs rebase |
| `-` | White | No Gerrit change associated (local-only branch) |

### 2. Display Options

Control which columns are shown in the output.

#### Column Control

```bash
# Hide Gerrit columns (hash and date)
dgt --no-gerrit

# Hide local columns (hash and date)
dgt --no-local

# Show both local and Gerrit columns (default)
dgt --gerrit --local

# Show Gerrit URL column
dgt --url
```

#### Verbose Output

```bash
# Show detailed execution information
dgt --verbose
# or
dgt -v
```

Example verbose output:

```text
[VERBOSE] Changing directory to: /path/to/repo
[VERBOSE] Fetching local branches...
[VERBOSE] Found 5 branches
[VERBOSE] Batch fetching Git information for all branches...
[VERBOSE] Processing branch: main
[VERBOSE] Branch main: No Gerrit configuration found for this branch
[VERBOSE] Batch querying Gerrit for 3 issue(s)...
[VERBOSE] Batch query completed: 3/3 changes found
```

#### Performance Timing

```bash
# Show performance breakdown
dgt --timing
# or
dgt -t
```

Example timing output:

```text
Performance Summary:
  Branch discovery:        45ms
  Git operations:         120ms
  Gerrit queries:         850ms
  Data processing:         35ms
  Output formatting:       15ms
  Total execution time:  1065ms
```

### 3. Repository Path

Analyze a repository in a different directory.

```bash
# Analyze specific repository
dgt --path /path/to/repository
# or
dgt -p D:\projects\dart-sdk

# Combine with other options
dgt --path /other/repo --verbose --timing
```

### 4. Filtering System

Filter branches to focus on specific work.

#### Status Filtering

```bash
# Show only Active branches
dgt --status active

# Show Active and WIP branches
dgt --status active --status wip

# Show only merged branches
dgt --status merged

# Show only branches with merge conflicts
dgt --status conflict

# Show all branches with Gerrit configuration
dgt --status gerrit

# Show only local-only branches (no Gerrit config)
dgt --status local
```

**Available Status Values**:

- `active` - Ready for review
- `wip` - Work in Progress
- `merged` - Successfully merged
- `abandoned` - Abandoned changes
- `conflict` - Has merge conflicts
- `gerrit` - All branches with Gerrit configuration
- `local` - Branches without Gerrit configuration

#### Date Filtering

```bash
# Show branches with commits after October 1st, 2025
dgt --since 2025-10-01

# Show branches with commits before October 10th, 2025
dgt --before 2025-10-10

# Show branches in a date range
dgt --since 2025-10-01 --before 2025-10-10

# ISO 8601 format is supported
dgt --since 2025-10-01T14:30:00
```

#### Divergence Filtering

```bash
# Show only branches with local or remote differences
dgt --diverged

# Combine with status filtering
dgt --status active --diverged

# Find all diverged branches since a date
dgt --diverged --since 2025-10-01
```

### 5. Sorting System

Sort branches by different criteria.

#### Sort Fields

```bash
# Sort by local commit date (newest first)
dgt --sort local-date --desc

# Sort by Gerrit update date (oldest first)
dgt --sort gerrit-date --asc

# Sort by status
dgt --sort status

# Sort by divergence state (most diverged first)
dgt --sort divergences --desc

# Sort by branch name alphabetically
dgt --sort name
```

**Available Sort Fields**:

- `local-date` - Local commit date
- `gerrit-date` - Gerrit update date
- `status` - Gerrit status
- `divergences` - Divergence state (both sides, one side, in sync)
- `name` - Branch name

#### Sort Directions

- `--asc` - Ascending order (default)
- `--desc` - Descending order

### 6. Divergence Detection

DGT automatically detects when local and remote states differ.

#### Local Changes Detection

Highlights when local branch has commits not uploaded to Gerrit:

- Compares local HEAD with `last-upload-hash` from Git config
- Shows local hash/date in normal color, Gerrit info highlighted in yellow
- Indicates you should upload your changes

#### Remote Changes Detection

Highlights when Gerrit has updates not reflected locally:

- Compares Gerrit current revision with `gerritsquashhash` from Git config
- Shows Gerrit hash/date in normal color, local info highlighted in yellow
- Indicates you should pull/rebase your branch

#### Visual Indicators

```text
feature/updates      | Active          | x1y2z3a4     | 2025-10-09 15:00  | b5c6d7e8     | 2025-10-09 10:00
                                                                           ^^^^^^^^     ^^^^^^^^^^^^^^^^
                                                                           (highlighted in yellow)
```

### 7. Configuration Management

Save default preferences to avoid repeating command-line options.

#### Saving Configuration

```bash
# Save display preferences
dgt config --no-gerrit          # Hide Gerrit columns by default
dgt config --url                # Show URL column by default
dgt config --gerrit --local     # Show all columns (reset)

# Save filter preferences
dgt config --status active      # Default to Active branches only
dgt config --status active --status wip  # Multiple statuses
dgt config --diverged           # Default to diverged branches only
dgt config --since 2025-10-01  # Default date filter

# Save sort preferences
dgt config --sort local-date --desc  # Default sort by recent local commits
```

#### Viewing Configuration

```bash
# Show current configuration
dgt config
```

Example output:

```text
Current Configuration:
  Display Options:
    Local columns:     true
    Gerrit columns:    false
    URL column:        true

  Filter Options:
    Status filter:     active, wip
    Diverged filter:   true
    Since date:        2025-10-01

  Sort Options:
    Sort field:        local-date
    Sort direction:    desc
```

#### Removing Configuration

```bash
# Remove specific options
dgt config --no-status          # Remove status filter defaults
dgt config --no-sort            # Remove sort defaults

# Reset to defaults (remove all configuration)
dgt config clean

# Force reset without confirmation
dgt config clean --force
```

#### Configuration Storage

- Location: `~/.dgt/.config`
- Format: JSON
- Scope: User-level (applies to all repositories)

### 8. Branch Cleanup

Wrapper around Git's `git cl archive` command for cleaning up branches.

#### Basic Usage

```bash
# Archive all merged branches
dgt clean
```

#### Pass-through Arguments

All arguments after `clean` are passed directly to `git cl archive`:

```bash
dgt clean
# Executes: git cl archive
```

### 9. Help System

Comprehensive help information available at multiple levels.

#### General Help

```bash
# Show main help
dgt --help
# or
dgt -h
```

#### Command-specific Help

```bash
# Configuration help
dgt config --help

# Clean command help
dgt clean --help
```

#### Status Value Help

When an invalid status is provided, DGT shows available options:

```text
Invalid status value: "invalid"
Allowed values:
  active (Ready for review)
  wip (Work in Progress)
  merged (Successfully merged)
  abandoned (Abandoned changes)
  conflict (Has merge conflicts)
  gerrit (All Gerrit statuses)
  local (Branches without Gerrit configuration)
```

## Advanced Features

### 1. Batch Processing

DGT optimizes performance through batch operations:

#### Git Batch Operations

- Single `git for-each-ref` call instead of multiple `git log` calls
- Single `git config --get-regexp` instead of multiple config queries
- Reduces Git process spawn overhead significantly

#### Gerrit Batch Queries

- Queries up to 10 changes per API request
- Uses isolates for parallel processing
- Handles partial failures gracefully

### 2. Performance Optimization

#### Execution Time Targets

- **Achieved**: Often < a few seconds for repositories with dozens of branches

#### Optimization Techniques

- **Parallel Processing**: Git operations and API calls run concurrently
- **Caching**: Git command results cached within execution
- **Batch APIs**: Minimize network round-trips to Gerrit
- **Isolates**: CPU-intensive JSON parsing in separate threads

### 3. Error Recovery

DGT handles various error conditions gracefully:

#### Git Errors

- Repository validation before operations
- Graceful handling of missing branches
- Partial results when some Git operations fail

#### Network Errors

- Continue with local data when Gerrit API fails
- Display partial results for successful API calls
- Show "-" for unavailable Gerrit information

#### Invalid Input

- Validate date formats with helpful error messages
- Validate status and sort field values
- Suggest corrections for common mistakes

### 4. Cross-Platform Support

#### Path Handling

- Uses Dart's `path` package for cross-platform file paths
- Handles Windows, macOS, and Linux path conventions
- Resolves user home directory (`~`) appropriately

#### Shell Compatibility

- Works with various shells (bash, zsh, PowerShell, cmd)
- Handles different Git executable locations
- Respects system PATH configuration

## Integration with Development Workflow

### 1. Daily Usage Patterns

#### Morning Check-in

```bash
# Quick overview of all work
dgt --status active --status wip --diverged
```

#### Feature Development

```bash
# Focus on current work
dgt --status active --since 2025-10-01
```

#### Pre-merge Review

```bash
# Check what's ready to merge
dgt --status active --sort gerrit-date
```

#### Branch Cleanup

```bash
# Clean up merged branches
dgt clean --delete
```

### 2. Configuration Strategies

#### Minimal Setup

```bash
# Basic configuration for most users
dgt config --url --status active --status wip
```

#### Power User Setup

```bash
# Comprehensive configuration
dgt config --url --diverged --sort local-date --desc --since 2025-10-01
```

#### Team Configuration

Teams can share configuration recommendations in documentation:

```bash
# Recommended team configuration
dgt config --status active --status wip --diverged --sort local-date --desc
```

### 3. Performance Considerations

#### Large Repositories

DGT is optimized for repositories with many branches:

- Batch operations scale linearly with branch count
- Memory usage remains constant regardless of repository size
- Network usage minimized through batch API calls

This comprehensive feature documentation covers all current functionality in the DGT tool, providing users and developers with detailed understanding of capabilities and usage patterns.
