# Project Structure Documentation

## Overview

This document describes the architecture and structure of the DGT (Dart Gerrit Tool) project, explaining how different components work together to provide branch and Gerrit integration functionality.

## Project Layout

```text
dgt/
├── bin/
│   └── dgt.dart              # Main entry point and CLI command handling
├── lib/
│   ├── branch_info.dart      # Branch information data model
│   ├── clean_command.dart    # Git clean/archive command wrapper
│   ├── cli_options.dart      # CLI option definitions and metadata
│   ├── config_command.dart   # Configuration command handling
│   ├── config_service.dart   # Configuration file management
│   ├── display_options.dart  # Display configuration model
│   ├── error_validation.dart # Input validation and error handling
│   ├── filtering.dart        # Branch filtering logic
│   ├── gerrit_service.dart   # Gerrit API integration
│   ├── git_service.dart      # Git repository operations
│   ├── git_service_batch.dart # Batch Git operations for performance
│   ├── output_formatter.dart # Table formatting and display
│   ├── performance_tracker.dart # Performance measurement utilities
│   ├── print_config.dart     # Configuration display utilities
│   ├── print_usage.dart      # Help text and usage information
│   ├── sorting.dart          # Branch sorting logic
│   ├── terminal.dart         # Terminal output utilities
│   └── verbose_output.dart   # Verbose logging system
├── doc/                      # Documentation files
├── analysis_options.yaml     # Dart analysis configuration
├── pubspec.yaml             # Dart package configuration
└── README.md               # User-facing documentation
```

## Architecture Overview

The DGT tool follows a modular architecture with clear separation of concerns:

### Core Components

#### 1. Entry Point (`bin/dgt.dart`)

**Purpose**: Main application entry point that orchestrates command execution.

**Responsibilities**:

- Command-line argument parsing
- Command routing (list, config, clean)
- Global option handling (verbose, timing, help)
- Error handling and user feedback
- Performance tracking coordination

**Key Functions**:

- `main()`: Application entry point
- `runListCommand()`: Orchestrates branch listing workflow
- `runConfigCommand()`: Handles configuration management
- `runCleanCommand()`: Wraps git cl archive functionality

#### 2. Data Models

##### BranchInfo (`lib/branch_info.dart`)

**Purpose**: Represents complete information about a Git branch and its Gerrit status.

**Key Properties**:

- `branchName`: Local Git branch name
- `localHash`/`localDate`: Local commit information
- `gerritConfig`: Gerrit configuration from Git config
- `gerritChange`: Gerrit change information (nullable)
- `gerritUrl`: Gerrit change URL (nullable)

**Key Methods**:

- `getDisplayStatus()`: User-friendly status string
- `hasLocalChanges()`: Detects uncommitted local changes
- `hasRemoteChanges()`: Detects Gerrit updates not pulled locally

##### GerritChange (`lib/gerrit_service.dart`)

**Purpose**: Represents a Gerrit change with all its metadata.

**Key Properties**:

- `changeId`: Gerrit change ID
- `status`: Change status (NEW, MERGED, ABANDONED)
- `workInProgress`: WIP flag
- `mergeable`: Whether change can be merged
- `lgtm`: Code review status with vote counts

#### 3. Service Layer

##### GitService (`lib/git_service.dart`)

**Purpose**: Handles all Git repository interactions.

**Key Functions**:

- `getAllBranches()`: Discovers local branches
- `getCommitHash()`/`getCommitDate()`: Retrieves commit info
- `isGitRepository()`: Validates Git repository
- `getGerritConfig()`: Extracts Gerrit metadata from Git config

**Features**:

- Command result caching to avoid redundant Git calls
- Change-ID extraction from commit messages
- Gerrit configuration parsing from `.git/config`

##### GitServiceBatch (`lib/git_service_batch.dart`)

**Purpose**: Optimized batch operations for improved performance.

**Key Functions**:

- `getBatchCommitInfo()`: Gets commit info for multiple branches in single Git call
- `getBatchGerritConfig()`: Extracts Gerrit config for all branches efficiently

**Benefits**:

- Reduces Git process spawn overhead
- Minimizes total execution time
- Scales better with large numbers of branches

##### GerritService (`lib/gerrit_service.dart`)

**Purpose**: Integrates with Gerrit REST API for change information.

**Key Functions**:

- `getBatchChangesByIssueNumbers()`: Batch query multiple changes
- `getChangeByIssue()`: Single change lookup
- `parseGerritResponse()`: Handles XSSI protection and JSON parsing

**Features**:

- Batch API queries (up to 10 changes per request)
- Isolate-based processing for performance
- Graceful error handling with partial results
- LGTM vote counting and Commit-Queue status detection

#### 4. Processing Layer

##### FilterOptions & Filtering (`lib/filtering.dart`)

**Purpose**: Handles branch filtering based on user criteria.

**Filter Types**:

- Status filtering (by Gerrit status)
- Date range filtering (since/before dates)
- Divergence filtering (branches with differences)

**Key Functions**:

- `applyFilters()`: Applies all active filters to branch list
- `parseDate()`: Validates and parses ISO 8601 dates
- `validateStatus()`: Validates status filter values

##### SortOptions & Sorting (`lib/sorting.dart`)

**Purpose**: Handles branch sorting functionality.

**Sort Fields**:

- `local-date`: Local commit date
- `gerrit-date`: Gerrit update date
- `status`: Gerrit status
- `divergences`: Divergence state
- `name`: Branch name

**Key Functions**:

- `applySort()`: Sorts branches by specified criteria
- `validateSortField()`/`validateSortDirection()`: Input validation

#### 5. Configuration Management

##### ConfigService (`lib/config_service.dart`)

**Purpose**: Manages persistent user configuration.

**Configuration Storage**:

- Location: `~/.dgt/.config`
- Format: JSON
- Scope: User-level (not repository-specific)

**Key Functions**:

- `loadConfig()`/`saveConfig()`: File I/O operations
- `removeOptions()`: Selective configuration removal
- `getConfigPath()`: Cross-platform path resolution

**Configuration Options**:

- Display preferences (column visibility)
- Filter defaults (status, date ranges, divergence)
- Sort preferences (field and direction)

#### 6. Output and Display

##### OutputFormatter (`lib/output_formatter.dart`)

**Purpose**: Formats and displays branch information in tabular format.

**Features**:

- Dynamic column width calculation
- Color coding for status and divergence
- Difference highlighting (yellow for mismatches)
- Performance summary display

**Key Functions**:

- `displayBranchTable()`: Main table rendering
- `displayPerformanceSummary()`: Performance metrics display

##### Terminal (`lib/terminal.dart`)

**Purpose**: Provides consistent terminal output utilities.

**Features**:

- Color-coded output (using ansicolor package)
- Consistent message formatting
- Error/info/warning output methods

#### 7. Utility Components

##### PerformanceTracker (`lib/performance_tracker.dart`)

**Purpose**: Measures and reports execution performance.

**Features**:

- Operation timing with start/end markers
- Total execution time tracking
- Performance summary reporting

##### VerboseOutput (`lib/verbose_output.dart`)

**Purpose**: Handles verbose logging throughout the application.

**Features**:

- Singleton pattern for global access
- Conditional output based on verbose flag
- Detailed operation logging for debugging

## Data Flow

### Branch Listing Workflow

1. **Initialization**
   - Parse command-line arguments
   - Load user configuration
   - Initialize performance tracking

2. **Repository Validation**
   - Check if current directory is Git repository
   - Change to specified path if provided

3. **Branch Discovery**
   - Use `git branch --list` to find all local branches
   - Batch fetch commit info using `git for-each-ref`
   - Extract Gerrit configuration from `.git/config`

4. **Gerrit Integration**
   - Build issue number to branch mapping
   - Batch query Gerrit API for change information
   - Process responses in parallel using isolates

5. **Data Processing**
   - Combine local and Gerrit information into BranchInfo objects
   - Apply user-specified filters (status, date, divergence)
   - Apply sorting if specified

6. **Output Generation**
   - Format data into tabular display
   - Apply color coding and highlighting
   - Display performance summary if requested

### Configuration Workflow

1. **Load Existing Config**
   - Read configuration file from `~/.dgt/.config`
   - Parse JSON into DgtConfig object

2. **Merge Settings**
   - Combine CLI arguments, config file, and defaults
   - Handle precedence: CLI > Config > Defaults

3. **Save Updates**
   - Write updated configuration back to file
   - Handle selective removal of options

## Performance Optimizations

### Batch Operations

**Git Operations**:

- Single `git for-each-ref` call instead of N `git log` calls
- Single config regexp query instead of N config queries

**Gerrit API**:

- Batch queries of up to 10 changes per request
- Parallel processing using Dart isolates
- Graceful handling of partial failures

### Caching Strategy

**Git Command Cache**:

- Cache results within single execution
- Avoid redundant Git process spawns
- Clear cache when repository state might change

### Parallel Processing

**Concurrent Operations**:

- Git operations for different branches
- Gerrit API batch queries
- JSON parsing in separate isolates

## Error Handling

### Graceful Degradation

**Git Errors**:

- Continue processing other branches if one fails
- Display partial results with error indicators
- Validate repository state before operations

**Gerrit API Errors**:

- Handle network failures gracefully
- Process partial API responses
- Display "-" for unavailable information

### Input Validation

**User Input**:

- Validate date formats (ISO 8601)
- Validate status and sort field values
- Provide helpful error messages with suggestions

## Extension Points

### Adding New Commands

1. Add command definition in `bin/dgt.dart`
2. Create command handler function
3. Add argument parsing logic
4. Integrate with existing services

### Adding New Filters

1. Extend `FilterOptions` class
2. Add CLI option definitions
3. Implement filter logic in `applyFilters()`
4. Add validation if needed

### Adding New Sort Fields

1. Add field to `allowedSortFields` constant
2. Implement sort comparison in `applySort()`
3. Add field description for help text
4. Update validation

## Dependencies

### Core Dependencies

- `args`: Command-line argument parsing
- `http`: Gerrit API communication
- `ansicolor`: Terminal color output
- `path`: Cross-platform file path handling

### Development Dependencies

- `lints`: Dart code analysis rules
- `test`: Unit testing framework
