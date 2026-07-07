import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/dio_client.dart';
import 'services/sync_service.dart';
import 'state/state.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authController = AuthController();
  await authController.bootstrap();

  // Token expirado ou rejeitado pela API (401) em qualquer chamada: limpa a
  // sessão (estado + storage) e joga o usuário de volta pro login, de onde
  // quer que ele esteja na navegação.
  DioClient.onSessionExpired = () {
    authController.handleSessionExpired();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  };

  // Se já tem sessão válida, aproveita que o app acabou de confirmar
  // conexão (bootstrap chamou a API) pra tentar sincronizar qualquer
  // pendência salva offline numa sessão anterior.
  if (authController.isAuthenticated) {
    unawaited(SyncService.instance.trySync());
  }

  runApp(MyApp(authController: authController));
}

class MyApp extends StatelessWidget {
  MyApp({super.key, AuthController? authController})
    : authController = authController ?? AuthController();

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),
        ChangeNotifierProvider(create: (_) => ProductsController()),
        ChangeNotifierProvider(create: (_) => SalesController()),
        ChangeNotifierProvider(create: (_) => TransactionsController()),
        ChangeNotifierProvider(create: (_) => DashboardController()),
        ChangeNotifierProvider(create: (_) => ReportsController()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'BabyBox',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: authController.isAuthenticated
            ? const DashboardScreen()
            : const WelcomeScreen(),
      ),
    );
  }
}
