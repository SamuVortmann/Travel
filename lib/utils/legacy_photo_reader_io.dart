import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readLegacyPhoto(String path) => File(path).readAsBytes();
