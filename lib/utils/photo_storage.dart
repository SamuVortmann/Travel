import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Reads selected images so their bytes can be persisted directly in SQLite.
class PhotoStorage {
  PhotoStorage._();

  static Future<List<Uint8List>> readAll(List<XFile> photos) async {
    if (photos.isEmpty) return const [];
    final result = <Uint8List>[];
    for (final photo in photos) {
      final bytes = await photo.readAsBytes().timeout(
        const Duration(seconds: 12),
      );
      if (bytes.isEmpty) throw StateError('Uma das imagens está vazia.');
      if (bytes.lengthInBytes > 12 * 1024 * 1024) {
        throw StateError('Uma das imagens é grande demais para ser salva.');
      }
      result.add(bytes);
    }
    return result;
  }
}
