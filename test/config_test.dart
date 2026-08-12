import 'package:args/args.dart';
import 'package:dgt/cli_options.dart';
import 'package:dgt/config_service.dart';
import 'package:dgt/date_display.dart';
import 'package:dgt/display_options.dart';
import 'package:test/test.dart';

/// Parses [args] as the `list` subcommand and returns its results.
ArgResults parseList(List<String> args) =>
    CliOptions.buildParser().parse(['list', ...args]).command!;

/// Parses [args] as the `config` subcommand and returns its results.
ArgResults parseConfig(List<String> args) =>
    CliOptions.buildParser().parse(['config', ...args]).command!;

void main() {
  group('DgtConfig JSON', () {
    test('round-trips every field', () {
      final config = DgtConfig(
        showLocal: false,
        showGerrit: true,
        showUrl: true,
        filterStatuses: ['wip', 'active'],
        filterSince: '2025-01-01',
        filterBefore: '2025-12-31',
        filterDiverged: true,
        sortField: 'name',
        sortDirection: 'desc',
      );

      final restored = DgtConfig.fromJson(config.toJson());

      expect(restored.showLocal, isFalse);
      expect(restored.showGerrit, isTrue);
      expect(restored.showUrl, isTrue);
      expect(restored.filterStatuses, ['wip', 'active']);
      expect(restored.filterSince, '2025-01-01');
      expect(restored.filterBefore, '2025-12-31');
      expect(restored.filterDiverged, isTrue);
      expect(restored.sortField, 'name');
      expect(restored.sortDirection, 'desc');
    });

    test('omits unset values and empty status lists', () {
      expect(DgtConfig().toJson(), isEmpty);
      expect(DgtConfig(filterStatuses: []).toJson(), isEmpty);
      expect(DgtConfig(showLocal: false).toJson(), {'local': false});
    });

    test('reads an empty JSON object as all-unset', () {
      final config = DgtConfig.fromJson(<String, dynamic>{});

      expect(config.showLocal, isNull);
      expect(config.filterStatuses, isNull);
      expect(config.sortField, isNull);
    });
  });

  group('DgtConfig.fromArgResults', () {
    test('captures only the options the user actually passed', () {
      final config = DgtConfig.fromArgResults(
        parseConfig(['--sort', 'name', '--desc']),
      );

      expect(config.sortField, 'name');
      expect(config.sortDirection, 'desc');
      expect(config.showGerrit, isNull);
      expect(config.showLocal, isNull);
      expect(config.filterStatuses, isNull);
    });

    test('records negated flags as false', () {
      final config = DgtConfig.fromArgResults(parseConfig(['--no-gerrit']));

      expect(config.showGerrit, isFalse);
      expect(config.showLocal, isNull);
    });

    test('--no-sort clears both sort fields with empty strings', () {
      // Empty string is the sentinel meaning "remove this from the config".
      final config = DgtConfig.fromArgResults(parseConfig(['--no-sort']));

      expect(config.sortField, '');
      expect(config.sortDirection, '');
    });

    test('accepts a direction flag without --sort', () {
      final config = DgtConfig.fromArgResults(parseConfig(['--asc']));

      expect(config.sortField, isNull);
      expect(config.sortDirection, 'asc');
    });

    test('takes --desc over --asc when both are given', () {
      final config = DgtConfig.fromArgResults(
        parseConfig(['--sort', 'name', '--asc', '--desc']),
      );

      expect(config.sortDirection, 'desc');
    });

    test('captures filters', () {
      final config = DgtConfig.fromArgResults(
        parseConfig([
          '--status',
          'wip',
          '--status',
          'active',
          '--since',
          '2025-01-01',
          '--before',
          '2025-12-31',
          '--diverged',
        ]),
      );

      expect(config.filterStatuses, ['wip', 'active']);
      expect(config.filterSince, '2025-01-01');
      expect(config.filterBefore, '2025-12-31');
      expect(config.filterDiverged, isTrue);
    });
  });

  group('resolveFlag precedence', () {
    test('prefers the CLI flag over config and default', () {
      final config = DgtConfig(showUrl: false);

      expect(config.resolveFlag(parseList(['--url']), 'url', false), isTrue);
      expect(
        DgtConfig(
          showUrl: true,
        ).resolveFlag(parseList(['--no-url']), 'url', true),
        isFalse,
      );
    });

    test('falls back to config when the flag was not passed', () {
      expect(
        DgtConfig(showUrl: true).resolveFlag(parseList([]), 'url', false),
        isTrue,
      );
      expect(
        DgtConfig(showGerrit: false).resolveFlag(parseList([]), 'gerrit', true),
        isFalse,
      );
    });

    test('falls back to the default with no config at all', () {
      const DgtConfig? config = null;

      expect(config.resolveFlag(parseList([]), 'url', false), isFalse);
      expect(config.resolveFlag(parseList([]), 'gerrit', true), isTrue);
    });

    test('uses the default for flags the config does not know about', () {
      final config = DgtConfig(showUrl: true);

      expect(config.resolveFlag(parseList([]), 'no-status', false), isFalse);
      expect(config.resolveFlag(parseList([]), 'no-status', true), isTrue);
    });
  });

  group('resolveOption and resolveMultiOption precedence', () {
    test('prefers the CLI option over config', () {
      final config = DgtConfig(sortField: 'status');

      // The type argument is required when the default is null, otherwise T
      // infers as Null and the internal cast throws. Production call sites
      // spell it out the same way.
      expect(
        config.resolveOption<String?>(
          parseList(['--sort', 'name']),
          'sort',
          null,
        ),
        'name',
      );
    });

    test('falls back to config then to the default', () {
      expect(
        DgtConfig(
          sortField: 'status',
        ).resolveOption<String?>(parseList([]), 'sort', null),
        'status',
      );
      expect(DgtConfig().resolveOption(parseList([]), 'sort', 'name'), 'name');
    });

    test('returns a null default when neither CLI nor config supplies one', () {
      expect(
        DgtConfig().resolveOption<String?>(parseList([]), 'since', null),
        isNull,
      );
    });

    test('throws when a null default is passed without a type argument', () {
      // Pinning a sharp edge rather than endorsing it: `null` alone infers
      // T as Null, so the internal `as T` fails as soon as a value exists.
      // Callers must write resolveOption<String?>(...). Remove this test if
      // the signature is reworked to make the type argument unnecessary.
      expect(
        () => DgtConfig(
          sortField: 'status',
        ).resolveOption(parseList([]), 'sort', null),
        throwsA(isA<TypeError>()),
      );
    });

    test('resolves multi-options, treating an empty config list as unset', () {
      expect(
        DgtConfig(
          filterStatuses: ['merged'],
        ).resolveMultiOption(parseList(['--status', 'wip']), 'status', []),
        ['wip'],
      );
      expect(
        DgtConfig(
          filterStatuses: ['merged'],
        ).resolveMultiOption(parseList([]), 'status', []),
        ['merged'],
      );
      expect(
        DgtConfig(
          filterStatuses: [],
        ).resolveMultiOption(parseList([]), 'status', ['fallback']),
        ['fallback'],
      );
    });
  });

  group('resolveSortDirection', () {
    test('prefers --desc, then --asc, then config, then the default', () {
      final config = DgtConfig(sortDirection: 'desc');

      expect(
        DgtConfig().resolveSortDirection(parseList(['--desc']), 'asc'),
        'desc',
      );
      expect(config.resolveSortDirection(parseList(['--asc']), 'desc'), 'asc');
      expect(config.resolveSortDirection(parseList([]), 'asc'), 'desc');
      expect(DgtConfig().resolveSortDirection(parseList([]), 'asc'), 'asc');
    });

    test('takes --desc when both direction flags are passed', () {
      expect(
        DgtConfig().resolveSortDirection(parseList(['--asc', '--desc']), 'asc'),
        'desc',
      );
    });
  });

  group('--dates', () {
    test('is captured into the config when passed', () {
      final config = DgtConfig.fromArgResults(parseConfig(['--dates', 'utc']));

      expect(config.dateDisplay, 'utc');
    });

    test('is absent from the config when not passed', () {
      expect(DgtConfig.fromArgResults(parseConfig([])).dateDisplay, isNull);
    });

    test('round-trips through JSON under the "dates" key', () {
      final config = DgtConfig(dateDisplay: 'utc');

      expect(config.toJson(), {'dates': 'utc'});
      expect(DgtConfig.fromJson(config.toJson()).dateDisplay, 'utc');
    });

    test('resolves CLI over config over the local default', () {
      expect(
        DisplayOptions.resolve(
          results: parseList(['--dates', 'utc']),
          config: DgtConfig(dateDisplay: 'local'),
          showTiming: false,
        ).dateDisplay,
        DateDisplay.utc,
      );
      expect(
        DisplayOptions.resolve(
          results: parseList([]),
          config: DgtConfig(dateDisplay: 'utc'),
          showTiming: false,
        ).dateDisplay,
        DateDisplay.utc,
      );
      expect(
        DisplayOptions.resolve(
          results: parseList([]),
          config: null,
          showTiming: false,
        ).dateDisplay,
        DateDisplay.local,
      );
    });

    test('falls back to local when the config holds a bad value', () {
      expect(
        DisplayOptions.resolve(
          results: parseList([]),
          config: DgtConfig(dateDisplay: 'mars'),
          showTiming: false,
        ).dateDisplay,
        DateDisplay.local,
      );
    });

    test('rejects an unknown value on the command line', () {
      expect(
        () => parseList(['--dates', 'mars']),
        throwsA(isA<ArgParserException>()),
      );
    });

    test('is removable from the config', () {
      expect(
        RemovableConfigOption.fromString('dates'),
        RemovableConfigOption.dates,
      );
      expect(RemovableConfigOption.dates.displayName, 'dates');
    });
  });

  group('DisplayOptions', () {
    test('resolves from CLI flags, config and defaults', () {
      final options = DisplayOptions.resolve(
        results: parseList(['--url']),
        config: DgtConfig(showLocal: false),
        showTiming: true,
      );

      expect(options.showUrl, isTrue, reason: 'from the CLI flag');
      expect(options.showLocal, isFalse, reason: 'from the config file');
      expect(options.showGerrit, isTrue, reason: 'from the built-in default');
      expect(options.showTiming, isTrue, reason: 'passed in directly');
    });

    test('uses built-in defaults with no CLI flags and no config', () {
      final options = DisplayOptions.resolve(
        results: parseList([]),
        config: null,
        showTiming: false,
      );

      expect(options, const DisplayOptions());
      expect(options.showGerrit, isTrue);
      expect(options.showLocal, isTrue);
      expect(options.showUrl, isFalse);
      expect(options.showTiming, isFalse);
    });

    test('copyWith replaces only the named fields', () {
      const options = DisplayOptions();

      expect(
        options.copyWith(showUrl: true),
        const DisplayOptions(showUrl: true),
      );
      expect(options.copyWith(), options);
    });

    test('equality and hashCode cover every field', () {
      const base = DisplayOptions();

      expect(base, const DisplayOptions());
      expect(base.hashCode, const DisplayOptions().hashCode);
      expect(base, isNot(const DisplayOptions(showUrl: true)));
      expect(base, isNot(const DisplayOptions(showGerrit: false)));
      expect(base, isNot(const DisplayOptions(showLocal: false)));
      expect(base, isNot(const DisplayOptions(showTiming: true)));
    });
  });

  group('CliOptions.buildParser', () {
    test('rejects disallowed status and sort values', () {
      expect(
        () => parseList(['--status', 'bogus']),
        throwsA(isA<ArgParserException>()),
      );
      expect(
        () => parseList(['--sort', 'bogus']),
        throwsA(isA<ArgParserException>()),
      );
    });

    test('collects repeated --status values', () {
      final results = parseList(['--status', 'wip', '--status', 'merged']);

      expect(results.multiOption('status'), ['wip', 'merged']);
    });

    test('exposes negatable display flags on list but not on config clean', () {
      expect(parseList(['--no-gerrit']).flag('gerrit'), isFalse);

      final cleanParser =
          CliOptions.buildParser().commands['config']!.commands['clean']!;
      expect(
        () => cleanParser.parse(['--no-gerrit']),
        throwsA(isA<ArgParserException>()),
      );
    });

    test('recognises clean as a bare pass-through command', () {
      // The clean parser defines no options of its own; dgt slices everything
      // after "clean" out of the argument list before parsing and forwards it
      // to `git cl archive`, so the parser only ever sees the command name.
      final results = CliOptions.buildParser().parse(['clean']);

      expect(results.command!.name, 'clean');
      expect(results.command!.options, isEmpty);
    });
  });

  group('RemovableConfigOption', () {
    test('maps known names and rejects unknown ones', () {
      for (final option in RemovableConfigOption.values) {
        expect(RemovableConfigOption.fromString(option.displayName), option);
      }
      expect(RemovableConfigOption.fromString('bogus'), isNull);
    });
  });
}
