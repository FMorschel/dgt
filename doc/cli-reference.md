# CLI Reference

## Overview

Complete command-line interface reference for the DGT (Dart Gerrit Tool).

## Global Options

These options are available for all commands.

### Help and Information

```bash
--help, -h                 Show help information
--version                  Show version information
--verbose, -v              Enable verbose output with detailed execution information
--timing, -t               Show performance timing breakdown after execution
```

### Repository Options

```bash
--path <path>, -p <path>   Specify repository path (default: current directory)
```

## Commands

### `dgt` (default command)

Alias for `dgt list`. Lists all local branches with their Gerrit status.

### `dgt list`

Lists all local Git branches with their Gerrit code review status.

#### Syntax

```bash
dgt list [options]
```

#### Display Options

```bash
--gerrit / --no-gerrit     Show or hide Gerrit columns (hash, date) [default: true]
--local / --no-local       Show or hide local columns (hash, date) [default: true]
--url                      Show Gerrit URL column [default: false]
```

#### Filter Options

```bash
--status <status>          Filter by Gerrit status (can be used multiple times)
                          Allowed values: active, wip, merged, abandoned, conflict, gerrit, local

--since <date>             Show branches with commits after this date (ISO 8601 format)
--before <date>            Show branches with commits before this date (ISO 8601 format)
--diverged                 Show only branches with local or remote differences
```

#### Sort Options

```bash
--sort <field>             Sort branches by field
                          Allowed values: local-date, gerrit-date, status, divergences, name
--asc                      Sort in ascending order [default]
--desc                     Sort in descending order
```

#### Examples

```bash
# Basic usage
dgt list
dgt

# Filter examples
dgt list --status active
dgt list --status active --status wip
dgt list --since 2025-10-01 --before 2025-10-10
dgt list --diverged

# Sort examples
dgt list --sort local-date --desc
dgt list --sort status --asc

# Display options
dgt list --no-gerrit
dgt list --url --verbose

# Combined options
dgt list --status active --diverged --sort local-date --desc --url
```

### `dgt config`

Manage configuration settings to set default preferences.

#### Syntax

```bash
dgt config [subcommand] [options]
```

#### Subcommands

```bash
dgt config                 Show current configuration
dgt config [options]       Save configuration options
dgt config clean          Reset configuration to defaults
```

#### Configuration Options

All options from `dgt list` can be saved as defaults:

```bash
# Display options
--gerrit / --no-gerrit
--local / --no-local
--url

# Filter options
--status <status>
--since <date>
--before <date>
--diverged

# Sort options
--sort <field>
--asc / --desc
```

#### Special Configuration Options

```bash
--no-status               Remove saved status filter defaults
--no-sort                 Remove saved sort defaults
```

#### Clean Command Options

```bash
--force                   Reset configuration without confirmation prompt
```

#### Configuration File

- **Location**: `~/.dgt/.config`
- **Format**: JSON
- **Scope**: User-level (applies to all repositories)

#### Examples

```bash
# View current configuration
dgt config

# Save display preferences
dgt config --no-gerrit --url

# Save filter preferences
dgt config --status active --status wip --diverged

# Save sort preferences
dgt config --sort local-date --desc

# Remove specific options
dgt config --no-status
dgt config --no-sort

# Reset everything
dgt config clean
dgt config clean --force
```

### `dgt clean`

Wrapper around `git cl archive` command for cleaning up branches.

#### Syntax

```bash
dgt clean [git-cl-archive-options...]
```

#### Behavior

All arguments after `clean` are passed directly to `git cl archive`.

#### Examples

```bash
# Basic cleanup
dgt clean

# Archive with deletion
dgt clean --delete

# Force archive without prompts
dgt clean --force --delete

# Any git cl archive options work
dgt clean --dry-run --delete
```

## Status Values

### Gerrit Status Mapping

| CLI Value | Display Value | Description | Color |
|-----------|---------------|-------------|-------|
| `active` | `Active` | Ready for review (NEW, not WIP, mergeable) | Green |
| `wip` | `WIP` | Work in Progress | Yellow |
| `merged` | `Merged` | Successfully merged | Cyan |
| `abandoned` | `Abandoned` | Abandoned change | Gray |
| `conflict` | `Merge conflict` | Cannot be merged, needs rebase | Red |
| `gerrit` | _various_ | All branches with Gerrit configuration | - |
| `local` | `-` | No Gerrit configuration (local-only) | White |

## Sort Fields

| Field | Description | Sort Behavior |
|-------|-------------|---------------|
| `local-date` | Local commit date | Sorts by commit timestamp |
| `gerrit-date` | Gerrit update date | Sorts by last Gerrit update |
| `status` | Gerrit status | Sorts alphabetically by status |
| `divergences` | Divergence state | Sorts by: both diverged, one side, in sync |
| `name` | Branch name | Sorts alphabetically by branch name |

## Date Format

All date inputs use ISO 8601 format:

### Supported Formats

```bash
# Date only
2025-10-01
2025-12-25

# Date and time
2025-10-01T14:30:00
2025-10-01T14:30:00Z
2025-10-01T14:30:00-07:00

# Partial formats
2025-10
2025
```

### Examples

```bash
dgt list --since 2025-10-01
dgt list --before 2025-10-31T23:59:59
dgt config --since 2025-01-01 --before 2025-12-31
```

## Output Format

### Table Columns

The output table includes these columns (when enabled):

1. **Branch Name** - Local Git branch name
2. **Status** - Gerrit status or "-" for local-only branches
3. **Local Hash** - First 8 characters of local commit hash
4. **Local Date** - Local commit date in YYYY-MM-DD HH:MM format
5. **Gerrit Hash** - First 8 characters of Gerrit revision hash
6. **Gerrit Date** - Gerrit update date in YYYY-MM-DD HH:MM format
7. **URL** - Gerrit change URL (when `--url` is used)

### Color Coding

- **Green**: Active changes ready for review
- **Yellow**: Work in Progress changes or diverged information
- **Cyan**: Successfully merged changes
- **Red**: Changes with merge conflicts
- **Gray**: Abandoned changes
- **White**: Local-only branches or default text

### Divergence Indicators

When local and Gerrit states differ, the differing information is highlighted in yellow:

```text
feature/example      | Active          | abc12345     | 2025-10-09 15:00  | def67890     | 2025-10-09 10:00
                                                                           ^^^^^^^^     ^^^^^^^^^^^^^^^^
                                                                           (highlighted - different from local)
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error (invalid arguments, Git errors, etc.) |
| 2 | Not in a Git repository |

## Environment Variables

DGT respects standard environment variables:

- `HOME` / `USERPROFILE` - Used for configuration file location
- `PATH` - Used to locate Git executable
- `GIT_DIR` - Git repository directory (if set)

## Configuration Precedence

Settings are resolved in this order (highest to lowest priority):

1. **Command-line flags** - Explicit options provided with command
2. **Configuration file** - Saved defaults in `~/.dgt/.config`
3. **Built-in defaults** - Hardcoded default values

### Example

If you have saved `--status active` in config but run `dgt list --status wip`, the command-line `--status wip` takes precedence.

## Error Messages

### Common Errors

#### Invalid Repository

```text
Error: Not a Git repository
Please run this command from within a Git repository.
```

#### Invalid Date Format

```text
Invalid date format: "2025/10/01". Expected ISO 8601 format (e.g., 2025-10-10 or 2025-10-10T14:30:00)
```

#### Invalid Status Value

```text
The current --status given value "invalid" is not valid.
Allowed values:
  active (Ready for review)
  wip (Work in Progress)
  merged (Successfully merged)
  abandoned (Abandoned changes)
  conflict (Has merge conflicts)
  gerrit (All Gerrit statuses)
  local (Branches without Gerrit configuration)
```

#### Invalid Sort Field

```text
Invalid sort field: "invalid-field".
Allowed values:
  local-date (Local commit date)
  gerrit-date (Gerrit update date)
  status (Gerrit status)
  divergences (Divergence state)
  name (Branch name)
```

## Performance Notes

### Typical Performance

- **Small repositories** (< 10 branches): < 1 second
- **Medium repositories** (10-50 branches): 1-2 seconds
- **Large repositories** (50+ branches): 2-3 seconds

### Optimization Tips

1. **Use filters** to reduce processing: `--status active`
2. **Hide unnecessary columns**: `--no-gerrit` skips API calls entirely
3. **Use batch operations**: DGT automatically optimizes Git and API calls

### Performance Tracking

Use `--timing` to see execution breakdown:

```text
Performance Summary:
  Branch discovery:        45ms
  Git operations:         120ms
  Gerrit queries:         850ms
  Data processing:         35ms
  Output formatting:       15ms
  Total execution time:  1065ms
```

## Integration Examples

### Shell Aliases

```bash
# Quick status check
alias dgs='dgt --status active --status wip'

# Recent work
alias dgr='dgt --since $(date -d "1 week ago" +%Y-%m-%d)'

# Diverged branches
alias dgd='dgt --diverged --sort divergences --desc'
```

### Git Hooks

```bash
# In .git/hooks/post-checkout
#!/bin/bash
echo "Branch status:"
dgt --status active --status wip --diverged
```

### CI/CD Integration

```bash
# Check for stale branches in CI
dgt --status active --before $(date -d "30 days ago" +%Y-%m-%d) --format json
```

This CLI reference provides complete documentation of all command-line options, behaviors, and usage patterns for the DGT tool.
