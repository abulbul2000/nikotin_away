// Google Sign-In service.
//
// Allows users to sign in with their Google account so their data
// (survey, progress, breath tests) can be synced to Firestore.
// On reinstall, signing in again restores everything.
//
// Uses google_sign_in 7.x API (singleton instance, initialize first,
// authenticate() instead of signIn(), separate access token via
// authorizationClient).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static bool _initialized = false;

  // Firebase project's Web OAuth client. Passing this explicitly avoids
  // relying on generated Android resources when google_sign_in initializes.
  static const _serverClientId =
      '269922488535-ku41a5487u3mql48s2l2o6hculqgqskm.apps.googleusercontent.com';

  /// Must be called once at app startup (before signInWithGoogle).
  static Future<void> initialize() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
    _initialized = true;
  }

  /// Sign in with Google. Returns true on success.
  static Future<bool> signInWithGoogle() async {
    try {
      // Full interactive sign in
      final GoogleSignInAccount googleAccount =
          await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // Get auth tokens
      final googleAuth = googleAccount.authentication;
      final idToken = googleAuth.idToken;

      // Get access token via authorization client
      String? accessToken;
      try {
        final authz = await googleAccount.authorizationClient
            .authorizeScopes(['email', 'profile']);
        accessToken = authz.accessToken;
      } catch (e) {
        debugPrint('[GoogleAuth] Access token not available: $e');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      await _signInOrLink(credential);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[GoogleAuth] Sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Signs in with [credential], linking it to the current anonymous user
  /// when one exists. Linking is essential: replacing an anonymous UID with a
  /// newly-created account would orphan the user's existing cloud identity.
  /// If the credential already belongs to an account, normal sign-in is used;
  /// the caller then restores that account's cloud snapshot into the same
  /// local database instead of discarding local rows.
  static Future<UserCredential> _signInOrLink(
    AuthCredential credential,
  ) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'email-already-in-use') {
          rethrow;
        }
        return FirebaseAuth.instance.signInWithCredential(credential);
      }
    }
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Creates or signs in to a Firebase email/password account.
  static Future<bool> signInWithEmail({
    required String email,
    required String password,
    required bool createAccount,
  }) async {
    try {
      if (createAccount) {
        final credential = EmailAuthProvider.credential(
          email: email.trim(),
          password: password,
        );
        await _signInOrLink(credential);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('[Auth] Email account operation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Deletes the current Firebase account. The caller must remove cloud
  /// documents first; Firebase may require recent authentication.
  static Future<void> deleteCurrentAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    await user.delete();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  /// Sign out (both Google and Firebase).
  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Whether user is signed in (any method — Google or anonymous).
  static bool get isLoggedIn =>
      FirebaseAuth.instance.currentUser != null;

  /// Whether signed in with a cloud-backed non-anonymous account.
  static bool get isCloudUser =>
      FirebaseAuth.instance.currentUser != null &&
      !(FirebaseAuth.instance.currentUser?.isAnonymous ?? true);

  /// Whether signed in specifically with Google.
  static bool get isGoogleUser =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  /// User's display name (from Google).
  static String? get displayName =>
      FirebaseAuth.instance.currentUser?.displayName;

  /// User's email (from Google).
  static String? get email => FirebaseAuth.instance.currentUser?.email;
}
