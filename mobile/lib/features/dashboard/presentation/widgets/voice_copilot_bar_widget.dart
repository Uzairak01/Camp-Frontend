import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/skeuomorphic_container.dart';

/// Voice Copilot Bar — recessed inset surface with glowing orange AI button.
class VoiceCopilotBarWidget extends StatefulWidget {
  const VoiceCopilotBarWidget({
    super.key,
    this.onSubmitted,
    this.onVoicePressed,
    this.onAiPressed,
  });

  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onVoicePressed;
  final VoidCallback? onAiPressed;

  @override
  State<VoiceCopilotBarWidget> createState() => _VoiceCopilotBarWidgetState();
}

class _VoiceCopilotBarWidgetState extends State<VoiceCopilotBarWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SkeuomorphicContainer(
      borderRadius: 32,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          // ── Left: Raised mic button ──────────────────────────────────────
          _VoiceMicButton(onTap: widget.onVoicePressed),

          const SizedBox(width: 8),

          // ── Middle: Recessed input field ──────────────────────────────────
          Expanded(
            child: _CopilotInputField(
              controller: _controller,
              onSubmitted: widget.onSubmitted,
            ),
          ),

          const SizedBox(width: 8),

          // ── Right: Glowing extruded orange AI button ──────────────────────
          SkeuomorphicOrangeIconButton(
            icon: Icons.smart_toy_rounded,
            size: 44,
            onTap: widget.onAiPressed,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SUB-WIDGETS (Extracted for readability, performance, and clean syntax)
// =============================================================================

class _VoiceMicButton extends StatelessWidget {
  const _VoiceMicButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SkeuomorphicContainer(
        borderRadius: 100,
        shadows: AppColors.skeuRaisedSmall,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Icon(
              Icons.mic_none_rounded,
              color: AppColors.terracotta,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _CopilotInputField extends StatelessWidget {
  const _CopilotInputField({
    required this.controller,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  static const _textStyle = TextStyle(
    color: AppColors.darkCharcoal,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const _hintStyle = TextStyle(
    color: Color(0xFF7A7570),
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
  );

  static const _inputDecoration = InputDecoration(
    hintText: 'Ask about fuel, service, or mechanics...',
    hintStyle: _hintStyle,
    border: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );

  @override
  Widget build(BuildContext context) {
    return SkeuomorphicInsetContainer(
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: _textStyle,
        decoration: _inputDecoration,
      ),
    );
  }
}
