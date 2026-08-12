# Testing

Run everything with `dart test`. Tests live in `test/` and are plain
`package:test`; there is no code generation and no runner configuration.

## Layout

| File | Covers |
| ---- | ------ |
| `filtering_test.dart` | `applyFilters`, `parseDate`, `validateStatus` |
| `sorting_test.dart` | `applySort` and the sort validators |
| `branch_info_test.dart` | Divergence booleans and display getters |
| `gerrit_change_test.dart` | `GerritChange.fromJson`, status text, `getChangeUrl` |
| `gerrit_service_test.dart` | The batched Gerrit query, end to end |
| `enums_test.dart` | `BranchStatus`, `DateDisplay`, and the CLI metadata derived from them |
| `config_test.dart` | `DgtConfig`, option precedence, `DisplayOptions`, the parser |
| `config_service_test.dart` | Reading, writing, showing and pruning the config file |
| `output_formatter_test.dart` | Table layout, column widths, date rendering |
| `git_service_test.dart` | `GitService` and `GitServiceBatch` against a real repository |
| `performance_tracker_test.dart` | Timer bookkeeping |

Shared helpers: `fixtures.dart` (branch and change builders),
`fake_gerrit_server.dart`, `temp_git_repo.dart`, `capture.dart`.

## Seams

Most of the code is pure and needs nothing special. Three areas talk to the
outside world, and each has a seam rather than a mocking framework.

### Gerrit: a real loopback server

`GerritService` performs its HTTP calls inside `Isolate.run`, so an in-process
`http.Client` mock cannot reach them — only sendable values cross an isolate
boundary. `FakeGerritServer` binds a real `HttpServer` on an ephemeral port and
is injected through the `serverUrl` parameter the method already accepts:

```dart
final server = await FakeGerritServer.start();
server.changes['389423'] = gerritChangeJson(number: '389423');
server.mergeable['389423'] = false;

final result = await GerritService.getBatchChangesByIssueNumbers(
  ['389423'],
  server.url,
);
```

It records every request, can force error status codes, and can serve the flat
array Gerrit returns for a single-query request. Because it is a real server,
the tests exercise the production path: isolate dispatch, batching, XSSI
stripping and the separate mergeable round-trip.

### Git: a real temporary repository

`GitService` shells out to `git`, so the tests give it a real repository built
by `TempGitRepo` rather than faking process output. Parsing bugs — dotted
branch names, values containing spaces — only show up against genuine `git`
output.

```dart
final repo = await TempGitRepo.create();
await repo.commitFile(fileName: 'a.txt', message: 'initial commit');
await repo.setBranchConfig('main', 'gerritissue', '389423');

expect((await GitService.getGerritConfig('main')).gerritIssue, '389423');
```

`TempGitRepo` sets `GitService.workingDirectory` instead of changing
`Directory.current`, so nothing process-wide is touched and test files stay
independent. `dgt` itself still assigns `Directory.current` for `--path`, so
that the processes `dgt clean` spawns inherit the right repository.

`GitService` caches command output. The key includes the working directory, but
the cache still has to be cleared when the repository changes underneath it —
`TempGitRepo` does that after every mutation.

### Config file: an overridable path

`ConfigService` derives its path from `HOME`/`USERPROFILE`, and
`Platform.environment` cannot be changed at runtime. Set
`ConfigService.configFilePathOverride` to point it at a temp directory; every
method routes through `getConfigFilePath()`, so nothing else changes.

```dart
ConfigService.configFilePathOverride = p.join(tempDir.path, '.dgt', '.config');
addTearDown(() => ConfigService.configFilePathOverride = null);
```

`ConfigService` logs through the `VerboseOutput` singleton, including from its
catch blocks, so call `VerboseOutput.initialize(false)` first or every call
throws a `StateError`.

## Capturing output

`Terminal` and the config service write with `print`. `capture.dart` runs a
callback in a zone that collects those lines, so output can be asserted without
changing production code:

```dart
final lines = capturePrints(
  () => const OutputFormatter(DisplayOptions()).displayBranchTable(branches),
);
expect(lines.last, 'Total: 2 branches');
```

Use `capturePrintsAsync` for anything returning a `Future`. Set
`ansiColorDisabled = true` first so pens emit plain text and assertions are not
comparing escape codes.

## Conventions

- Tests are written against behavior a user could notice, not implementation
  detail. Where a test pins something questionable on purpose, a comment says
  so and says what would replace it.
- Expectations that would otherwise depend on the machine are computed rather
  than hard-coded. The date tests derive local-time expectations the same way
  the formatter does, so they pass in any timezone.
- Statuses come from `BranchStatus`; when adding one, the filter, sort and CLI
  metadata follow automatically, and `enums_test.dart` guards the derivation.
- Assert on `branchStatus` when a test is about behavior, and on
  `getDisplayStatus()` only when it is about the text in the Status column.
  Nothing in `lib/` parses that text, and tests should not either.
