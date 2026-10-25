import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/entry/entry_brand_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (ratio, pixels) in [(1.0, 225), (2.625, 590), (5.0, 1024)]) {
    test(
      'entry texture fits $ratio DPR without upscaling the approved source',
      () async {
        final image = await decodeEntryBrandImage(devicePixelRatio: ratio);
        try {
          expect(image.width, pixels);
          expect(image.height, pixels);
        } finally {
          image.dispose();
        }
      },
    );
  }
}
