import 'package:ansicolor/ansicolor.dart';
import 'package:dgt/branch_info.dart';
import 'package:dgt/date_display.dart';
import 'package:dgt/display_options.dart';
import 'package:dgt/output_formatter.dart';
import 'package:dgt/performance_tracker.dart';
import 'package:test/test.dart';

import 'capture.dart';
import 'fixtures.dart';

/// Renders [time] the way the date columns do, for building expectations that
/// do not depend on the machine's timezone.
String stamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

void main() {
  setUp(() {
    // Pens consult this flag on every call, so plain output is guaranteed
    // regardless of whether the runner looks like a terminal.
    ansiColorDisabled = true;
  });

  group('displayBranchTable', () {
    test('reports an empty branch list', () {
      final lines = capturePrints(
        () => const OutputFormatter(DisplayOptions()).displayBranchTable([]),
      );

      expect(lines, ['No branches found.']);
    });

    test('prints a header, separator, one row per branch and a total', () {
      const formatter = OutputFormatter(
        DisplayOptions(showLocal: false, showGerrit: false),
      );

      final lines = capturePrints(
        () => formatter.displayBranchTable([
          mergedBranch(name: 'main'),
          wipBranch(name: 'feature'),
        ]),
      );

      expect(lines.first, startsWith('Branch Name'));
      expect(lines[1], matches(RegExp(r'^-+\-\+\--+$')));
      expect(lines[2], startsWith('main'));
      expect(lines[3], startsWith('feature'));
      expect(lines[4], '');
      expect(lines.last, 'Total: 2 branches');
    });

    test('uses the singular noun for a single branch', () {
      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(),
        ).displayBranchTable([mergedBranch()]),
      );

      expect(lines.last, 'Total: 1 branch');
    });

    test('announces the active sort and omits it otherwise', () {
      const formatter = OutputFormatter(DisplayOptions());

      final sorted = capturePrints(
        () => formatter.displayBranchTable(
          [mergedBranch()],
          sortField: 'name',
          sortDirection: 'desc',
        ),
      );
      expect(sorted.first, 'Sorted by: name (desc)');
      expect(sorted[1], '');

      final unsorted = capturePrints(
        () => formatter.displayBranchTable([mergedBranch()]),
      );
      expect(unsorted.first, startsWith('Branch Name'));
    });

    test('defaults the direction to asc in the sort indicator', () {
      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(),
        ).displayBranchTable([mergedBranch()], sortField: 'name'),
      );

      expect(lines.first, 'Sorted by: name (asc)');
    });

    test('shows local and gerrit columns by default', () {
      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(),
        ).displayBranchTable([mergedBranch()]),
      );

      expect(
        lines.first,
        allOf(
          contains('Local Hash'),
          contains('Local Date'),
          contains('Gerrit Hash'),
          contains('Gerrit Date'),
        ),
      );
      expect(lines.first, isNot(contains('URL')));
    });

    test('drops the columns that are switched off', () {
      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(showLocal: false, showGerrit: false),
        ).displayBranchTable([mergedBranch()]),
      );

      expect(
        lines.first,
        allOf(
          contains('Branch Name'),
          contains('Status'),
          isNot(contains('Local Hash')),
          isNot(contains('Gerrit Hash')),
        ),
      );
    });

    test('adds the URL column on request', () {
      final lines = capturePrints(
        () =>
            const OutputFormatter(
              DisplayOptions(
                showLocal: false,
                showGerrit: false,
                showUrl: true,
              ),
            ).displayBranchTable([
              makeBranch(
                name: 'main',
                change: makeChange(),
                gerritUrl: 'https://gerrit.test/c/389423',
              ),
            ]),
      );

      expect(lines.first, contains('URL'));
      expect(lines[2], contains('https://gerrit.test/c/389423'));
    });

    test('renders a missing URL as a dash', () {
      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(showLocal: false, showGerrit: false, showUrl: true),
        ).displayBranchTable([mergedBranch(name: 'main')]),
      );

      expect(lines[2].trimRight(), endsWith('-'));
    });
  });

  group('column widths', () {
    test('keeps the branch column at 20 for short names', () {
      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(showLocal: false, showGerrit: false),
        ).displayBranchTable([mergedBranch(name: 'main')]),
      );

      expect(lines.first.indexOf('|'), 21);
    });

    test('widens the branch column for a long name', () {
      const longName = 'feature/a-very-long-branch-name-indeed';

      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(showLocal: false, showGerrit: false),
        ).displayBranchTable([mergedBranch(name: longName)]),
      );

      expect(lines.first.indexOf('|'), longName.length + 2);
      expect(lines[2], startsWith(longName));
    });

    test('sizes the status column to the longest status', () {
      // "Active (LGTM +1)" is 16 characters, and the column adds 3.
      final lines = capturePrints(
        () => const OutputFormatter(
          DisplayOptions(showLocal: false, showGerrit: false),
        ).displayBranchTable([lgtmBranch(name: 'main'), mergedBranch()]),
      );

      final header = lines.first;
      final statusColumn = header.substring(header.indexOf('|') + 2);
      expect(statusColumn, hasLength(19));
    });
  });

  group('row contents', () {
    List<String> rowFor(BranchInfo branch) => capturePrints(
      () =>
          const OutputFormatter(DisplayOptions()).displayBranchTable([branch]),
    );

    test('truncates hashes to eight characters', () {
      final lines = rowFor(
        makeBranch(
          name: 'main',
          localHash: '0123456789abcdef0123456789abcdef01234567',
          change: makeChange(
            currentRevision: 'fedcba9876543210fedcba9876543210fedcba98',
          ),
        ),
      );

      expect(lines[2], contains('01234567'));
      expect(lines[2], isNot(contains('0123456789')));
      expect(lines[2], contains('fedcba98'));
    });

    test('renders a missing gerrit hash and date as dashes', () {
      final lines = rowFor(makeBranch(name: 'main'));

      expect(lines[2], contains('-'));
      expect(lines[2], isNot(contains('rev1')));
    });

    test('renders both timestamp formats in local time by default', () {
      final lines = rowFor(
        makeBranch(
          name: 'main',
          localDate: '2025-10-07 14:30:45 -0400',
          change: makeChange(updated: '2025-10-07 09:05:00.000000000'),
        ),
      );

      // Git prints an explicit offset; Gerrit's offset-less format is UTC.
      // Both are absolute instants, so the expectation is computed rather
      // than hard-coded: local time depends on the machine running the test.
      expect(
        lines[2],
        contains(stamp(DateTime.parse('2025-10-07 14:30:45-0400').toLocal())),
      );
      expect(
        lines[2],
        contains(stamp(DateTime.parse('2025-10-07 09:05:00Z').toLocal())),
      );
    });

    test('renders both timestamp formats in UTC on request', () {
      final lines = capturePrints(
        () =>
            const OutputFormatter(
              DisplayOptions(dateDisplay: DateDisplay.utc),
            ).displayBranchTable([
              makeBranch(
                name: 'main',
                localDate: '2025-10-07 14:30:45 -0400',
                change: makeChange(updated: '2025-10-07 09:05:00.000000000'),
              ),
            ]),
      );

      // 14:30:45 -0400 is 18:30 UTC; Gerrit's timestamp is already UTC.
      expect(lines[2], contains('2025-10-07 18:30'));
      expect(lines[2], contains('2025-10-07 09:05'));
    });

    test('puts both columns on the same clock', () {
      // The same instant spelled in each source's format must render
      // identically in either mode.
      for (final mode in DateDisplay.values) {
        final lines = capturePrints(
          () => OutputFormatter(DisplayOptions(dateDisplay: mode))
              .displayBranchTable([
                makeBranch(
                  name: 'main',
                  localDate: '2025-10-07 14:30:45 -0400',
                  change: makeChange(updated: '2025-10-07 18:30:45.000000000'),
                ),
              ]),
        );

        final stamps = RegExp(
          r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}',
        ).allMatches(lines[2]).map((match) => match.group(0)).toList();

        expect(stamps, hasLength(2), reason: 'local and gerrit columns');
        expect(stamps.first, stamps.last, reason: 'mode: ${mode.cliValue}');
      }
    });

    test('passes through a value that is not a timestamp', () {
      final lines = rowFor(makeBranch(name: 'main', localDate: 'not-a-date'));

      expect(lines[2], contains('not-a-date'));
    });

    test('appends an up arrow for unpushed local commits', () {
      final lines = rowFor(
        makeBranch(
          name: 'main',
          localHash: 'aaa',
          lastUploadHash: 'bbb',
          change: makeChange(),
        ),
      );

      expect(lines[2], contains('↑'));
      expect(lines[2], isNot(contains('↓')));
    });

    test('appends a down arrow when Gerrit moved ahead', () {
      final lines = rowFor(
        makeBranch(
          name: 'main',
          gerritSquashHash: 'ccc',
          change: makeChange(currentRevision: 'ddd'),
        ),
      );

      expect(lines[2], contains('↓'));
      expect(lines[2], isNot(contains('↑')));
    });

    test('appends both arrows when both sides diverged', () {
      final lines = rowFor(
        makeBranch(
          name: 'main',
          localHash: 'aaa',
          lastUploadHash: 'bbb',
          gerritSquashHash: 'ccc',
          change: makeChange(currentRevision: 'ddd'),
        ),
      );

      expect(lines[2], contains('↑↓'));
    });

    test('shows no arrows for a branch that is in sync', () {
      final lines = rowFor(
        makeBranch(
          name: 'main',
          localHash: 'aaa',
          lastUploadHash: 'aaa',
          gerritSquashHash: 'ccc',
          change: makeChange(currentRevision: 'ccc'),
        ),
      );

      expect(lines[2], isNot(contains('↑')));
      expect(lines[2], isNot(contains('↓')));
    });
  });

  group('displayPerformanceSummary', () {
    test('prints nothing when no timings were recorded', () {
      final tracker = PerformanceTracker();

      final lines = capturePrints(
        () => OutputFormatter.displayPerformanceSummary(tracker),
      );

      expect(lines, isEmpty);
    });

    test('lists known operations with a total', () {
      final tracker = PerformanceTracker()
        ..startTimer('git_operations')
        ..endTimer('git_operations')
        ..startTimer('gerrit_queries')
        ..endTimer('gerrit_queries');

      final lines = capturePrints(
        () => OutputFormatter.displayPerformanceSummary(tracker),
      );

      expect(lines[1], 'Performance Summary:');
      expect(lines.any((line) => line.contains('Git operations')), isTrue);
      expect(lines.any((line) => line.contains('Gerrit API queries')), isTrue);
      expect(lines.last, contains('Total execution time'));
      expect(lines.last, endsWith('ms'));
    });

    test('omits operations that were never timed', () {
      final tracker = PerformanceTracker()
        ..startTimer('sorting')
        ..endTimer('sorting');

      final lines = capturePrints(
        () => OutputFormatter.displayPerformanceSummary(tracker),
      );

      expect(lines.any((line) => line.contains('Sorting')), isTrue);
      expect(lines.any((line) => line.contains('Branch discovery')), isFalse);
    });
  });
}
