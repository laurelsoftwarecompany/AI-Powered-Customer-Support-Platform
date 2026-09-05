import 'package:flutter_test/flutter_test.dart';
import 'package:customer_support_app/features/auth/bloc/auth_bloc.dart';
import 'package:customer_support_app/features/auth/bloc/auth_event.dart';
import 'package:customer_support_app/features/auth/bloc/auth_state.dart';
import 'package:customer_support_app/features/auth/data/auth_repository.dart';
import 'package:customer_support_app/features/auth/data/user_model.dart';
import 'package:customer_support_app/core/network/api_client.dart';
import 'package:customer_support_app/core/storage/token_storage.dart';

class FakeAuthRepo extends AuthRepository {
  final UserModel? stubUser;
  final bool shouldFail;

  FakeAuthRepo({this.stubUser, this.shouldFail = false})
      : super(
          apiClient: ApiClient(tokenStorage: TokenStorage()),
          tokenStorage: TokenStorage(),
          useMock: false,
        );

  @override
  Future<UserModel?> getCurrentUser() async {
    if (shouldFail) throw Exception('Network error');
    return stubUser;
  }

  @override
  Future<UserModel> login({required String email, required String password}) async {
    if (shouldFail) throw Exception('Invalid email or password');
    return stubUser ?? UserModel(id: '1', name: 'Test User', email: email);
  }

  @override
  Future<UserModel> register({required String name, required String email, required String password}) async {
    if (shouldFail) throw Exception('Registration failed');
    return UserModel(id: '2', name: name, email: email);
  }

  @override
  Future<void> logout() async {}
}

void main() {
  group('AuthBloc State Transitions', () {
    test('Initial state is AuthInitial', () {
      final repo = FakeAuthRepo();
      final bloc = AuthBloc(authRepository: repo);
      expect(bloc.state, isA<AuthInitial>());
    });

    test('AppStartedEvent emits Authenticated when user exists', () async {
      final user = UserModel(id: '1', name: 'Sarah Connor', email: 'sarah@example.com');
      final repo = FakeAuthRepo(stubUser: user);
      final bloc = AuthBloc(authRepository: repo);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(AppStartedEvent());
      await pumpEventQueue();

      expect(states, [isA<Authenticated>()]);
      expect((states.first as Authenticated).user?.email, 'sarah@example.com');

      await subscription.cancel();
    });

    test('AppStartedEvent emits Unauthenticated when user is null', () async {
      final repo = FakeAuthRepo(stubUser: null);
      final bloc = AuthBloc(authRepository: repo);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(AppStartedEvent());
      await pumpEventQueue();

      expect(states, [isA<Unauthenticated>()]);

      await subscription.cancel();
    });

    test('LoginSubmittedEvent emits [AuthLoading, Authenticated] on success', () async {
      final user = UserModel(id: '1', name: 'Sarah', email: 'sarah@example.com');
      final repo = FakeAuthRepo(stubUser: user);
      final bloc = AuthBloc(authRepository: repo);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(LoginSubmittedEvent(email: 'sarah@example.com', password: 'Password123!'));
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<AuthLoading>());
      expect(states[1], isA<Authenticated>());

      await subscription.cancel();
    });

    test('LoginSubmittedEvent emits [AuthLoading, AuthFailure] on error', () async {
      final repo = FakeAuthRepo(shouldFail: true);
      final bloc = AuthBloc(authRepository: repo);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(LoginSubmittedEvent(email: 'sarah@example.com', password: 'wrong'));
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<AuthLoading>());
      expect(states[1], isA<AuthFailure>());
      expect((states[1] as AuthFailure).message, contains('Invalid email or password'));

      await subscription.cancel();
    });

    test('LogoutRequestedEvent emits [AuthLoading, Unauthenticated]', () async {
      final repo = FakeAuthRepo();
      final bloc = AuthBloc(authRepository: repo);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(LogoutRequestedEvent());
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<AuthLoading>());
      expect(states[1], isA<Unauthenticated>());

      await subscription.cancel();
    });
  });
}
