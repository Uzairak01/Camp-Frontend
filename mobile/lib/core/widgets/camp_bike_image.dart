import 'dart:io';
import 'package:flutter/material.dart';

/// Shared helper widget for displaying a motorcycle image with fallback to placeholder.
/// Handles asset images, persistent file images, missing files, and null paths.
class CampBikeImage extends StatelessWidget {
  const CampBikeImage({
    super.key,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderAsset = 'assets/images/bmw_r1250_scan_placeholder.jpg',
  });

  final String? imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final String placeholderAsset;

  @override
  Widget build(BuildContext context) {
    Widget image;
    final path = imagePath?.trim();

    if (path == null || path.isEmpty) {
      image = Image.asset(
        placeholderAsset,
        fit: fit,
        width: width,
        height: height,
      );
    } else if (path.startsWith('assets/')) {
      image = Image.asset(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          placeholderAsset,
          fit: fit,
          width: width,
          height: height,
        ),
      );
    } else {
      image = Image.file(
        File(path),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          placeholderAsset,
          fit: fit,
          width: width,
          height: height,
        ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }
    return image;
  }
}
