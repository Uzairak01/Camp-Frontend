import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/data/app_repositories.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../../core/widgets/inset_tile.dart';
import '../../../garage/domain/bike_model.dart';
import '../../domain/carburetor_guidance_table.dart';

/// Tab 2 — Carburetor altitude calibration advisor.
/// Only rendered when the active bike's fuelSystem == carburetor.
///
/// Altitude sources (in priority order):
///   1. GPS altitude via geolocator (requested on demand; falls back if denied).
///   2. Manual numeric entry field (always visible).
///
/// Baseline altitude and jetting specs are entered in "Jetting Log" and persisted
/// per bike through MaintenanceRepository.
///
/// All guidance text is labelled "Guidance only" and sourced from
/// [carburetor_guidance_table.dart] which carries visible TODO: verify markers.
class CarburetorTab extends StatefulWidget {
  const CarburetorTab({required this.bike, super.key});

  final Bike bike;

  @override
  State<CarburetorTab> createState() => _CarburetorTabState();
}

class _CarburetorTabState extends State<CarburetorTab> {
  // ── Manual altitude fields ────────────────────────────────────────────────
  final _currentAltController = TextEditingController();
  final _baselineAltController = TextEditingController();
  final _mainJetController = TextEditingController();
  final _pilotJetController = TextEditingController();
  final _needleClipController = TextEditingController();
  final _airScrewController = TextEditingController();

  String? _currentBikeId;

  /// GPS-sourced altitude (nullable — set when user taps "Use GPS").
  double? _gpsAltitude;

  /// True while GPS location is being fetched.
  bool _fetchingGps = false;

  /// Non-null if GPS failed — shown as a small info banner.
  String? _gpsError;

  // ── Computed values (derived from field contents) ─────────────────────────

  /// Current altitude in metres — GPS value takes precedence over manual.
  double? get _currentAltM {
    if (_gpsAltitude != null) return _gpsAltitude;
    return double.tryParse(_currentAltController.text.trim());
  }

  double? get _baselineAltM =>
      double.tryParse(_baselineAltController.text.trim());

  @override
  void initState() {
    super.initState();
    _currentBikeId = widget.bike.id;
    _loadForBike(widget.bike.id);
  }

  @override
  void didUpdateWidget(covariant CarburetorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bike.id != widget.bike.id) {
      _currentBikeId = widget.bike.id;
      _loadForBike(widget.bike.id);
    }
  }

  Future<void> _loadForBike(String? bikeId) async {
    _currentBikeId = bikeId;
    final repo = AppRepositories.instance.maintenanceRepository;
    final data = await repo.loadJettingBaseline(bikeId);
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _baselineAltController.text =
            data['baselineAltitude']?.toString() ?? '';
        _mainJetController.text = data['mainJet']?.toString() ?? '';
        _pilotJetController.text = data['pilotJet']?.toString() ?? '';
        _needleClipController.text = data['needleClip']?.toString() ?? '';
        _airScrewController.text = data['airScrew']?.toString() ?? '';
      });
    } else {
      setState(() {
        _baselineAltController.clear();
        _mainJetController.clear();
        _pilotJetController.clear();
        _needleClipController.clear();
        _airScrewController.clear();
      });
    }
  }

  Future<void> _saveBaseline() async {
    final repo = AppRepositories.instance.maintenanceRepository;
    await repo.saveJettingBaseline({
      'baselineAltitude': _baselineAltController.text.trim(),
      'mainJet': _mainJetController.text.trim(),
      'pilotJet': _pilotJetController.text.trim(),
      'needleClip': _needleClipController.text.trim(),
      'airScrew': _airScrewController.text.trim(),
    }, _currentBikeId);
  }

  @override
  void dispose() {
    _currentAltController.dispose();
    _baselineAltController.dispose();
    _mainJetController.dispose();
    _pilotJetController.dispose();
    _needleClipController.dispose();
    _airScrewController.dispose();
    super.dispose();
  }

  // ── GPS Fetch ─────────────────────────────────────────────────────────────
  Future<void> _fetchGpsAltitude() async {
    setState(() {
      _fetchingGps = true;
      _gpsError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _gpsError =
              'Location permission denied. Enter altitude manually below.';
          _fetchingGps = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _gpsAltitude = position.altitude;
        _currentAltController.text = position.altitude.toStringAsFixed(0);
        _fetchingGps = false;
      });
    } on LocationServiceDisabledException {
      setState(() {
        _gpsError =
            'Location services are off. Enable them or enter altitude manually.';
        _fetchingGps = false;
      });
    } catch (_) {
      setState(() {
        _gpsError =
            'GPS unavailable. Enter your current altitude manually below.';
        _fetchingGps = false;
      });
    }
  }

  void _clearGps() {
    setState(() {
      _gpsAltitude = null;
      _currentAltController.clear();
      _gpsError = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final carbModel = widget.bike.carburetorType ?? 'Keihin / Mikuni CVK';
    final carbType = parseCarbType(widget.bike.carburetorType);

    final currentAlt = _currentAltM;
    final baselineAlt = _baselineAltM;
    final hasBaseline = baselineAlt != null;
    final hasCurrentAlt = currentAlt != null;

    DensityBand? band;
    double? densityRatio;
    if (hasBaseline && hasCurrentAlt) {
      densityRatio = altitudeDensityRatio(currentAlt, baselineAlt);
      band = densityBand(densityRatio);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Spec Card ────────────────────────────────────────────────────
        CampCard(
          padding: const EdgeInsets.all(16),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 20, color: AppColors.tacticalOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CARBURETOR SPECIFICATION',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // "Guidance only" label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: Text(
                      'Guidance only',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Fitted Spec: $carbModel',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Software-based atmospheric jetting advisor using user-entered altitude and standard atmosphere density formula. No barometer or sensor is used.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedText,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 2. Jetting Log — Baseline Altitude & Jetting Setup ─────────────
        CampCard(
          padding: const EdgeInsets.all(16),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'JETTING LOG',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: Text(
                      'Guidance only',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Record your current carburetor jetting and baseline altitude where it was tuned. Settings are saved per motorcycle for reference and theoretical density calculations. Always check adjustments with a qualified mechanic.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkCharcoal,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'BASELINE ALTITUDE (m ASL)',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedText,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              InsetTile(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                borderRadius: AppColors.radiusTile,
                child: TextField(
                  controller: _baselineAltController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {
                    setState(() {});
                    _saveBaseline();
                  },
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 500',
                    hintStyle:
                        GoogleFonts.manrope(color: AppColors.mutedLight),
                    border: InputBorder.none,
                    suffixText: 'm ASL',
                    suffixStyle: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAIN JET',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InsetTile(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          borderRadius: AppColors.radiusTile,
                          child: TextField(
                            controller: _mainJetController,
                            onChanged: (_) => _saveBaseline(),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkCharcoal,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 115',
                              hintStyle: GoogleFonts.manrope(
                                  color: AppColors.mutedLight),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PILOT / SLOW JET',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InsetTile(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          borderRadius: AppColors.radiusTile,
                          child: TextField(
                            controller: _pilotJetController,
                            onChanged: (_) => _saveBaseline(),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkCharcoal,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 38',
                              hintStyle: GoogleFonts.manrope(
                                  color: AppColors.mutedLight),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEEDLE CLIP POSITION',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InsetTile(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          borderRadius: AppColors.radiusTile,
                          child: TextField(
                            controller: _needleClipController,
                            onChanged: (_) => _saveBaseline(),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkCharcoal,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 3rd from top',
                              hintStyle: GoogleFonts.manrope(
                                  color: AppColors.mutedLight),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AIR / FUEL SCREW',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InsetTile(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          borderRadius: AppColors.radiusTile,
                          child: TextField(
                            controller: _airScrewController,
                            onChanged: (_) => _saveBaseline(),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkCharcoal,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 1.75 turns out',
                              hintStyle: GoogleFonts.manrope(
                                  color: AppColors.mutedLight),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 3. Current Altitude — GPS or Manual ────────────────────────────
        CampCard(
          padding: const EdgeInsets.all(16),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CURRENT ALTITUDE',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // GPS status badge
                  if (_gpsAltitude != null)
                    GestureDetector(
                      onTap: _clearGps,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(AppColors.radiusPill),
                        ),
                        child: Text(
                          'GPS • tap to clear',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.clayDark,
                        borderRadius: BorderRadius.circular(AppColors.radiusPill),
                      ),
                      child: Text(
                        'Manual entry',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your current altitude, or tap "Use GPS" to read it from your phone\'s location.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkCharcoal,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // GPS error banner
              if (_gpsError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF92400E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _gpsError!,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Manual entry field
              InsetTile(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                borderRadius: AppColors.radiusTile,
                child: TextField(
                  controller: _currentAltController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: _gpsAltitude == null, // lock field when GPS is active
                  onChanged: (_) => setState(() {
                    _gpsAltitude = null; // manual entry clears GPS override
                  }),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 2800',
                    hintStyle: GoogleFonts.manrope(color: AppColors.mutedLight),
                    border: InputBorder.none,
                    suffixText: 'm ASL',
                    suffixStyle: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Use GPS button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _fetchingGps ? null : _fetchGpsAltitude,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.clayDark,
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    boxShadow: AppColors.skeuRaisedSmall,
                    border: Border.all(
                      color: AppColors.tacticalOrange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_fetchingGps)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.tacticalOrangeDark,
                          ),
                        )
                      else
                        const Icon(Icons.gps_fixed_rounded, size: 16, color: AppColors.tacticalOrangeDark),
                      const SizedBox(width: 8),
                      Text(
                        _fetchingGps ? 'Fetching GPS...' : 'Use GPS Altitude',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tacticalOrangeDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 4. Guidance Result ─────────────────────────────────────────────
        if (!hasBaseline)
          _buildBaselineEmptyState()
        else if (!hasCurrentAlt)
          _buildCurrentAltEmptyState()
        else
          _buildGuidanceCard(band!, densityRatio!, carbType),
      ],
    );
  }

  // ── Empty States ──────────────────────────────────────────────────────────
  Widget _buildBaselineEmptyState() {
    return CampCard(
      padding: const EdgeInsets.all(18),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaisedSmall,
      child: Column(
        children: [
          const Icon(Icons.landscape_rounded, size: 36, color: AppColors.mutedLight),
          const SizedBox(height: 10),
          Text(
            'Set your baseline altitude first.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the altitude (metres) where your current jetting was set up in the Jetting Log above.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentAltEmptyState() {
    return CampCard(
      padding: const EdgeInsets.all(18),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaisedSmall,
      child: Column(
        children: [
          const Icon(Icons.location_searching_rounded, size: 36, color: AppColors.mutedLight),
          const SizedBox(height: 10),
          Text(
            'Enter your current altitude.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Type a value in metres or tap "Use GPS Altitude" above.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  // ── Guidance Result Card ──────────────────────────────────────────────────
  Widget _buildGuidanceCard(DensityBand band, double densityRatio, CarbType carbType) {
    final densityChangePercent = ((1.0 - densityRatio) * 100).abs().toStringAsFixed(1);
    final isDenserThanBaseline = densityRatio > 1.0;
    final isLeanBeyondMinimal = isDenserThanBaseline && band != DensityBand.minimal;

    final Color bandColor;
    final String bandLabel;
    switch (band) {
      case DensityBand.minimal:
        bandColor = AppColors.statusGreen;
        bandLabel = 'Minimal change (< 5%)';
        break;
      case DensityBand.slight:
        bandColor = AppColors.tacticalOrange;
        bandLabel = isDenserThanBaseline ? 'Slight lean condition (5–10%)' : 'Slight rich condition (5–10%)';
        break;
      case DensityBand.noticeable:
        bandColor = AppColors.tacticalOrangeDark;
        bandLabel = isDenserThanBaseline ? 'Noticeable lean risk (10–20%)' : 'Noticeable rich condition (10–20%)';
        break;
      case DensityBand.significant:
        bandColor = const Color(0xFFDC2626);
        bandLabel = isDenserThanBaseline ? 'Severe lean risk (> 20%)' : 'Significant rich condition (> 20%)';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Prominent Lean-Risk Warning (when ratio > 1 beyond 5%) ───────
        if (isLeanBeyondMinimal) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.dangerous_rounded, size: 20, color: Color(0xFF991B1B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leanRunningRiskWarning,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Return-to-baseline warning — always visible on every recommendation
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFF92400E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  returnToBaselineWarning,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Density ratio summary ─────────────────────────────────────────
        CampCard(
          padding: const EdgeInsets.all(16),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.compress_rounded, size: 18, color: AppColors.tacticalOrange),
                  const SizedBox(width: 8),
                  Text(
                    'AIR DENSITY RATIO',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    densityRatio.toStringAsFixed(3),
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: Text(
                      bandLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: bandColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isDenserThanBaseline
                    ? 'Current altitude is lower than baseline — air is $densityChangePercent% denser. '
                        'Mixture will run leaner; revert to baseline jetting.'
                    : 'Current altitude is $densityChangePercent% lower air density than baseline. '
                        'Mixture will run richer; see guidance below.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkCharcoal,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Formula: density(h) = (1 − 2.25577×10⁻⁵ · h)^4.25588  ·  US Standard Atmosphere 1976',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Jetting recommendation text ───────────────────────────────────
        CampCard(
          padding: const EdgeInsets.all(16),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded, size: 18, color: AppColors.tacticalOrange),
                  const SizedBox(width: 8),
                  Text(
                    'JETTING RECOMMENDATION',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: Text(
                      'Guidance only',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InsetTile(
                padding: const EdgeInsets.all(14),
                borderRadius: AppColors.radiusTile,
                child: Text(
                  jetingGuidanceText(band, carbType, densityRatio: densityRatio),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkCharcoal,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
