import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../dashboard/controllers/profile_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../domain/geocoding_service.dart';

/// Top search bar with mic icon, profile monogram avatar, and search suggestions overlay
/// displaying Recent and Saved places. Search only executes on submit.
class NavSearchBar extends StatefulWidget {
  const NavSearchBar({
    required this.controller,
    required this.onOpenProfile,
    this.onSelectPlace,
    super.key,
  });

  final NavigationController controller;
  final VoidCallback onOpenProfile;
  final ValueChanged<PlaceSearchResult>? onSelectPlace;

  @override
  State<NavSearchBar> createState() => _NavSearchBarState();
}

/// State for [NavSearchBar].
///
/// Search runs only on explicit submit (keyboard search key or the search
/// icon) because Nominatim forbids autocomplete. The results panel is driven
/// by [NavigationController.searchStatus] and stays visible after the keyboard
/// closes: the keyboard search action unfocuses the field, so tying the panel
/// to focus would hide the very results the rider just asked for.
class _NavSearchBarState extends State<NavSearchBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Submits the current text as a search (keyboard search key or icon tap).
  void _handleSubmitted(String query) {
    if (query.trim().isEmpty) return;
    widget.controller.submitSearch(query);
  }

  /// Clears the field and any search results/errors.
  void _clearSearch() {
    _textController.clear();
    widget.controller.clearSearch();
  }

  void _selectPlace(PlaceSearchResult place) {
    _textController.text = place.name;
    _focusNode.unfocus();
    widget.controller.clearSearch();
    setState(() {
      _isFocused = false;
    });

    if (widget.onSelectPlace != null) {
      widget.onSelectPlace!(place);
    } else {
      widget.controller.openRoutePreview(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on search status changes and on every text edit (clear button,
    // empty-field panel).
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _textController]),
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final status = widget.controller.searchStatus;
    final fieldEmpty = _textController.text.trim().isEmpty;
    final showPanel = _isFocused || status != PlaceSearchStatus.idle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main Search Bar Pill ─────────────────────────────────────────────
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              // Search icon: tapping it submits the search like the keyboard key.
              IconButton(
                tooltip: 'Search',
                icon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.mutedText,
                  size: 22,
                ),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _handleSubmitted,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.darkCharcoal,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search here',
                    hintStyle: TextStyle(
                      color: AppColors.mutedLight,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.mutedLight,
                  onPressed: _clearSearch,
                ),
              // Mic Icon (Voice Copilot placeholder)
              IconButton(
                icon: const Icon(
                  Icons.mic_none_rounded,
                  color: AppColors.mutedText,
                  size: 22,
                ),
                onPressed: () {
                  // TODO: Connect speech-to-text package when configured
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voice input coming soon'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              // Profile Avatar
              GestureDetector(
                onTap: widget.onOpenProfile,
                child: ListenableBuilder(
                  listenable: ProfileController.instance,
                  builder: (context, _) {
                    final profile = ProfileController.instance;
                    final firstName = profile.firstName;
                    final initial = firstName.isNotEmpty
                        ? firstName[0].toUpperCase()
                        : (profile.fullName.isNotEmpty
                              ? profile.fullName[0].toUpperCase()
                              : '');

                    Widget avatarChild;
                    if (profile.avatarPath != null &&
                        profile.avatarPath!.isNotEmpty) {
                      final file = File(profile.avatarPath!);
                      if (file.existsSync()) {
                        avatarChild = ClipOval(
                          child: Image.file(
                            file,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                          ),
                        );
                      } else {
                        avatarChild = initial.isNotEmpty
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  color: AppColors.tacticalOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              )
                            : const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.tacticalOrange,
                                size: 20,
                              );
                      }
                    } else if (initial.isNotEmpty) {
                      avatarChild = Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.tacticalOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      );
                    } else {
                      avatarChild = const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.tacticalOrange,
                        size: 20,
                      );
                    }

                    return Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF141416),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: avatarChild,
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Dropdown Overlay for Suggestions, Recents & Saved Places ─────────
        if (showPanel) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              // Transparent Material so the ListTiles' ink/splash can paint
              // above the white DecoratedBox instead of being hidden by it.
              child: Material(
                color: Colors.transparent,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  children: [
                    if (status == PlaceSearchStatus.loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (status == PlaceSearchStatus.results) ...[
                      _buildSectionHeader('SEARCH RESULTS'),
                      ...widget.controller.searchResults.map(_buildPlaceTile),
                    ] else if (status == PlaceSearchStatus.empty)
                      _buildMessage(
                        'No results. Try a different spelling or add the city.',
                      )
                    else if (status == PlaceSearchStatus.failed)
                      _buildMessage(
                        "Couldn't search. Check your internet connection.",
                      )
                    else ...[
                      if (widget.controller.savedPlaces.isNotEmpty) ...[
                        _buildSectionHeader('SAVED PLACES'),
                        ...widget.controller.savedPlaces.map(_buildPlaceTile),
                      ],
                      if (widget.controller.recentPlaces.isNotEmpty) ...[
                        _buildSectionHeader('RECENT SEARCHES'),
                        ...widget.controller.recentPlaces.map(_buildPlaceTile),
                      ],
                      // Only when the field is empty and no search is running.
                      if (fieldEmpty &&
                          widget.controller.savedPlaces.isEmpty &&
                          widget.controller.recentPlaces.isEmpty)
                        _buildMessage('No saved places or recent searches'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Centered grey status line inside the dropdown (empty / error states).
  Widget _buildMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedLight,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppColors.mutedLight,
        ),
      ),
    );
  }

  Widget _buildPlaceTile(PlaceSearchResult place) {
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.place_outlined,
        color: AppColors.tacticalOrange,
        size: 20,
      ),
      title: Text(
        place.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.darkCharcoal,
        ),
      ),
      // Short address line (area, city) instead of the full display name.
      subtitle: place.shortAddress.isEmpty
          ? null
          : Text(
              place.shortAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
      onTap: () => _selectPlace(place),
    );
  }
}
