import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/sync_columns.dart';
import '../models/body.dart';
import '../utils/date_keys.dart';

/// Progress photos, stored as files in the app's private folder. They stay
/// on this phone (they don't sync) and are named
/// `<yyyy-mm-dd>_<pose>_<id>.jpg`, so no database is needed.
class PhotoStore {
  static final PhotoStore instance = PhotoStore();

  /// Where photos live; tests point this somewhere temporary.
  Future<Directory> Function() baseDir;

  PhotoStore({Future<Directory> Function()? baseDir}) : baseDir = baseDir ?? _defaultDir;

  static Future<Directory> _defaultDir() async =>
      Directory(p.join((await getApplicationDocumentsDirectory()).path, 'progress_photos'));

  Future<Directory> _dir() async {
    final dir = await baseDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static final _name = RegExp(r'^(\d{4}-\d{2}-\d{2})_(front|side|back)_([A-Za-z0-9-]+)\.jpg$');

  /// All photos, newest first.
  Future<List<ProgressPhoto>> list() async {
    final dir = await _dir();
    final photos = <ProgressPhoto>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final match = _name.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      photos.add(ProgressPhoto(
        id: match.group(3)!,
        date: parseDateKey(match.group(1)!),
        pose: match.group(2)!,
        path: entity.path,
      ));
    }
    photos.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : photoPoses.indexOf(a.pose).compareTo(photoPoses.indexOf(b.pose));
    });
    return photos;
  }

  /// Copies [source] in as a photo for [date] and [pose].
  Future<ProgressPhoto> add(File source, {required DateTime date, required String pose}) async {
    final dir = await _dir();
    final id = newId();
    final path = p.join(dir.path, '${dateKey(date)}_${pose}_$id.jpg');
    await source.copy(path);
    return ProgressPhoto(id: id, date: DateTime(date.year, date.month, date.day), pose: pose, path: path);
  }

  Future<void> delete(ProgressPhoto photo) async {
    final file = File(photo.path);
    if (await file.exists()) await file.delete();
  }

  /// Removes every photo (on sign-out, so the next person can't see them).
  Future<void> deleteAll() async {
    final dir = await baseDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
