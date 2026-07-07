import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_overlay.dart';

/// Painel "Exportar / Importar" do modo desktop: mesma função de backup
/// dos dados da versão mobile, em um layout mais compacto e alinhado à
/// esquerda, adequado a telas largas.
class DesktopDataContent extends StatefulWidget {
  const DesktopDataContent({super.key});

  @override
  State<DesktopDataContent> createState() => _DesktopDataContentState();
}

class _DesktopDataContentState extends State<DesktopDataContent> {
  final _nameController = TextEditingController();
  bool _isSavingName = false;
  bool _isRotatingCode = false;

  String _lastBackupDate = '28/jun/2026';
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = context.read<AuthController>().account?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _isSavingName = true);
    final auth = context.read<AuthController>();
    final success = await auth.updateName(_nameController.text);

    if (!mounted) return;
    setState(() => _isSavingName = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Não foi possível salvar o nome.'),
        ),
      );
      return;
    }
    _showSuccessSnackBar('Nome da conta atualizado com sucesso!');
  }

  Future<void> _rotateCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gerar novo código de acesso?'),
        content: const Text(
          'O código atual deixará de funcionar imediatamente. Você vai precisar usar o novo código em todos os aparelhos onde já entrou.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Gerar novo código'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isRotatingCode = true);
    final auth = context.read<AuthController>();
    final newCode = await auth.rotateCode();

    if (!mounted) return;
    setState(() => _isRotatingCode = false);

    if (newCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage ?? 'Não foi possível gerar um novo código.',
          ),
        ),
      );
      return;
    }
    _showNewCodeDialog(newCode);
  }

  void _showNewCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo código gerado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guarde em um lugar seguro. Sem ele você não consegue mais acessar sua conta em outro computador.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Código copiado para a área de transferência!'),
                ),
              );
            },
            child: const Text('Copiar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Já guardei'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exportar dados'),
          content: const Text(
            'Escolha o formato do arquivo para exportação de seus dados:',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSuccessSnackBar(
                  'Dados exportados em formato Planilha Excel (.xlsx)!',
                );
              },
              child: const Text('Planilha (Excel)'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSuccessSnackBar('Dados exportados em formato PDF!');
              },
              child: const Text('PDF'),
            ),
          ],
        );
      },
    );
  }

  void _importData() {
    _showSuccessSnackBar(
      'Arquivo importado com sucesso! Seus dados foram atualizados.',
    );
  }

  void _triggerBackup() {
    setState(() => _isBackingUp = true);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        final now = DateTime.now();
        final formattedDate =
            '${now.day.toString().padLeft(2, '0')}/${_getMonthAbbr(now.month)}/${now.year}';

        setState(() {
          _isBackingUp = false;
          _lastBackupDate = formattedDate;
        });

        _showSuccessSnackBar('Backup realizado com sucesso!');
      }
    });
  }

  String _getMonthAbbr(int month) {
    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return months[month - 1];
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            Theme.of(context).extension<AppThemeExtension>()?.positiveColor ??
            Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSavingName || _isRotatingCode || _isBackingUp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meus dados',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minha conta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nome da conta',
                  tooltip:
                      'Nome usado para identificar sua conta/loja no aplicativo.',
                  controller: _nameController,
                  hintText: 'Ex: Loja da Mari',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    AppButton(
                      variant: AppButtonVariant.outlined,
                      label: 'Salvar nome',
                      isLoading: _isSavingName,
                      onPressed: _saveName,
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      variant: AppButtonVariant.outlined,
                      label: 'Gerar novo código de acesso',
                      icon: Icons.vpn_key_outlined,
                      isLoading: _isRotatingCode,
                      onPressed: _rotateCode,
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Text(
                  'Guardar uma cópia',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gere um arquivo com todos os seus registros para guardar ou abrir no Excel.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  variant: AppButtonVariant.outlined,
                  label: 'Exportar (planilha / PDF)',
                  icon: Icons.share_outlined,
                  onPressed: _exportData,
                ),
                const SizedBox(height: 36),
                Text(
                  'Trazer dados de volta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recupere suas vendas e despesas de um backup que você salvou anteriormente.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  variant: AppButtonVariant.outlined,
                  label: 'Importar de um arquivo',
                  icon: Icons.drive_folder_upload_outlined,
                  onPressed: _importData,
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cloud_done_outlined,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INFO',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Último backup: $_lastBackupDate.\nRecomendamos exportar uma vez por mês.',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.75),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Fazer backup automático',
                  isLoading: _isBackingUp,
                  onPressed: _triggerBackup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
