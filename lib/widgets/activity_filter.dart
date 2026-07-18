import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'field_label.dart';

/// Opções de tipo pro filtro de movimentações (Todos/Ganhos/Despesas),
/// usado tanto no Início quanto no Relatório Mensal.
const activityTypeFilters = ['Todos', 'Ganhos', 'Despesas'];

/// Resultado do bottom sheet de filtro de movimentações: descrições
/// selecionadas e/ou um dia específico.
class ActivityFilterResult {
  const ActivityFilterResult({required this.descriptions, required this.day});

  final Set<String> descriptions;
  final DateTime? day;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Aplica o filtro de tipo (Todos/Ganhos/Despesas) + descrições selecionadas
/// + dia específico sobre uma lista de movimentações — mesma lógica usada
/// tanto no Início quanto no Relatório Mensal, pra manter o comportamento
/// de filtro idêntico nas duas telas.
List<DashboardActivity> filterActivityList(
  List<DashboardActivity> activity, {
  required String typeFilter,
  required Set<String> descriptions,
  required DateTime? day,
}) {
  Iterable<DashboardActivity> filtered = activity;
  switch (typeFilter) {
    case 'Ganhos':
      filtered = filtered.where((a) => a.amount >= 0);
      break;
    case 'Despesas':
      filtered = filtered.where((a) => a.amount < 0);
      break;
  }
  if (descriptions.isNotEmpty) {
    filtered = filtered.where((a) => descriptions.contains(a.description));
  }
  if (day != null) {
    filtered = filtered.where((a) => _isSameDay(a.date, day));
  }
  return filtered.toList();
}

/// Botão de filtro (ícone com badge quando há filtro ativo) usado ao lado
/// dos chips de tipo, tanto no Início quanto no Relatório Mensal.
class ActivityFilterButton extends StatelessWidget {
  const ActivityFilterButton({
    super.key,
    required this.hasFilter,
    required this.onPressed,
  });

  final bool hasFilter;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: hasFilter
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          shape: CircleBorder(
            side: BorderSide(
              color: hasFilter
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            tooltip: 'Filtrar movimentações',
            icon: Icon(
              Icons.filter_alt_outlined,
              color: hasFilter
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (hasFilter)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Abre o bottom sheet de filtro de movimentações (dia + descrições),
/// devolvendo o resultado escolhido ou `null` se cancelado.
Future<ActivityFilterResult?> showActivityFilterSheet(
  BuildContext context, {
  required List<String> options,
  required Set<String> initialSelected,
  required DateTime? initialDay,
}) {
  return showModalBottomSheet<ActivityFilterResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ActivityFilterSheet(
      options: options,
      initialSelected: initialSelected,
      initialDay: initialDay,
    ),
  );
}

class _ActivityFilterSheet extends StatefulWidget {
  const _ActivityFilterSheet({
    required this.options,
    required this.initialSelected,
    required this.initialDay,
  });

  final List<String> options;
  final Set<String> initialSelected;
  final DateTime? initialDay;

  @override
  State<_ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<_ActivityFilterSheet> {
  late final Set<String> _selected = Set.of(widget.initialSelected);
  late DateTime? _day = widget.initialDay;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = _query.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtrar movimentações',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_selected.isNotEmpty || _day != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _selected.clear();
                      _day = null;
                    }),
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const FieldLabel(text: 'Dia'),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _day ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('pt', 'BR'),
                );
                if (picked != null) setState(() => _day = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _day != null
                        ? AppTheme.primaryColor
                        : Colors.black.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: _day != null
                          ? AppTheme.primaryColor
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _day == null
                            ? 'Qualquer dia'
                            : '${_day!.day.toString().padLeft(2, '0')}/'
                                  '${_day!.month.toString().padLeft(2, '0')}/'
                                  '${_day!.year}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _day != null
                              ? AppTheme.primaryColor
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (_day != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _day = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: widget.options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nenhuma movimentação registrada ainda.'),
                    )
                  : filteredOptions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nenhum item encontrado.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = filteredOptions[index];
                        return CheckboxListTile(
                          value: _selected.contains(option),
                          title: Text(option),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(option);
                              } else {
                                _selected.remove(option);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  ActivityFilterResult(descriptions: _selected, day: _day),
                ),
                child: Text(
                  _selected.isEmpty && _day == null
                      ? 'Mostrar tudo'
                      : 'Aplicar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
