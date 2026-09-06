import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/api_client.dart';
import 'core/network/websocket_service.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/dashboard/presentation/main_navigation_screen.dart';
import 'features/knowledge/data/knowledge_repository.dart';
import 'features/tickets/bloc/ticket_bloc.dart';
import 'features/tickets/bloc/ticket_event.dart';
import 'features/tickets/data/ticket_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);

  // Flip to `true` to demo the UI with canned data and no backend running.
  const useMockData = false;

  final authRepository = AuthRepository(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    useMock: useMockData,
  );

  final ticketRepository = TicketRepository(
    apiClient: apiClient,
    useMock: useMockData,
  );

  final wsService = WebSocketService(tokenStorage: tokenStorage);

  final chatRepository = ChatRepository(
    apiClient: apiClient,
    wsService: wsService,
    useMock: useMockData,
  );

  final knowledgeRepository = KnowledgeRepository(
    apiClient: apiClient,
  );

  runApp(
    CustomerSupportApp(
      authRepository: authRepository,
      ticketRepository: ticketRepository,
      chatRepository: chatRepository,
      knowledgeRepository: knowledgeRepository,
    ),
  );
}

class CustomerSupportApp extends StatelessWidget {
  final AuthRepository authRepository;
  final TicketRepository ticketRepository;
  final ChatRepository chatRepository;
  final KnowledgeRepository knowledgeRepository;

  const CustomerSupportApp({
    super.key,
    required this.authRepository,
    required this.ticketRepository,
    required this.chatRepository,
    required this.knowledgeRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<TicketRepository>.value(value: ticketRepository),
        RepositoryProvider<ChatRepository>.value(value: chatRepository),
        RepositoryProvider<KnowledgeRepository>.value(value: knowledgeRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) =>
                AuthBloc(
                  authRepository: authRepository,
                  chatRepository: chatRepository,
                )
                  ..add(AppStartedEvent()),
          ),
          BlocProvider<TicketBloc>(
            create: (_) =>
                TicketBloc(ticketRepository: ticketRepository)
                  ..add(LoadTicketsEvent()),
          ),
        ],
        child: MaterialApp(
          title: 'Laurel Desk',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5),
            ),
            useMaterial3: true,
          ),
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is Authenticated) {
          return MainNavigationScreen(user: state.user);
        }

        return const AuthScreen();
      },
    );
  }
}
