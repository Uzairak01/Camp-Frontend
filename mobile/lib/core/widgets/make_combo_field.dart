import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../constants/bike_makes.dart';

/// A combo-box field for motorcycle Make / Manufacturer.
///
/// - Shows an editable [TextField] styled like [LabeledTextField].
/// - Displays a floating suggestions list while typing (or on empty-focus).
/// - Tapping a suggestion fills the field with the canonical spelling.
/// - Any free-form text is accepted; on submit/unfocus it is stored
///   through [onChanged] via [canonicaliseMake].
/// - Validation: required, 2–30 chars after trim.
class MakeComboField extends StatefulWidget {
  const MakeComboField({
    required this.initialValue,
    required this.onChanged,
    super.key,
    this.isError = false,
    this.errorText,
    this.rightLabelWidget,
    this.onUserEdited,
  });

  /// The current make value (used to initialize the text field on first build).
  final String initialValue;

  /// Called whenever the canonical make string changes.
  final ValueChanged<String> onChanged;

  /// Whether to show the error border / text.
  final bool isError;

  /// Optional inline error text shown below the field.
  final String? errorText;

  /// Optional widget shown on the right side of the label row (e.g. Auto-filled chip).
  final Widget? rightLabelWidget;

  /// Called the first time the user edits the field (used to dismiss Auto-filled chips).
  final VoidCallback? onUserEdited;

  @override
  State<MakeComboField> createState() => _MakeComboFieldState();
}

class _MakeComboFieldState extends State<MakeComboField> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  bool _userHasEdited = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  // ── Suggestion filtering ────────────────────────────────────────────────────

  List<String> _filterSuggestions(String query) {
    if (query.trim().isEmpty) return kCanonicalBikeMakes;
    final lower = query.toLowerCase();
    return kCanonicalBikeMakes
        .where((m) => m.toLowerCase().contains(lower))
        .toList();
  }

  // ── Overlay management ──────────────────────────────────────────────────────

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(_textController.text);
    } else {
      // Commit canonical value on blur.
      final canonical = canonicaliseMake(_textController.text);
      if (canonical != _textController.text) {
        _textController.text = canonical;
      }
      widget.onChanged(canonical);
      _removeOverlay();
    }
  }

  void _updateSuggestions(String query) {
    final filtered = _filterSuggestions(query);
    setState(() => _suggestions = filtered);
    if (filtered.isEmpty) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(String make) {
    _textController.text = make;
    widget.onChanged(make);
    _removeOverlay();
    _focusNode.unfocus();
  }

  // ── Overlay widget ──────────────────────────────────────────────────────────

  Widget _buildOverlay() {
    return Positioned(
      width: 0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 48), // below the field (field height ≈ 48)
        child: Material(
          color: Colors.transparent,
          child: _SuggestionsOverlay(
            suggestions: _suggestions,
            onSelect: _selectSuggestion,
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isError
        ? AppColors.alertRed
        : Colors.white.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Text('Make / Manufacturer', style: AppTextStyles.overline),
            const Spacer(),
            if (widget.rightLabelWidget != null) widget.rightLabelWidget!,
          ],
        ),
        const SizedBox(height: 5),

        // Field
        CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: AppColors.skeuRecessed,
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: AppTextStyles.body,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Honda, United, TVS',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.mutedLight,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: InputBorder.none,
                suffixIcon: const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.mutedLight,
                    size: 20,
                  ),
                ),
              ),
              onChanged: (val) {
                if (!_userHasEdited) {
                  _userHasEdited = true;
                  widget.onUserEdited?.call();
                }
                _updateSuggestions(val);
                // Notify immediately with trimmed (not yet canonicalised) value
                // so the controller stays in sync while typing.
                widget.onChanged(val.trim());
              },
              onSubmitted: (val) {
                final canonical = canonicaliseMake(val);
                _textController.text = canonical;
                widget.onChanged(canonical);
                _removeOverlay();
              },
            ),
          ),
        ),

        // Error text
        if (widget.isError && widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.alertRed,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Suggestions list widget ─────────────────────────────────────────────────

class _SuggestionsOverlay extends StatelessWidget {
  const _SuggestionsOverlay({
    required this.suggestions,
    required this.onSelect,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Clamp height: show up to 6 items before scrolling.
    const itemHeight = 44.0;
    final listHeight = (suggestions.length * itemHeight).clamp(0.0, itemHeight * 6);

    return Container(
      constraints: BoxConstraints(maxHeight: listHeight),
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final make = suggestions[index];
            return InkWell(
              onTap: () => onSelect(make),
              child: Container(
                height: itemHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: index < suggestions.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        )
                      : null,
                ),
                child: Text(make, style: AppTextStyles.body),
              ),
            );
          },
        ),
      ),
    );
  }
}
