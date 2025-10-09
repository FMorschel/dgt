import 'config_service.dart';
import 'terminal.dart';

/// Handles the config command to set default configuration options
Future<void> runConfigCommand(
  bool verbose,
  bool? showGerrit,
  bool? showLocal,
) async {
  try {
    // Read existing config first
    final existingConfig = await ConfigService.readConfig(verbose: verbose);

    // Create config, merging with existing values
    // Only update fields that were explicitly provided
    final config = DgtConfig(
      showGerrit: showGerrit ?? existingConfig?.showGerrit,
      showLocal: showLocal ?? existingConfig?.showLocal,
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
    Terminal.info('');
    Terminal.info('These settings will be used as defaults for future runs.');
    Terminal.info(
      'You can override them with command-line flags like --no-gerrit or --no-local.',
    );
  } catch (e) {
    Terminal.error('Error saving configuration: $e');
    if (verbose) {
      Terminal.error('Stack trace: ${StackTrace.current}');
    }
  }
}
