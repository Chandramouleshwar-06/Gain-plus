import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_service.dart';
import '../../services/photo_store.dart';
import '../../sync/firestore_remote_store.dart';
import '../../sync/sync_engine.dart';

/// Sign-in state and sync. Accounts are optional: everything works signed
/// out, and signing in turns on backup and sync.
class AccountProvider extends ChangeNotifier {
  /// False when Firebase couldn't start (e.g. in tests); then sign-in is off.
  final bool available;

  AccountProvider({required this.available}) {
    if (!available) return;
    _engine = SyncEngine(FirestoreRemoteStore());
    user = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
    SharedPreferences.getInstance().then((prefs) {
      final last = prefs.getInt(_lastSyncKey);
      if (last != null) lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(last);
      notifyListeners();
    });
  }

  static const _lastSyncKey = 'last_synced_at';

  SyncEngine? _engine;
  StreamSubscription<User?>? _authSub;
  bool _googleReady = false;

  User? user;
  bool syncing = false;
  DateTime? lastSyncedAt;
  String? lastError;

  /// Called after a sync that pulled changes, so screens can reload.
  VoidCallback? onDataPulled;

  bool get signedIn => user != null;

  /// Syncs now if signed in. Returns false if it failed (offline etc.).
  Future<bool> syncNow() async {
    final uid = user?.uid;
    final engine = _engine;
    if (uid == null || engine == null) return false;
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      final result = await engine.sync(uid);
      lastSyncedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, lastSyncedAt!.millisecondsSinceEpoch);
      if (result.pulled > 0) onDataPulled?.call();
      return true;
    } catch (e) {
      debugPrint('Sync failed: $e');
      lastError = "Couldn't sync. Check your connection.";
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize();
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AccountError("Google didn't return a sign-in token. Please try again.");
    await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    await _afterSignIn();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _authCall(() => FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password));
    await _afterSignIn();
  }

  Future<void> createAccount(String email, String password) async {
    await _authCall(() => FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password));
    await _afterSignIn();
  }

  Future<void> sendPasswordReset(String email) =>
      _authCall(() => FirebaseAuth.instance.sendPasswordResetEmail(email: email));

  Future<void> _afterSignIn() async {
    user = FirebaseAuth.instance.currentUser;
    notifyListeners();
    // Uploads anything done while signed out, and downloads the account's data.
    await syncNow();
  }

  /// Uploads everything, then signs out and clears this phone's copy. If
  /// changes can't be uploaded, throws unless [discardUnsynced] is set.
  Future<void> signOut({bool discardUnsynced = false}) async {
    final uid = user?.uid;
    if (uid == null) return;
    final ok = await syncNow();
    if (!ok && !discardUnsynced) {
      final pending = await SyncEngine.pendingChanges();
      if (pending > 0) throw UnsyncedChangesError(pending);
    }
    await DatabaseService.instance.wipe();
    await PhotoStore.instance.deleteAll();
    await SyncEngine.resetCursors(uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    lastSyncedAt = null;
    await FirebaseAuth.instance.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
    user = null;
    notifyListeners();
    onDataPulled?.call(); // reload everything from the now-empty database
  }

  Future<T> _authCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseAuthException catch (e) {
      throw AccountError(_friendly(e.code));
    }
  }

  static String _friendly(String code) => switch (code) {
        'invalid-email' => "That email address doesn't look right.",
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password.',
        'email-already-in-use' => 'There is already an account with that email. Try signing in.',
        'weak-password' => 'Use a password with at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
        'network-request-failed' => "You're offline. Connect and try again.",
        'operation-not-allowed' => 'This sign-in method is not enabled yet.',
        _ => 'Something went wrong ($code). Please try again.',
      };

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class AccountError implements Exception {
  final String message;
  const AccountError(this.message);

  @override
  String toString() => message;
}

class UnsyncedChangesError implements Exception {
  final int pending;
  const UnsyncedChangesError(this.pending);
}
