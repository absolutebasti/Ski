import 'package:image_picker/image_picker.dart';

import '../features/account/avatar_picker.dart';

/// Gallery picker for the profile avatar (PHPicker on iOS 14+, no photo
/// permission needed). The picked bytes are centre-cropped and downscaled
/// by [squareAvatar]; null when the user cancelled.
class ImagePickerAvatarPicker implements AvatarPicker {
  ImagePickerAvatarPicker();
  final ImagePicker _picker = ImagePicker();

  @override
  Future<PickedAvatar?> pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
    if (file == null) return null;
    return squareAvatar(await file.readAsBytes());
  }
}
