import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class BodyCameraScreen extends StatefulWidget {
  const BodyCameraScreen({super.key, this.reference});
  final String? reference;
  @override
  State<BodyCameraScreen> createState() => _BodyCameraScreenState();
}

class _BodyCameraScreenState extends State<BodyCameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  int lens = 0, delay = 5, count = 0;
  bool overlay = true, busy = false;
  String? error;
  Timer? timer;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    final current = ++generation;
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final next = CameraController(
        cameras[lens % cameras.length],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted || current != generation) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        error = null;
      });
    } on Object {
      if (mounted)
        setState(
          () => error =
              'The camera is unavailable. Allow camera access in Android settings, or import a photo.',
        );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      generation++;
      timer?.cancel();
      count = 0;
      controller?.dispose();
      controller = null;
    }
    if (state == AppLifecycleState.resumed && controller == null) initCamera();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> capture() async {
    final c = controller;
    if (c == null || busy) return;
    setState(() => busy = true);
    try {
      final photo = await c.takePicture();
      if (mounted) Navigator.pop(context, photo.path);
    } on Object {
      if (mounted)
        setState(() => error = 'The photo could not be captured. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void start() {
    if (count > 0 || busy) return;
    if (delay == 0) {
      capture();
      return;
    }
    setState(() => count = delay);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => count--);
      if (count == 0) {
        t.cancel();
        capture();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Progress photo')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Use the same light, camera distance, clothing, and pose. All views are optional.',
          ),
          const SizedBox(height: 12),
          if (error != null)
            Text(error!)
          else if (controller == null)
            const Center(child: CircularProgressIndicator())
          else
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: 1 / controller!.value.aspectRatio,
                        child: CameraPreview(controller!),
                      ),
                    ),
                    if (overlay && widget.reference != null)
                      IgnorePointer(
                        child: Opacity(
                          opacity: .22,
                          child: Image.file(
                            File(widget.reference!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const IgnorePointer(child: CustomPaint(painter: _Grid())),
                    if (count > 0)
                      Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 80,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              DropdownButton<int>(
                value: delay,
                items: [0, 5, 10]
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: Text(n == 0 ? 'No timer' : '$n second timer'),
                      ),
                    )
                    .toList(),
                onChanged: busy || count > 0
                    ? null
                    : (v) => setState(() => delay = v!),
              ),
              if (widget.reference != null)
                FilterChip(
                  label: const Text('Previous photo'),
                  selected: overlay,
                  onSelected: (v) => setState(() => overlay = v),
                ),
              IconButton(
                tooltip: 'Switch camera',
                onPressed: cameras.length < 2 || busy || count > 0
                    ? null
                    : () async {
                        await controller?.dispose();
                        setState(() {
                          controller = null;
                          lens++;
                        });
                        await initCamera();
                      },
                icon: const Icon(Icons.cameraswitch_outlined),
              ),
              FilledButton.icon(
                onPressed: controller == null || busy || count > 0
                    ? null
                    : start,
                icon: const Icon(Icons.camera_alt),
                label: Text(busy ? 'Saving…' : 'Take photo'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Grid extends CustomPainter {
  const _Grid();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (final f in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(s.width * f, 0), Offset(s.width * f, s.height), p);
      canvas.drawLine(
        Offset(0, s.height * f),
        Offset(s.width, s.height * f),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
