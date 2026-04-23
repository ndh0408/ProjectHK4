import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId:
        '749860554682-561q7d9r0rqihph1jkb7jhrsdlv9t72u.apps.googleusercontent.com',
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(googleSignInProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._googleSignIn)
      : super(const AuthInitial()) {
    unawaited(_checkAuthStatus());
  }

  final AuthRepository _repository;
  final GoogleSignIn _googleSignIn;

  /// Remembers the last pending-verification handshake so that an error → clearError
  /// cycle on the OTP screen restores the pending state instead of dropping to
  /// Unauthenticated (which would kick the router back to /login).
  PendingEmailVerification? _lastPending;

  Future<void> _checkAuthStatus() async {
    final isAuthenticated = await _repository.isAuthenticated();
    if (isAuthenticated) {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = Authenticated(user);
        return;
      }
    }
    state = const Unauthenticated();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();

    try {
      final result = await _repository.login(
        LoginRequest(email: email, password: password),
      );
      _applyAuthResult(result);
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = AuthError('Error: $e');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    state = const AuthLoading();

    try {
      final result = await _repository.register(
        RegisterRequest(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
        ),
      );
      _applyAuthResult(result);
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('Register error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = AuthError('Error: $e');
    }
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repository.verifyOtp(
        VerifyOtpRequest(email: email, otp: otp),
      );
      state = Authenticated(user);
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('Verify OTP error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = AuthError('Error: $e');
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      await _repository.resendOtp(email);
    } on AuthException catch (e) {
      state = AuthError(e.message);
    }
  }

  void _applyAuthResult(AuthResult result) {
    switch (result) {
      case AuthSuccess(user: final user):
        _lastPending = null;
        state = Authenticated(user);
      case AuthPendingVerification(
          email: final email,
          otpExpiresInSeconds: final expires,
        ):
        final pending = PendingEmailVerification(
          email: email,
          otpExpiresInSeconds: expires,
        );
        _lastPending = pending;
        state = pending;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = const Unauthenticated();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken != null) {
        final user = await _repository.googleAuth(idToken);
        state = Authenticated(user);
      } else if (accessToken != null) {
        final user = await _repository.googleAuthWithAccessToken(
          accessToken: accessToken,
          email: googleUser.email,
          fullName: googleUser.displayName,
          avatarUrl: googleUser.photoUrl,
        );
        state = Authenticated(user);
      } else {
        throw AuthException('Failed to get Google authentication token.');
      }
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = AuthError('Google Sign-In failed: $e');
    }
  }

  Future<void> signInWithQrChallenge({
    required String challengeId,
    required String pollingToken,
  }) async {
    state = const AuthLoading();

    try {
      final user = await _repository.exchangeQrLoginChallenge(
        challengeId: challengeId,
        pollingToken: pollingToken,
      );
      _lastPending = null;
      state = Authenticated(user);
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('QR Sign-In error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = AuthError('QR Sign-In failed: $e');
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _repository.logout();
    _lastPending = null;
    state = const Unauthenticated();
  }

  void clearError() {
    if (state is AuthError) {
      // If the error happened during the OTP handshake, keep the user on the
      // OTP screen; otherwise fall back to the login screen.
      final pending = _lastPending;
      state = pending ?? const Unauthenticated();
    }
  }
}

void unawaited(Future<void>? future) {}

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState is Authenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    return authState.user;
  }
  return null;
});
