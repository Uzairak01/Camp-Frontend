import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/image_storage_helper.dart';
import '../presentation/screens/bike_scan_screen.dart';

/// Helper utility for picking bike photos from the device gallery
/// and managing permissions gracefully.
class GalleryPickerHelper {
  const GalleryPickerHelper._();

  /// Picks an image from the gallery. Returns the [XFile] if selected, or null if cancelled or failed.
  /// If [onError] is provided, it will be invoked on permission or platform exceptions.
  static Future<XFile?> pickImageFromGallery({
    void Function(String message)? onError,
  }) async {
    HapticFeedback.lightImpact();
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      return image;
    } catch (e) {
      onError?.call('Unable to access photo gallery. Please check permissions.');
      return null;
    }
  }

  /// Picks a photo from the gallery and navigates directly to [BikeScanScreen] with the selected image.
  static Future<void> pickAndNavigateToScan(BuildContext context) async {
    final image = await pickImageFromGallery(
      onError: (message) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.darkCharcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 2200),
          ),
        );
      },
    );

    if (image == null || !context.mounted) return;

    final savedPath = await persistBikePhoto(image.path);
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BikeScanScreen(imagePath: savedPath),
      ),
    );
  }
}
