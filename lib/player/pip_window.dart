import 'package:flutter/material.dart';

class PipWindow extends StatefulWidget {
  const PipWindow({
    super.key,
    required this.child,
    required this.onClose,
    this.width = 300,
    this.height = 190,
    this.initialOffset = const Offset(16, 120),
  });

  final Widget child;
  final VoidCallback onClose;
  final double width;
  final double height;
  final Offset initialOffset;

  @override
  State<PipWindow> createState() => _PipWindowState();
}

class _PipWindowState extends State<PipWindow> {
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: Draggable<int>(
        feedback: _frame(opacity: 0.9),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: (details) {
          final newOffset = details.offset;
          final maxX = (size.width - widget.width).clamp(0, double.infinity);
          final maxY = (size.height - widget.height).clamp(0, double.infinity);

          setState(() {
            _offset = Offset(
              newOffset.dx.clamp(0, maxX).toDouble(),
              newOffset.dy.clamp(0, maxY).toDouble(),
            );
          });
        },
        child: _frame(),
      ),
    );
  }

  Widget _frame({double opacity = 1}) {
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 32,
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator, size: 18),
                    const SizedBox(width: 6),
                    const Text('Mini Window', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    IconButton(
                      onPressed: widget.onClose,
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      splashRadius: 14,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}
