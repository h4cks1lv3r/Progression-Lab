import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'athletic_history.dart';
import 'athletic_program.dart';
import 'brand.dart';
import 'daily_inputs.dart';
import 'daily_inputs_screen.dart';
import 'share_card.dart';
import 'store.dart';

Future<void> showAthleticPositionSheet(
  BuildContext context,
  AppStore store, {
  int? initialWeek,
}) async {
  final safeInitialWeek = (initialWeek ?? store.athleticWeek)
      .clamp(1, AthleticProgram.totalWeeks)
      .toInt();
  final initial = AthleticProgram.week(safeInitialWeek);
  var targetCycle = initial.cycleNumber;
  var targetWeekInCycle = initial.weekInCycle;
  var selectedSession = safeInitialWeek == store.athleticWeek
      ? store.athleticSessionIndex
      : 0;
  final now = DateTime.now();
  var nextSessionDate = DateTime(now.year, now.month, now.day);
  var startNewRun = false;
  var saving = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .78),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final targetWeekNumber =
            (targetCycle - 1) * AthleticProgram.weeksPerCycle +
            targetWeekInCycle;
        final targetWeek = AthleticProgram.week(targetWeekNumber);
        selectedSession = selectedSession
            .clamp(0, AthleticProgram.sessionsPerWeek - 1)
            .toInt();
        final targetHasHistory = store.isAthleticSessionCompleted(
          targetWeekNumber,
          selectedSession,
        );
        final canSave = startNewRun || !targetHasHistory;

        Future<void> chooseDate() async {
          final chosen = await showDatePicker(
            context: sheetContext,
            initialDate: nextSessionDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(now.year + 10, 12, 31),
            helpText: 'Choose the date of the next athletic session',
          );
          if (chosen != null && sheetContext.mounted) {
            setSheetState(() => nextSessionDate = chosen);
          }
        }

        Future<void> commit() async {
          if (saving || !canSave) return;
          setSheetState(() => saving = true);
          try {
            await store.setAthleticProgramPosition(
              weekNumber: targetWeekNumber,
              sessionIndex: selectedSession,
              nextSessionDate: nextSessionDate,
              startNewRun: startNewRun,
            );
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          } on StateError catch (error) {
            if (!sheetContext.mounted) return;
            setSheetState(() => saving = false);
            ScaffoldMessenger.of(
              sheetContext,
            ).showSnackBar(SnackBar(content: Text(error.message.toString())));
          } on Object {
            if (!sheetContext.mounted) return;
            setSheetState(() => saving = false);
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              const SnackBar(
                content: Text('The athletic position could not be changed.'),
              ),
            );
          }
        }

        return DraggableScrollableSheet(
          initialChildSize: .92,
          minChildSize: .65,
          maxChildSize: .97,
          expand: false,
          builder: (context, controller) => Material(
            color: BrandColors.panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('athletic-position-scroll'),
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: BrandColors.cyan.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: BrandColors.cyan.withValues(alpha: .34),
                              ),
                            ),
                            child: const Icon(
                              Icons.flag_circle_rounded,
                              color: BrandColors.cyan,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CHANGE ATHLETIC START',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Choose the cycle, week, and next session that match your current training.',
                                  style: TextStyle(
                                    color: BrandColors.muted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const BrandSectionLabel('Training cycle'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: BrandColors.panelHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: BrandColors.line),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: targetCycle,
                            isExpanded: true,
                            dropdownColor: BrandColors.panelHigh,
                            borderRadius: BorderRadius.circular(18),
                            items: [
                              for (final cycle in AthleticProgram.cycles)
                                DropdownMenuItem(
                                  value: cycle.number,
                                  child: Text(
                                    'Cycle ${cycle.number} · ${cycle.name}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setSheetState(() => targetCycle = value);
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const BrandSectionLabel('Week in cycle'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (
                            var weekInCycle = 1;
                            weekInCycle <= AthleticProgram.weeksPerCycle;
                            weekInCycle++
                          )
                            ChoiceChip(
                              selected: targetWeekInCycle == weekInCycle,
                              label: Text('WEEK $weekInCycle'),
                              onSelected: saving
                                  ? null
                                  : (_) => setSheetState(
                                      () => targetWeekInCycle = weekInCycle,
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      BrandSectionLabel(
                        'Next session',
                        trailing: Text(
                          'PROGRAM WEEK $targetWeekNumber',
                          style: const TextStyle(
                            color: BrandColors.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final entry in targetWeek.sessions.asMap().entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _AthleticPositionSessionOption(
                            session: entry.value,
                            index: entry.key,
                            selected: selectedSession == entry.key,
                            onTap: saving
                                ? null
                                : () => setSheetState(
                                    () => selectedSession = entry.key,
                                  ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const BrandSectionLabel('Next session date'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: saving ? null : chooseDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(_formatDate(nextSessionDate)),
                      ),
                      const SizedBox(height: 22),
                      const BrandSectionLabel('How to apply it'),
                      const SizedBox(height: 10),
                      _AthleticPositionModeOption(
                        selected: !startNewRun,
                        icon: Icons.my_location_rounded,
                        title: 'MOVE CURRENT RUN',
                        description:
                            'Keep run ${store.athleticProgramRun} and move its active marker.',
                        onTap: saving
                            ? null
                            : () => setSheetState(() => startNewRun = false),
                      ),
                      const SizedBox(height: 9),
                      _AthleticPositionModeOption(
                        selected: startNewRun,
                        icon: Icons.restart_alt_rounded,
                        title: 'START A NEW ATHLETIC RUN',
                        description:
                            'Create run ${store.athleticProgramRun + 1}. Existing sessions and assessments remain in history.',
                        onTap: saving
                            ? null
                            : () => setSheetState(() => startNewRun = true),
                      ),
                      if (targetHasHistory && !startNewRun) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: BrandColors.magenta.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: BrandColors.magenta.withValues(alpha: .28),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                color: BrandColors.magenta,
                                size: 19,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This session is already complete in the current run. Start a new run to use it as the next session.',
                                  style: TextStyle(
                                    color: BrandColors.white,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      LabPanel(
                        accent: BrandColors.cyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NEW STARTING POSITION',
                              style: TextStyle(
                                color: BrandColors.cyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Run ${startNewRun ? store.athleticProgramRun + 1 : store.athleticProgramRun} · Cycle $targetCycle · Week $targetWeekInCycle',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${targetWeek.sessions[selectedSession].name} · ${_formatDate(nextSessionDate)}',
                              style: const TextStyle(
                                color: BrandColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: BrandColors.ink,
                    border: Border(top: BorderSide(color: BrandColors.line)),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: saving || !canSave ? null : commit,
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                startNewRun
                                    ? Icons.restart_alt_rounded
                                    : Icons.flag_rounded,
                              ),
                        label: Text(
                          saving
                              ? 'SAVING'
                              : startNewRun
                              ? 'START NEW RUN HERE'
                              : 'SET CURRENT POSITION',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: .45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _AthleticPositionSessionOption extends StatelessWidget {
  const _AthleticPositionSessionOption({
    required this.session,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final AthleticSession session;
  final int index;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(17),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? BrandColors.cyan.withValues(alpha: .1)
            : BrandColors.panelHigh,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected
              ? BrandColors.cyan.withValues(alpha: .46)
              : BrandColors.line,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: selected
                ? BrandColors.cyan
                : BrandColors.panelSoft,
            foregroundColor: selected ? BrandColors.ink : BrandColors.muted,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${session.day} · ${session.durationMinutes} min',
                  style: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? BrandColors.cyan : BrandColors.muted,
          ),
        ],
      ),
    ),
  );
}

class _AthleticPositionModeOption extends StatelessWidget {
  const _AthleticPositionModeOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: selected
            ? BrandColors.violet.withValues(alpha: .1)
            : BrandColors.panelHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? BrandColors.violet.withValues(alpha: .5)
              : BrandColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: selected ? BrandColors.violet : BrandColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .55,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? BrandColors.violet : BrandColors.muted,
          ),
        ],
      ),
    ),
  );
}

class AthleticTrainingPage extends StatelessWidget {
  const AthleticTrainingPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final week = store.currentAthleticWeek;
      final session = store.currentAthleticSession;
      final cycle = AthleticProgram.cycleForWeek(store.athleticWeek);
      final runAssessments = store.athleticAssessments
          .where((item) => item.programRun == store.athleticProgramRun)
          .toList();
      final latestAssessment = runAssessments.isEmpty
          ? null
          : runAssessments.last;
      return BrandBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            key: const PageStorageKey('athletic-training-page'),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: _AthleticHeader(
                        store: store,
                        week: week,
                        run: store.athleticProgramRun,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProgramProgressPanel(
                            store: store,
                            week: week,
                            cycle: cycle,
                          ),
                          const SizedBox(height: 18),
                          if (store.athleticProgramComplete)
                            _ProgramCompletePanel(store: store)
                          else
                            _NextAthleticSessionPanel(
                              store: store,
                              week: week,
                              session: session,
                            ),
                          const SizedBox(height: 26),
                          BrandSectionLabel(
                            'This week',
                            trailing: Text(
                              week.stage.toUpperCase(),
                              style: const TextStyle(
                                color: BrandColors.cyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _WeekRoutine(store: store, week: week),
                          const SizedBox(height: 26),
                          const BrandSectionLabel('Weekly rhythm'),
                          const SizedBox(height: 12),
                          const _WeeklyRhythmPanel(),
                          const SizedBox(height: 26),
                          BrandSectionLabel(
                            'Training cycles',
                            trailing: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AthleticPlanScreen(store: store),
                                ),
                              ),
                              child: const Text('VIEW 12 WEEKS'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _CycleCards(currentCycle: cycle.number),
                          const SizedBox(height: 26),
                          const BrandSectionLabel('Performance targets'),
                          const SizedBox(height: 12),
                          const _QualityGrid(),
                          const SizedBox(height: 26),
                          BrandSectionLabel(
                            'Field measures',
                            trailing: TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AthleticAssessmentScreen(store: store),
                                ),
                              ),
                              icon: const Icon(Icons.science_rounded, size: 17),
                              label: const Text('ASSESS'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AssessmentPanel(
                            assessment: latestAssessment,
                            onOpenHistory: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AthleticHistoryScreen(store: store),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Training guidance only. Stop for sharp pain, dizziness, or loss of control. Field measures are repeatable performance markers, not medical screening or diagnosis.',
                            style: TextStyle(
                              color: BrandColors.muted.withValues(alpha: .8),
                              fontSize: 11,
                              height: 1.45,
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
      );
    },
  );
}

class _AthleticHeader extends StatelessWidget {
  const _AthleticHeader({
    required this.store,
    required this.week,
    required this.run,
  });

  final AppStore store;
  final AthleticWeek week;
  final int run;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const LabMark(size: 58),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ATHLETIC FUNCTIONAL',
              style: TextStyle(
                color: BrandColors.white,
                fontSize: 21,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
            const Text(
              'TRAINING',
              style: TextStyle(
                color: BrandColors.violet,
                fontSize: 24,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Run $run · Cycle ${week.cycleNumber} · ${week.cycleName}',
              style: const TextStyle(color: BrandColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Athletic history',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AthleticHistoryScreen(store: store),
          ),
        ),
        icon: const Icon(Icons.history_rounded),
      ),
    ],
  );
}

class _ProgramProgressPanel extends StatelessWidget {
  const _ProgramProgressPanel({
    required this.store,
    required this.week,
    required this.cycle,
  });

  final AppStore store;
  final AthleticWeek week;
  final AthleticCycle cycle;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: BrandColors.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BrandColors.cyan.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.directions_run_rounded,
                color: BrandColors.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEK ${store.athleticWeek} OF ${AthleticProgram.totalWeeks}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${cycle.name} · Session ${store.athleticSessionIndex + 1} of ${AthleticProgram.sessionsPerWeek}',
                    style: const TextStyle(
                      color: BrandColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(store.athleticProgress * 100).round()}%',
              style: const TextStyle(
                color: BrandColors.violet,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: store.athleticProgress,
            minHeight: 8,
            backgroundColor: BrandColors.panelSoft,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          week.goal,
          style: const TextStyle(color: BrandColors.white, height: 1.45),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => showAthleticPositionSheet(context, store),
            icon: const Icon(Icons.flag_circle_rounded, size: 18),
            label: const Text('CHANGE STARTING POINT'),
          ),
        ),
      ],
    ),
  );
}

class _NextAthleticSessionPanel extends StatelessWidget {
  const _NextAthleticSessionPanel({
    required this.store,
    required this.week,
    required this.session,
  });

  final AppStore store;
  final AthleticWeek week;
  final AthleticSession session;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF25114A), BrandColors.panel, Color(0xFF0C1D29)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: BrandColors.violet.withValues(alpha: .35)),
      boxShadow: [
        BoxShadow(
          color: BrandColors.purple.withValues(alpha: .17),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'NEXT SESSION',
              style: TextStyle(
                color: BrandColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.25,
              ),
            ),
            const Spacer(),
            Text(
              _formatDate(
                store.athleticDateForSlot(
                  store.athleticWeek,
                  store.athleticSessionIndex,
                ),
              ),
              style: const TextStyle(color: BrandColors.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          session.name.toUpperCase(),
          style: const TextStyle(
            fontSize: 27,
            height: 1.02,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          session.summary,
          style: const TextStyle(color: BrandColors.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _InfoPill(Icons.calendar_today_rounded, session.day),
            _InfoPill(Icons.timer_outlined, '${session.durationMinutes} MIN'),
            _InfoPill(
              Icons.format_list_numbered_rounded,
              '${session.drills.length} DRILLS',
            ),
          ],
        ),
        const SizedBox(height: 18),
        GradientAction(
          label: 'START SESSION',
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AthleticSessionScreen(
                store: store,
                week: week,
                sessionIndex: store.athleticSessionIndex,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProgramCompletePanel extends StatelessWidget {
  const _ProgramCompletePanel({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: BrandColors.violet,
    child: Column(
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          color: BrandColors.violet,
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          '12-WEEK CYCLE COMPLETE',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review your field measures and session notes before beginning another run. History remains available after restart.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BrandColors.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        GradientAction(
          label: 'RESTART AS A NEW RUN',
          icon: Icons.restart_alt_rounded,
          onPressed: () => _confirmRestart(context),
        ),
      ],
    ),
  );

  Future<void> _confirmRestart(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a new athletic run?'),
        content: const Text(
          'The position returns to week 1. Completed sessions and assessments from this run remain in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('START NEW RUN'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.restartAthleticProgram();
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not restart the program.')),
      );
    }
  }
}

class _WeekRoutine extends StatelessWidget {
  const _WeekRoutine({required this.store, required this.week});

  final AppStore store;
  final AthleticWeek week;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final entry in week.sessions.asMap().entries) ...[
        _RoutineSessionTile(
          store: store,
          week: week,
          session: entry.value,
          sessionIndex: entry.key,
          completed: store.isAthleticSessionCompleted(week.number, entry.key),
          current:
              !store.athleticProgramComplete &&
              week.number == store.athleticWeek &&
              entry.key == store.athleticSessionIndex,
        ),
        if (entry.key < week.sessions.length - 1) const SizedBox(height: 10),
      ],
    ],
  );
}

class _RoutineSessionTile extends StatelessWidget {
  const _RoutineSessionTile({
    required this.store,
    required this.week,
    required this.session,
    required this.sessionIndex,
    required this.completed,
    required this.current,
  });

  final AppStore store;
  final AthleticWeek week;
  final AthleticSession session;
  final int sessionIndex;
  final bool completed;
  final bool current;

  @override
  Widget build(BuildContext context) => LabPanel(
    padding: const EdgeInsets.all(14),
    accent: current
        ? BrandColors.violet
        : completed
        ? BrandColors.success
        : BrandColors.line,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => current
            ? AthleticSessionScreen(
                store: store,
                week: week,
                sessionIndex: sessionIndex,
              )
            : AthleticSessionPreviewScreen(
                week: week,
                sessionIndex: sessionIndex,
                completed: completed,
              ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: completed
                ? BrandColors.success.withValues(alpha: .12)
                : current
                ? BrandColors.purple.withValues(alpha: .22)
                : BrandColors.panelSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            completed
                ? Icons.check_rounded
                : current
                ? Icons.play_arrow_rounded
                : Icons.fitness_center_rounded,
            color: completed
                ? BrandColors.success
                : current
                ? BrandColors.violet
                : BrandColors.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    session.day,
                    style: const TextStyle(
                      color: BrandColors.cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'CURRENT',
                      style: TextStyle(
                        color: BrandColors.violet,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                session.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${session.durationMinutes} min · ${session.drills.length} drills',
                style: const TextStyle(color: BrandColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: BrandColors.muted),
      ],
    ),
  );
}

class _WeeklyRhythmPanel extends StatelessWidget {
  const _WeeklyRhythmPanel();

  @override
  Widget build(BuildContext context) {
    const days = [
      ('MON', 'Train', BrandColors.violet),
      ('TUE', 'Walk + mobility', BrandColors.cyan),
      ('WED', 'Train', BrandColors.violet),
      ('THU', 'Recovery', BrandColors.cyan),
      ('FRI', 'Train', BrandColors.violet),
      ('SAT', 'Train', BrandColors.violet),
      ('SUN', 'Recover', BrandColors.cyan),
    ];
    return LabPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth >= 620
              ? (constraints.maxWidth - 36) / 7
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final day in days)
                SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: day.$3.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: day.$3.withValues(alpha: .18)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          day.$1,
                          style: TextStyle(
                            color: day.$3,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: BrandColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CycleCards extends StatelessWidget {
  const _CycleCards({required this.currentCycle});

  final int currentCycle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final cycle in AthleticProgram.cycles) ...[
        LabPanel(
          accent: cycle.number == currentCycle
              ? BrandColors.violet
              : BrandColors.line,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            leading: CircleAvatar(
              backgroundColor: cycle.number == currentCycle
                  ? BrandColors.purple.withValues(alpha: .25)
                  : BrandColors.panelSoft,
              foregroundColor: cycle.number == currentCycle
                  ? BrandColors.violet
                  : BrandColors.muted,
              child: Text(
                '${cycle.number}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            title: Text(
              cycle.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              cycle.weeks,
              style: const TextStyle(color: BrandColors.cyan),
            ),
            children: [
              Text(
                cycle.description,
                style: const TextStyle(color: BrandColors.muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              for (final aim in cycle.aims)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: BrandColors.cyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(aim)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (cycle != AthleticProgram.cycles.last) const SizedBox(height: 10),
      ],
    ],
  );
}

class _QualityGrid extends StatelessWidget {
  const _QualityGrid();

  static const items = [
    (Icons.directions_walk_rounded, 'Gait', 'Cross-body timing'),
    (Icons.accessibility_new_rounded, 'Mobility', 'Usable joint range'),
    (Icons.balance_rounded, 'Balance', 'Single-leg control'),
    (Icons.rotate_right_rounded, 'Rotation', 'Diagonal transfer'),
    (Icons.flash_on_rounded, 'Elastic', 'Spring and landing'),
    (Icons.speed_rounded, 'Speed', 'Acceleration mechanics'),
    (Icons.turn_sharp_right_rounded, 'Agility', 'Brake and redirect'),
    (Icons.battery_charging_full_rounded, 'Capacity', 'Repeat quality efforts'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 4 : 2;
      final gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: LabPanel(
                padding: const EdgeInsets.all(14),
                accent: BrandColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$1, color: BrandColors.cyan, size: 22),
                    const SizedBox(height: 10),
                    Text(
                      item.$2.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      style: const TextStyle(
                        color: BrandColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _AssessmentPanel extends StatelessWidget {
  const _AssessmentPanel({
    required this.assessment,
    required this.onOpenHistory,
  });

  final AthleticAssessment? assessment;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: BrandColors.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assessment == null) ...[
          const Text(
            'NO FIELD MEASURES RECORDED',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record a repeatable baseline now, then retest at the end of weeks 4, 8, and 12 under similar conditions.',
            style: TextStyle(color: BrandColors.muted, height: 1.45),
          ),
        ] else ...[
          Row(
            children: [
              const Icon(Icons.science_rounded, color: BrandColors.cyan),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'LATEST · ${_formatDate(assessment!.recordedAt)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'QUALITY ${assessment!.movementQuality}/5',
                style: const TextStyle(
                  color: BrandColors.violet,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MeasureChip(
                'L BAL',
                _value(assessment!.leftBalanceSeconds, 's'),
              ),
              _MeasureChip(
                'R BAL',
                _value(assessment!.rightBalanceSeconds, 's'),
              ),
              _MeasureChip(
                'BROAD',
                _value(assessment!.broadJumpCentimeters, 'cm'),
              ),
              _MeasureChip(
                '10 M',
                _value(assessment!.sprint10MetersSeconds, 's'),
              ),
              _MeasureChip(
                '5-0-5',
                _value(assessment!.changeOfDirection505Seconds, 's'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onOpenHistory,
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('SESSION & ASSESSMENT HISTORY'),
          ),
        ),
      ],
    ),
  );

  static String _value(double? value, String suffix) => value == null
      ? '—'
      : '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} $suffix';
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: BrandColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: BrandColors.cyan),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .55,
          ),
        ),
      ],
    ),
  );
}

class _MeasureChip extends StatelessWidget {
  const _MeasureChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: BrandColors.cyan.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: BrandColors.cyan.withValues(alpha: .16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: BrandColors.muted,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class AthleticSessionScreen extends StatefulWidget {
  const AthleticSessionScreen({
    super.key,
    required this.store,
    required this.week,
    required this.sessionIndex,
  });

  final AppStore store;
  final AthleticWeek week;
  final int sessionIndex;

  @override
  State<AthleticSessionScreen> createState() => _AthleticSessionScreenState();
}

class _AthleticSessionScreenState extends State<AthleticSessionScreen> {
  final Set<int> completedDrills = {};
  final DateTime startedAt = DateTime.now();
  bool saving = false;

  AthleticSession get session => widget.week.sessions[widget.sessionIndex];

  @override
  Widget build(BuildContext context) {
    final progress = completedDrills.length / session.drills.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('${session.day} · WEEK ${widget.week.number}'),
      ),
      body: BrandBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                const LabMark(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${widget.week.cycleName} · ${session.durationMinutes} min',
                        style: const TextStyle(color: BrandColors.cyan),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              session.summary,
              style: const TextStyle(color: BrandColors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 7),
            Text(
              '${completedDrills.length} OF ${session.drills.length} DRILLS COMPLETE',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 20),
            for (final entry in session.drills.asMap().entries) ...[
              _ActiveDrillCard(
                index: entry.key,
                drill: entry.value,
                complete: completedDrills.contains(entry.key),
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      completedDrills.add(entry.key);
                    } else {
                      completedDrills.remove(entry.key);
                    }
                  });
                  HapticFeedback.selectionClick();
                },
              ),
              if (entry.key < session.drills.length - 1)
                const SizedBox(height: 12),
            ],
            const SizedBox(height: 22),
            GradientAction(
              label: saving ? 'SAVING SESSION' : 'FINISH SESSION',
              icon: Icons.check_circle_rounded,
              onPressed:
                  completedDrills.length == session.drills.length && !saving
                  ? _finish
                  : null,
            ),
            if (completedDrills.length < session.drills.length) ...[
              const SizedBox(height: 10),
              const Text(
                'Complete every drill before finishing. Use the listed regression when the prescribed version cannot be controlled.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BrandColors.muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final result = await showModalBottomSheet<_SessionFinishResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SessionFinishSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => saving = true);
    final responseSessionId = createRecordId('athletic-session');
    try {
      await widget.store.completeAthleticSession(
        effort: result.effort,
        notes: result.notes,
        sessionId: responseSessionId,
      );
      if (mounted) {
        await showWorkoutResponseSheet(
          context,
          widget.store,
          sessionId: responseSessionId,
          track: 'athletic',
        );
      }
      if (mounted) {
        final cycleComplete =
            widget.sessionIndex == AthleticProgram.sessionsPerWeek - 1 &&
            widget.week.number % AthleticProgram.weeksPerCycle == 0;
        await showWorkoutCompleteSheet(
          context,
          WorkoutShareData(
            program: 'Athletic Functional Training',
            title: session.name,
            contextLine:
                '${widget.week.cycleName} · Week ${widget.week.number} · ${session.day}',
            completedAt: DateTime.now(),
            achievementLabel: cycleComplete ? 'Cycle complete' : null,
            metrics: [
              ShareMetric(
                'Duration',
                formatShareDuration(DateTime.now().difference(startedAt)),
              ),
              ShareMetric('Drills', '${session.drills.length}'),
              ShareMetric('Effort', '${result.effort}/10'),
              ShareMetric('Program', 'Week ${widget.week.number}/12'),
            ],
            highlightLabel: 'Training focus',
            highlightValue: session.summary,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } on Object {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the athletic session.')),
      );
    }
  }
}

class _ActiveDrillCard extends StatelessWidget {
  const _ActiveDrillCard({
    required this.index,
    required this.drill,
    required this.complete,
    required this.onChanged,
  });

  final int index;
  final AthleticDrill drill;
  final bool complete;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: complete ? BrandColors.success : BrandColors.violet,
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      key: PageStorageKey('athletic-drill-$index'),
      tilePadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      leading: InkWell(
        onTap: () => onChanged(!complete),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: complete
                ? BrandColors.success.withValues(alpha: .14)
                : BrandColors.purple.withValues(alpha: .18),
            shape: BoxShape.circle,
          ),
          child: Icon(
            complete ? Icons.check_rounded : Icons.circle_outlined,
            color: complete ? BrandColors.success : BrandColors.violet,
          ),
        ),
      ),
      title: Text(
        '${index + 1}. ${drill.name}',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          decoration: complete ? TextDecoration.lineThrough : null,
          decorationColor: BrandColors.muted,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          drill.prescription,
          style: const TextStyle(
            color: BrandColors.cyan,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      children: [
        _DrillDetail(label: 'PURPOSE', text: drill.purpose),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'PRIMARY CUES',
            style: TextStyle(
              color: BrandColors.violet,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
        const SizedBox(height: 7),
        for (final cue in drill.cues)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: BrandColors.cyan,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Expanded(child: Text(cue)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _DrillDetail(label: 'EQUIPMENT', text: drill.equipment),
        const SizedBox(height: 10),
        _DrillDetail(label: 'REGRESSION', text: drill.regression),
        const SizedBox(height: 10),
        _DrillDetail(label: 'PROGRESSION', text: drill.progression),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => onChanged(!complete),
            icon: Icon(complete ? Icons.undo_rounded : Icons.check_rounded),
            label: Text(complete ? 'MARK NOT COMPLETE' : 'MARK COMPLETE'),
          ),
        ),
      ],
    ),
  );
}

class _DrillDetail extends StatelessWidget {
  const _DrillDetail({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: BrandColors.violet,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(height: 4),
      Text(text, style: const TextStyle(color: BrandColors.muted, height: 1.4)),
    ],
  );
}

class _SessionFinishResult {
  const _SessionFinishResult(this.effort, this.notes);

  final int effort;
  final String notes;
}

class _SessionFinishSheet extends StatefulWidget {
  const _SessionFinishSheet();

  @override
  State<_SessionFinishSheet> createState() => _SessionFinishSheetState();
}

class _SessionFinishSheetState extends State<_SessionFinishSheet> {
  double effort = 6;
  final notes = TextEditingController();

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SESSION COMPLETE',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Rate the whole session, not the hardest single drill.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'EFFORT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '${effort.round()} / 10',
                style: const TextStyle(
                  color: BrandColors.cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: effort,
            min: 1,
            max: 10,
            divisions: 9,
            label: '${effort.round()}',
            onChanged: (value) => setState(() => effort = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'SESSION NOTES',
              hintText: 'Control, discomfort, wins, or changes for next time',
            ),
          ),
          const SizedBox(height: 18),
          GradientAction(
            label: 'SAVE & ADVANCE',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => Navigator.pop(
              context,
              _SessionFinishResult(effort.round(), notes.text),
            ),
          ),
        ],
      ),
    ),
  );
}

class AthleticSessionPreviewScreen extends StatelessWidget {
  const AthleticSessionPreviewScreen({
    super.key,
    required this.week,
    required this.sessionIndex,
    required this.completed,
  });

  final AthleticWeek week;
  final int sessionIndex;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final session = week.sessions[sessionIndex];
    return Scaffold(
      appBar: AppBar(title: Text('Week ${week.number} · ${session.day}')),
      body: BrandBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              session.name.toUpperCase(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${week.cycleName} · ${session.durationMinutes} min${completed ? ' · COMPLETED' : ''}',
              style: TextStyle(
                color: completed ? BrandColors.success : BrandColors.cyan,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              session.summary,
              style: const TextStyle(color: BrandColors.muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            for (final entry in session.drills.asMap().entries) ...[
              LabPanel(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: BrandColors.purple.withValues(alpha: .18),
                    foregroundColor: BrandColors.violet,
                    child: Text('${entry.key + 1}'),
                  ),
                  title: Text(
                    entry.value.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    entry.value.prescription,
                    style: const TextStyle(color: BrandColors.cyan),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _DrillDetail(label: 'PURPOSE', text: entry.value.purpose),
                    const SizedBox(height: 10),
                    _DrillDetail(
                      label: 'REGRESSION',
                      text: entry.value.regression,
                    ),
                    const SizedBox(height: 10),
                    _DrillDetail(
                      label: 'PROGRESSION',
                      text: entry.value.progression,
                    ),
                  ],
                ),
              ),
              if (entry.key < session.drills.length - 1)
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class AthleticPlanScreen extends StatelessWidget {
  const AthleticPlanScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('12-week athletic plan')),
    body: BrandBackdrop(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: AthleticProgram.totalWeeks,
        itemBuilder: (context, index) {
          final week = AthleticProgram.week(index + 1);
          final current = week.number == store.athleticWeek;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LabPanel(
              accent: current ? BrandColors.violet : BrandColors.line,
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: current,
                leading: CircleAvatar(
                  backgroundColor: current
                      ? BrandColors.purple.withValues(alpha: .25)
                      : BrandColors.panelSoft,
                  foregroundColor: current
                      ? BrandColors.violet
                      : BrandColors.muted,
                  child: Text('${week.number}'),
                ),
                title: Text(
                  'Week ${week.number} · ${week.stage}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Cycle ${week.cycleNumber} · ${week.cycleName}',
                  style: const TextStyle(color: BrandColors.cyan),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    week.goal,
                    style: const TextStyle(
                      color: BrandColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showAthleticPositionSheet(
                        context,
                        store,
                        initialWeek: week.number,
                      ),
                      icon: const Icon(Icons.flag_circle_rounded, size: 18),
                      label: Text(
                        current
                            ? 'EDIT STARTING POINT'
                            : 'START FROM THIS WEEK',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in week.sessions.asMap().entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        store.isAthleticSessionCompleted(week.number, entry.key)
                            ? Icons.check_circle_rounded
                            : Icons.fitness_center_rounded,
                        color:
                            store.isAthleticSessionCompleted(
                              week.number,
                              entry.key,
                            )
                            ? BrandColors.success
                            : BrandColors.violet,
                      ),
                      title: Text(entry.value.name),
                      subtitle: Text(
                        '${entry.value.day} · ${entry.value.durationMinutes} min',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AthleticSessionPreviewScreen(
                            week: week,
                            sessionIndex: entry.key,
                            completed: store.isAthleticSessionCompleted(
                              week.number,
                              entry.key,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class AthleticAssessmentScreen extends StatefulWidget {
  const AthleticAssessmentScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<AthleticAssessmentScreen> createState() =>
      _AthleticAssessmentScreenState();
}

class _AthleticAssessmentScreenState extends State<AthleticAssessmentScreen> {
  final leftBalance = TextEditingController();
  final rightBalance = TextEditingController();
  final broadJump = TextEditingController();
  final sprint = TextEditingController();
  final changeDirection = TextEditingController();
  final notes = TextEditingController();
  double quality = 3;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    leftBalance.dispose();
    rightBalance.dispose();
    broadJump.dispose();
    sprint.dispose();
    changeDirection.dispose();
    notes.dispose();
    super.dispose();
  }

  double? _optionalValue(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Athletic field measures')),
    body: BrandBackdrop(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const LabMark(size: 58),
          const SizedBox(height: 14),
          const Text(
            'REPEATABLE FIELD MEASURES',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the same surface, footwear, warm-up, timing method, and test order. Record only tests that are appropriate for you today.',
            style: TextStyle(color: BrandColors.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MeasureField(
                  controller: leftBalance,
                  label: 'LEFT BALANCE (SEC)',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasureField(
                  controller: rightBalance,
                  label: 'RIGHT BALANCE (SEC)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MeasureField(
            controller: broadJump,
            label: 'STANDING BROAD JUMP (CM)',
          ),
          const SizedBox(height: 12),
          _MeasureField(controller: sprint, label: '10 M SPRINT (SEC)'),
          const SizedBox(height: 12),
          _MeasureField(
            controller: changeDirection,
            label: '5-0-5 CHANGE OF DIRECTION (SEC)',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'MOVEMENT QUALITY',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${quality.round()} / 5',
                style: const TextStyle(
                  color: BrandColors.violet,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: quality,
            min: 1,
            max: 5,
            divisions: 4,
            label: '${quality.round()}',
            onChanged: (value) => setState(() => quality = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notes,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'TEST CONDITIONS & NOTES',
              hintText:
                  'Surface, footwear, warm-up, symptoms, or timing method',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: BrandColors.error)),
          ],
          const SizedBox(height: 20),
          GradientAction(
            label: saving ? 'SAVING MEASURES' : 'SAVE MEASURES',
            icon: Icons.save_rounded,
            onPressed: saving ? null : _save,
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    final values = [
      _optionalValue(leftBalance),
      _optionalValue(rightBalance),
      _optionalValue(broadJump),
      _optionalValue(sprint),
      _optionalValue(changeDirection),
    ];
    final enteredInvalid =
        [
          leftBalance,
          rightBalance,
          broadJump,
          sprint,
          changeDirection,
        ].asMap().entries.any(
          (entry) =>
              entry.value.text.trim().isNotEmpty && values[entry.key] == null,
        );
    if (enteredInvalid ||
        values.whereType<double>().any((value) => value <= 0)) {
      setState(() => error = 'Use positive numbers or leave a measure blank.');
      return;
    }
    if (values.every((value) => value == null) && notes.text.trim().isEmpty) {
      setState(() => error = 'Record at least one measure or a note.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final assessment = AthleticAssessment(
      programRun: widget.store.athleticProgramRun,
      recordedAt: DateTime.now(),
      leftBalanceSeconds: values[0],
      rightBalanceSeconds: values[1],
      broadJumpCentimeters: values[2],
      sprint10MetersSeconds: values[3],
      changeOfDirection505Seconds: values[4],
      movementQuality: quality.round(),
      notes: notes.text.trim(),
    );
    try {
      await widget.store.saveAthleticAssessment(assessment);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save the measures. Try again.';
        });
      }
    }
  }
}

class _MeasureField extends StatelessWidget {
  const _MeasureField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
  );
}

class AthleticHistoryScreen extends StatelessWidget {
  const AthleticHistoryScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Athletic history')),
    body: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final records = List<AthleticSessionRecord>.of(store.athleticHistory)
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        final assessments = List<AthleticAssessment>.of(
          store.athleticAssessments,
        )..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        return BrandBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const BrandSectionLabel('Completed sessions'),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const LabPanel(
                  child: Text(
                    'No athletic sessions completed yet.',
                    style: TextStyle(color: BrandColors.muted),
                  ),
                )
              else
                for (final record in records) ...[
                  _HistorySessionCard(record: record),
                  if (record != records.last) const SizedBox(height: 10),
                ],
              const SizedBox(height: 26),
              const BrandSectionLabel('Field measures'),
              const SizedBox(height: 12),
              if (assessments.isEmpty)
                const LabPanel(
                  child: Text(
                    'No field measures recorded yet.',
                    style: TextStyle(color: BrandColors.muted),
                  ),
                )
              else
                for (final assessment in assessments) ...[
                  _HistoryAssessmentCard(assessment: assessment),
                  if (assessment != assessments.last)
                    const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    ),
  );
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({required this.record});

  final AthleticSessionRecord record;

  @override
  Widget build(BuildContext context) {
    final week = AthleticProgram.week(record.week);
    final session = week.sessions[record.sessionIndex];
    return LabPanel(
      padding: const EdgeInsets.all(14),
      accent: BrandColors.success,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: BrandColors.success),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Run ${record.programRun} · Week ${record.week} · ${_formatDate(record.completedAt)} · Effort ${record.effort}/10',
                  style: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 11,
                  ),
                ),
                if (record.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(record.notes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryAssessmentCard extends StatelessWidget {
  const _HistoryAssessmentCard({required this.assessment});

  final AthleticAssessment assessment;

  @override
  Widget build(BuildContext context) => LabPanel(
    padding: const EdgeInsets.all(14),
    accent: BrandColors.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.science_rounded, color: BrandColors.cyan),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Run ${assessment.programRun} · ${_formatDate(assessment.recordedAt)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${assessment.movementQuality}/5',
              style: const TextStyle(
                color: BrandColors.violet,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MeasureChip(
              'L BAL',
              _historyValue(assessment.leftBalanceSeconds, 's'),
            ),
            _MeasureChip(
              'R BAL',
              _historyValue(assessment.rightBalanceSeconds, 's'),
            ),
            _MeasureChip(
              'BROAD',
              _historyValue(assessment.broadJumpCentimeters, 'cm'),
            ),
            _MeasureChip(
              '10 M',
              _historyValue(assessment.sprint10MetersSeconds, 's'),
            ),
            _MeasureChip(
              '5-0-5',
              _historyValue(assessment.changeOfDirection505Seconds, 's'),
            ),
          ],
        ),
        if (assessment.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            assessment.notes,
            style: const TextStyle(color: BrandColors.muted),
          ),
        ],
      ],
    ),
  );

  static String _historyValue(double? value, String suffix) => value == null
      ? '—'
      : '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} $suffix';
}

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
