import '../models/models.dart';
import 'month_utils.dart';

/// Monta a lista de atividades (vendas + transações) ordenada da mais
/// recente pra mais antiga, sem nenhum corte de quantidade — ao contrário do
/// `GET /dashboard` do servidor, que limita a 10 itens
/// (`back_mari/src/routes/dashboard.routes.ts`).
List<DashboardActivity> buildActivityList({
  required List<Sale> sales,
  required List<Transaction> transactions,
}) {
  return <DashboardActivity>[
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
}

/// Reconstrói um [DashboardData] a partir das listas de vendas/transações já
/// cacheadas localmente — usado quando a resposta do servidor pra
/// `GET /dashboard` ainda não sabe de mutações feitas offline (ou quando não
/// há conexão nenhuma). `ganhos`/`despesas`/`saldoDoMes` são filtrados por mês
/// (em UTC), igual ao backend; `activity` traz o mês inteiro, sem corte.
DashboardData buildDashboardDataFromCache({
  required List<Sale> sales,
  required List<Transaction> transactions,
  String? month,
}) {
  final resolvedMonth = month ?? _currentMonthUtc();
  final bounds = monthDateRangeUtc(resolvedMonth);

  bool inMonth(DateTime date) =>
      !date.isBefore(bounds.start) && date.isBefore(bounds.end);

  final salesInMonth = sales.where((s) => inMonth(s.createdAt)).toList();
  final transactionsInMonth = transactions
      .where((t) => inMonth(t.occurredAt))
      .toList();

  final salesTotal = salesInMonth.fold<double>(0, (sum, s) => sum + s.total);
  final incomeSum = transactionsInMonth
      .where((t) => t.type == TransactionType.income)
      .fold<double>(0, (sum, t) => sum + t.amount);
  final despesas = transactionsInMonth
      .where((t) => t.type == TransactionType.expense)
      .fold<double>(0, (sum, t) => sum + t.amount);
  final ganhos = salesTotal + incomeSum;

  return DashboardData(
    month: resolvedMonth,
    saldoDoMes: ganhos - despesas,
    ganhos: ganhos,
    despesas: despesas,
    activity: buildActivityList(
      sales: salesInMonth,
      transactions: transactionsInMonth,
    ),
  );
}

String _currentMonthUtc() {
  final now = DateTime.now().toUtc();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
