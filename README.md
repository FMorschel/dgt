<!-- markdownlint-disable MD040 -->
# DGT - Dart Gerrit Tool

> **Note**: This project was built by AI.

A command-line interface tool for Dart SDK contributors to manage their local branches and track their Gerrit review status.

## Features

- **List Local Branches**: Display all your local Git branches with their Gerrit review status
- **Gerrit Integration**: Automatically queries Gerrit REST API to get the current status of your changes
- **Status Detection**: Shows one of four states for each branch:
  - **WIP** (Work in Progress): Changes marked as work-in-progress in Gerrit
  - **Active**: Changes that are ready for review (NEW status in Gerrit)
  - **Merge conflict**: Changes that cannot be merged cleanly
  - **Merged**: Changes that have been successfully merged

## Prerequisites

- Git repository with Gerrit remotes configured
- Access to `gerrit-review.googlesource.com` (for Dart SDK contributions)

## Installation

```bash
dart pub global activate --source path .
```

## Usage

### List branches with Gerrit status

```bash
dart pub global run dgt list
# or simply
dart pub global run dgt
```

### Example Output

Here's what the output looks like when you run `dgt` in a repository with multiple branches:

```
Branch Name          | Status          | Local Hash   | Local Date        | Gerrit Hash  | Gerrit Date
----------------------------------------------------------------------------------------------------------------------------
main                 | -               | a1b2c3d4     | 2025-10-09 10:15  | -            | -
feature/new-api      | Active          | e5f6a7b8     | 2025-10-09 14:30  | e5f6a7b8     | 2025-10-09 14:30
bugfix/memory-leak   | WIP             | c9d0e1f2     | 2025-10-08 16:45  | c9d0e1f2     | 2025-10-08 16:45
refactor/cleanup     | Merged          | g3h4i5j6     | 2025-10-07 09:20  | g3h4i5j6     | 2025-10-07 11:00
hotfix/crash         | Merge conflict  | k7l8m9n0     | 2025-10-09 08:00  | k7l8m9n0     | 2025-10-09 08:00
experiment/perf      | -               | o1p2q3r4     | 2025-10-06 13:15  | -            | -

Total: 6 branch(es)
```

**Color Coding:**

- 🟢 **Active** (Green): Changes ready for review
- 🟡 **WIP** (Yellow): Work in progress, not ready for review
- 🔴 **Merge conflict** (Red): Cannot be merged, needs rebase
- 🔵 **Merged** (Cyan/Blue): Successfully merged
- ⚪ **-** (White): No Gerrit change (local-only branch)

**Difference Highlighting:**

When your local branch differs from what's uploaded to Gerrit, the Gerrit hash and/or date will be highlighted in yellow:

```
Branch Name          | Status          | Local Hash   | Local Date        | Gerrit Hash  | Gerrit Date
----------------------------------------------------------------------------------------------------------------------------
feature/updates      | Active          | x1y2z3a4     | 2025-10-09 15:00  | b5c6d7e8     | 2025-10-09 10:00
                                                                           ^^^^^^^^     ^^^^^^^^^^^^^^^^
                                                                           (highlighted in yellow - different from local)
```

This indicates that you have local commits that haven't been uploaded to Gerrit yet.

### Verbose Output

For detailed information about what DGT is doing:

```bash
dart pub global run dgt --verbose
# or
dart pub global run dgt -v
```

This shows:

- Git commands being executed
- Gerrit API queries being made
- Branch processing status
- Query results and timing

### Performance Timing

Display a summary of execution time breakdown:

```bash
dart pub global run dgt --timing
# or
dart pub global run dgt -t
```

This shows a performance summary after the branch table:

```
Performance Summary:
  Branch discovery:        45ms
  Git operations:         320ms
  Gerrit API queries:     890ms
  Result processing:       28ms
  Filtering:                3ms
  Total execution time:  1283ms
```

You can combine with other flags:

```bash
dart pub global run dgt -v -t  # Verbose output with timing
dart pub global run dgt -p /path/to/repo --timing  # Timing for specific repo
```

### Show Gerrit URL column

Include the Gerrit change URL in the table output:

```bash
dart pub global run dgt --url
```

Save URL column as a default in your config:

```bash
# Save the URL column as a default (stored in ~/.dgt/.config)
dart pub global run dgt config --url
```

### Specify Repository Path

Analyze a repository in a different directory:

```bash
dart pub global run dgt --path /path/to/repo
# or
dart pub global run dgt -p D:\projects\dart-sdk
```

### Configuration Commands

Save default display preferences:

```bash
# Hide Gerrit columns by default
dart pub global run dgt config --no-gerrit

# Hide local columns by default
dart pub global run dgt config --no-local

# Show all columns (reset to defaults)
dart pub global run dgt config --gerrit --local
```

Save default filter preferences:

```bash
# Set default to show only Active branches
dart pub global run dgt config --status active

# Set default to show only diverged branches
dart pub global run dgt config --diverged

# Set default to show branches since a date
dart pub global run dgt config --since 2025-10-01

# Combine multiple defaults
dart pub global run dgt config --status active --status wip --diverged
```

Configuration is saved to `~/.dgt/.config` and applies to all repositories unless overridden by command-line flags.

### Filtering Branches

Filter the branch list to focus on specific branches:

**Filter by Status:**

```bash
# Show only Active branches
dart pub global run dgt --status active

# Show Active and WIP branches
dart pub global run dgt --status active --status wip

# Show only merged branches
dart pub global run dgt --status merged

# Show only branches with merge conflicts
dart pub global run dgt --status conflict
```

Allowed status values:

- `wip` - Work in Progress
- `active` - Ready for review
- `merged` - Successfully merged
- `conflict` - Has merge conflicts

> **Tip:** Run `dgt --help` to see all available options and status values.

**Filter by Date:**

```bash
# Show branches with commits after October 1st, 2025
dart pub global run dgt --since 2025-10-01

# Show branches with commits before October 10th, 2025
dart pub global run dgt --before 2025-10-10

# Show branches in a date range
dart pub global run dgt --since 2025-10-01 --before 2025-10-10
```

**Filter by Divergence:**

```bash
# Show only branches that have diverged (local or remote changes)
dart pub global run dgt --diverged

# Combine with status filter
dart pub global run dgt --status active --diverged
```

**Combining Filters:**

```bash
# Active branches that have diverged, updated since October 1st
dart pub global run dgt --status active --diverged --since 2025-10-01

# WIP or Active branches from the last week
dart pub global run dgt --status wip --status active --since 2025-10-03
```

### Help

```bash
dart pub global run dgt --help
```

## How it works

1. **Branch Discovery**: Scans your local Git repository for all branches using `git branch --list`
2. **Git Information Gathering**: For each branch, retrieves commit hash, date, and message (in parallel for performance)
3. **Config Parsing**: Reads `.git/config` to extract Gerrit metadata (issue number, server URL, patchset info)
4. **Batch API Queries**: Queries Gerrit REST API for all branches at once (batches of up to 10) for optimal performance
5. **Status Mapping**: Translates Gerrit API responses (NEW, MERGED, etc.) into user-friendly status indicators
6. **Difference Detection**: Compares local commit hashes/dates with Gerrit to highlight un-uploaded changes
7. **Formatted Display**: Presents results in a color-coded table with difference highlighting

### Performance Optimizations

- **Parallel Git Operations**: All Git commands run concurrently using Dart's Future.wait
- **Batch Gerrit Queries**: Multiple changes queried in single API calls (up to 10 per request)
- **Isolate-based Processing**: Each batch query and JSON parsing runs in a separate isolate
- **Result Caching**: Git command results are cached to avoid redundant executions
- **Partial Success**: If some queries fail, continues processing other branches

Typical execution time: **< 3 seconds** for repositories with dozens of branches.

## Documentation

For more detailed information, see:

- **[Gerrit API Documentation](doc/gerrit_api.md)** - Detailed information about Gerrit REST API endpoints, request/response formats, XSSI protection, and batch query optimization
- **[Git Config Documentation](doc/git_config.md)** - Explanation of how Gerrit metadata is stored in `.git/config` and how DGT uses it
- **[Implementation Plan](doc/plan.md)** - Complete implementation roadmap and technical details
- **[Product Requirements](doc/prd.md)** - Original product requirements and design decisions

## Configuration

The tool automatically reads your local Git configuration to extract:

- **Gerrit Issue Numbers**: From `.git/config` branch settings (e.g., `branch.feature.gerritissue`)
- **Gerrit Server URLs**: Server where the change was uploaded (e.g., `branch.feature.gerritserver`)
- **Change-IDs**: Extracted from commit messages as a fallback (format: `Change-Id: I[40 hex chars]`)
- **Patchset Information**: Current patchset number and upload hashes

See the [Git Config Documentation](doc/git_config.md) for full details on the configuration format.

## Contributing

This tool is designed specifically for Dart SDK contributors working with Gerrit code reviews.
