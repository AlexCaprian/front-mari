import 'package:dio/dio.dart';

import '../models/models.dart';
import 'dio_client.dart';

class ApiRoutes {
  static const String baseUrl = 'https://192.168.18.152/babybox';

  // Auth
  static Future<Response> register(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post(
      '/auth/register',
      body: body,
    );
    await _persistSession(response);
    return response;
  }

  static Future<Response> login(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post('/auth/login', body: body);
    await _persistSession(response);
    return response;
  }

  static Future<void> _persistSession(Response response) async {
    final data = response.data;
    if (data is! Map || data['token'] is! String) return;

    final expiresAtRaw = data['expiresAt'];
    final expiresAt = expiresAtRaw is String
        ? DateTime.tryParse(expiresAtRaw)
        : null;
    await DioClient.setToken(data['token'] as String, expiresAt: expiresAt);
  }

  // Account
  static Future<Account> getAccount() async {
    final response = await DioClient.instance.get('/account/me');
    return Account.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Account> updateAccount(Map<String, dynamic> body) async {
    final response = await DioClient.instance.put('/account/me', body: body);
    return Account.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<String> rotateAccountCode() async {
    final response = await DioClient.instance.post('/account/rotate-code');
    return (response.data as Map<String, dynamic>)['code'] as String;
  }

  // Products
  static Future<List<Product>> getProducts() async {
    final response = await DioClient.instance.get('/products');
    return (response.data as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Product> createProduct(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post('/products', body: body);
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Product> updateProduct(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await DioClient.instance.put('/products/$id', body: body);
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteProduct(String id) =>
      DioClient.instance.delete('/products/$id');

  // Sales
  static Future<List<Sale>> getSales({
    String? startDate,
    String? endDate,
  }) async {
    final response = await DioClient.instance.get(
      '/sales',
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );
    return (response.data as List)
        .map((e) => Sale.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Sale> createSale(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post('/sales', body: body);
    return Sale.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Sale> updateSale(String id, Map<String, dynamic> body) async {
    final response = await DioClient.instance.put('/sales/$id', body: body);
    return Sale.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteSale(String id) =>
      DioClient.instance.delete('/sales/$id');

  // Transactions
  static Future<List<Transaction>> getTransactions({
    String? startDate,
    String? endDate,
    String? type,
  }) async {
    final response = await DioClient.instance.get(
      '/transactions',
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (type != null) 'type': type,
      },
    );
    return (response.data as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Transaction> createTransaction(
    Map<String, dynamic> body,
  ) async {
    final response = await DioClient.instance.post('/transactions', body: body);
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Transaction> updateTransaction(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await DioClient.instance.put(
      '/transactions/$id',
      body: body,
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteTransaction(String id) =>
      DioClient.instance.delete('/transactions/$id');

  // Dashboard
  static Future<DashboardData> getDashboard({String? month}) async {
    final response = await DioClient.instance.get(
      '/dashboard',
      queryParameters: {if (month != null) 'month': month},
    );
    return DashboardData.fromJson(response.data as Map<String, dynamic>);
  }

  // Reports
  static Future<MonthlyReport> getMonthlyReport({String? month}) async {
    final response = await DioClient.instance.get(
      '/reports/monthly',
      queryParameters: {if (month != null) 'month': month},
    );
    return MonthlyReport.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<MonthComparison>> compareMonths(
    List<String> months,
  ) async {
    final response = await DioClient.instance.get(
      '/reports/compare',
      queryParameters: {'months': months.join(',')},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['months'] as List)
        .map((e) => MonthComparison.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
