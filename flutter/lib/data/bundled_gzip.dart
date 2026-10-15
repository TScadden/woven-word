import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

/// Inflates one gzipped bundled JSON asset to its JSON text.
///
/// Top-level and compute-safe: the data loaders pass raw asset
/// bytes into their parse isolates and call this there, so the
/// inflate cost stays off the UI thread (the shape
/// `SefariaData.load` established for `assets/sefaria.json.gz`).
///
/// Uses package:archive's [GZipDecoder] rather than dart:io's
/// GZipCodec so decoding is platform-uniform, including web,
/// where dart:io is unavailable.
String inflateBundledJson(Uint8List bytes) =>
    utf8.decode(GZipDecoder().decodeBytes(bytes));

/// Loads a bundled asset's raw bytes from the [rootBundle].
Future<Uint8List> loadBundledBytes(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// [loadBundledBytes] as failures-as-values: a missing or
/// unloadable asset returns null instead of throwing, for the
/// loaders' optional (best-effort) assets.
Future<Uint8List?> loadBundledBytesOrNull(String path) async {
  try {
    return await loadBundledBytes(path);
  } catch (_) {
    return null;
  }
}
