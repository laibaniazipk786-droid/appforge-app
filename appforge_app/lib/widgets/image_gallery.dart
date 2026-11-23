import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Full-screen product photos: swipe between images, pinch or double-tap to zoom.
class ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ImageGalleryScreen({super.key, required this.images, this.initialIndex = 0});

  static Future<void> open(BuildContext context, List<String> images, int index) {
    final list = images.where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return Future.value();
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => ImageGalleryScreen(images: list, initialIndex: index.clamp(0, list.length - 1).toInt()),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late final PageController _page = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ZoomableImage(
              url: widget.images[i],
              onZoomChanged: (z) {
                if (z != _zoomed) setState(() => _zoomed = z);
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (widget.images.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('${_index + 1} / ${widget.images.length}', style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoomChanged;
  const _ZoomableImage({required this.url, required this.onZoomChanged});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Animation<Matrix4>? _animation;
  TapDownDetails? _tap;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_animation != null) _controller.value = _animation!.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    final Matrix4 target;
    if (zoomed) {
      target = Matrix4.identity();
    } else {
      final p = _tap?.localPosition ?? Offset.zero;
      const s = 2.5;
      target = Matrix4.identity()
        ..translate(-p.dx * (s - 1), -p.dy * (s - 1))
        ..scale(s);
    }
    _animation = Matrix4Tween(begin: _controller.value, end: target).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0);
    widget.onZoomChanged(!zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tap = d,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: (_) => widget.onZoomChanged(_controller.value.getMaxScaleOnAxis() > 1.01),
        child: SizedBox.expand(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}
