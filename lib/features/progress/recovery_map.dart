import 'package:flutter/material.dart';
import '../../data/muscles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'muscle_analysis.dart';

/// Ready muscles are a soft lime so the ones still recovering stand out.
final _readyColor = Color.alphaBlend(AppColors.lime.withValues(alpha: 0.4), AppColors.surface);
const _recoveringColor = Color(0xFFE8C547);
const _tiredColor = AppColors.orange;
const _bodyColor = Color(0xFF2A2A2E);
const _idleColor = Color(0xFF3A3A3F);

Color recoveryColor(RecoveryStatus status) => switch (status) {
      RecoveryStatus.fresh => _readyColor,
      RecoveryStatus.recovering => _recoveringColor,
      RecoveryStatus.tired => _tiredColor,
    };

String recoveryLabel(RecoveryStatus status) => switch (status) {
      RecoveryStatus.fresh => 'Ready',
      RecoveryStatus.recovering => 'Recovering',
      RecoveryStatus.tired => 'Fatigued',
    };

/// "ready in ~5 h", "ready tomorrow", "ready in ~2 days".
String readyInLabel(int hours) {
  if (hours <= 1) return 'ready within the hour';
  if (hours < 20) return 'ready in ~$hours h';
  if (hours < 36) return 'ready tomorrow';
  return 'ready in ~${(hours / 24).round()} days';
}

/// Short form for lists: "<1 h", "5 h", "tomorrow", "2 days".
String readyInShort(int hours) {
  if (hours <= 1) return '<1 h';
  if (hours < 20) return '$hours h';
  if (hours < 36) return 'tomorrow';
  return '${(hours / 24).round()} days';
}

// ---------------------------------------------------------------------------
// The figure, drawn in a 100 x 190 box with the centre line at x = 50.
// Shapes are given for the right half as (distance from centre, y) and
// mirrored; corners are softened by stroking with round joins.

/// One muscle region of the figure.
class _Region {
  final Muscle muscle;
  final Path path;
  _Region(this.muscle, this.path);
}

typedef _Pt = (double, double);

/// A shape on one side ([side] = 1 right, -1 left).
Path _side(List<_Pt> pts, double side) {
  final path = Path()..moveTo(50 + side * pts.first.$1, pts.first.$2);
  for (final (dx, y) in pts.skip(1)) {
    path.lineTo(50 + side * dx, y);
  }
  return path..close();
}

/// The same shape on both sides.
Path _pair(List<_Pt> pts) => Path()
  ..addPath(_side(pts, 1), Offset.zero)
  ..addPath(_side(pts, -1), Offset.zero);

/// One shape across the centre line: [pts] runs down the right half from
/// the centre line; the left half is its mirror.
Path _across(List<_Pt> pts) {
  final all = [...pts, for (final (dx, y) in pts.reversed) (-dx, y)];
  return _side(all, 1);
}

Path _oval(double dx, double cy, double rx, double ry, {bool pair = true}) {
  Path one(double side) =>
      Path()..addOval(Rect.fromCenter(center: Offset(50 + side * dx, cy), width: rx * 2, height: ry * 2));
  return pair ? (Path()..addPath(one(1), Offset.zero)..addPath(one(-1), Offset.zero)) : one(1);
}

Path _merge(List<Path> paths) {
  final out = Path();
  for (final p in paths) {
    out.addPath(p, Offset.zero);
  }
  return out;
}

final _silhouette = _merge([
  _oval(0, 12, 8.5, 10, pair: false),
  _across(const [(0, 19), (4.5, 19), (4.5, 27), (0, 27)]),
  // Torso: shoulders, waist, hips.
  _across(const [(0, 25), (7, 26), (15, 28.5), (19.5, 32), (19, 42), (16.5, 55), (13, 68), (12, 79), (14, 89), (14, 97), (4, 102), (0, 102)]),
  // Arms.
  _pair(const [(17.5, 31), (22, 32), (25, 37), (26, 47), (26.5, 60), (28.5, 72), (29, 86), (27, 92), (23, 92), (21.5, 80), (19.5, 64), (18, 50)]),
  _oval(25, 97, 3.6, 6),
  // Legs.
  _pair(const [(1, 99), (14, 92), (15.5, 106), (14.5, 126), (12.5, 142), (13.5, 156), (12, 172), (10.5, 181), (5, 181), (4, 170), (3, 155), (2.5, 140), (1, 120)]),
  _oval(8, 184, 6, 3.5),
]);

/// The six-pack: three rows of blocks a side, plus the lower abs.
final _abs = _merge([
  for (final (top, bottom) in const [(48.0, 55.5), (57.0, 64.5), (66.0, 73.5)])
    _pair([(1.2, top), (7.5, top + 0.5), (7.8, bottom), (1.2, bottom)]),
  _pair(const [(1.2, 75), (7, 75.5), (6, 88), (1.2, 92)]),
]);

final _front = <_Region>[
  _Region(Muscle.chest, _pair(const [(1.2, 31), (9, 29.5), (15.5, 31), (18, 35), (17, 42), (12, 46), (5, 46.5), (1.2, 44)])),
  _Region(Muscle.frontDelts, _pair(const [(15.5, 29), (19.5, 30.5), (21, 35), (20, 41.5), (17.8, 41), (17.5, 35)])),
  _Region(Muscle.sideDelts, _pair(const [(20.2, 30.8), (23, 32.5), (24.8, 37), (24.5, 43), (21.5, 42), (21.8, 35.5)])),
  _Region(Muscle.biceps, _pair(const [(19, 44), (23.5, 44), (25.3, 50), (25, 58), (21.5, 60), (19.2, 52)])),
  _Region(Muscle.forearms, _pair(const [(20.5, 63.5), (25.8, 62.5), (27.8, 72), (27.8, 82), (25, 88), (22.8, 80), (21, 70)])),
  _Region(Muscle.abs, _abs),
  _Region(Muscle.quads, _pair(const [(2.5, 102), (8, 98), (13.5, 95.5), (15, 106), (13.8, 124), (11.5, 136), (7.5, 138), (4, 134), (2.5, 120)])),
  _Region(Muscle.calves, _pair(const [(4, 146), (11.5, 145), (12.8, 155), (11.2, 168), (8, 172), (5, 167), (3.8, 156)])),
];

final _back = <_Region>[
  _Region(Muscle.traps, _across(const [(0, 21), (4.5, 23), (9, 27), (15, 30), (10, 33), (4, 39), (1.5, 48), (0, 50)])),
  _Region(Muscle.rearDelts, _pair(const [(15.5, 30.5), (19.5, 30.5), (21, 35), (20, 41.5), (17.8, 41), (16.5, 35)])),
  _Region(Muscle.sideDelts, _pair(const [(20.2, 30.8), (23, 32.5), (24.8, 37), (24.5, 43), (21.5, 42), (21.8, 35.5)])),
  _Region(Muscle.upperBack, _pair(const [(5.5, 42), (11.5, 35), (16.5, 33.5), (18, 40), (14, 45.5), (7, 48)])),
  _Region(Muscle.lats, _pair(const [(7, 49.5), (14.5, 46.5), (18.5, 41.5), (17.5, 52), (14.5, 64), (10, 73), (6, 67)])),
  _Region(Muscle.lowerBack, _pair(const [(1.2, 55), (4.5, 51.5), (6.5, 66), (6, 82), (1.2, 84)])),
  _Region(Muscle.triceps, _pair(const [(19, 44), (23.5, 44), (25.3, 50), (25, 58), (21.5, 60), (19.2, 52)])),
  _Region(Muscle.forearms, _pair(const [(20.5, 63.5), (25.8, 62.5), (27.8, 72), (27.8, 82), (25, 88), (22.8, 80), (21, 70)])),
  _Region(Muscle.glutes, _pair(const [(1.2, 87), (8, 85), (13.5, 88), (14.5, 96), (12, 102), (5, 103.5), (1.2, 101)])),
  _Region(Muscle.hamstrings, _pair(const [(2.5, 106), (12.5, 105), (14.5, 114), (13, 130), (10, 139), (5.5, 139), (3, 130), (2.2, 116)])),
  _Region(Muscle.calves, _pair(const [(3.5, 143), (12.5, 143), (13.5, 152), (11.5, 166), (8, 171), (4.8, 166), (3, 153)])),
];

class _BodyPainter extends CustomPainter {
  final List<_Region> regions;
  final Color Function(Muscle) colorFor;
  final Muscle? selected;

  _BodyPainter(this.regions, this.colorFor, this.selected);

  static const _boxHeight = 190.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _boxHeight;
    canvas.translate((size.width - 100 * scale) / 2, 0);
    canvas.scale(scale);

    // Rounded-off body: fill, then a thick round-joined stroke.
    final body = Paint()..color = _bodyColor;
    canvas.drawPath(_silhouette, body);
    canvas.drawPath(
      _silhouette,
      Paint()
        ..color = _bodyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    for (final r in regions) {
      canvas.drawPath(r.path, Paint()..color = colorFor(r.muscle));
      // A body-coloured edge rounds the corners and leaves a small gap
      // between neighbouring muscles.
      canvas.drawPath(
        r.path,
        Paint()
          ..color = _bodyColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeJoin = StrokeJoin.round,
      );
      if (r.muscle == selected) {
        canvas.drawPath(
          r.path,
          Paint()
            ..color = AppColors.text
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.selected != selected || old.colorFor != colorFor;
}

/// Front and back figures side by side; [onTap] gets the muscle tapped
/// (or null for empty space).
class _Figures extends StatelessWidget {
  final Color Function(Muscle) colorFor;
  final Muscle? selected;
  final ValueChanged<Muscle?>? onTap;
  final double height;

  const _Figures({required this.colorFor, this.selected, this.onTap, required this.height});

  Widget _figure(String label, List<_Region> regions) {
    return Expanded(
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onTap == null
                  ? null
                  : (details) {
                      final scale = height / _BodyPainter._boxHeight;
                      final dx = (constraints.maxWidth - 100 * scale) / 2;
                      final p =
                          Offset((details.localPosition.dx - dx) / scale, details.localPosition.dy / scale);
                      onTap!(regions.where((r) => r.path.contains(p)).firstOrNull?.muscle);
                    },
              child: CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _BodyPainter(regions, colorFor, selected),
              ),
            );
          }),
          const SizedBox(height: 6),
          Text(label, style: AppText.eyebrow),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Row(children: [_figure('FRONT', _front), _figure('BACK', _back)]);
}

/// Recovery at a glance: how many muscles are ready, front and back
/// figures coloured by recovery (tap a muscle for details), and the
/// muscles still recovering with when they'll be ready.
class RecoveryMap extends StatefulWidget {
  final Map<Muscle, double> load;

  /// Hours until each recovering muscle is ready, when known.
  final Map<Muscle, int> readyInHours;

  const RecoveryMap({super.key, required this.load, this.readyInHours = const {}});

  @override
  State<RecoveryMap> createState() => _RecoveryMapState();
}

class _RecoveryMapState extends State<RecoveryMap> {
  Muscle? _selected;

  double _recovery(Muscle m) => recoveryFor(m, widget.load);
  RecoveryStatus _status(Muscle m) => statusFor(_recovery(m));
  Color _colorFor(Muscle m) => recoveryColor(_status(m));

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final notReady = [for (final m in Muscle.values) if (_status(m) != RecoveryStatus.fresh) m]
      ..sort((a, b) => _recovery(a).compareTo(_recovery(b)));
    final readyCount = Muscle.values.length - notReady.length;

    return Semantics(
      label: 'Muscle recovery: $readyCount of ${Muscle.values.length} muscles ready. '
          '${notReady.map((m) => '${m.label} ${(_recovery(m) * 100).round()}% recovered').join(', ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$readyCount', style: AppText.display(40)),
                Text('/${Muscle.values.length}', style: AppText.display(24, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('muscles ready to train', style: AppText.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: _Figures(
              colorFor: _colorFor,
              selected: selected,
              height: 230,
              onTap: (m) => setState(() => _selected = m == _selected ? null : m),
            ),
          ),
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
          const SizedBox(height: 14),
          if (selected != null && _status(selected) == RecoveryStatus.fresh)
            _MuscleRow(muscle: selected, recovery: _recovery(selected), color: _colorFor(selected), selected: true)
          else if (notReady.isEmpty)
            const Text(
              'Everything has recovered. A good day for a hard session.',
              textAlign: TextAlign.center,
              style: AppText.muted,
            )
          else ...[
            const Text('STILL RECOVERING', style: AppText.eyebrow),
            const SizedBox(height: 4),
            for (final m in notReady)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selected = m == _selected ? null : m),
                child: _MuscleRow(
                  muscle: m,
                  recovery: _recovery(m),
                  color: _colorFor(m),
                  readyInHours: widget.readyInHours[m],
                  selected: m == selected,
                ),
              ),
          ],
          if (notReady.isNotEmpty || selected != null) ...[
            const SizedBox(height: 6),
            const Text(
              'Tap a muscle on the figure to check it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  final Muscle muscle;
  final double recovery;
  final Color color;
  final int? readyInHours;
  final bool selected;

  const _MuscleRow({
    required this.muscle,
    required this.recovery,
    required this.color,
    this.readyInHours,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final ready = statusFor(recovery) == RecoveryStatus.fresh;
    final when = ready ? 'ready' : (readyInHours == null ? '' : readyInShort(readyInHours!));
    return Semantics(
      label: '${muscle.label}, ${(recovery * 100).round()}% recovered'
          '${ready ? ', ready to train' : readyInHours == null ? '' : ', ${readyInLabel(readyInHours!)}'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceHigh : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Text(muscle.label, style: AppText.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: ProgressBar(value: recovery, height: 6, color: color)),
              const SizedBox(width: 10),
              SizedBox(
                width: 74,
                child: Text(
                  when,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
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
          ? Color.alphaBlend(AppColors.lime.withValues(alpha: 0.4), AppColors.surface)
          : _idleColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Works ${primary.map((m) => m.label).join(', ')}'
          '${secondary.isEmpty ? '' : '; also ${secondary.map((m) => m.label).join(', ')}'}',
      child: ExcludeSemantics(child: _Figures(colorFor: _colorFor, height: height)),
    );
  }
}
