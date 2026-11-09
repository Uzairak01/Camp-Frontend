import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/image_storage_helper.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../controllers/bike_onboarding_controller.dart';
import '../../domain/camera_permission_service.dart';
import '../../utils/gallery_picker_helper.dart';
import 'bike_details_screen.dart';

/// Distinct failure and permission states for the camera screen.
enum CameraScreenErrorState {
  /// No error; camera is active or initializing.
  none,

  /// Camera permission was denied; user can be prompted to grant permission.
  permissionDenied,

  /// Camera permission was permanently denied; user must open device settings.
  permissionPermanentlyDenied,

  /// No camera hardware found on the device.
  noCameraHardware,

  /// Camera hardware is available and permission is granted, but starting failed.
  initializationError,
}

/// CAMP Bike Photo Screen — camera flow that connects to the Bike Details form.
///
/// Accepts:
///   [imagePath] — optional, starts in "photo taken" state with a gallery image.
///   [cameraAvailable] — injectable for widget tests (defaults to runtime detection).
///   [camerasFetcher] — injectable camera loader for widget tests (e.g. slow-start testing).
///   [cameraController] — injectable camera controller for widget tests.
///   [permissionService] — injectable camera permission service for tests.
///   [controllerCreator] — injectable controller factory for testing initialization failures.
class BikeScanScreen extends StatefulWidget {
  const BikeScanScreen({
    super.key,
    this.imagePath,
    this.cameraAvailable,
    this.camerasFetcher,
    this.cameraController,
    this.permissionService,
    this.controllerCreator,
  });

  final String? imagePath;

  /// Override camera availability (true = has camera, false = no camera, null = autodetect).
  final bool? cameraAvailable;

  /// Override availableCameras lookup for tests.
  final Future<List<CameraDescription>> Function()? camerasFetcher;

  /// Injected camera controller (e.g. for tests).
  final CameraController? cameraController;

  /// Injected camera permission service (e.g. for tests).
  final CameraPermissionService? permissionService;

  /// Injected controller creator (e.g. to simulate controller.initialize() errors).
  final CameraController Function(CameraDescription description)? controllerCreator;

  @override
  State<BikeScanScreen> createState() => _BikeScanScreenState();
}

class _BikeScanScreenState extends State<BikeScanScreen>
    with WidgetsBindingObserver {
  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraLoading = true;
  CameraScreenErrorState _errorState = CameraScreenErrorState.none;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  List<CameraDescription> _cameras = [];

  late final CameraPermissionService _permissionService;

  // ── Screen state ──────────────────────────────────────────────────────────
  String? _capturedImagePath;
  bool get _hasPhoto => _capturedImagePath != null;

  bool _cameraDepsInitialized = false;

  @override
  void initState() {
    super.initState();
    _permissionService =
        widget.permissionService ?? const MethodChannelCameraPermissionService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cameraDepsInitialized) {
      _cameraDepsInitialized = true;
      // If a pre-selected image was passed in, skip the live camera.
      final initPath = widget.imagePath ??
          (ModalRoute.of(context)?.settings.arguments is String
              ? ModalRoute.of(context)!.settings.arguments as String
              : null);
      if (initPath != null && initPath.isNotEmpty) {
        _capturedImagePath = initPath;
        _isCameraLoading = false;
      } else {
        _checkPermissionAndInitialize();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Directly dispose the controller without setState — the element is
    // already being unmounted and calling setState would assert-fail.
    final c = _cameraController;
    _cameraController = null;
    if (widget.cameraController == null) {
      c?.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed && !_hasPhoto) {
      // When resuming from background or settings, re-check permission and start camera
      // automatically if permission was granted.
      _checkPermissionAndInitialize();
    }
  }

  // ── Camera helpers ────────────────────────────────────────────────────────

  void _disposeCamera() {
    final c = _cameraController;
    _cameraController = null;
    if (widget.cameraController == null) {
      c?.dispose();
    }
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        _isCameraLoading = false;
      });
    } else {
      _isCameraInitialized = false;
      _isCameraLoading = false;
    }
  }

  /// Explicitly requests camera permission before controller initialization,
  /// awaiting the result so the live camera starts immediately upon granting.
  Future<void> _checkPermissionAndInitialize() async {
    if (!mounted) return;
    setState(() {
      _isCameraLoading = true;
      _isCameraInitialized = false;
      _errorState = CameraScreenErrorState.none;
    });

    // Respect the injected override (useful for tests).
    if (widget.cameraAvailable == false) {
      if (!mounted) return;
      setState(() {
        _isCameraLoading = false;
        _errorState = CameraScreenErrorState.noCameraHardware;
      });
      return;
    }

    final currentPermission = await _permissionService.checkPermission();
    if (!mounted) return;

    if (currentPermission == CameraPermissionStatus.denied) {
      // First-time or not yet granted: request permission explicitly before initializing
      final requestedStatus = await _permissionService.requestPermission();
      if (!mounted) return;

      if (requestedStatus == CameraPermissionStatus.denied) {
        setState(() {
          _isCameraLoading = false;
          _errorState = CameraScreenErrorState.permissionDenied;
        });
        return;
      } else if (requestedStatus == CameraPermissionStatus.permanentlyDenied) {
        setState(() {
          _isCameraLoading = false;
          _errorState = CameraScreenErrorState.permissionPermanentlyDenied;
        });
        return;
      }
      // If granted, proceed to start camera immediately!
    } else if (currentPermission == CameraPermissionStatus.permanentlyDenied) {
      setState(() {
        _isCameraLoading = false;
        _errorState = CameraScreenErrorState.permissionPermanentlyDenied;
      });
      return;
    }

    // Permission is granted; query hardware and start camera controller.
    await _startCamera();
  }

  /// Queries available camera hardware and creates the controller.
  Future<void> _startCamera() async {
    if (!mounted) return;
    setState(() {
      _isCameraLoading = true;
      _errorState = CameraScreenErrorState.none;
    });

    try {
      List<CameraDescription> cameras;
      try {
        cameras = await (widget.camerasFetcher != null
                ? widget.camerasFetcher!()
                : availableCameras())
            .timeout(
          const Duration(seconds: 8),
        );
      } on MissingPluginException {
        throw Exception('camera_plugin_unavailable');
      }

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isCameraLoading = false;
          _errorState = CameraScreenErrorState.noCameraHardware;
        });
        return;
      }

      _cameras = cameras;

      final desc = _cameras.firstWhere(
        (c) => c.lensDirection ==
            (_isFrontCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => _cameras.first,
      );

      await _disposeAndCreateController(desc);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCameraLoading = false;
        _errorState = CameraScreenErrorState.initializationError;
      });
    }
  }

  Future<void> _disposeAndCreateController(CameraDescription desc) async {
    final old = _cameraController;
    _cameraController = null;
    if (widget.cameraController == null) {
      await old?.dispose();
    }

    if (!mounted) return;

    final controller = widget.cameraController ??
        (widget.controllerCreator != null
            ? widget.controllerCreator!(desc)
            : CameraController(
                desc,
                ResolutionPreset.high,
                enableAudio: false,
              ));
    _cameraController = controller;

    try {
      if (!controller.value.isInitialized) {
        await controller.initialize().timeout(
          const Duration(seconds: 8),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCameraLoading = false;
        _errorState = CameraScreenErrorState.initializationError;
      });
      return;
    }

    if (!mounted) {
      if (widget.cameraController == null) {
        await controller.dispose();
      }
      return;
    }
    setState(() {
      _isCameraInitialized = true;
      _isCameraLoading = false;
      _errorState = CameraScreenErrorState.none;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _startCamera();
  }

  Future<void> _toggleFlash() async {
    final c = _cameraController;
    if (c != null && c.value.isInitialized) {
      try {
        await c.setFlashMode(_isFlashOn ? FlashMode.off : FlashMode.torch);
      } catch (_) {
        // Ignore on emulators.
      }
    }
    if (!mounted) return;
    setState(() => _isFlashOn = !_isFlashOn);
  }

  // ── Shutter ───────────────────────────────────────────────────────────────

  Future<void> _takePicture() async {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;
    HapticFeedback.mediumImpact();
    try {
      final xFile = await c.takePicture();
      if (!mounted) return;
      final savedPath = await persistBikePhoto(xFile.path);
      setState(() {
        _capturedImagePath = savedPath;
      });
    } catch (_) {
      // Ignore capture errors silently.
    }
  }

  void _retake() {
    setState(() {
      _capturedImagePath = null;
    });
    if (!_isCameraInitialized) {
      _checkPermissionAndInitialize();
    }
  }

  // ── Gallery ───────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final image = await GalleryPickerHelper.pickImageFromGallery(
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.darkCharcoal,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 2200),
          ),
        );
      },
    );
    if (image == null || !mounted) return;
    final savedPath = await persistBikePhoto(image.path);
    setState(() {
      _capturedImagePath = savedPath;
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openBikeDetails() {
    final controller = BikeOnboardingController.instance;
    // Save the captured photo path.
    controller.setImagePath(_capturedImagePath);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const BikeDetailsScreen(
          prefilled: false,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background / Camera / Image ─────────────────────────────────
            _buildBackground(),

            // ── Top overlay ─────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildTopBar(),
                ),
              ),
            ),

            // ── Bottom overlay ───────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: _buildBottomControls(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    if (_capturedImagePath != null) {
      return Image.file(
        File(_capturedImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (_isCameraInitialized && _cameraController != null) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1,
            height: _cameraController!.value.previewSize?.width ?? 1,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }
    if (_isCameraLoading) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.tacticalOrange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Starting camera…',
                style: GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // No camera / error / permission denied.
    return const ColoredBox(color: Colors.black);
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        _glassButton(
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 20),
          onTap: () => Navigator.of(context).maybePop(),
        ),

        // Center pill
        _buildPill(
          label: _hasPhoto ? 'PHOTO TAKEN' : 'PHOTO',
          active: _hasPhoto,
        ),

        // Flash toggle (only in live camera mode)
        if (!_hasPhoto)
          _glassButton(
            child: Icon(
              _isFlashOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: _isFlashOn ? AppColors.tacticalOrangeLight : Colors.white,
              size: 20,
            ),
            onTap: _toggleFlash,
          )
        else
          const SizedBox(width: 44, height: 44),
      ],
    );
  }

  Widget _buildPill({required String label, bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.tacticalOrangeLight
                  : AppColors.tacticalOrange,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.50),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Bottom Controls ───────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    if (_errorState != CameraScreenErrorState.none && !_hasPhoto) {
      return _buildNoCameraControls();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Gallery button
        _galleryButton(),

        // Center: Shutter / Retake
        _hasPhoto ? _retakeButton() : _shutterButton(),

        // Right: flip camera (live) or Add Details (photo taken)
        _hasPhoto
            ? _addDetailsButton()
            : _flipCameraButton(),
      ],
    );
  }

  /// Builds state-specific error controls:
  /// (a) permission denied: "Camera permission is needed to scan" with "Grant permission",
  ///     or "Open app settings" when permanently denied.
  /// (b) no camera hardware: "Camera unavailable on this device."
  /// (c) initialization failure: "Couldn't start the camera. Try again" with "Retry".
  /// "Enter details manually" and the gallery button stay present in every state.
  Widget _buildNoCameraControls() {
    String message;
    Widget? actionButton;

    switch (_errorState) {
      case CameraScreenErrorState.permissionDenied:
        message = 'Camera permission is needed to scan';
        actionButton = PrimaryButton(
          label: 'Grant permission',
          icon: Icons.camera_alt_rounded,
          onTap: () async {
            final status = await _permissionService.requestPermission();
            if (!mounted) return;
            if (status == CameraPermissionStatus.granted) {
              await _startCamera();
            } else if (status == CameraPermissionStatus.permanentlyDenied) {
              setState(() {
                _errorState = CameraScreenErrorState.permissionPermanentlyDenied;
              });
            }
          },
        );
        break;
      case CameraScreenErrorState.permissionPermanentlyDenied:
        message = 'Camera permission is needed to scan';
        actionButton = PrimaryButton(
          label: 'Open app settings',
          icon: Icons.settings_rounded,
          onTap: () => _permissionService.openAppSettings(),
        );
        break;
      case CameraScreenErrorState.initializationError:
        message = "Couldn't start the camera. Try again";
        actionButton = PrimaryButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          onTap: () => _checkPermissionAndInitialize(),
        );
        break;
      case CameraScreenErrorState.noCameraHardware:
      case CameraScreenErrorState.none:
        message = 'Camera unavailable on this device.';
        actionButton = null;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (actionButton != null) ...[
          const SizedBox(height: 16),
          actionButton,
        ],
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            BikeOnboardingController.instance.setImagePath(null);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BikeDetailsScreen(prefilled: false),
              ),
            );
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: Text(
              'Enter details manually',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Gallery button stays accessible across all error and permission states.
        _galleryButton(),
      ],
    );
  }

  Widget _galleryButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickFromGallery,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.20), width: 1.5),
        ),
        child: const Center(
          child: Icon(Icons.photo_library_rounded,
              color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _shutterButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _takePicture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }

  Widget _retakeButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _retake,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.55),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Retake',
            style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _flipCameraButton() {
    return _glassButton(
      child: const Icon(Icons.flip_camera_android_rounded,
          color: Colors.white, size: 22),
      onTap: _cameras.length >= 2 ? _flipCamera : () {},
    );
  }

  Widget _addDetailsButton() {
    return PrimaryButton(
      label: 'Add Details',
      icon: Icons.arrow_forward_rounded,
      onTap: _openBikeDetails,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    );
  }
}
