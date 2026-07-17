import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/responsive_layout.dart';
import 'code_generated_screen.dart';
import 'dashboard_screen.dart';

/// Formata a entrada do usuário para a máscara "MC-XXXX-XXXX" automaticamente
class CodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase();

    // Se o texto for vazio, limpa tudo
    if (text.isEmpty) {
      return newValue;
    }

    // Se o usuário estiver apagando e sobrar apenas parte do prefixo "MC-", permite limpar tudo
    if (text.length < oldValue.text.length &&
        oldValue.text.startsWith('MC-') &&
        text.length <= 3) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Garante que o texto comece com "MC-"
    if (!text.startsWith('MC-')) {
      // Se digitar apenas letras/números, insere o prefixo na frente
      text = 'MC-$text';
    }

    // Filtra apenas caracteres válidos (A-Z, 0-9) após o "MC-"
    String cleanText = text.substring(3).replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Limita o conteúdo líquido a 8 caracteres (para formar MC-XXXX-XXXX)
    if (cleanText.length > 8) {
      cleanText = cleanText.substring(0, 8);
    }

    // Reconstrói a máscara com o traço intermediário
    String formatted = 'MC-';
    if (cleanText.isNotEmpty) {
      if (cleanText.length <= 4) {
        formatted += cleanText;
      } else {
        formatted += '${cleanText.substring(0, 4)}-${cleanText.substring(4)}';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    // Código válido deve ter exatamente 12 caracteres (ex: MC-7QK4-93BX)
    setState(() {
      _isButtonEnabled = _codeController.text.length == 12;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.login(_codeController.text);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Código inválido.')),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  Future<void> _handleCreateAccount() async {
    final auth = context.read<AuthController>();
    final code = await auth.register();
    if (!mounted) return;

    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Não foi possível criar a conta.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CodeGeneratedScreen(code: code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthController>().isLoading;
    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        body: SafeArea(
          child: ResponsiveLayout(
            mobileBuilder: (context) => _buildMobileBody(context),
            desktopBuilder: (context) => _buildDesktopBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    final isLoading = context.watch<AuthController>().isLoading;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            // 1. Logo circular "R$"
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'R\$',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Título da Aplicação
            Text(
              'Mari',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            // 3. Subtítulo
            Text(
              'Suas vendas e despesas,\nsimples de organizar',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 48),

            // 4. Botão "Criar minha conta"
            AppButton(
              label: 'Criar minha conta',
              isLoading: isLoading,
              onPressed: _handleCreateAccount,
              fullWidth: true,
            ),
            const SizedBox(height: 8),

            // 5. Subtexto descritivo do botão
            Text(
              'gera um código só seu',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 36),

            // 6. Divisor "ou"
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Colors.black.withValues(alpha: 0.12),
                    thickness: 1.2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'ou',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Colors.black.withValues(alpha: 0.12),
                    thickness: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // 7. Seção de login com código
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Já tenho uma conta — digite o código',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message:
                        'Código usado para entrar na sua conta em outro '
                        'aparelho ou recuperar seus dados.',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Campo de entrada do código
            AppTextField(
              controller: _codeController,
              inputFormatters: [CodeInputFormatter()],
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
              hintText: 'MC-XXXX-XXXX',
              filled: true,
              fillColor: Colors.white,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira o código de acesso.';
                }
                if (value.length < 12) {
                  return 'Código incompleto. Formato: MC-XXXX-XXXX';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Botão "Entrar com código"
            AppButton(
              variant: AppButtonVariant.outlined,
              label: 'Entrar com código',
              isLoading: isLoading,
              onPressed: _isButtonEnabled ? _handleLogin : null,
              fullWidth: true,
            ),
            const SizedBox(height: 48),

            // 8. Card de Informação inferior "COMO FUNCIONA"
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMO FUNCIONA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O código identifica sua conta. Use o mesmo código em outro celular para ver os mesmos dados.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Layout dividido em duas colunas para telas largas: painel de marca à
  /// esquerda e formulário de acesso à direita, conforme o wireframe desktop.
  Widget _buildDesktopBody(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildDesktopBrandPanel(context)),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 48.0,
                vertical: 48.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildDesktopFormPanel(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBrandPanel(BuildContext context) {
    return Container(
      color: const Color(0xFF1E0E3D),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'R\$',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mari',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Suas vendas e despesas,\nsimples de organizar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFormPanel(BuildContext context) {
    final isLoading = context.watch<AuthController>().isLoading;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Criar minha conta',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Gere um código só seu para acessar suas vendas e despesas em qualquer computador.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleCreateAccount,
              child: const Text('Criar minha conta'),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.black.withValues(alpha: 0.12),
                  thickness: 1.2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'ou',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.black.withValues(alpha: 0.12),
                  thickness: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Já tenho uma conta — digite o código',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _codeController,
            inputFormatters: [CodeInputFormatter()],
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            hintText: 'MC-XXXX-XXXX',
            filled: true,
            fillColor: Colors.white,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, insira o código de acesso.';
              }
              if (value.length < 12) {
                return 'Código incompleto. Formato: MC-XXXX-XXXX';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isButtonEnabled && !isLoading ? _handleLogin : null,
              child: const Text('Entrar com código'),
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMO FUNCIONA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'O código identifica sua conta. Use o mesmo código em outro computador para ver os mesmos dados.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
