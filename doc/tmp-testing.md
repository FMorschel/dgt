
## Testing Patterns

### Unit Testing

Test individual components in isolation:

```dart
void main() {
  group('BranchInfo', () {
    test('hasLocalChanges returns true when hashes differ', () {
      final branch = BranchInfo(
        branchName: 'test',
        localHash: 'abc123',
        gerritConfig: GerritBranchConfig(lastUploadHash: 'def456'),
        // ... other properties
      );

      expect(branch.hasLocalChanges(), isTrue);
    });
  });
}
```

### Integration Testing

Test service interactions:

```dart
void main() {
  group('GitService integration', () {
    test('getAllBranches returns current branches', () async {
      // Setup test repository
      // Run test
      final branches = await GitService.getAllBranches();
      expect(branches, contains('main'));
    });
  });
}
```

### Mock Services

Use dependency injection for testing:

```dart
abstract class GitServiceInterface {
  Future<List<String>> getAllBranches();
}

class MockGitService implements GitServiceInterface {
  @override
  Future<List<String>> getAllBranches() async {
    return ['main', 'feature/test'];
  }
}
```

## Testing Strategy

The project structure supports comprehensive testing:

**Unit Tests**:

- Individual service methods
- Data model behavior
- Filter and sort logic
- Configuration management

**Integration Tests**:

- Git repository interactions
- Gerrit API integration
- End-to-end command execution

**Performance Tests**:

- Batch operation efficiency
- Large repository handling
- API request optimization
