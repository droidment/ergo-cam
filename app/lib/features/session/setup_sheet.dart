import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../providers/live_session_provider.dart';
import '../../providers/session_setup_provider.dart';

/// Opens the session setup sheet. Changes apply live.
Future<void> showSetupSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) =>
      const FractionallySizedBox(heightFactor: 0.85, child: SetupSheet()),
);

class SetupSheet extends ConsumerWidget {
  const SetupSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(sessionSetupProvider);
    final ctrl = ref.read(sessionSetupProvider.notifier);
    final i = setup.inputs;
    void edit(SessionInputs Function(SessionInputs) f) => ctrl.updateInputs(f);

    Widget toggle(
      String key,
      String title,
      bool value,
      SessionInputs Function(SessionInputs, bool) set, {
      String? subtitle,
    }) => SwitchListTile(
      key: Key(key),
      dense: true,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: (v) => edit((s) => set(s, v)),
    );

    final text = Theme.of(context).textTheme;
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(t, style: text.titleSmall),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Session setup', style: text.titleLarge),
              const Spacer(),
              TextButton(
                key: const Key('setup-reset'),
                onPressed: () => _confirmReset(context, ctrl),
                child: const Text('Reset'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextFormField(
            key: const Key('task-name'),
            initialValue: setup.taskName,
            decoration: const InputDecoration(
              labelText: 'Task',
              hintText: 'e.g. Unload pallet',
            ),
            textInputAction: TextInputAction.next,
            onChanged: ctrl.setTaskName,
          ),
        ),

        header('Load and grip'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            key: const Key('load-kg'),
            initialValue: i.loadKg == 0 ? '' : _kg(i.loadKg),
            decoration: const InputDecoration(
              labelText: 'Load or force',
              suffixText: 'kg',
              hintText: '0',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d?)?')),
            ],
            onChanged: (v) {
              final kg = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              edit((s) => s.copyWith(loadKg: kg));
            },
          ),
        ),
        toggle(
          'shock',
          'Shock or rapid build-up of force',
          i.shockOrRapidForce,
          (s, v) => s.copyWith(shockOrRapidForce: v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<Coupling>(
            key: const Key('coupling'),
            showSelectedIcon: false,
            segments: [
              for (final c in Coupling.values)
                ButtonSegment(
                  value: c,
                  label: Text(switch (c) {
                    Coupling.good => 'Good',
                    Coupling.fair => 'Fair',
                    Coupling.poor => 'Poor',
                    Coupling.unacceptable => 'Unacc.',
                  }),
                ),
            ],
            selected: {i.coupling},
            onSelectionChanged: (c) =>
                edit((s) => s.copyWith(coupling: c.first)),
          ),
        ),

        header('Stance'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final st in Stance.values)
                ChoiceChip(
                  key: Key('stance-${st.name}'),
                  label: Text(st.label),
                  selected: Stance.of(i) == st,
                  onSelected: (_) => edit(st.applyTo),
                ),
            ],
          ),
        ),

        header('Activity'),
        toggle(
          'static',
          'Body part held static > 1 min',
          i.staticPosture,
          (s, v) => s.copyWith(staticPosture: v),
        ),
        toggle(
          'repeated',
          'Small-range action repeated > 4×/min',
          i.repeatedSmallRange,
          (s, v) => s.copyWith(repeatedSmallRange: v),
        ),
        toggle(
          'rapid',
          'Rapid large posture changes or unstable base',
          i.rapidLargeChanges,
          (s, v) => s.copyWith(rapidLargeChanges: v),
        ),

        header('Posture the camera can\'t see'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'A side-view camera can\'t judge these. Turn on what you observe; '
            'they\'re shown as assumptions.',
            style: text.bodySmall,
          ),
        ),
        toggle(
          'trunk-twist',
          'Trunk twisted or bent sideways',
          i.trunkTwistOrSideBend,
          (s, v) => s.copyWith(trunkTwistOrSideBend: v),
        ),
        toggle(
          'neck-twist',
          'Neck twisted or bent sideways',
          i.neckTwistOrSideBend,
          (s, v) => s.copyWith(neckTwistOrSideBend: v),
        ),
        toggle(
          'wrist-flexed',
          'Wrist bent more than 15°',
          i.wristFlexedOver15,
          (s, v) => s.copyWith(wristFlexedOver15: v),
        ),
        toggle(
          'wrist-deviated',
          'Wrist deviated or twisted',
          i.wristDeviatedOrTwisted,
          (s, v) => s.copyWith(wristDeviatedOrTwisted: v),
        ),
        toggle(
          'arm-abducted',
          'Arm abducted (out to the side) or rotated',
          i.armAbductedOrRotated,
          (s, v) => s.copyWith(armAbductedOrRotated: v),
        ),
        toggle(
          'shoulder-raised',
          'Shoulder raised',
          i.shoulderRaised,
          (s, v) => s.copyWith(shoulderRaised: v),
        ),
        toggle(
          'arm-supported',
          'Arm supported or person leaning',
          i.armSupported,
          (s, v) => s.copyWith(armSupported: v),
        ),

        header('Pose model'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<PoseDetectionModel>(
            key: const Key('pose-model'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: PoseDetectionModel.base,
                label: Text('Base (faster)'),
              ),
              ButtonSegment(
                value: PoseDetectionModel.accurate,
                label: Text('Accurate'),
              ),
            ],
            selected: {ref.watch(liveSessionProvider.select((s) => s.model))},
            onSelectionChanged: (m) =>
                ref.read(liveSessionProvider.notifier).setModel(m.first),
          ),
        ),
      ],
    );
  }

  static String _kg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();

  static Future<void> _confirmReset(
    BuildContext context,
    SessionSetupController ctrl,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset setup?'),
        content: const Text('Clears the task, load and all toggles.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      ctrl.reset();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
