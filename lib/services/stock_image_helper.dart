import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class StockImageHelper {
  static final _picker = ImagePicker();

  /// Picks and compresses an image to JPEG base64 for Firestore (~200–300KB target).
  static Future<({String base64, String mime})?> pickCompressed({
    required ImageSource source,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (file == null) return null;

    final raw = await file.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      raw,
      minWidth: 800,
      minHeight: 800,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    var bytes = compressed.isEmpty ? raw : Uint8List.fromList(compressed);

    // Further shrink if still large (>280KB).
    if (bytes.lengthInBytes > 280 * 1024) {
      final tighter = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 640,
        minHeight: 640,
        quality: 55,
        format: CompressFormat.jpeg,
      );
      if (tighter.isNotEmpty) {
        bytes = Uint8List.fromList(tighter);
      }
    }

    return (base64: base64Encode(bytes), mime: 'image/jpeg');
  }

  static Uint8List? decodeBase64(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}
