@Tags(['network'])
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:voice_models/voice_models.dart';

/// Checks the catalog against the publishers, over the network.
///
/// A size that drifts is not a cosmetic error: `has()` reports a correctly
/// downloaded model as missing, and `ensure()` throws away a good download as
/// truncated. Nothing offline can catch that, so this asks the servers.
void main() {
  late http.Client client;
  setUpAll(() => client = http.Client());
  tearDownAll(() => client.close());

  /// Asks for the first byte and reads the total out of `Content-Range`.
  ///
  /// A HEAD would be the obvious way, but Hugging Face omits `Content-Length`
  /// on some files — the small text ones — while a ranged request reports the
  /// true size for every file on both hosts.
  Future<int> upstreamSize(String url) async {
    final request = http.Request('GET', Uri.parse(url))
      ..headers['Range'] = 'bytes=0-0';
    final response = await client.send(request);
    await response.stream.drain<void>();

    expect(response.statusCode, 206,
        reason: '$url did not honour a range request');
    final range = response.headers['content-range'];
    expect(range, isNotNull, reason: 'no Content-Range on a 206 from $url');
    return int.parse(range!.split('/').last);
  }

  for (final model in voiceModelCatalog) {
    group(model.id, () {
      for (final file in model.files) {
        test('${file.name} is ${file.bytes} bytes upstream', () async {
          expect(
            await upstreamSize(file.url),
            file.bytes,
            reason: 'the file upstream changed size — update the catalog, and '
                'check whether the model itself was replaced',
          );
        }, timeout: const Timeout(Duration(seconds: 60)));
      }
    });
  }
}
