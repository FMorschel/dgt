import 'config_service.dart';
import 'terminal.dart';

/// Handles the config show subcommand
Future<void> runConfigShowCommand(bool verbose) async {
  await ConfigService.showConfig(verbose: verbose);
}

/// Handles the config clean subcommand
Future<void> runConfigCleanCommand(bool verbose, bool force) async {
  await ConfigService.cleanConfig(verbose: verbose, force: force);
}

/// Handles the config command to set default configuration options
Future<void> runConfigCommand(
  bool verbose,
  DgtConfig configToSave,
  bool removeStatus,
  bool removeDiverged,
) async {
  try {
    // Handle removal flags first
    if (removeStatus) {
      await ConfigService.removeOption('status', verbose: verbose);
      return;
    }

    if (removeDiverged) {
      await ConfigService.removeOption('diverged', verbose: verbose);
      return;
    }

    // Read existing config first
    final existingConfig = await ConfigService.readConfig(verbose: verbose);

    // Create config, merging with existing values
    // Only update fields that were explicitly provided
    // Empty string signals to clear a field
    final config = DgtConfig(
      showGerrit: configToSave.showGerrit ?? existingConfig?.showGerrit,
      showLocal: configToSave.showLocal ?? existingConfig?.showLocal,
      showUrl: configToSave.showUrl ?? existingConfig?.showUrl,
      filterStatuses:
          configToSave.filterStatuses ?? existingConfig?.filterStatuses,
      filterSince: configToSave.filterSince ?? existingConfig?.filterSince,
      filterBefore: configToSave.filterBefore ?? existingConfig?.filterBefore,
      filterDiverged:
          configToSave.filterDiverged ?? existingConfig?.filterDiverged,
      sortField: configToSave.sortField == ''
          ? null
          : (configToSave.sortField ?? existingConfig?.sortField),
      sortDirection: configToSave.sortDirection == ''
          ? null
          : (configToSave.sortDirection ?? existingConfig?.sortDirection),
    );

    // Write config to file
    await ConfigService.writeConfig(config, verbose: verbose);

    final configPath = ConfigService.getConfigFilePath();
    Terminal.info('Configuration saved to: $configPath');
    Terminal.info('');
    Terminal.info('Settings:');
    if (config.showLocal != null) {
      Terminal.info('  local:  ${config.showLocal}');
    }
    if (config.showGerrit != null) {
      Terminal.info('  gerrit: ${config.showGerrit}');
    }
    if (config.filterStatuses != null && config.filterStatuses!.isNotEmpty) {
      Terminal.info('  filterStatuses: ${config.filterStatuses}');
    }
    if (config.filterSince != null) {
      Terminal.info('  filterSince: ${config.filterSince}');
    }
    if (config.filterBefore != null) {
      Terminal.info('  filterBefore: ${config.filterBefore}');
    }
    if (config.filterDiverged != null) {
      Terminal.info('  filterDiverged: ${config.filterDiverged}');
    }
    if (config.sortField != null) {
      Terminal.info('  sortField: ${config.sortField}');
    }
    if (config.sortDirection != null) {
      Terminal.info('  sortDirection: ${config.sortDirection}');
    }
    if (config.showUrl != null) {
      Terminal.info('  url: ${config.showUrl}');
    }
    Terminal.info('');
    Terminal.info('These settings will be used as defaults for future runs.');
    Terminal.info(
      'You can override them with command-line flags like --no-gerrit, '
      '--no-local, --status, --sort, etc.',
    );
  } catch (e) {
    Terminal.error('Error saving configuration: $e');
    if (verbose) {
      Terminal.error('Stack trace: ${StackTrace.current}');
    }
  }
}
