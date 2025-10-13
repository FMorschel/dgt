<!-- markdownlint-disable MD040 -->
# Product Requirements Document: DGT (Dart Gerrit Tool)

## Overview

DGT is a command-line interface tool designed to help Dart SDK contributors efficiently manage their local Git branches and track the status of their Gerrit code reviews.

## Problem Statement

Dart SDK contributors working with Gerrit often have multiple branches with different review states. Currently, developers need to:

- Manually check each branch's status in the Gerrit web interface
- Remember which changes are ready for review, merged, or have conflicts
- Switch between terminal and browser to get a complete picture of their work

This leads to inefficiency and potential oversight of important review status changes.

## Goals

### Primary Goals

1. **Centralized Status View**: Provide a single command to view all local branches with their Gerrit review status
2. **Automation**: Eliminate manual checking by automatically querying Gerrit API
3. **Developer Efficiency**: Reduce context switching between tools and interfaces

### Secondary Goals

1. **Integration**: Seamlessly work with existing Git workflows
2. **Reliability**: Handle network issues and API limitations gracefully
3. **Extensibility**: Support future enhancements for other Git hosting platforms

## Target Users

- **Primary**: Dart SDK contributors who use Gerrit for code reviews
- **Secondary**: Any developer working with Gerrit-based workflows

## Features

### Core Features

#### 1. Branch Listing with Status

**Description**: Display all local Git branches with their current Gerrit review status.

**Acceptance Criteria**:

- List all local branches
- Show one of four status indicators: WIP, Active, Merge conflict, Merged
- Display local commit hash (hash of the commit on the local branch)
- Display Gerrit commit hash (hash of the latest commit in the Gerrit change)
- Display local commit date (timestamp of the local commit)
- Display Gerrit change date (last updated timestamp from Gerrit)
- Handle branches without Gerrit changes gracefully
- Performance: Complete execution in under 3 seconds for typical repositories

#### 2. Gerrit API Integration

**Description**: Query Gerrit REST API to retrieve change status information.

**Technical Requirements**:

- Use Gerrit REST API v3.13+ endpoints
- Query `GET /changes/` endpoint with appropriate filters
- Extract `updated` timestamp from Gerrit change responses
- Extract current revision hash from Gerrit change responses
- Handle authentication (if required)
- Parse JSON responses correctly

**Status Mapping**:

- **WIP**: Changes with `work_in_progress: true`
- **Active**: Changes with `status: "NEW"` and `work_in_progress: false`
- **Merge conflict**: Changes with `mergeable: false`
- **Merged**: Changes with `status: "MERGED"`

#### 3. Git Configuration Parsing

**Description**: Extract Gerrit-related information from local Git configuration.

**Git Branch Configuration Format**:

Gerrit data for each branch is stored in the Git config file (`.git/config`) with the following structure:

```properties
[branch "branch-name"]
    base = <commit-hash>
    base-upstream = refs/remotes/origin/main
    gerritissue = <issue-number>
    gerritserver = https://dart-review.googlesource.com
    gerritpatchset = <patchset-number>
    gerritsquashhash = <squashed-commit-hash>
    last-upload-hash = <last-uploaded-commit-hash>
    vscode-merge-base = origin/main
```

**Key Configuration Fields**:

- `gerritissue`: The Gerrit change/issue number (e.g., 389423)
- `gerritserver`: The Gerrit server URL (e.g., <https://dart-review.googlesource.com>)
- `gerritpatchset`: The current patchset number
- `gerritsquashhash`: Hash of the squashed commit in Gerrit (the commit hash as it exists in the Gerrit review)
- `last-upload-hash`: Hash of the last uploaded commit from the local branch
- `base`: The base commit hash this branch was created from
- `base-upstream`: The upstream reference branch

**Technical Requirements**:

- Read and parse `.git/config` file to extract branch-specific Gerrit metadata
- Extract `gerritissue` and `gerritserver` to construct Gerrit API URLs
- Use `gerritissue` to query the Gerrit API for change status
- **Compare `last-upload-hash` with local HEAD to detect local changes not yet uploaded**
- **Compare `gerritsquashhash` with Gerrit's current revision to detect remote changes not yet pulled**
- Extract commit hashes from local Git history
- Extract commit timestamps from local Git history
- Handle branches without Gerrit configuration gracefully
- Handle multiple remotes appropriately

### Command Line Interface

```bash
# Primary command - list branches with status
dgt [list]

# Help
dgt --help

# Version
dgt --version

# Enable timing summary
dgt --timing
dgt -t
```

### Output Format

```
Branch Name          | Status         | Change ID          | Local Hash  | Local Date       | Gerrit Hash | Gerrit Date
---------------------|----------------|--------------------| ------------|------------------|-------------|------------------
main                 | -              | -                  | a1b2c3d     | 2025-10-07 14:30 | -           | -
feature/new-api      | Active         | I8473b95934b57...  | e4f5g6h     | 2025-10-06 09:15 | e4f5g6h     | 2025-10-06 09:20
bugfix/memory-leak   | Merged         | I9584c06e45d28...  | i7j8k9l     | 2025-09-28 16:45 | m1n2o3p     | 2025-09-30 11:00
wip/experimental     | WIP            | I7395d17f32e19...  | q4r5s6t     | 2025-10-05 13:22 | q4r5s6t     | 2025-10-05 13:25
hotfix/critical      | Merge conflict | I6284a29c41b37...  | u7v8w9x     | 2025-10-01 10:00 | y0z1a2b     | 2025-10-01 10:05
```

**Optional Timing Summary** (with `--timing` flag):

```
Performance Summary:
  Branch discovery:        45ms
  Git operations:         320ms
  Gerrit API queries:     890ms
  Result processing:       28ms
  Total execution time:  1283ms
```

**Color Coding**: Status indicators are color-coded for visual clarity:

- **WIP**: Yellow
- **Active**: Green
- **Merge conflict**: Red
- **Merged**: Blue/Cyan

**Difference Highlighting**:

The tool highlights differences between local and Gerrit state to help identify sync issues:

- **Yellow Gerrit Hash**: Indicates that Gerrit's current revision differs from the local HEAD commit
  - This means either:
    - The Gerrit change has been updated (new patchset uploaded, rebased, amended)
    - The local branch is based on an older patchset
  - **Detection**: Compare `gerritsquashhash` (from Git config) with Gerrit API's `current_revision`
  
- **Yellow Gerrit Date**: Indicates temporal difference, often accompanying hash differences
  - Shows the last update time differs between local and remote

- **Yellow Local Hash**: Indicates local changes not yet uploaded to Gerrit
  - This means:
    - The local branch has new commits since the last upload
    - Changes need to be uploaded to Gerrit
  - **Detection**: Compare local HEAD hash with `last-upload-hash` (from Git config)

**Current Implementation Issue**:

The current implementation compares the truncated local HEAD hash directly with Gerrit's current revision hash, which doesn't accurately represent the sync state because:

1. It doesn't use `last-upload-hash` to detect local changes
2. It doesn't use `gerritsquashhash` to detect remote changes
3. Hash comparison is unreliable when rebases or amendments occur

**Improved Detection Logic**:

```
Local changes exist when: local_HEAD_hash ≠ last-upload-hash
Remote changes exist when: gerritsquashhash ≠ gerrit_current_revision
```

## Non-Goals

1. **Change Creation**: Tool will not create or modify Gerrit changes
2. **Code Review**: No reviewing functionality (comments, approvals)
3. **Multi-Repository**: Single repository operation only
4. **Complex Authentication**: Basic authentication support only

## Technical Specifications

### Architecture

- **Language**: Dart
- **Dependencies**:
  - `http` package for API calls
  - `args` package for CLI parsing
  - `ansicolor` package for colored terminal output
  - Native Dart `Process` for Git commands

### API Requirements

- **Gerrit REST API**: Support for `gerrit-review.googlesource.com`
- **Endpoints**:
  - `GET /changes/?q={query}` for change lookup
  - Support for Change-Id and commit SHA queries
- **Authentication**: Anonymous access (public Dart repository)

### Error Handling

- **Network Errors**: Graceful fallback with clear error messages
- **Git Errors**: Handle repositories without Gerrit configuration
- **API Errors**: Handle rate limits and service unavailability

### Performance Requirements

- **Startup Time**: < 1 second
- **API Queries**: Batch requests where possible
- **Total Execution**: < 3 seconds for typical use cases

## Success Metrics

1. **Adoption**: Used by 10+ Dart SDK contributors within first month
2. **Efficiency**: 50% reduction in time spent checking review status
3. **Reliability**: 99%+ successful executions in normal network conditions
4. **User Satisfaction**: Positive feedback from core Dart team

## Dependencies and Assumptions

### Dependencies

- Git installed and configured
- Network access to `gerrit-review.googlesource.com`
- Dart SDK 3.9.2+

### Assumptions

- Users have Gerrit Change-IDs in their commit messages
- Local branches correspond to Gerrit changes
- Public repository access (no authentication required)

## Optional Features

### Performance Timing Summary

**Description**: Display a breakdown of execution time for different operations.

**Flag**: `--timing` or `-t`

**Output**: After the branch table, display:

- Time spent discovering branches
- Time spent executing Git operations
- Time spent querying Gerrit API
- Time spent processing results
- Total execution time

**Purpose**: Help users and developers:

- Identify performance bottlenecks
- Understand where time is spent
- Debug slow operations
- Optimize workflows

## Future Enhancements

1. **Notification System**: Alert on status changes
2. **Integration**: VS Code extension or Git hooks
3. **Enhanced Output**: JSON format option, customizable color schemes
4. **Change Details**: Show review comments count, approval status

## Requirements

The following requirements capture user requests and open issues identified for the project (recorded on 2025-10-10):

1. Sort output

   - Description: Users must be able to sort the tool's output by one or more fields to make scanning large lists easier.
   - Acceptance criteria:
     - Provide a CLI option to sort by: date (local or Gerrit), status, divergences (missing push/pull), and branch name.
     - Support ascending and descending order.
     - Sorting should be stable and performant for typical repositories.

2. Filter output

   - Description: Users must be able to filter the output to focus on branches of interest.
   - Acceptance criteria:
     - Provide CLI options to filter by status (WIP, Active, Merge conflict, Merged).
     - Provide date-based filters: `--since <date>` and `--before <date>` to limit by last commit date.
     - Filters may be combined (e.g., status + date range) and should be applied efficiently.

3. Show Gerrit URL column

   - Description: Users should be able to display a clickable Gerrit change URL for each branch in the output table.
   - Acceptance criteria:
     - Provide a CLI option to include a "URL" column in the output.
     - The URL should link directly to the Gerrit change page for each branch (when available).
     - The column should be shown alongside branch name and status, and may be toggled on/off for space efficiency.
     - Handle branches without Gerrit changes gracefully (show empty or placeholder).
