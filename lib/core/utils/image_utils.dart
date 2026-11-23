import 'dart:typed_data';

/// Detects the real image type from the first bytes of the file (the file
/// extension or the picker's guess is not reliable, especially on iPhone).
String? detectImageMime(Uint8List bytes) {
  if (bytes.length < 12) return null;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
  if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
  // ISO base media file: "....ftyp<brand>"
  if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
    const heifBrands = {'heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1', 'heif', 'heim', 'heis'};
    if (heifBrands.contains(brand)) return 'image/heic';
    if (brand == 'avif' || brand == 'avis') return 'image/avif';
  }
  return null;
}

String extensionForMime(String mime) {
  switch (mime) {
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    default:
      return 'jpg';
  }
}

/// Image types the backend accepts.
bool isSupportedUploadMime(String? mime) =>
    mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp';

const String unsupportedPhotoMessage =
    'This photo format is not supported. Please use a JPG or PNG photo '
    '(on iPhone: Settings > Camera > Formats > Most Compatible).';
