import 'dart:io';
import 'dart:typed_data';

/// Lê do sistema de arquivos os bytes de uma foto criada por versões anteriores.
Future<Uint8List?> readLegacyPhoto(String path) => File(path).readAsBytes();
