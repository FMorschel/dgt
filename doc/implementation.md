# Implementation Guide

## Overview

This guide explains how to implement new features and modifications in the DGT tool. It covers the existing codebase patterns, extension points, and development workflows.

## Development Environment Setup

### Prerequisites

- Dart SDK 3.9.2 or later
- Git (for repository operations)
- Access to Gerrit server (for testing API integration)

### Project Setup

1. Clone the repository
2. Install dependencies: `dart pub get`
3. Run analysis: `dart analyze`
4. Run tests: `dart test`

### Code Style

The project follows Dart's official style guide with additional linting rules defined in `analysis_options.yaml`.

**Key Rules**:

- Use single quotes for strings
- Always declare return types
- Prefer `const` constructors where possible
- Lines should not exceed 80 characters
- Use relative imports within the package

## Architecture Patterns

### Service Layer Pattern

All external integrations (Git, Gerrit, file system) are encapsulated in service classes.

**Example**: `GitService` handles all Git operations.

```dart
class GitService {
  static Future<List<String>> getAllBranches() async {
    // Implementation
  }
}
```

### Data Models

Use immutable data classes with named constructors for domain objects.

**Example**: `BranchInfo` combines Git and Gerrit data.

```dart
class BranchInfo {
  const BranchInfo({
    required this.branchName,
    required this.localHash,
    // ... other properties
  });

  final String branchName;
  final String localHash;
}
```

### Configuration Resolution

Use a three-layer precedence system: CLI arguments > Config file > Defaults.

**Pattern**:

```dart
factory DisplayOptions.resolve({
  required ArgResults results,
  required DgtConfig? config,
}) {
  return DisplayOptions(
    showGerrit: config.resolveFlag(results, 'gerrit', true),
    // ... other options
  );
}
```

## Adding New Commands

### 1. Command Structure

Commands are handled in `bin/dgt.dart` with a switch statement on the first argument.

### 2. Implementation Steps

#### 1. **Add Command Parsing**

```dart
// In main() function
case 'new-command':
  await runNewCommand(/* parameters */);
```

#### 2. **Create Command Handler**

```dart
Future<void> runNewCommand(
  String? repositoryPath,
  // Other parameters
) async {
  // Command implementation
}
```

#### 3. **Add CLI Options**

```dart
// In CliOptions class
static const String newOption = 'new-option';
```

#### 4. **Update Help Text**

Add command description in `lib/print_usage.dart`.

### Example: Adding a Status Command

```dart
// 1. Add command case
case 'status':
  final branch = statusResults.option('branch');
  await runStatusCommand(repositoryPath, branch);

// 2. Implement command
Future<void> runStatusCommand(String? path, String? branch) async {
  // Change directory if needed
  if (path != null) {
    Directory.current = path;
  }

  // Get branch info
  final targetBranch = branch ?? await GitService.getCurrentBranch();
  final branchInfo = await getBranchInfo(targetBranch);

  // Display results
  Terminal.info('Status for $targetBranch: ${branchInfo.getDisplayStatus()}');
}
```

## Adding New Filters

### 1. Extend FilterOptions

```dart
class FilterOptions {
  FilterOptions({
    this.statuses,
    this.since,
    this.before,
    this.diverged,
    this.newFilter, // Add new filter
  });

  final bool? newFilter;
}
```

### 2. Add CLI Option

```dart
// In CliOptions.addCommonOptions()
parser.addFlag(
  'new-filter',
  help: 'Description of new filter',
);
```

### 3. Implement Filter Logic

```dart
// In applyFilters() function
if (filters.newFilter == true) {
  filtered = filtered.where((branch) {
    // Filter logic here
    return /* condition */;
  }).toList();
}
```

### 4. Add Configuration Support

```dart
// In DgtConfig class
final bool? filterNewFilter;

// In fromArgResults factory
filterNewFilter: _extractFlag(results, 'new-filter'),
```

## Adding New Sort Fields

### 1. Update Allowed Fields

```dart
// In CliOptions class
static const List<String> allowedSortFields = [
  'local-date',
  'gerrit-date',
  'status',
  'divergences',
  'name',
  'new-field', // Add new field
];
```

### 2. Add Field Description

```dart
static const Map<String, String> sortFieldDescriptions = {
  // ... existing fields
  'new-field': 'Description of new sort field',
};
```

### 3. Implement Sort Logic

```dart
// In applySort() function
switch (sortOptions.field!.toLowerCase()) {
  // ... existing cases
  case 'new-field':
    sorted.sort((a, b) {
      // Sort comparison logic
      final valueA = /* extract value from a */;
      final valueB = /* extract value from b */;
      return multiplier * valueA.compareTo(valueB);
    });
```

## Working with Git Operations

### Performance Considerations

**Always use batch operations when possible**:

```dart
// Good: Batch operation
final commitInfoMap = await GitServiceBatch.getBatchCommitInfo(branches);

// Avoid: Individual operations
for (final branch in branches) {
  final info = await GitService.getCommitHashAndDate(branch);
}
```

### Caching Strategy

Git operations are automatically cached within `GitService`. Clear cache when repository state changes:

```dart
GitService.clearCache(); // Call when switching repositories
```

### Error Handling

Always handle Git errors gracefully:

```dart
try {
  final result = await GitService.someOperation();
  // Process result
} catch (e) {
  VerboseOutput.instance.warning('Git operation failed: $e');
  // Provide fallback or continue processing
}
```

## Working with Gerrit API

### Batch Query Pattern

Always use batch queries for multiple changes:

```dart
// Collect issue numbers
final issueNumbers = <String>[];
for (final branch in branches) {
  if (branch.gerritConfig.hasGerritConfig) {
    issueNumbers.add(branch.gerritConfig.gerritIssue!);
  }
}

// Batch query
final changes = await GerritService.getBatchChangesByIssueNumbers(issueNumbers);
```

### Error Recovery

Handle API failures gracefully:

```dart
try {
  final changes = await GerritService.getBatchChangesByIssueNumbers(issues);
  // Process successful results
} catch (e) {
  VerboseOutput.instance.warning('Gerrit API failed: $e');
  // Continue with local data only
}
```

### Response Processing

Remember to handle Gerrit's XSSI protection:

```dart
String cleanResponse(String response) {
  // Remove Gerrit's XSSI protection prefix
  if (response.startsWith(")]}'")) {
    return response.substring(4);
  }
  return response;
}
```

## Configuration Management

### Adding New Configuration Options

#### 1. **Extend DgtConfig**

```dart
class DgtConfig {
  DgtConfig({
    // ... existing properties
    this.newOption,
  });

  final String? newOption;
}
```

#### 2. **Add JSON Serialization**

```dart
// In fromJson factory
newOption: json['newOption'] as String?,

// In toJson method
if (newOption != null) 'newOption': newOption,
```

#### 3. **Add CLI Integration**

```dart
// In fromArgResults factory
newOption: _extractOption(results, 'new-option'),
```

#### 4. **Add Resolution Method**

```dart
// In DgtConfigExtensions
String resolveOption(ArgResults argResults, String optionName, String defaultValue) {
  if (argResults.wasParsed(optionName)) {
    return argResults.option(optionName) ?? defaultValue;
  }

  final configValue = /* extract from config */;
  return configValue ?? defaultValue;
}
```

## Performance Optimization

### Measurement

Use `PerformanceTracker` to measure new operations:

```dart
Future<void> expensiveOperation() async {
  tracker?.startTimer('operation_name');

  try {
    // Perform operation
  } finally {
    tracker?.endTimer('operation_name');
  }
}
```

### Parallel Processing

Use `Future.wait()` for independent operations:

```dart
final results = await Future.wait([
  GitService.getCommitHash(branch1),
  GitService.getCommitHash(branch2),
  GerritService.getChangeByIssue(issue1),
]);
```

### Isolate Usage

For CPU-intensive processing, use isolates:

```dart
// Define isolate function
static Future<Map<String, dynamic>> processInIsolate(String data) async {
  return await Isolate.run(() {
    // CPU-intensive processing
    return processData(data);
  });
}

// Use in main thread
final result = await processInIsolate(jsonData);
```

## Output Formatting

### Color Usage

Use `Terminal` class for consistent output:

```dart
Terminal.info('Informational message');    // White
Terminal.error('Error message');           // Red
Terminal.warning('Warning message');       // Yellow
```

### Custom Colors

Define status-specific colors:

```dart
String colorizeStatus(String status) {
  return switch (status) {
    'Active' => AnsiPen()..green(),
    'WIP' => AnsiPen()..yellow(),
    'Merged' => AnsiPen()..cyan(),
    _ => AnsiPen()..white(),
  }(status);
}
```

### Table Formatting

Use `OutputFormatter` patterns for tabular data:

```dart
class CustomFormatter {
  void displayTable(List<Data> items) {
    // Calculate column widths
    final maxWidth = items.map((item) => item.name.length).reduce(max);

    // Print headers
    _printHeader(['Name', 'Value'], [maxWidth, 20]);

    // Print rows
    for (final item in items) {
      _printRow([item.name, item.value], [maxWidth, 20]);
    }
  }
}
```

## Error Handling Best Practices

### Graceful Degradation

Always provide fallbacks:

```dart
String getDisplayValue(BranchInfo branch) {
  try {
    return branch.gerritChange?.status ?? '-';
  } catch (e) {
    VerboseOutput.instance.warning('Failed to get status: $e');
    return '?';
  }
}
```

### User-Friendly Messages

Provide actionable error messages:

```dart
void validateInput(String input) {
  if (!isValidDate(input)) {
    throw FormatException(
      'Invalid date format: "$input".\n'
      'Expected ISO 8601 format (e.g., 2025-10-10 or 2025-10-10T14:30:00)'
    );
  }
}
```

### Partial Success

Continue processing when possible:

```dart
final results = <BranchInfo>[];
for (final branch in branches) {
  try {
    final info = await processBranch(branch);
    results.add(info);
  } catch (e) {
    VerboseOutput.instance.warning('Failed to process $branch: $e');
    // Add placeholder or skip
  }
}
```

## Debugging Support

### Verbose Output

Use `VerboseOutput` for debugging:

```dart
VerboseOutput.instance.info('[VERBOSE] Processing branch: $branchName');
VerboseOutput.instance.warning('[VERBOSE] API request failed, retrying...');
```

### Performance Tracking

Add timing for new operations:

```dart
tracker?.startTimer('new_operation');
try {
  await performOperation();
} finally {
  tracker?.endTimer('new_operation');
}
```

### State Inspection

Log important state changes:

```dart
VerboseOutput.instance.info(
  '[VERBOSE] Found ${branches.length} branches, '
  '${issueNumbers.length} with Gerrit config'
);
```

## Common Patterns

### Option Resolution

```dart
final resolvedValue = config.resolveFlag(argResults, 'option-name', defaultValue);
```

### Batch Processing

```dart
final batchSize = 10;
for (var i = 0; i < items.length; i += batchSize) {
  final batch = items.skip(i).take(batchSize).toList();
  await processBatch(batch);
}
```

### Resource Cleanup

```dart
Future<void> withTempDirectory(Future<void> Function(Directory) action) async {
  final tempDir = await Directory.systemTemp.createTemp('dgt_');
  try {
    await action(tempDir);
  } finally {
    await tempDir.delete(recursive: true);
  }
}
```

## Code Review Guidelines

### Before Submitting

1. Run `dart analyze` and fix all issues
2. Run `dart test` and ensure all tests pass
3. Test manually with various repository states
4. Update documentation if adding public APIs

### Code Quality

- Keep functions focused and single-purpose
- Use descriptive variable and function names
- Add comments for complex logic
- Handle errors appropriately
- Follow existing code patterns

### Performance Considerations

- Profile new operations with `PerformanceTracker`
- Use batch operations when possible
- Avoid unnecessary Git process spawns
- Consider memory usage for large repositories

This implementation guide provides the foundation for extending the DGT tool while maintaining code quality and performance standards.
