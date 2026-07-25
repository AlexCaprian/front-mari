import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_button.dart';
import 'mobile/dashboard_screen.dart';

/// Salvar a credencial no gerenciador de senhas (Google Password Manager /
/// Keychain) só se aplica ao Android/iOS.
bool get _isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class CodeGeneratedScreen extends StatefulWidget {
  const CodeGeneratedScreen({super.key, required this.code});

  /// Código de acesso já gerado pela API no cadastro (POST /auth/register).
  final String code;

  @override
  State<CodeGeneratedScreen> createState() => _CodeGeneratedScreenState();
}

class _CodeGeneratedScreenState extends State<CodeGeneratedScreen> {
  // Segura o código dentro do AutofillGroup para o sistema conseguir capturá-lo
  // ao salvar a credencial.
  late final TextEditingController _codeController = TextEditingController(
    text: widget.code,
  );

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado para a área de transferência!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Pede ao gerenciador de senhas do sistema para guardar o código como
  /// credencial — assim ele fica salvo na conta Google (Android) / Keychain
  /// (iOS) da pessoa e é preenchido automaticamente num próximo login.
  void _saveToPasswordManager() {
    if (_isMobilePlatform) {
      TextInput.finishAutofillContext(shouldSave: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirme na janela do sistema para salvar o código.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copie o código e guarde em um lugar seguro.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final positiveColor = customTheme?.positiveColor ?? Colors.green;
    final negativeColor = customTheme?.negativeColor ?? Colors.red;
    final contrastShadow = customTheme?.premiumShadow ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // 1. Ícone de checkmark verde (sucesso)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: positiveColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: positiveColor,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Título
                Text(
                  'Conta criada!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Subtítulo
                Text(
                  'Este é o seu código de acesso.\nGuarde em um lugar seguro.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),

                // 4. Box do Código Gerado (com sombra de alto contraste)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: contrastShadow,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SEU CÓDIGO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Campo read-only só para exibir o código e, ao mesmo
                      // tempo, expô-lo ao autofill do sistema (o valor precisa
                      // estar num campo dentro do AutofillGroup para ser salvo).
                      TextField(
                        controller: _codeController,
                        readOnly: true,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        textAlign: TextAlign.center,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Botões de Ação (Copiar / Salvar)
                Row(
                  children: [
                    // Botão Copiar
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.outlined,
                        label: 'Copiar',
                        icon: Icons.copy_rounded,
                        onPressed: _copyToClipboard,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Botão Salvar
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.outlined,
                        label: _isMobilePlatform
                            ? 'Salvar no Google'
                            : 'Salvar',
                        icon: Icons.download_rounded,
                        onPressed: _saveToPasswordManager,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // 6. Alerta de Atenção em Vermelho
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: negativeColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: negativeColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: negativeColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATENÇÃO',
                              style: TextStyle(
                                color: negativeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sem este código não dá para recuperar a conta em outro aparelho. Anote agora.',
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
                const SizedBox(height: 48),

                // 7. Botão Principal Continuar
                AppButton(
                  label: 'Já guardei, continuar',
                  fullWidth: true,
                  onPressed: () {
                    // Última chance de pedir ao sistema para salvar o código,
                    // caso a pessoa não tenha tocado em "Salvar no Google".
                    if (_isMobilePlatform) {
                      TextInput.finishAutofillContext(shouldSave: true);
                    }
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                      (route) =>
                          false, // Remove todas as telas anteriores da pilha
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
