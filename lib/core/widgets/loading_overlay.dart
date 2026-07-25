import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Overlay de carregamento padrão do app: escurece e bloqueia a tela atual
/// com um indicador central enquanto uma requisição está em andamento.
/// Usado em toda ação que depende de uma chamada à API (salvar, excluir,
/// entrar, etc.), tanto no mobile quanto no desktop, pra impedir que o
/// usuário mexa na tela ou navegue pra longe no meio da requisição.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.contrastShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            message!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
