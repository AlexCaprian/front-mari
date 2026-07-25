import 'package:flutter/foundation.dart';

/// Notifica quando a sessão atual termina (logout manual ou token expirado/
/// rejeitado pela API). Os controllers que guardam dados de conta (produtos,
/// vendas, transações, dashboard, relatórios) escutam isso pra limpar o
/// estado em memória — sem isso, ao trocar de conta no mesmo aparelho sem
/// reiniciar o app, uma tela que ainda não chamou `load()` de novo
/// continuaria mostrando os dados da conta anterior por um instante.
class SessionEvents extends ChangeNotifier {
  SessionEvents._internal();

  static final SessionEvents instance = SessionEvents._internal();

  void notifySessionEnded() => notifyListeners();
}
