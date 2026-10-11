import 'package:flutter/material.dart';
import '../../data/muscles.dart';
import '../../theme/app_theme.dart';
import 'muscle_analysis.dart';

const _readyColor = AppColors.lime;
const _recoveringColor = Color(0xFFE8C547);
const _tiredColor = AppColors.orange;
const _bodyColor = Color(0xFF26262A);

Color recoveryColor(RecoveryStatus status) => switch (status) {
      RecoveryStatus.fresh => _readyColor,
      RecoveryStatus.recovering => _recoveringColor,
      RecoveryStatus.tired => _tiredColor,
    };

String recoveryLabel(RecoveryStatus status) => switch (status) {
      RecoveryStatus.fresh => 'Ready',
      RecoveryStatus.recovering => 'Recovering',
      RecoveryStatus.tired => 'Worked hard',
    };

/// One muscle region of the figure, in a 100 x 200 box.
class _Region {
  final Muscle muscle;
  final Path path;
  _Region(this.muscle, this.path);
}

Path _ellipse(double cx, double cy, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));

Path _rrect(double l, double t, double r, double b, [double radius = 4]) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

Path _both(Path Function(double side) half) => Path()
  ..addPath(half(-1), Offset.zero)
  ..addPath(half(1), Offset.zero);

/// Mirror helper: x offset from the centre line (50).
double _x(double side, double fromCentre) => 50 + side * fromCentre;

final _front = <_Region>[
  _Region(Muscle.chest, _both((s) => _rrect(s < 0 ? 36 : 51, 33, s < 0 ? 49 : 64, 49, 6))),
  _Region(Muscle.frontDelts, _both((s) => _ellipse(_x(s, 19), 37, 7, 7))),
  _Region(Muscle.biceps, _both((s) => _ellipse(_x(s, 24), 54, 5, 10))),
  _Region(Muscle.forearms, _both((s) => _ellipse(_x(s, 28), 77, 4.5, 11))),
  _Region(Muscle.abs, _rrect(41, 52, 59, 84, 5)),
  _Region(Muscle.quads, _both((s) => _ellipse(_x(s, 8), 114, 7.5, 21))),
  _Region(Muscle.calves, _both((s) => _ellipse(_x(s, 8), 162, 5, 15))),
];

final _back = <_Region>[
  _Region(Muscle.traps, Path()..addPolygon([const Offset(39, 31), const Offset(61, 31), const Offset(50, 47)], true)),
  _Region(Muscle.rearDelts, _both((s) => _ellipse(_x(s, 19), 37, 7, 7))),
  _Region(Muscle.upperBack, _rrect(38, 40, 62, 55, 5)),
  _Region(Muscle.lats, _both((s) => Path()
    ..addPolygon([
      Offset(_x(s, 13), 42),
      Offset(_x(s, 16), 46),
      Offset(_x(s, 11), 72),
      Offset(_x(s, 7), 66),
    ], true))),
  _Region(Muscle.triceps, _both((s) => _ellipse(_x(s, 24), 54, 5, 10))),
  _Region(Muscle.forearms, _both((s) => _ellipse(_x(s, 28), 77, 4.5, 11))),
  _Region(Muscle.lowerBack, _rrect(43, 58, 57, 82, 5)),
  _Region(Muscle.glutes, _both((s) => _ellipse(_x(s, 7), 94, 8, 8))),
  _Region(Muscle.hamstrings, _both((s) => _ellipse(_x(s, 8), 124, 7, 19))),
  _Region(Muscle.calves, _both((s) => _ellipse(_x(s, 8), 162, 6, 15))),
];

/// Non-muscle body outline drawn under the regions.
Path _silhouette() => Path()
  ..addOval(Rect.fromCenter(center: const Offset(50, 14), width: 20, height: 22))
  ..addRRect(RRect.fromLTRBR(45, 22, 55, 30, const Radius.circular(3)))
  ..addRRect(RRect.fromLTRBR(32, 29, 68, 88, const Radius.circular(12)))
  ..addRRect(RRect.fromLTRBR(38, 84, 62, 100, const Radius.circular(8)))
  ..addPath(_both((s) => _rrect(_x(s, s < 0 ? 33 : 19), 31, _x(s, s < 0 ? 19 : 33), 92, 7)), Offset.zero)
  ..addPath(_both((s) => _rrect(_x(s, s < 0 ? 16 : 1), 92, _x(s, s < 0 ? 1 : 16), 182, 7)), Offset.zero);

class _BodyPainter extends CustomPainter {
  final List<_Region> regions;
  final Color Function(Muscle) colorFor;
  final Muscle? selected;

  _BodyPainter(this.regions, this.colorFor, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 190;
    canvas.translate((size.width - 100 * scale) / 2, 0);
    canvas.scale(scale);
    canvas.drawPath(_silhouette(), Paint()..color = _bodyColor);
    for (final r in regions) {
      canvas.drawPath(r.path, Paint()..color = colorFor(r.muscle));
      // A surface-coloured edge keeps neighbouring regions apart.
      canvas.drawPath(
        r.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.muscle == selected ? 1.6 : 0.8
          ..color = r.muscle == selected ? AppColors.text : AppColors.surface,
      );
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.selected != selected || old.colorFor != colorFor;
}

/// Front and back figures coloured by recovery; tap a muscle for details.
class RecoveryMap extends StatefulWidget {
  final Map<Muscle, double> load;
  const RecoveryMap({super.key, required this.load});

  @override
  State<RecoveryMap> createState() => _RecoveryMapState();
}

class _RecoveryMapState extends State<RecoveryMap> {
  Muscle? _selected;

  Color _colorFor(Muscle m) => recoveryColor(statusFor(recoveryFor(m, widget.load)));

  Widget _figure(String label, List<_Region> regions) {
    return Expanded(
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            const height = 220.0;
            return GestureDetector(
              onTapUp: (details) {
                final scale = height / 190;
                final dx = (constraints.maxWidth - 100 * scale) / 2;
                final p = Offset((details.localPosition.dx - dx) / scale, details.localPosition.dy / scale);
                final hit = regions.where((r) => r.path.contains(p)).firstOrNull;
                setState(() => _selected = hit?.muscle);
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _BodyPainter(regions, _colorFor, _selected),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(label, style: AppText.eyebrow),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final byStatus = <RecoveryStatus, List<Muscle>>{};
    for (final m in Muscle.values) {
      byStatus.putIfAbsent(statusFor(recoveryFor(m, widget.load)), () => []).add(m);
    }

    return Semantics(
      label: 'Muscle recovery. '
          '${RecoveryStatus.values.map((s) => '${recoveryLabel(s)}: ${(byStatus[s] ?? []).map((m) => m.label).join(', ')}').join('. ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [_figure('FRONT', _front), _figure('BACK', _back)]),
          const SizedBox(height: 12),
          if (selected != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: _colorFor(selected), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(selected.label, style: AppText.strong)),
                  Text(
                    '${(recoveryFor(selected, widget.load) * 100).round()}% recovered · '
                    '${recoveryLabel(statusFor(recoveryFor(selected, widget.load)))}',
                    style: AppText.muted,
                  ),
                ],
              ),
            )
          else
            const Text('Tap a muscle to see how recovered it is.', textAlign: TextAlign.center, style: AppText.muted),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final s in RecoveryStatus.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: recoveryColor(s), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(recoveryLabel(s), style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
            ],
          ),
          if ((byStatus[RecoveryStatus.tired] ?? []).isNotEmpty ||
              (byStatus[RecoveryStatus.recovering] ?? []).isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final s in [RecoveryStatus.tired, RecoveryStatus.recovering])
              if ((byStatus[s] ?? []).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${recoveryLabel(s)}: ',
                        style: TextStyle(fontWeight: FontWeight.w700, color: recoveryColor(s)),
                      ),
                      TextSpan(text: byStatus[s]!.map((m) => m.label).join(', '), style: AppText.muted),
                    ]),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// Front and back figures with the muscles an exercise works: [primary]
/// in lime, [secondary] in a lighter lime.
class MuscleHighlight extends StatelessWidget {
  final List<Muscle> primary;
  final List<Muscle> secondary;
  final double height;

  const MuscleHighlight({super.key, required this.primary, required this.secondary, this.height = 170});

  Color _colorFor(Muscle m) => primary.contains(m)
      ? AppColors.lime
      : secondary.contains(m)
          ? AppColors.lime.withValues(alpha: 0.4)
          : const Color(0xFF3A3A3F);

  @override
  Widget build(BuildContext context) {
    Widget figure(String label, List<_Region> regions) => Expanded(
          child: Column(
            children: [
              CustomPaint(size: Size(double.infinity, height), painter: _BodyPainter(regions, _colorFor, null)),
              const SizedBox(height: 4),
              Text(label, style: AppText.eyebrow),
            ],
          ),
        );

    return Semantics(
      label: 'Works ${primary.map((m) => m.label).join(', ')}'
          '${secondary.isEmpty ? '' : '; also ${secondary.map((m) => m.label).join(', ')}'}',
      child: ExcludeSemantics(
        child: Row(children: [figure('FRONT', _front), figure('BACK', _back)]),
      ),
    );
  }
}
