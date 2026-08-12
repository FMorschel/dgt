import 'dart:convert';
import 'dart:io';

import 'package:dgt/cli_options.dart';
import 'package:dgt/config_service.dart';
import 'package:dgt/verbose_output.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'capture.dart';

void main() {
  group('getConfigFilePath', () {
    tearDown(() {
      ConfigService.configFilePathOverride = null;
    });

    test('derives ~/.dgt/.config from the environment by default', () {
      final path = ConfigService.getConfigFilePath();

      expect(path, endsWith('${Platform.pathSeparator}.config'));
      expect(p.basename(p.dirname(path)), '.dgt');
    });

    test('honours the override', () {
      ConfigService.configFilePathOverride = r'C:\somewhere\.config';

      expect(ConfigService.getConfigFilePath(), r'C:\somewhere\.config');
    });
  });

  group('with a temporary config file', () {
    late Directory tempDir;
    late File configFile;

    setUp(() async {
      // ConfigService logs through the VerboseOutput singleton, including
      // from its own catch blocks, so it has to exist before any call.
      VerboseOutput.initialize(false);
      tempDir = await Directory.systemTemp.createTemp('dgt_config_');
      configFile = File(p.join(tempDir.path, '.dgt', '.config'));
      ConfigService.configFilePathOverride = configFile.path;
    });

    tearDown(() async {
      ConfigService.configFilePathOverride = null;
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // A leftover temp directory is not worth failing a test over.
      }
    });

    Future<void> writeRaw(String contents) async {
      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(contents);
    }

    group('readConfig', () {
      test('returns null when the file does not exist', () async {
        expect(await ConfigService.readConfig(), isNull);
      });

      test('parses a stored configuration', () async {
        await writeRaw(
          jsonEncode({
            'local': false,
            'gerrit': true,
            'filterStatuses': ['wip'],
            'sortField': 'name',
          }),
        );

        final config = await ConfigService.readConfig();

        expect(config, isNotNull);
        expect(config!.showLocal, isFalse);
        expect(config.showGerrit, isTrue);
        expect(config.filterStatuses, ['wip']);
        expect(config.sortField, 'name');
        expect(config.showUrl, isNull);
      });

      test('returns null rather than throwing on malformed JSON', () async {
        await writeRaw('{not json');

        expect(await ConfigService.readConfig(), isNull);
      });

      test('returns null when the JSON is not an object', () async {
        await writeRaw('[1, 2, 3]');

        expect(await ConfigService.readConfig(), isNull);
      });
    });

    group('writeConfig', () {
      test('creates the .dgt directory and writes JSON', () async {
        expect(await configFile.parent.exists(), isFalse);

        await ConfigService.writeConfig(DgtConfig(sortField: 'name'));

        expect(await configFile.exists(), isTrue);
        expect(jsonDecode(await configFile.readAsString()), {
          'sortField': 'name',
        });
      });

      test('round-trips through readConfig', () async {
        await ConfigService.writeConfig(
          DgtConfig(
            showUrl: true,
            filterStatuses: ['wip', 'active'],
            filterDiverged: true,
            sortField: 'status',
            sortDirection: 'desc',
          ),
        );

        final config = await ConfigService.readConfig();

        expect(config!.showUrl, isTrue);
        expect(config.filterStatuses, ['wip', 'active']);
        expect(config.filterDiverged, isTrue);
        expect(config.sortField, 'status');
        expect(config.sortDirection, 'desc');
      });

      test('writes an empty object for an empty config', () async {
        await ConfigService.writeConfig(DgtConfig());

        expect(await configFile.readAsString(), '{}');
      });

      test('replaces the previous contents rather than merging', () async {
        await ConfigService.writeConfig(DgtConfig(sortField: 'name'));
        await ConfigService.writeConfig(DgtConfig(showUrl: true));

        final config = await ConfigService.readConfig();

        expect(config!.showUrl, isTrue);
        expect(config.sortField, isNull);
      });
    });

    group('showConfig', () {
      test('explains how to create a missing config', () async {
        final lines = await capturePrintsAsync(ConfigService.showConfig);

        expect(lines.first, contains('No configuration file found at:'));
        expect(lines.any((line) => line.contains('dgt config')), isTrue);
      });

      test('lists the settings that are present', () async {
        await ConfigService.writeConfig(
          DgtConfig(
            showLocal: false,
            sortField: 'name',
            filterStatuses: ['wip'],
          ),
        );

        final lines = await capturePrintsAsync(ConfigService.showConfig);

        expect(lines.first, contains('Configuration file:'));
        expect(lines.any((line) => line.contains('local:  false')), isTrue);
        expect(
          lines.any((line) => line.contains('sortField:      name')),
          isTrue,
        );
        expect(lines.any((line) => line.contains('[wip]')), isTrue);
        // Unset values are not listed at all.
        expect(lines.any((line) => line.contains('url:')), isFalse);
      });

      test('shows the dates setting', () async {
        await ConfigService.writeConfig(DgtConfig(dateDisplay: 'utc'));

        final lines = await capturePrintsAsync(ConfigService.showConfig);

        expect(lines.any((line) => line.contains('dates:  utc')), isTrue);
      });

      test('reports an empty configuration', () async {
        await ConfigService.writeConfig(DgtConfig());

        final lines = await capturePrintsAsync(ConfigService.showConfig);

        expect(
          lines.any((line) => line.contains('Configuration is empty')),
          isTrue,
        );
      });
    });

    group('cleanConfig', () {
      test('deletes the file when forced', () async {
        await ConfigService.writeConfig(DgtConfig(sortField: 'name'));

        final lines = await capturePrintsAsync(
          () => ConfigService.cleanConfig(force: true),
        );

        expect(await configFile.exists(), isFalse);
        expect(lines.first, 'Configuration reset to defaults.');
      });

      test('says there is nothing to clean when no file exists', () async {
        final lines = await capturePrintsAsync(
          () => ConfigService.cleanConfig(force: true),
        );

        expect(lines.last, 'Nothing to clean.');
      });
    });

    group('removeOptions', () {
      test('removes everything when given no specific options', () async {
        await ConfigService.writeConfig(DgtConfig(sortField: 'name'));

        await capturePrintsAsync(() => ConfigService.removeOptions(null));

        expect(await configFile.exists(), isFalse);
      });

      test('removes a single option and leaves the rest', () async {
        await ConfigService.writeConfig(
          DgtConfig(
            showUrl: true,
            sortField: 'name',
            filterSince: '2025-01-01',
          ),
        );

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.url, value: null),
          ]),
        );

        final config = await ConfigService.readConfig();
        expect(config!.showUrl, isNull);
        expect(config.sortField, 'name');
        expect(config.filterSince, '2025-01-01');
      });

      test('removes one status value and keeps the others', () async {
        await ConfigService.writeConfig(
          DgtConfig(filterStatuses: ['wip', 'active']),
        );

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.status, value: 'wip'),
          ]),
        );

        expect((await ConfigService.readConfig())!.filterStatuses, ['active']);
      });

      test('drops the status key once the last value is removed', () async {
        await ConfigService.writeConfig(DgtConfig(filterStatuses: ['wip']));

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.status, value: 'wip'),
          ]),
        );

        expect((await ConfigService.readConfig())!.filterStatuses, isNull);
      });

      test('removes sort only when the value matches', () async {
        await ConfigService.writeConfig(
          DgtConfig(sortField: 'name', sortDirection: 'desc'),
        );

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.sort, value: 'status'),
          ]),
        );
        expect((await ConfigService.readConfig())!.sortField, 'name');

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.sort, value: 'name'),
          ]),
        );

        final config = await ConfigService.readConfig();
        expect(config!.sortField, isNull);
        expect(config.sortDirection, isNull);
      });

      test('applies several removals in one pass', () async {
        await ConfigService.writeConfig(
          DgtConfig(
            showUrl: true,
            showLocal: false,
            filterDiverged: true,
            filterBefore: '2025-12-31',
          ),
        );

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.url, value: null),
            (option: RemovableConfigOption.diverged, value: null),
          ]),
        );

        final config = await ConfigService.readConfig();
        expect(config!.showUrl, isNull);
        expect(config.filterDiverged, isNull);
        expect(config.showLocal, isFalse);
        expect(config.filterBefore, '2025-12-31');
      });

      test('clears the dates setting', () async {
        await ConfigService.writeConfig(
          DgtConfig(dateDisplay: 'utc', showUrl: true),
        );

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.dates, value: null),
          ]),
        );

        final config = await ConfigService.readConfig();
        expect(config!.dateDisplay, isNull);
        expect(config.showUrl, isTrue);
      });

      test('keeps the dates setting when removing something else', () async {
        // Each removal rebuilds DgtConfig field by field, so a new field is
        // easy to drop by accident.
        await ConfigService.writeConfig(
          DgtConfig(dateDisplay: 'utc', showUrl: true, sortField: 'name'),
        );

        await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.url, value: null),
            (option: RemovableConfigOption.sort, value: null),
          ]),
        );

        expect((await ConfigService.readConfig())!.dateDisplay, 'utc');
      });

      test('reports when there is no config to remove from', () async {
        final lines = await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.url, value: null),
          ]),
        );

        expect(
          lines,
          contains(
            'No configuration file found. Nothing to '
            'remove.',
          ),
        );
      });

      test('names what it removed', () async {
        await ConfigService.writeConfig(DgtConfig(showUrl: true));

        final lines = await capturePrintsAsync(
          () => ConfigService.removeOptions([
            (option: RemovableConfigOption.url, value: null),
          ]),
        );

        expect(lines.first, 'Removed [url] from configuration.');
      });
    });
  });
}
