import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/device_automatic_backup_storage.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DeviceExportGateway implements ExportGateway {
  DeviceExportGateway({DeviceAutomaticBackupStorage? backupStorage})
    : backupStorage = backupStorage ?? DeviceAutomaticBackupStorage();

  final DeviceAutomaticBackupStorage backupStorage;

  @override
  Future<ExportArtifact?> pickBackup({String? dialogTitle}) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: dialogTitle ?? 'Choose a Hoopito backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return ExportArtifact(
      fileName: picked.name,
      mimeType: 'application/json',
      bytes: bytes,
    );
  }

  @override
  Future<BackupDirectorySelection?> pickDirectory({String? dialogTitle}) async {
    if (Platform.isAndroid) return backupStorage.pickDirectory();
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle ?? 'Choose an automatic backup folder',
    );
    if (directory == null) return null;
    return BackupDirectorySelection(
      reference: directory,
      displayName: directory,
    );
  }

  @override
  Future<void> share(
    List<ExportArtifact> artifacts, {
    required String subject,
  }) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final exportDirectory = Directory(
      path.join(temporaryDirectory.path, 'hoopito-exports'),
    );
    await exportDirectory.create(recursive: true);
    final files = <XFile>[];
    for (final artifact in artifacts) {
      final file = File(path.join(exportDirectory.path, artifact.fileName));
      await file.writeAsBytes(artifact.bytes, flush: true);
      files.add(XFile(file.path, mimeType: artifact.mimeType));
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: subject,
        text: subject,
        fileNameOverrides: artifacts
            .map((artifact) => artifact.fileName)
            .toList(),
      ),
    );
  }
}
