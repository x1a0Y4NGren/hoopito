import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:intl/intl.dart';

String settingsFriendlyError(Object error, AppLocalizations l10n) {
  if (error is BackupCapacityException) {
    final numbers = NumberFormat.decimalPattern(l10n.localeName);
    String measurement(int value) {
      if (error.limitKind == BackupCapacityLimit.payloadBytes) {
        if (value < 1024 * 1024) return '${numbers.format(value)} B';
        final mebibytes = NumberFormat('0.00', l10n.localeName);
        return '${mebibytes.format(value / (1024 * 1024))} MiB';
      }
      return '${numbers.format(value)} ${l10n.v2BackupRows}';
    }

    return l10n.v2BackupCapacityError(
      measurement(error.measured),
      measurement(error.limit),
    );
  }
  if (error is SafetyBackupWriteException) return l10n.v2SafetyWriteError;
  if (error is BackupChecksumException) return l10n.settingsErrorChecksum;
  if (error is UnsupportedBackupSchemaException) {
    return l10n.settingsErrorFutureVersion;
  }
  if (error is BackupFormatException ||
      error is BackupValidationException ||
      error is BackupRestoreException) {
    return l10n.settingsErrorInvalidBackup;
  }
  if (error is BackupMergeException) return l10n.settingsErrorMerge;
  if (error is BackupDirectoryNotConfiguredException) {
    return l10n.settingsErrorDirectoryRequired;
  }
  if (error is BackupDirectoryUnavailableException) {
    return l10n.settingsErrorDirectoryUnavailable;
  }
  if (error is AutomaticBackupWriteException) {
    return l10n.settingsErrorBackupWrite;
  }
  if (error is BackupRestoreBlockedException) {
    return l10n.settingsErrorRestoreBlocked;
  }
  return l10n.settingsErrorGeneric;
}
