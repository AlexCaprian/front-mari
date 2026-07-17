import 'package:dio/dio.dart';

import 'api_routes.dart';
import 'http_client_config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DioClient {
  DioClient._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiRoutes.baseUrl,
          // Sem isso, uma requisição sem resposta (sem internet, servidor
          // fora do ar, IP da LAN inalcançável) fica pendurada pelo timeout
          // padrão do SO — na prática, "carregando" pra sempre em vez de
          // cair rápido no tratamento de erro de conectividade.
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ) {
    configureHttpClient(_dio);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Já sabemos que expirou: nem manda a requisição, desloga direto.
          if (_expiresAt != null && _expiresAt!.isBefore(DateTime.now())) {
            await _forceLogout();
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'Sessão expirada',
              ),
            );
            return;
          }
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _forceLogout();
          }
          handler.next(error);
        },
      ),
    );
  }

  static final DioClient instance = DioClient._internal();

  final Dio _dio;
  static String? _token;
  static DateTime? _expiresAt;

  /// Callback registrado pela UI (uma vez, na raiz do app) pra saber quando
  /// precisa levar o usuário de volta pra tela de login — seja por logout
  /// manual ou porque o token expirou/foi rejeitado pela API (401).
  static void Function()? onSessionExpired;

  static bool get isAuthenticated => _token != null;

  /// Chamado uma vez na inicialização do app, antes da primeira tela, pra
  /// recarregar a sessão salva no keystore/keychain/DPAPI. Se o token salvo
  /// já tiver expirado, já limpa e não restaura nada.
  static Future<bool> restoreSession() async {
    final token = await TokenStorage.instance.readToken();
    final expiresAt = await TokenStorage.instance.readExpiresAt();

    if (token == null ||
        (expiresAt != null && expiresAt.isBefore(DateTime.now()))) {
      await TokenStorage.instance.clear();
      _token = null;
      _expiresAt = null;
      return false;
    }

    _token = token;
    _expiresAt = expiresAt;
    return true;
  }

  static Future<void> setToken(String token, {DateTime? expiresAt}) async {
    _token = token;
    _expiresAt = expiresAt;
    await TokenStorage.instance.save(token, expiresAt: expiresAt);
  }

  /// Logout manual (botão "Sair"): mesma limpeza do logout forçado, mas sem
  /// reemitir o callback pra UI evitar navegação duplicada — quem chamou já
  /// está no fluxo de navegação.
  static Future<void> logout() async {
    _token = null;
    _expiresAt = null;
    await TokenStorage.instance.clear();
  }

  static Future<void> _forceLogout() async {
    if (_token == null) return; // já deslogado, evita disparar duas vezes
    await logout();
    onSessionExpired?.call();
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _send(() => _dio.get(path, queryParameters: queryParameters));
  }

  Future<Response> post(String path, {dynamic body}) {
    return _send(() => _dio.post(path, data: body));
  }

  Future<Response> put(String path, {dynamic body}) {
    return _send(() => _dio.put(path, data: body));
  }

  Future<Response> delete(String path, {dynamic body}) {
    return _send(() => _dio.delete(path, data: body));
  }

  Future<Response> _send(Future<Response> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (_isConnectivityError(e)) {
        throw ApiException(
          'Sem conexão com a internet. Verifique sua rede e tente novamente.',
          statusCode: e.response?.statusCode,
        );
      }
      final data = e.response?.data;
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : e.message ?? 'Erro de conexão';
      throw ApiException(message, statusCode: e.response?.statusCode);
    }
  }
}

/// `true` para falhas de rede (sem internet, API fora do ar, timeout) — nesses
/// casos o Dio não recebe resposta nenhuma e sua mensagem padrão (`e.message`)
/// é técnica e em inglês, então trocamos por um aviso amigável em vez de
/// mostrar isso cru pro usuário.
bool _isConnectivityError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    default:
      return false;
  }
}
