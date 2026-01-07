import 'package:flutter/material.dart';

class PulsingMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onLongPress;
  final VoidCallback onLongPressUp;

  const PulsingMicButton({super.key, required this.isRecording, required this.onLongPress, required this.onLongPressUp});

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant PulsingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _controller.repeat(); // Start pulsing
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _controller.reset(); // Stop pulsing
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      onLongPressUp: widget.onLongPressUp,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. The Ripple Effect (Only visible when recording)
          if (widget.isRecording)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    ),
                  ),
                );
              },
            ),

          // 2. The Actual Button
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: widget.isRecording ? Colors.red : Colors.white10,
              shape: BoxShape.circle,
              boxShadow: widget.isRecording ? [const BoxShadow(color: Colors.redAccent, blurRadius: 10, spreadRadius: 2)] : [],
            ),
            child: Icon(widget.isRecording ? Icons.mic : Icons.mic_none, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}
