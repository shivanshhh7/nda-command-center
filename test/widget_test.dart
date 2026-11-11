import 'package:flutter_test/flutter_test.dart';
import 'package:ascend/main.dart';

void main() {
  test('ASCEND app can be created', () {
    expect(() => const AscendApp(), returnsNormally);
  });
}
