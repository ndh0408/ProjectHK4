import '../../../shared/models/user.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);

  final User user;
}

/// The account exists but the email hasn't been verified yet — the user
/// must enter the OTP before any authenticated action is permitted.
class PendingEmailVerification extends AuthState {
  const PendingEmailVerification({
    required this.email,
    required this.otpExpiresInSeconds,
  });

  final String email;
  final int otpExpiresInSeconds;
}

class Unauthenticated extends AuthState {
  const Unauthenticated([this.message]);

  final String? message;
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}
