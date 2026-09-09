import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable full-screen and dialog viewer for user-uploaded hazard/evidence photos.
///
/// Features:
/// - Dark neutral backdrop (modal dialog)
/// - [InteractiveViewer] supporting smooth pinch-to-zoom (1.0x to 5.0x) and panning
/// - Double-tap to zoom in / reset zoom
/// - Reset zoom action button in toolbar
/// - Prominent, accessible Close button (minimum 48x48 tap target)
/// - Dismissible via <kbd>Escape</kbd> key, Android system back, and barrier tap
/// - Safe error and loading placeholders
class SafetyImageViewer extends StatefulWidget {
  const SafetyImageViewer({
    super.key,
    required this.imageProvider,
    this.title = 'Hazard Evidence',
    this.subtitle,
  });

  final ImageProvider imageProvider;
  final String title;
  final String? subtitle;

  /// Opens the image viewer modal dialog for the given [ImageProvider].
  static Future<void> show(
    BuildContext context, {
    required ImageProvider imageProvider,
    String title = 'Hazard Evidence',
    String? subtitle,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(235),
      barrierDismissible: true,
      builder: (dialogContext) => SafetyImageViewer(
        imageProvider: imageProvider,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  /// Convenience method to open the viewer using raw [Uint8List] bytes.
  static Future<void> showBytes(
    BuildContext context, {
    required Uint8List bytes,
    String title = 'Hazard Evidence',
    String? subtitle,
  }) {
    return show(
      context,
      imageProvider: MemoryImage(bytes),
      title: title,
      subtitle: subtitle,
    );
  }

  /// Convenience method to open the viewer using a network URL.
  static Future<void> showNetwork(
    BuildContext context, {
    required String url,
    String title = 'Hazard Evidence',
    String? subtitle,
  }) {
    return show(
      context,
      imageProvider: NetworkImage(url),
      title: title,
      subtitle: subtitle,
    );
  }

  @override
  State<SafetyImageViewer> createState() => _SafetyImageViewerState();
}

class _SafetyImageViewerState extends State<SafetyImageViewer> {
  final TransformationController _transformController =
      TransformationController();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_handleTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final zoomed = (scale - 1.0).abs() > 0.05;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _resetZoom();
    } else {
      _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 768;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                // Centered Interactive Image Canvas
                Positioned.fill(
                  child: GestureDetector(
                    onDoubleTap: _handleDoubleTap,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 5.0,
                        clipBehavior: Clip.none,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop
                                ? mediaQuery.size.width * 0.88
                                : mediaQuery.size.width,
                            maxHeight: isDesktop
                                ? mediaQuery.size.height * 0.82
                                : mediaQuery.size.height * 0.80,
                          ),
                          child: Image(
                            image: widget.imageProvider,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white70,
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Evidence image could not be loaded.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Toolbar / Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        // Title and optional subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (widget.subtitle != null &&
                                  widget.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Zoom Reset Action (visible when zoomed)
                        if (_isZoomed)
                          Semantics(
                            button: true,
                            label: 'Reset zoom to original size',
                            child: IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: 'Reset zoom',
                              icon: const Icon(
                                Icons.zoom_out_map_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _resetZoom,
                            ),
                          ),

                        const SizedBox(width: 8),

                        // Close Button with minimum 48x48 accessible touch target
                        Semantics(
                          button: true,
                          label: 'Close image viewer',
                          child: IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            tooltip: 'Close image viewer',
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Hint Banner (pan/zoom instructions)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            kIsWeb || isDesktop
                                ? Icons.mouse_outlined
                                : Icons.pinch_outlined,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            kIsWeb || isDesktop
                                ? 'Scroll to zoom • Drag to pan • Esc to close'
                                : 'Pinch to zoom • Drag to pan • Double-tap to reset',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable wrapper that adds tap-to-enlarge behavior and visual affordances
/// to any evidence image preview or thumbnail.
class ExpandableEvidenceImage extends StatelessWidget {
  const ExpandableEvidenceImage({
    super.key,
    required this.child,
    required this.imageProvider,
    this.title = 'Hazard Evidence',
    this.subtitle,
    this.enabled = true,
    this.showAffordance = true,
    this.affordanceAlignment = Alignment.bottomRight,
    this.tooltip = 'Click to enlarge photo',
    this.heroTag,
  });

  final Widget child;
  final ImageProvider imageProvider;
  final String title;
  final String? subtitle;
  final bool enabled;
  final bool showAffordance;
  final Alignment affordanceAlignment;
  final String tooltip;
  final Object? heroTag;

  void _handleTap(BuildContext context) {
    if (!enabled) return;
    SafetyImageViewer.show(
      context,
      imageProvider: imageProvider,
      title: title,
      subtitle: subtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _handleTap(context),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                child,
                if (showAffordance)
                  Positioned.fill(
                    child: Align(
                      alignment: affordanceAlignment,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Enlarge',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
