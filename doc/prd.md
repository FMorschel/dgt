# Product Requirements Document (PRD) - DGT Tool

## Overview

DGT (Dart Gerrit Tool) is a command-line interface designed specifically for Dart SDK contributors to efficiently manage their local branches and track their Gerrit code review status. The tool provides a unified view of local Git repository state alongside corresponding Gerrit change information.

## Product Vision

Enable Dart SDK contributors to quickly understand the status of all their development branches in relation to Gerrit code reviews, reducing context switching and manual lookups between local Git repository and Gerrit web interface.

## Target Users

- **Primary**: Dart SDK contributors who use Gerrit for code review
- **Secondary**: Developers working with Git repositories that have Gerrit integration

## Core Use Cases

### 1. Branch Status Overview

**User Story**: As a contributor, I want to see all my local branches with their corresponding Gerrit review status in one place.

**Requirements**:

- Display all local Git branches
- Show Gerrit status for each branch (WIP, Active, Merged, Abandoned, Merge conflict)
- Indicate branches without Gerrit association (local-only)
- Color-coded output for quick visual identification

### 2. Divergence Detection

**User Story**: As a contributor, I want to know when my local branch differs from what's uploaded to Gerrit.

**Requirements**:

- Detect when local commits haven't been uploaded to Gerrit
- Detect when Gerrit has updates not reflected locally
- Highlight differences in hash and date columns
- Clear visual indicators for sync status

### 3. Branch Filtering and Organization

**User Story**: As a contributor working on multiple features, I want to filter branches to focus on specific work.

**Requirements**:

- Filter by Gerrit status (active, wip, merged, etc.)
- Filter by date range (since/before specific dates)
- Filter by divergence state (only branches with differences)
- Support multiple filter combinations

### 4. Configuration Management

**User Story**: As a regular user, I want to save my preferred display and filter settings.

**Requirements**:

- Persistent configuration storage
- Default display options (show/hide columns)
- Default filter preferences
- Configuration reset capability

### 5. Performance and Efficiency

**User Story**: As a contributor with many branches, I want fast execution times.

**Requirements**:

- Batch API queries to minimize network requests
- Parallel Git operations
- Optional performance timing display

## Core Features

### 1. Branch Listing (`dgt` / `dgt list`)

**Core Functionality**:

- Discovers all local Git branches
- Queries Gerrit for change status via batch API calls
- Displays information in formatted table with columns:
  - Branch Name
  - Status (WIP, Active, Merged, Abandoned, Merge conflict, -)
  - Local Hash (first 8 chars)
  - Local Date
  - Gerrit Hash (first 8 chars)
  - Gerrit Date
  - Optional: Gerrit URL

**Status Mapping**:

- `WIP`: Changes marked as work-in-progress
- `Active`: Changes ready for review (NEW status in Gerrit)
- `Merged`: Successfully merged changes
- `Abandoned`: Abandoned changes in Gerrit
- `Merge conflict`: Changes that cannot be merged
- `-`: No Gerrit change associated (local-only branch)

**Performance Features**:

- Batch Git operations using `git for-each-ref`
- Batch Gerrit API queries (up to 10 changes per request)
- Parallel processing with isolates
- Result caching to avoid redundant operations

### 2. Display Options

**Column Control**:

- `--gerrit` / `--no-gerrit`: Show/hide Gerrit columns
- `--local` / `--no-local`: Show/hide local Git columns
- `--url`: Include Gerrit URL column

**Output Enhancement**:

- `--verbose`: Detailed execution information
- `--timing`: Performance breakdown display
- Color coding for status and divergence indicators

### 3. Filtering System

**Status Filtering**:

- `--status <status>`: Filter by specific Gerrit status
- Multiple status values supported
- Special values: `gerrit` (all Gerrit statuses), `local` (no Gerrit config)

**Date Filtering**:

- `--since <date>`: Branches with commits after specified date
- `--before <date>`: Branches with commits before specified date
- ISO 8601 date format support

**Divergence Filtering**:

- `--diverged`: Show only branches with local or remote differences

### 4. Sorting System

**Sort Fields**:

- `local-date`: Local commit date
- `gerrit-date`: Gerrit update date
- `status`: Gerrit status
- `divergences`: Divergence state (both, one side, in sync)
- `name`: Branch name (default)

**Sort Directions**:

- `--asc`: Ascending order (default)
- `--desc`: Descending order

### 5. Configuration Management (`dgt config`)

**Save Defaults**:

- Display preferences (column visibility)
- Filter preferences (status, divergence, date ranges)
- Sort preferences (field and direction)

**Configuration Operations**:

- Save new configuration
- Remove specific options (`--no-status`, `--no-sort`)
- View current configuration
- Reset to defaults (`dgt config clean`)

**Storage**:

- Configuration file: `~/.dgt/.config`
- JSON format for easy parsing
- Cross-platform path resolution

### 6. Branch Cleanup (`dgt clean`)

**Functionality**:

- Wrapper around `git cl archive` command
- Passes all arguments directly to underlying command
- Maintains consistent verbose output and timing options

### 7. Git Integration

**Repository Detection**:

- Automatic Git repository validation
- Support for custom repository paths (`--path`)
- Error handling for non-Git directories

**Gerrit Configuration Extraction**:

- Reads `.git/config` for Gerrit metadata:
  - `branch.<name>.gerritissue`: Change number
  - `branch.<name>.gerritserver`: Gerrit server URL
  - `branch.<name>.gerritpatchset`: Patchset number
  - `branch.<name>.gerritsquashhash`: Squash hash
  - `branch.<name>.last-upload-hash`: Last uploaded commit

**Change-ID Fallback**:

- Extracts Change-IDs from commit messages when config missing
- Format: `Change-Id: I[40 hex characters]`

### 8. Gerrit API Integration

**Batch Query System**:

- Queries up to 10 changes per API request
- Handles Gerrit's XSSI protection (`)]}'` prefix)
- Isolate-based processing for performance
- Graceful error handling with partial results

**API Endpoints**:

- Primary: `/changes/?q=<query>&o=CURRENT_REVISION&o=LABELS&o=MESSAGES&o=REVIEWERS`
- Server: `https://dart-review.googlesource.com` (Dart SDK default)

**Data Extraction**:

- Status mapping from Gerrit API responses
- LGTM (Code-Review) vote counting
- Commit-Queue status detection
- Message and reviewer information

## Non-Functional Requirements

### Performance

- **Batch Operations**: Minimize Git process spawns and API requests
- **Parallel Processing**: Use Dart isolates for concurrent operations
- **Caching**: Cache Git command results within single execution

### Reliability

- **Error Handling**: Graceful degradation when API or Git operations fail
- **Partial Results**: Continue processing when some operations fail
- **Input Validation**: Validate all user inputs (dates, status values, etc.)

### Usability

- **Clear Output**: Color-coded, tabular display with alignment
- **Help System**: Comprehensive help text and usage examples
- **Error Messages**: Descriptive error messages with suggested fixes

## Technical Constraints

### API Limitations

- Gerrit API batch query limit: 10 changes per request
- Rate limiting considerations
- Network dependency for Gerrit queries

### Git Dependencies

- Requires Git installation and repository context
- Depends on specific `.git/config` format for Gerrit metadata
- Limited to repositories with Gerrit integration

### Configuration Scope

- User-level configuration only (no repository-specific config)
- Single configuration file format
- No remote configuration synchronization

## Future Considerations

This PRD focuses on existing implemented features. The tool provides a solid foundation for potential enhancements while maintaining its core value proposition of efficient branch and review status management for Dart SDK contributors.
