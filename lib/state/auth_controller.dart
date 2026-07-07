import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_routes.dart';
import '../services/dio_client.dart';
import '../services/sync_queue.dart';

class AuthController extends ChangeNotifier {
  Account? _account;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  Account? get account => _account;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Chamado uma vez no boot do app, antes do primeiro `runApp`. Restaura o
  /// token salvo e confirma com a API que a conta ainda existe/é válida.
  Future<void> bootstrap() async {
    _isAuthenticated = await DioClient.restoreSession();
    if (_isAuthenticated) {
      try {
        _account = await ApiRoutes.getAccount();
      } on ApiException {
        _isAuthenticated = false;
        await DioClient.logout();
      }
    }
    notifyListeners();
  }

  /// Cria a conta e devolve o código de acesso gerado (pra tela mostrar uma
  /// única vez), ou `null` se a API recusou a criação.
  Future<String?> register({String? name}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await ApiRoutes.register({
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      });
      _account = await ApiRoutes.getAccount();
      _isAuthenticated = true;
      return (response.data as Map)['code'] as String;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiRoutes.login({'code': code});
      _account = await ApiRoutes.getAccount();
      _isAuthenticated = true;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateName(String name) async {
    _errorMessage = null;
    try {
      _account = await ApiRoutes.updateAccount({'name': name.trim()});
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Devolve o novo código gerado, ou `null` se a API recusou.
  Future<String?> rotateCode() async {
    _errorMessage = null;
    try {
      final code = await ApiRoutes.rotateAccountCode();
      notifyListeners();
      return code;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> logout() async {
    await DioClient.logout();
    _clearSession();
  }

  /// Chamado pelo listener de `DioClient.onSessionExpired` (ver main.dart)
  /// quando o token expira ou é rejeitado (401) em qualquer chamada.
  void handleSessionExpired() => _clearSession();

  void _clearSession() {
    _account = null;
    _isAuthenticated = false;
    // Sem isso, uma fila de pendências offline de uma conta poderia tentar
    // sincronizar contra a sessão de outra conta depois de um logout/login
    // no mesmo aparelho.
    unawaited(SyncQueue.instance.clear());
    notifyListeners();
  }
}
