import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/body.dart';
import '../../services/photo_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../../utils/format.dart';
import '../profile/profile_provider.dart';
import '../progress/progress_provider.dart';

/// "81.5 cm" or "18.2 %".
String formatMeasurement(MeasurementSite site, double value, Units units) =>
    site.isPercent ? '${(value * 10).round() / 10} %' : units.length(value);

/// Body measurements and progress photos.
class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  List<ProgressPhoto> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await PhotoStore.instance.list();
      if (mounted) setState(() => _photos = photos);
    } catch (e) {
      debugPrint('Could not load photos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final units = profile.units;
    final measured = [for (final s in measurementSites) if (profile.latestMeasurement(s.code) != null) s];

    return Scaffold(
      appBar: AppBar(title: Text('BODY', style: AppText.display(22))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          SectionHeader(
            title: 'Measurements',
            actionLabel: 'Log',
            onAction: () => showLogMeasurementsSheet(context),
          ),
          if (measured.isEmpty)
            AppCard(
              onTap: () => showLogMeasurementsSheet(context),
              child: const Text(
                'Measure your waist, arms and more every few weeks. The tape often shows progress the scale misses.',
                style: AppText.muted,
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final site in measured)
                    _SiteRow(site: site, entries: profile.measurementsFor(site.code), units: units),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Progress photos',
            actionLabel: _photos.length >= 2 ? 'Compare' : null,
            onAction: _photos.length >= 2
                ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComparePhotosScreen(photos: _photos)))
                : null,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_photos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Take front, side and back photos in the same spot and light every few weeks. '
                      'Photos stay on this phone only.',
                      style: AppText.muted,
                    ),
                  )
                else ...[
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 3 / 4,
                    children: [for (final photo in _photos) _Thumb(photo: photo, onChanged: _loadPhotos)],
                  ),
                  const SizedBox(height: 8),
                  const Text('Photos stay on this phone only.', style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  text: 'Add photo',
                  icon: Icons.add_a_photo_rounded,
                  variant: ButtonVariant.secondary,
                  onPressed: () async {
                    if (await addProgressPhoto(context)) await _loadPhotos();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  final MeasurementSite site;
  final List<BodyMeasurement> entries;
  final Units units;
  const _SiteRow({required this.site, required this.entries, required this.units});

  @override
  Widget build(BuildContext context) {
    final latest = entries.last.value;
    final change = latest - entries.first.value;
    final good = site.growthIsGood == null || change == 0 ? null : (change > 0) == site.growthIsGood;
    final changeText = site.isPercent
        ? '${(change.abs() * 10).round() / 10} %'
        : units.length(change.abs());

    return InkWell(
      onTap: () => _showHistory(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(site.label, style: AppText.strong)),
            if (entries.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '${change >= 0 ? '+' : '−'}$changeText',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: good == null ? AppColors.textMuted : (good ? AppColors.lime : AppColors.orange),
                  ),
                ),
              ),
            Text(formatMeasurement(site, latest, units), style: AppText.strong),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SiteHistorySheet(site: site),
    );
  }
}

class _SiteHistorySheet extends StatelessWidget {
  final MeasurementSite site;
  const _SiteHistorySheet({required this.site});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final units = profile.units;
    final entries = profile.measurementsFor(site.code);
    double shown(double v) => site.isPercent ? v : units.fromCm(v);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(site.label.toUpperCase(), style: AppText.display(26)),
            const SizedBox(height: 12),
            if (entries.length >= 2)
              TrendLineChart(
                points: [for (final e in entries) (e.date, shown(e.value))],
                unit: site.isPercent ? '%' : units.lengthLabel,
                semanticsLabel: '${site.label} over ${entries.length} measurements, from '
                    '${formatMeasurement(site, entries.first.value, units)} to '
                    '${formatMeasurement(site, entries.last.value, units)}.',
              )
            else
              const Text('Measure again later to see a trend.', style: AppText.muted),
            const SizedBox(height: 8),
            for (final entry in entries.reversed)
              Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                ),
                onDismissed: (_) {
                  final navigator = Navigator.of(context);
                  final last = entries.length == 1;
                  context.read<ProfileProvider>().deleteMeasurement(entry.id);
                  if (last) navigator.pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(DateFormat('EEE d MMM y').format(entry.date), style: AppText.muted)),
                      Text(formatMeasurement(site, entry.value, units), style: AppText.strong),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            const Text('Swipe an entry to delete it.', style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}

/// Sheet for logging today's measurements; only filled-in sites are saved.
Future<void> showLogMeasurementsSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LogMeasurementsSheet(),
  );
}

class _LogMeasurementsSheet extends StatefulWidget {
  const _LogMeasurementsSheet();

  @override
  State<_LogMeasurementsSheet> createState() => _LogMeasurementsSheetState();
}

class _LogMeasurementsSheetState extends State<_LogMeasurementsSheet> {
  final _controllers = {for (final s in measurementSites) s.code: TextEditingController()};
  bool _saving = false;

  /// Shown in the sheet (a snackbar would be hidden behind it).
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final profile = context.read<ProfileProvider>();
    final prs = context.read<ProgressProvider>().prKgByExerciseId;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final values = <String, double>{};
    for (final site in measurementSites) {
      final v = parseDecimal(_controllers[site.code]!.text);
      if (v == null || v <= 0) continue;
      values[site.code] = site.isPercent ? v : profile.units.toCm(v);
    }
    if (values.isEmpty) {
      setState(() => _error = 'Fill in at least one measurement.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final List<Object> achieved;
    try {
      await profile.logMeasurements(values);
      achieved = await profile.markAchievedGoals(prs);
    } catch (e) {
      debugPrint('Could not save measurements: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save. Please try again.";
        });
      }
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(
        content: Text(achieved.isNotEmpty ? 'Saved. Goal reached, nice work!' : 'Measurements saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final units = profile.units;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text('LOG MEASUREMENTS', style: AppText.display(26)),
              const SizedBox(height: 4),
              const Text('Fill in what you measured today. Measure relaxed, in the morning, at the same spot each time.',
                  style: AppText.muted),
              const SizedBox(height: 12),
              for (final site in measurementSites)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    key: Key('measure-${site.code}'),
                    controller: _controllers[site.code],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: InputDecoration(
                      labelText: site.label,
                      suffixText: site.isPercent ? '%' : units.lengthLabel,
                      hintText: switch (profile.latestMeasurement(site.code)) {
                        null => null,
                        final last => 'Last: ${formatMeasurement(site, last, units)}',
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.orange)),
                ),
              PrimaryButton(text: _saving ? 'Saving...' : 'Save', onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks a pose and a photo (camera or gallery) and stores it. Returns
/// true if a photo was added.
Future<bool> addProgressPhoto(BuildContext context) async {
  var pose = 'front';
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ADD PHOTO', style: AppText.display(26)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in photoPoses)
                    ChoiceChip(
                      label: Text(poseLabel(p)),
                      selected: pose == p,
                      showCheckmark: false,
                      labelStyle: TextStyle(color: pose == p ? AppColors.onLime : AppColors.text),
                      onSelected: (_) => setSheetState(() => pose = p),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Take photo',
                icon: Icons.photo_camera_rounded,
                onPressed: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                text: 'Choose from gallery',
                icon: Icons.photo_library_rounded,
                variant: ButtonVariant.secondary,
                onPressed: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return false;
    await PhotoStore.instance.add(File(picked.path), date: DateTime.now(), pose: pose);
    return true;
  } catch (e) {
    debugPrint('Could not add photo: $e');
    messenger.showSnackBar(const SnackBar(content: Text("Couldn't add the photo. Please try again.")));
    return false;
  }
}

class _Thumb extends StatelessWidget {
  final ProgressPhoto photo;
  final VoidCallback onChanged;
  const _Thumb({required this.photo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${poseLabel(photo.pose)} photo, ${DateFormat('d MMM y').format(photo.date)}',
      child: GestureDetector(
        onTap: () async {
          final deleted = await Navigator.of(context)
              .push<bool>(MaterialPageRoute(builder: (_) => PhotoViewerScreen(photo: photo)));
          if (deleted == true) onChanged();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(photo.path), fit: BoxFit.cover, cacheWidth: 300),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: const Color(0x99000000),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    '${DateFormat('d MMM').format(photo.date)} · ${poseLabel(photo.pose)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One photo, full screen. Pops true if it was deleted.
class PhotoViewerScreen extends StatelessWidget {
  final ProgressPhoto photo;
  const PhotoViewerScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${poseLabel(photo.pose)} · ${DateFormat('d MMM y').format(photo.date)}'),
        actions: [
          IconButton(
            tooltip: 'Delete photo',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Delete photo?', message: "It can't be recovered.", confirmLabel: 'Delete', destructive: true);
              if (!ok || !context.mounted) return;
              await PhotoStore.instance.delete(photo);
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: InteractiveViewer(child: Center(child: Image.file(File(photo.path)))),
    );
  }
}

/// Two photos side by side; starts with the oldest and newest of one pose.
class ComparePhotosScreen extends StatefulWidget {
  final List<ProgressPhoto> photos;
  const ComparePhotosScreen({super.key, required this.photos});

  @override
  State<ComparePhotosScreen> createState() => _ComparePhotosScreenState();
}

class _ComparePhotosScreenState extends State<ComparePhotosScreen> {
  late ProgressPhoto _before;
  late ProgressPhoto _after;

  @override
  void initState() {
    super.initState();
    // Newest first: pick the pose with the most photos, then its ends.
    final byPose = {for (final p in photoPoses) p: widget.photos.where((x) => x.pose == p).toList()};
    final pose = photoPoses.reduce((a, b) => byPose[b]!.length > byPose[a]!.length ? b : a);
    final list = byPose[pose]!.length >= 2 ? byPose[pose]! : widget.photos;
    _after = list.first;
    _before = list.last;
  }

  Future<void> _pick(bool before) async {
    final picked = await showModalBottomSheet<ProgressPhoto>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3 / 4,
            children: [
              for (final photo in widget.photos)
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext, photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(photo.path), fit: BoxFit.cover, cacheWidth: 300),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() => before ? _before = picked : _after = picked);
  }

  @override
  Widget build(BuildContext context) {
    final days = _after.date.difference(_before.date).inDays.abs();
    Widget side(ProgressPhoto photo, String label, bool before) => Expanded(
          child: GestureDetector(
            onTap: () => _pick(before),
            child: Column(
              children: [
                Text(label, style: AppText.eyebrow),
                const SizedBox(height: 4),
                Text(DateFormat('d MMM y').format(photo.date), style: AppText.strong),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(photo.path), fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text('COMPARE', style: AppText.display(22))),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  side(_before, 'BEFORE', true),
                  const SizedBox(width: 8),
                  side(_after, 'AFTER', false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              days == 0 ? 'Tap a photo to change it.' : '$days days apart · tap a photo to change it.',
              style: AppText.muted,
            ),
          ],
        ),
      ),
    );
  }
}
