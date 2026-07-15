import 'dart:typed_data';

/// Retorna nulo em plataformas sem acesso direto ao sistema de arquivos.
Future<Uint8List?> readLegacyPhoto(String path) async => null;
