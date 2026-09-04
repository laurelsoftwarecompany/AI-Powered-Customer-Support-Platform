import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// App startup event to check if user is already logged in
class AppStartedEvent extends AuthEvent {}

// Triggered when user submits the login form
class LoginSubmittedEvent extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmittedEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

// Triggered when user submits the registration form
class RegisterSubmittedEvent extends AuthEvent {
  final String name;
  final String email;
  final String password;

  const RegisterSubmittedEvent({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [name, email, password];
}

// Triggered when user logs out
class LogoutRequestedEvent extends AuthEvent {}
