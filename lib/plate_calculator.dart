import 'package:flutter/material.dart';
import 'brand.dart';

/// Largest-first plate pairs for a standard bar. The unmatched load is explicit.
List<double> platesPerSide(double target, double bar, String unit) {
  final sizes = unit == 'kg'
      ? [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
      : [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];
  var remaining = (target - bar) / 2;
  final result = <double>[];
  for (final size in sizes) {
    while (remaining + .0001 >= size && result.length < 30) {
      result.add(size);
      remaining -= size;
    }
  }
  return result;
}

Future<void> showPlateCalculator(
  BuildContext context, {
  required String unit,
  double? target,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _PlateCalculator(unit: unit, target: target),
);

class _PlateCalculator extends StatefulWidget {
  const _PlateCalculator({required this.unit, this.target});
  final String unit;
  final double? target;
  @override
  State<_PlateCalculator> createState() => _PlateCalculatorState();
}

class _PlateCalculatorState extends State<_PlateCalculator> {
  late final target = TextEditingController(
    text: widget.target?.toString() ?? '',
  );
  late final bar = TextEditingController(
    text: widget.unit == 'kg' ? '20' : '45',
  );
  @override
  void dispose() {
    target.dispose();
    bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final load = double.tryParse(target.text);
    final barWeight = double.tryParse(bar.text);
    final valid =
        load != null &&
        load.isFinite &&
        barWeight != null &&
        barWeight.isFinite &&
        barWeight >= 0 &&
        load >= barWeight &&
        load <= 2000;
    final plates = valid
        ? platesPerSide(load, barWeight, widget.unit)
        : <double>[];
    final actual = valid
        ? barWeight + 2 * plates.fold<double>(0, (a, b) => a + b)
        : 0.0;
    String n(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toString();
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Plate calculator',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Total load includes the bar. Add the same plates to each side.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Total load (${widget.unit})',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bar,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Bar weight (${widget.unit})',
              ),
            ),
            const SizedBox(height: 20),
            if (valid) ...[
              Text('Each side', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: plates.isEmpty
                    ? [const Chip(label: Text('Bar only'))]
                    : [
                        for (final plate in plates)
                          Chip(label: Text('${n(plate)} ${widget.unit}')),
                      ],
              ),
              const SizedBox(height: 12),
              Text(
                'Loaded: ${n(actual)} ${widget.unit}${(load - actual).abs() > .01 ? '\n${n(load - actual)} ${widget.unit} below target. Smaller plates are needed for the exact load.' : ''}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Assumes standard plates are available; check your rack before loading.',
                style: TextStyle(color: BrandColors.muted),
              ),
            ] else
              const Text(
                'Enter a finite load at least as heavy as the bar (up to 2,000).',
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
