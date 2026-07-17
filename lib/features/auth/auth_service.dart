import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9._]{3,30}$');

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> loginWithUsername({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = _normalizeUsername(username);
    DocumentSnapshot<Map<String, dynamic>> usernameDoc;
    try {
      usernameDoc = await _firestore
          .collection('usernames')
          .doc(normalizedUsername)
          .get();
    } on FirebaseException catch (error) {
      throw AuthException(_mapFirestoreError(error));
    }

    if (!usernameDoc.exists) {
      throw AuthException('Username not found.');
    }

    final data = usernameDoc.data();
    final email = data?['email'] as String?;

    if (email == null || email.isEmpty) {
      throw AuthException('Username profile is invalid. Contact admin.');
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseAuthError(error));
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('Unable to sign in. Please try again.');
    }
  }

  Future<void> registerWithEmailUsername({
    required String email,
    required String username,
    required String password,
  }) async {
    final normalizedUsername = _normalizeUsername(username);

    if (!_usernamePattern.hasMatch(username.trim())) {
      throw AuthException(
        'Username must be 3-30 chars and use only letters, numbers, dot, or underscore.',
      );
    }

    final existingUsername = await _firestore
        .collection('usernames')
        .doc(normalizedUsername)
        .get()
        .catchError((error) {
          if (error is FirebaseException) {
            throw AuthException(_mapFirestoreError(error));
          }
          throw AuthException('Could not validate username. Please retry.');
        });
    if (existingUsername.exists) {
      throw AuthException('Username is already taken.');
    }

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseAuthError(error));
    }

    final user = credential.user;
    if (user == null) {
      throw AuthException('Account creation failed. Please try again.');
    }

    final uid = user.uid;
    final normalizedEmail = email.trim().toLowerCase();

    try {
      await _firestore.runTransaction((transaction) async {
        final usernameRef = _firestore
            .collection('usernames')
            .doc(normalizedUsername);
        final userRef = _firestore.collection('users').doc(uid);

        final takenDoc = await transaction.get(usernameRef);
        if (takenDoc.exists) {
          throw AuthException('Username is already taken.');
        }

        transaction.set(usernameRef, {
          'uid': uid,
          'email': normalizedEmail,
          'username': username.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef, {
          'uid': uid,
          'email': normalizedEmail,
          'username': username.trim(),
          'emailVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on AuthException {
      await _cleanupFailedSignup(user);
      rethrow;
    } on FirebaseException catch (error) {
      await _cleanupFailedSignup(user);
      throw AuthException(_mapFirestoreError(error));
    } catch (_) {
      await _cleanupFailedSignup(user);
      throw AuthException('Could not complete account setup. Please retry.');
    }
  }

  Future<void> sendPasswordResetByUsername(String username) async {
    final normalizedUsername = _normalizeUsername(username);
    final usernameDoc = await _firestore
        .collection('usernames')
        .doc(normalizedUsername)
        .get();

    if (!usernameDoc.exists) {
      throw AuthException('Username not found.');
    }

    final email = usernameDoc.data()?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw AuthException('Invalid username profile.');
    }

    await _auth.sendPasswordResetEmail(email: email);
  }

  String _normalizeUsername(String username) {
    final value = username.trim().toLowerCase();
    if (value.isEmpty) {
      throw AuthException('Username is required.');
    }
    return value;
  }

  Future<void> _cleanupFailedSignup(User user) async {
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    final rawMessage = (error.message ?? '').toLowerCase();
    switch (error.code) {
      case 'invalid-email':
        return 'Invalid email format.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase Authentication.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid username or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'expired-action-code':
        return 'Action code expired. Please retry.';
      case 'invalid-action-code':
        return 'Invalid action code.';
      case 'internal-error':
        if (rawMessage.contains('configuration_not_found')) {
          return 'Email/Password sign-in is not enabled. Enable it in Firebase Authentication.';
        }
        return 'Internal Firebase auth error. Please try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _mapFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore permission denied. Deploy rules and verify project setup.';
      case 'unavailable':
        return 'Firestore is unavailable. Check network and try again.';
      case 'not-found':
        return 'Firestore database not found. Create Firestore database first.';
      default:
        return error.message ?? 'Database error during authentication.';
    }
  }
}
