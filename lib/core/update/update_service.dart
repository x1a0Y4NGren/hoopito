import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'update_models.dart';

final updatePrimaryFeed = Uri.parse(
  'https://hoopito.com/updates/android/stable.json',
);
final updateFallbackFeed = Uri.parse(
  'https://github.com/x1a0Y4NGren/hoopito/releases/latest/download/android-update.json',
);
const updateMetadataByteLimit = 64 * 1024;
const updateSourceTimeout = Duration(seconds: 8);

/// Fetches only static public release data. No app, settings or player data is sent.
class UpdateService {
  UpdateService({Future<String> Function(Uri)? sourceReader})
    : _sourceReader = sourceReader ?? UpdateHttpSourceReader().read;
  final Future<String> Function(Uri) _sourceReader;

  Future<UpdateCheckResult> check(InstalledAppInfo installed) async {
    if (installed.applicationId != updateApplicationId) {
      throw const UpdateException('unsupported');
    }
    String lastError = 'network';
    for (final source in [updatePrimaryFeed, updateFallbackFeed]) {
      try {
        final text = await _sourceReader(source).timeout(updateSourceTimeout);
        if (utf8.encode(text).length > updateMetadataByteLimit) {
          throw const FormatException('Metadata too large');
        }
        final data = jsonDecode(text);
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Invalid metadata');
        }
        final release = UpdateRelease.fromJson(data);
        if (release.versionCode <= installed.versionCode) {
          return const UpdateCheckResult(status: UpdateCheckStatus.upToDate);
        }
        return UpdateCheckResult(
          status: release.minimumApi > installed.sdkInt
              ? UpdateCheckStatus.incompatible
              : UpdateCheckStatus.updateAvailable,
          release: release,
        );
      } on FormatException {
        lastError = 'metadata';
      } on Object {
        lastError = 'network';
      }
    }
    throw UpdateException(lastError);
  }
}

/// Disables automatic redirects so every hop is checked before opening it.
class UpdateHttpSourceReader {
  UpdateHttpSourceReader({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;
  final HttpClient Function() _clientFactory;

  Future<String> read(Uri source) async {
    if (source != updatePrimaryFeed && source != updateFallbackFeed) {
      throw const UpdateException('metadata');
    }
    final client = _clientFactory();
    try {
      return await _read(client, source).timeout(updateSourceTimeout);
    } finally {
      // A timeout closes in-flight requests and response streams as well.
      client.close(force: true);
    }
  }

  Future<String> _read(HttpClient client, Uri source) async {
    var uri = source;
    for (var redirects = 0; redirects <= 5; redirects++) {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || redirects == 5) {
          throw const UpdateException('network');
        }
        final next = uri.resolve(location);
        if (!_allowedRedirect(next, source)) {
          throw const UpdateException('metadata');
        }
        // Closing the client at the end cancels redirect bodies without reading them.
        uri = next;
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const UpdateException('network');
      }
      if (response.contentLength > updateMetadataByteLimit) {
        throw const UpdateException('metadata');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > updateMetadataByteLimit) {
          throw const UpdateException('metadata');
        }
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    }
    throw const UpdateException('network');
  }

  bool _allowedRedirect(Uri uri, Uri source) {
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return false;
    }
    if (uri.host == 'hoopito.com') {
      return source == updatePrimaryFeed &&
          uri.path == updatePrimaryFeed.path &&
          !uri.hasQuery;
    }
    if (uri.host == 'github.com') {
      return source == updateFallbackFeed &&
          uri.path.startsWith('/x1a0Y4NGren/hoopito/releases/') &&
          uri.path.endsWith('/android-update.json');
    }
    return source == updateFallbackFeed &&
        {
          'release-assets.githubusercontent.com',
          'objects.githubusercontent.com',
          'github-releases.githubusercontent.com',
        }.contains(uri.host);
  }
}
