import 'package:equatable/equatable.dart';
import '../data/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

// Initial state before checking token
class AuthInitial extends AuthState {}

// Showing a loading spinner during API calls
class AuthLoading extends AuthState {}

// User is authenticated and logged in
class Authenticated extends AuthState {
  final UserModel? user;

  const Authenticated({this.user});

  @override
  List<Object?> get props => [user];
}

// User is not logged in (show Login / Register UI)
class Unauthenticated extends AuthState {}

// Error state with a message to display in a SnackBar
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
