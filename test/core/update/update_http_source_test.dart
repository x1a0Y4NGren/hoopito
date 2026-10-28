import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/update/app_update.dart';

void main() {
  test('rejects cross-origin redirect before requesting its target', () async {
    final client = ScriptedClient([
      FakeResponse(
        status: 302,
        location: 'https://attacker.example/android-update.json',
      ),
    ]);
    final reader = UpdateHttpSourceReader(clientFactory: () => client);
    await expectLater(
      reader.read(updateFallbackFeed),
      throwsA(isA<UpdateException>()),
    );
    expect(client.visited, [updateFallbackFeed]);
    expect(client.closed, isTrue);
  });

  test(
    'follows Github release CDN redirects and decodes bounded metadata',
    () async {
      final client = ScriptedClient([
        FakeResponse(
          status: 302,
          location:
              'https://release-assets.githubusercontent.com/github-production-release-asset/1/a?signature=public',
        ),
        FakeResponse(body: utf8.encode('{"schemaVersion":1}')),
      ]);
      expect(
        await UpdateHttpSourceReader(
          clientFactory: () => client,
        ).read(updateFallbackFeed),
        '{"schemaVersion":1}',
      );
      expect(client.visited, hasLength(2));
      expect(client.followedAutomatically, isFalse);
      expect(client.closed, isTrue);
    },
  );

  test('bounds streaming bytes even without a content length', () async {
    final client = ScriptedClient([
      FakeResponse(chunks: [List.filled(32768, 32), List.filled(32769, 32)]),
    ]);
    await expectLater(
      UpdateHttpSourceReader(
        clientFactory: () => client,
      ).read(updatePrimaryFeed),
      throwsA(isA<UpdateException>()),
    );
    expect(client.closed, isTrue);
  });

  test('accepts exactly 64 KiB of UTF-8 rather than characters', () async {
    final body = utf8.encode('中' * 21845 + ' ');
    expect(body, hasLength(65536));
    final client = ScriptedClient([FakeResponse(body: body)]);
    expect(
      utf8.encode(
        await UpdateHttpSourceReader(
          clientFactory: () => client,
        ).read(updatePrimaryFeed),
      ),
      body,
    );
  });

  testWidgets('total timeout closes a hung source connection', (tester) async {
    final client = ScriptedClient([], hang: true);
    final result = UpdateHttpSourceReader(
      clientFactory: () => client,
    ).read(updatePrimaryFeed);
    final assertion = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 8));
    await assertion;
    expect(client.closed, isTrue);
  });

  test('rejects insecure and nonstandard-port redirects', () async {
    for (final target in [
      'http://hoopito.com/updates/android/stable.json',
      'https://hoopito.com:8443/updates/android/stable.json',
      'https://hoopito.com.evil.test/updates/android/stable.json',
    ]) {
      final client = ScriptedClient([
        FakeResponse(status: 302, location: target),
      ]);
      await expectLater(
        UpdateHttpSourceReader(
          clientFactory: () => client,
        ).read(updatePrimaryFeed),
        throwsA(isA<UpdateException>()),
      );
      expect(client.visited, hasLength(1));
    }
  });
}

class ScriptedClient implements HttpClient {
  ScriptedClient(this.responses, {this.hang = false});
  final List<FakeResponse> responses;
  final bool hang;
  final visited = <Uri>[];
  bool closed = false;
  bool followedAutomatically = false;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    visited.add(uri);
    if (hang) return Completer<HttpClientRequest>().future;
    return FakeRequest(this, responses.removeAt(0));
  }

  @override
  void close({bool force = false}) {
    closed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRequest implements HttpClientRequest {
  FakeRequest(this.client, this.response);
  final ScriptedClient client;
  final FakeResponse response;
  @override
  final HttpHeaders headers = FakeHeaders();
  @override
  set followRedirects(bool value) {
    client.followedAutomatically = value;
  }

  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeResponse({
    int status = 200,
    String? location,
    List<int>? body,
    List<List<int>>? chunks,
  }) : statusCode = status,
       headers = FakeHeaders(location: location),
       _stream = Stream.fromIterable(chunks ?? [body ?? []]);
  final Stream<List<int>> _stream;
  @override
  final int statusCode;
  @override
  final HttpHeaders headers;
  @override
  int get contentLength => -1;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHeaders implements HttpHeaders {
  FakeHeaders({this.location});
  final String? location;
  @override
  String? value(String name) =>
      name == HttpHeaders.locationHeader ? location : null;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
