import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const maxAvatarBytes = 2 * 1024 * 1024;

/// Picker files are disposable. Only publish an owned path after verifying it.
Future<File> importAvatar(File source) async {
  try {
    if (await source.length() > maxAvatarBytes) {
      throw StateError('Ảnh đại diện lớn hơn 2 MB. Hãy chọn ảnh nhỏ hơn.');
    }
    return await storeAvatarBytes(await source.readAsBytes());
  } on FileSystemException {
    throw StateError('Không lưu được ảnh đại diện. Hãy chọn lại ảnh.');
  }
}

/// Shared by selection and restore; filenames never depend on external paths.
Future<File> storeAvatarBytes(List<int> bytes) async {
  if (bytes.isEmpty || bytes.length > maxAvatarBytes) {
    throw StateError('Ảnh đại diện phải có dữ liệu và không vượt quá 2 MB.');
  }
  final digest = sha256.convert(bytes);
  final folder = await getApplicationDocumentsDirectory();
  final image = File(p.join(folder.path, 'avatar_$digest.img'));
  Future<bool> matches(File file) async =>
      await file.exists() &&
      await file.length() == bytes.length &&
      sha256.convert(await file.readAsBytes()) == digest;
  if (await matches(image)) return image;

  final temporary =
      File(p.join(folder.path, 'avatar_${const Uuid().v4()}.tmp'));
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    if (!await matches(temporary)) {
      throw StateError('Không lưu được ảnh đại diện. Hãy chọn lại ảnh.');
    }
    try {
      await temporary.rename(image.path);
    } on FileSystemException {
      // Another import of the same content may already have published it.
      if (!await matches(image)) rethrow;
    }
    if (!await matches(image)) {
      throw StateError('Không lưu được ảnh đại diện. Hãy chọn lại ảnh.');
    }
    return image;
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}
