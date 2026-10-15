import 'dart:io';

// crypto is a transitive dependency (via archive); it resolves
// from pubspec.lock and is used here only for the sha256 proof.
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Byte-equality proof for the DATA DIET package: every bundled
/// JSON asset now ships gzipped (`assets/<name>.json.gz`), and
/// inflating it must reproduce the pre-change plain asset byte
/// for byte. Each expectation below is the recorded pre-change
/// length and sha256 of the plain file; a single drifted byte in
/// any asset fails its test.
void main() {
  group('bundled gzipped assets inflate to the recorded bytes', () {
    const expected = <String, (int, String)>{
      'data': (
        8504484,
        'a7d669452ec25b62201124bdc10536219769972bc27ea6646174c34010049f19',
      ),
      'kjv': (
        4219564,
        'a253fcf118ad52cc26cfd712fb131520d9a2893e702beca103f45b25e42049df',
      ),
      'web': (
        4169532,
        'd62cac40dd8b2e97a1c0a227230c14bf5c8f47f92d1f0a01106385c5731264b7',
      ),
      'jps': (
        3276049,
        '97798cee3fe74060c43d0640fe917113ee8da919d9117aba928ab0c83776223d',
      ),
      'hebrew': (
        5426198,
        '7e6758ee277caf5c496626b6ef8ed2e3145cc86e5f6d1ecaad851225ab8d551f',
      ),
      'webc': (
        4672408,
        '26615af63e8ac357f87d4efb366b2b75a8db4fb51732fe54ca8afd33aa5fdeb3',
      ),
      'conference': (
        2284735,
        '03c2a4df9fb641e9c5e309867294d42a53cc5e46bae17afd7ddf488fa12a70e0',
      ),
      'confessions': (
        83129,
        '4967218729e4a029d99b6ad72d6a6cb53f0ca538039cde3560079fccb54d2aae',
      ),
    };

    for (final entry in expected.entries) {
      test('${entry.key}.json.gz inflates byte-identically', () {
        final gzBytes = File('assets/${entry.key}.json.gz').readAsBytesSync();
        final inflated = GZipCodec().decode(gzBytes);
        expect(inflated.length, entry.value.$1);
        expect(sha256.convert(inflated).toString(), entry.value.$2);
      });
    }
  });
}
