import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  // runApp acontece antes do bootstrap terminar: assim a UI (splash do
  // MyApp) aparece na hora, mesmo que a API demore ou esteja inacessível,
  // em vez de deixar a tela nativa travada esperando esse await resolver.
  runApp(MyApp(authController: authController));

  await authController.bootstrap();

  // Se já tem sessão válida, aproveita que o app acabou de confirmar
  // conexão (bootstrap chamou a API) pra tentar sincronizar qualquer
  // pendência salva offline numa sessão anterior.
  if (authController.isAuthenticated) {
    unawaited(SyncService.instance.trySync());
  }
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
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        home: AnimatedBuilder(
          animation: authController,
          builder: (context, _) {
            if (authController.isBootstrapping) {
              return const _SplashScreen();
            }
            return authController.isAuthenticated
                ? const DashboardScreen()
                : const WelcomeScreen();
          },
        ),
      ),
    );
  }
}

/// Tela exibida enquanto `AuthController.bootstrap` roda em paralelo com o
/// primeiro frame — restaura sessão salva e confirma com a API. Some assim
/// que isso termina, com sucesso, erro ou timeout (ver dio_client.dart).
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
  }
}
