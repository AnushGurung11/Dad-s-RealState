import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/ids.dart';

/// Tenant photo pipeline: gallery pick → copy into the app's documents
/// directory. The stored path is stable across reboots — the OS picker's
/// transient cache path is never persisted to a Person.
///
/// Screens depend on this abstraction; tests inject a fake implementing it.
abstract interface class TenantPhotoPicker {
  /// Returns the stored (stable, app-local) path of the picked photo, or
  /// null when the user cancelled.
  Future<String?> pickAndStore();
}

class GalleryTenantPhotoPicker implements TenantPhotoPicker {
  const GalleryTenantPhotoPicker();

  @override
  Future<String?> pickAndStore() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final documents = await getApplicationDocumentsDirectory();
    final photosDir = Directory(
        '${documents.path}${Platform.pathSeparator}tenant_photos');
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
    final name = picked.name;
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.'))
        : '.jpg';
    final target =
        '${photosDir.path}${Platform.pathSeparator}photo_${newId()}$extension';
    await File(picked.path).copy(target);
    return target;
  }
}
