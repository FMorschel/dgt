import 'config_service.dart';
import 'performance_tracker.dart';
import 'terminal.dart';

/// Handles the config show subcommand
Future<void> runConfigShowCommand({PerformanceTracker? tracker}) async {
  tracker?.startTimer('config_show');
  await ConfigService.showConfig();
  tracker?.endTimer('config_show');
}

/// Handles the config clean subcommand
Future<void> runConfigCleanCommand(
  bool force, {
  PerformanceTracker? tracker,
}) async {
  tracker?.startTimer('config_clean');
  await ConfigService.cleanConfig(force: force);
  tracker?.endTimer('config_clean');
}

/// Handles the config command to set default configuration options
Future<void> runConfigCommand(
  DgtConfig configToSave,
  bool removeStatus,
  bool removeDiverged,
  bool removeSort, {
  PerformanceTracker? tracker,
}) async {
  try {
    tracker?.startTimer('config_update');

    // Handle removal flags first
    if (removeStatus) {
      await ConfigService.removeOption('status');
      // Show updated config after removal
      await _displayCurrentConfig();
      tracker?.endTimer('config_update');
      return;
    }

    if (removeDiverged) {
      await ConfigService.removeOption('diverged');
      // Show updated config after removal
      await _displayCurrentConfig();
      tracker?.endTimer('config_update');
      return;
    }

    if (removeSort) {
      await ConfigService.removeOption('sort');
      // Show updated config after removal
      await _displayCurrentConfig();
      tracker?.endTimer('config_update');
      return;
    }

    // Read existing config first
    final existingConfig = await ConfigService.readConfig();

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
    await ConfigService.writeConfig(config);

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

    tracker?.endTimer('config_update');
  } catch (e) {
    Terminal.error('Error saving configuration: $e');
    Terminal.error('Stack trace: ${StackTrace.current}');
    tracker?.endTimer('config_update');
  }
}

/// Helper function to display the current configuration after updates
Future<void> _displayCurrentConfig() async {
  Terminal.info('');
  final config = await ConfigService.readConfig();

  if (config == null) {
    Terminal.info('Configuration has been reset to defaults.');
    return;
  }

  final configPath = ConfigService.getConfigFilePath();
  Terminal.info('Updated configuration at: $configPath');
  Terminal.info('');
  Terminal.info('Current settings:');

  if (config.showLocal != null) {
    Terminal.info('  local:  ${config.showLocal}');
  }
  if (config.showGerrit != null) {
    Terminal.info('  gerrit: ${config.showGerrit}');
  }
  if (config.showUrl != null) {
    Terminal.info('  url: ${config.showUrl}');
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

  Terminal.info('');
  Terminal.info('These settings will be used as defaults for future runs.');
}
