import '../models/models.dart';
import 'month_utils.dart';

/// Reconstrói um [DashboardData] a partir das listas de vendas/transações já
/// cacheadas localmente — usado quando a resposta do servidor pra
/// `GET /dashboard` ainda não sabe de mutações feitas offline (ou quando não
/// há conexão nenhuma). Espelha exatamente a lógica de
/// `back_mari/src/routes/dashboard.routes.ts` + `back_mari/src/lib/month.ts`,
/// inclusive o detalhe de que `activity` não é filtrado por mês, mas
/// `ganhos`/`despesas`/`saldoDoMes` são (em UTC).
DashboardData buildDashboardDataFromCache({
  required List<Sale> sales,
  required List<Transaction> transactions,
  String? month,
}) {
  final resolvedMonth = month ?? _currentMonthUtc();
  final bounds = monthDateRangeUtc(resolvedMonth);

  bool inMonth(DateTime date) =>
      !date.isBefore(bounds.start) && date.isBefore(bounds.end);

  final salesTotal = sales
      .where((s) => inMonth(s.createdAt))
      .fold<double>(0, (sum, s) => sum + s.total);
  final incomeSum = transactions
      .where((t) => t.type == TransactionType.income && inMonth(t.occurredAt))
      .fold<double>(0, (sum, t) => sum + t.amount);
  final despesas = transactions
      .where(
        (t) => t.type == TransactionType.expense && inMonth(t.occurredAt),
      )
      .fold<double>(0, (sum, t) => sum + t.amount);
  final ganhos = salesTotal + incomeSum;

  final activity =
      <DashboardActivity>[
          for (final sale in sales)
            DashboardActivity(
              id: sale.id,
              kind: 'sale',
              date: sale.createdAt,
              description: sale.product != null
                  ? 'Venda – ${sale.product!.name} (${sale.quantity} un.)'
                  : 'Venda (${sale.quantity} un.)',
              category: 'Venda',
              amount: sale.total,
              quantity: sale.quantity,
            ),
          for (final transaction in transactions)
            DashboardActivity(
              id: transaction.id,
              kind: 'transaction',
              date: transaction.occurredAt,
              description: transaction.category,
              category: transaction.category,
              amount: transaction.type == TransactionType.expense
                  ? -transaction.amount
                  : transaction.amount,
            ),
        ]
        ..sort((a, b) => b.date.compareTo(a.date));

  return DashboardData(
    month: resolvedMonth,
    saldoDoMes: ganhos - despesas,
    ganhos: ganhos,
    despesas: despesas,
    activity: activity.take(10).toList(),
  );
}

String _currentMonthUtc() {
  final now = DateTime.now().toUtc();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
