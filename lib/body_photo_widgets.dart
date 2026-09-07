import 'dart:io';
import 'package:flutter/material.dart';
import 'body_media.dart';
import 'body_privacy.dart';

class BodyPhotoFrame extends StatelessWidget {
  const BodyPhotoFrame({
    super.key,
    required this.photo,
    required this.path,
    this.showMask = true,
  });
  final BodyPhoto photo;
  final String path;
  final bool showMask;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 3 / 4,
    child: ClipRect(
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: photo.zoom,
              alignment: Alignment(photo.x, photo.y),
              child: RotatedBox(
                quarterTurns: photo.turns,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  alignment: Alignment(photo.x, photo.y),
                  errorBuilder: (context, error, stack) => const ColoredBox(
                    color: Color(0xFF24343B),
                    child: Center(
                      child: Icon(Icons.broken_image_outlined, size: 36),
                    ),
                  ),
                ),
              ),
            ),
            if (showMask && photo.coverFace)
              Positioned(
                left: c.maxWidth * photo.maskX,
                top: c.maxHeight * photo.maskY,
                width: c.maxWidth * photo.maskWidth,
                height: c.maxHeight * photo.maskHeight,
                child: const ColoredBox(color: Color(0xFF111C23)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<BodyPhoto?> editBodyPhoto(
  BuildContext context,
  BodyPhoto photo,
  String path, {
  required BodyMediaStore media,
}) => Navigator.push<BodyPhoto>(
  context,
  bodyRoute(media, (_) => _PhotoEditor(photo: photo, path: path)),
);

class _PhotoEditor extends StatefulWidget {
  const _PhotoEditor({required this.photo, required this.path});
  final BodyPhoto photo;
  final String path;
  @override
  State<_PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<_PhotoEditor> {
  late BodyPhoto photo = widget.photo;
  void update(Map<String, dynamic> v) => setState(() => photo = photo.edit(v));
  Widget slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) changed,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(value: value, min: min, max: max, onChanged: changed),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Framing and privacy'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, photo),
          child: const Text('Done'),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: BodyPhotoFrame(photo: photo, path: widget.path),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Edits preserve body proportions. The original app photo stays unchanged.',
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: () => update({'turns': (photo.turns + 1) % 4}),
                icon: const Icon(Icons.rotate_right),
                label: const Text('Rotate'),
              ),
              TextButton(
                onPressed: () => update({
                  'zoom': 1,
                  'x': 0,
                  'y': 0,
                  'turns': 0,
                  'coverFace': false,
                }),
                child: const Text('Reset'),
              ),
            ],
          ),
          slider('Zoom', photo.zoom, 1, 4, (v) => update({'zoom': v})),
          slider('Horizontal framing', photo.x, -1, 1, (v) => update({'x': v})),
          slider('Vertical framing', photo.y, -1, 1, (v) => update({'y': v})),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cover face or private detail'),
            subtitle: const Text(
              'Check the cover in every final image. Other details can still identify you.',
            ),
            value: photo.coverFace,
            onChanged: (v) => update({'coverFace': v}),
          ),
          if (photo.coverFace) ...[
            slider(
              'Cover position: left / right',
              photo.maskX,
              0,
              1,
              (v) => update({'maskX': v}),
            ),
            slider(
              'Cover position: top / bottom',
              photo.maskY,
              0,
              1,
              (v) => update({'maskY': v}),
            ),
            slider(
              'Cover width',
              photo.maskWidth,
              .05,
              1,
              (v) => update({'maskWidth': v}),
            ),
            slider(
              'Cover height',
              photo.maskHeight,
              .05,
              1,
              (v) => update({'maskHeight': v}),
            ),
          ],
        ],
      ),
    ),
  );
}
