// Seleciona em tempo de compilação a implementação adequada para fotos antigas.
export 'legacy_photo_reader_stub.dart'
    if (dart.library.io) 'legacy_photo_reader_io.dart';
