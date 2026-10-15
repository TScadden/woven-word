import 'dart:convert';
import 'dart:io';

/// Reads a bundled asset that now ships gzipped (`assets/*.json.gz`)
/// and returns its inflated JSON text — the same bytes the app's
/// data layer inflates at runtime, read here through dart:io
/// (tests run on the VM) so fixture assertions see identical input.
String readBundledJson(String gzPath) =>
    utf8.decode(GZipCodec().decode(File(gzPath).readAsBytesSync()));
