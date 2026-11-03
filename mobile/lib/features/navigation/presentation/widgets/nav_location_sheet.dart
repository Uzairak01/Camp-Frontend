import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../controllers/navigation_controller.dart';

/// State 1 collapsed bottom card displaying reverse-geocoded user location,
/// GPS status pill, and the primary "Directions" button.
class NavLocationSheet extends StatelessWidget {
  const NavLocationSheet({
    required this.controller,
    required this.onTapDirections,
    super.key,
  });

  final NavigationController controller;
  final VoidCallback onTapDirections;

  /// Opens the rename dialog and saves the rider's current position under the
  /// entered name via [NavigationController.saveCurrentLocationAs]. Needs a
  /// real GPS fix, so without one the rider gets a hint instead.
  Future<void> _openRenameDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (controller.userLatLng == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Waiting for your location before it can be saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenamePlaceDialog(
        initialName: controller.savedPlaceNameNearRider ?? '',
      ),
    );
    if (name == null) return;
    final saved = await controller.saveCurrentLocationAs(name);
    if (saved) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved as "$name"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Row(
            children: [
              // Location Icon Tile
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, and Pill Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // "YOUR LOCATION" Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YOUR LOCATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        Text(
                          controller.currentLocationSubtitle.isNotEmpty
                              ? controller.currentLocationSubtitle
                              : 'GPS Ready',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Tapping the label lets the rider name this place.
                    InkWell(
                      onTap: () => _openRenameDialog(context),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              controller.currentLocationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.mutedLight,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Primary "Directions" Orange Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTapDirections,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.tacticalOrangeLight,
                          AppColors.tacticalOrange,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.tacticalOrange.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Directions',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Small dialog with a name field and a "Save this place" action.
///
/// Owns its [TextEditingController] so it is disposed with the dialog; pops the
/// trimmed name, or null when cancelled or left blank.
class _RenamePlaceDialog extends StatefulWidget {
  const _RenamePlaceDialog({required this.initialName});

  /// Pre-filled name (the existing saved name here, or empty).
  final String initialName;

  @override
  State<_RenamePlaceDialog> createState() => _RenamePlaceDialogState();
}

class _RenamePlaceDialogState extends State<_RenamePlaceDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Closes the dialog returning the trimmed name (null when blank).
  void _submit() {
    final name = _nameController.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this place'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          hintText: 'e.g. Home, PUEHS Town II',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save this place'),
        ),
      ],
    );
  }
}
