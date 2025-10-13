import 'config_service.dart';
import 'terminal.dart';

/// Handles the config command to set default configuration options
Future<void> runConfigCommand(
  bool verbose,
  bool? showGerrit,
  bool? showLocal,
  bool? showUrl,
  List<String>? filterStatuses,
  String? filterSince,
  String? filterBefore,
  bool? filterDiverged,
  String? sortField,
  String? sortDirection,
) async {
  try {
    // Read existing config first
    final existingConfig = await ConfigService.readConfig(verbose: verbose);

    // Create config, merging with existing values
    // Only update fields that were explicitly provided
    // Empty string signals to clear a field
    final config = DgtConfig(
      showGerrit: showGerrit ?? existingConfig?.showGerrit,
      showLocal: showLocal ?? existingConfig?.showLocal,
      showUrl: showUrl ?? existingConfig?.showUrl,
      filterStatuses: filterStatuses ?? existingConfig?.filterStatuses,
      filterSince: filterSince ?? existingConfig?.filterSince,
      filterBefore: filterBefore ?? existingConfig?.filterBefore,
      filterDiverged: filterDiverged ?? existingConfig?.filterDiverged,
      sortField: sortField == ''
          ? null
          : (sortField ?? existingConfig?.sortField),
      sortDirection: sortDirection == ''
          ? null
          : (sortDirection ?? existingConfig?.sortDirection),
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
