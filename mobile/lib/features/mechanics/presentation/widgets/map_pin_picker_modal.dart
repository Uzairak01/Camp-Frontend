import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

/// Modal dialog allowing a rider to choose a workshop location on a map by dropping a pin.
class MapPinPickerModal extends StatefulWidget {
  const MapPinPickerModal({
    required this.initialCenter,
    super.key,
    this.initialPin,
    this.tileProvider,
  });

  final LatLng initialCenter;
  final LatLng? initialPin;
  final TileProvider? tileProvider;

  @override
  State<MapPinPickerModal> createState() => _MapPinPickerModalState();
}

class _MapPinPickerModalState extends State<MapPinPickerModal> {
  late LatLng? _selectedPin;
  final MapController _mapController = MapController();

  static const String _osmStandardUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _selectedPin = widget.initialPin ?? widget.initialCenter;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onTapMap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPin = point;
    });
  }

  void _confirmSelection() {
    if (_selectedPin != null) {
      Navigator.of(context).pop(_selectedPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.clay,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: double.infinity,
          height: 520,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                color: AppColors.clayDark,
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      color: AppColors.tacticalOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose on Map',
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          Text(
                            'Tap anywhere on the map to drop a pin',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.mutedText,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Interactive Map
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedPin ?? widget.initialCenter,
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 19.0,
                    onTap: _onTapMap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _osmStandardUrl,
                      tileProvider: widget.tileProvider,
                      userAgentPackageName: 'com.camp.moto',
                      maxZoom: 19,
                    ),
                    if (_selectedPin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPin!,
                            width: 50,
                            height: 50,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.tacticalOrange,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Bottom Confirmation Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.clayDark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedPin != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Pin at ${_selectedPin!.latitude.toStringAsFixed(4)}°, ${_selectedPin!.longitude.toStringAsFixed(4)}°',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'No pin dropped yet',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            key: const ValueKey('confirm_map_pin_button'),
                            onPressed: _selectedPin != null ? _confirmSelection : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.tacticalOrange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.tacticalOrange.withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Confirm Pin',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
