import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  final double size;
  final bool editable;
  const ProfileAvatar({super.key, this.size = 48, this.editable = false});

  Future<void> _pickAndSaveImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 90);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop profile picture',
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop profile picture',
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final newPath = '${docsDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(cropped.path).copy(newPath);

    if (!context.mounted) return;
    final appState = AppStateScope.of(context);
    final oldPath = appState.profileImagePath;

    await appState.setProfileImagePath(newPath);
    if (oldPath != null && oldPath != newPath) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = AppStateScope.of(context).profileImagePath;
    final hasImage = path != null && File(path).existsSync();

    final avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
      child: hasImage
          ? Image.file(File(path), fit: BoxFit.cover)
          : Icon(Icons.person, size: size * 0.5, color: context.colors.textSecondary),
    );

    if (!editable) return avatar;

    return GestureDetector(
      onTap: () => _pickAndSaveImage(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.colors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.background, width: 2),
              ),
              child: const Icon(Icons.edit, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
