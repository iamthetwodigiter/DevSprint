import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileImageService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndPersist() async {
    XFile? picked;

    if (Platform.isAndroid || Platform.isIOS) {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1200,
      );
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      final path = result?.files.single.path;
      if (path != null) picked = XFile(path);
    }

    if (picked == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final target = File('${directory.path}/devsprint_profile_image');
    final bytes = await picked.readAsBytes();
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }
}

final profileImageServiceProvider = Provider<ProfileImageService>(
  (ref) => ProfileImageService(),
);
