import 'package:flutter/material.dart';

import 'exercise_library.dart';
import 'store.dart';

const _panel = Color(0xFF121821);
const _lime = Color(0xFFB9FF3B);
const _cyan = Color(0xFF37D7FF);

class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final builtIns = List<BuiltInExercise>.of(BuiltInExercises.values)
        ..sort((a, b) => a.name.compareTo(b.name));
      final custom =
          store.customExercises
              .where((exercise) => !exercise.isArchived)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise library')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(context),
          backgroundColor: _lime,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add_rounded),
          label: const Text('ADD EXERCISE'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            const Text(
              'EXERCISE LIBRARY',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Built-in program exercises are permanent. Custom exercises can be edited or deleted.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            _SectionLabel('CUSTOM', count: custom.length),
            const SizedBox(height: 9),
            if (custom.isEmpty)
              const _EmptyCustomLibrary()
            else
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final entry in custom.asMap().entries) ...[
                      _CustomExerciseTile(
                        exercise: entry.value,
                        onEdit: () =>
                            _openEditor(context, exercise: entry.value),
                        onDelete: () => _confirmDelete(context, entry.value),
                      ),
                      if (entry.key < custom.length - 1)
                        const Divider(height: 1, indent: 58),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 26),
            _SectionLabel('BUILT-IN', count: builtIns.length),
            const SizedBox(height: 9),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final entry in builtIns.asMap().entries) ...[
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.white10,
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                      title: Text(entry.value.name),
                      trailing: const Text(
                        'BUILT-IN',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    if (entry.key < builtIns.length - 1)
                      const Divider(height: 1, indent: 58),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _openEditor(
    BuildContext context, {
    CustomExercise? exercise,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseEditorScreen(store: store, exercise: exercise),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CustomExercise exercise,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete custom exercise?'),
        content: Text(
          '${exercise.name} will be hidden from future selection. Existing history remains readable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.archiveCustomExercise(exercise.id);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the exercise.')),
      );
    }
  }
}

class ExerciseEditorScreen extends StatefulWidget {
  const ExerciseEditorScreen({super.key, required this.store, this.exercise});

  final AppStore store;
  final CustomExercise? exercise;

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  late final TextEditingController _name;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.exercise?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final exercise = widget.exercise;
      if (exercise == null) {
        await widget.store.addCustomExercise(_name.text);
      } else {
        await widget.store.renameCustomExercise(exercise.id, _name.text);
      }
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } on Object {
      if (mounted) setState(() => _error = 'Could not save the exercise.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.exercise == null ? 'Add exercise' : 'Edit exercise'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: 'EXERCISE NAME',
            hintText: 'Enter a name',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'SAVING' : 'SAVE'),
        ),
      ],
    ),
  );
}

class _CustomExerciseTile extends StatelessWidget {
  const _CustomExerciseTile({
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const CircleAvatar(
      backgroundColor: Color(0x1837D7FF),
      child: Icon(Icons.fitness_center_rounded, color: _cyan, size: 18),
    ),
    title: Text(exercise.name),
    subtitle: const Text('Custom'),
    trailing: PopupMenuButton<String>(
      tooltip: 'Custom exercise actions',
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('EDIT')),
        PopupMenuItem(value: 'delete', child: Text('DELETE')),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      const Spacer(),
      Text('$count', style: const TextStyle(color: Colors.white38)),
    ],
  );
}

class _EmptyCustomLibrary extends StatelessWidget {
  const _EmptyCustomLibrary();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Text(
      'No custom exercises yet. The built-in program is ready to use below.',
      style: TextStyle(color: Colors.white54),
    ),
  );
}
