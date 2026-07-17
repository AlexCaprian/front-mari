import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla o tamanho da fonte do app (aumentar/diminuir em passos de 1),
/// persistindo a preferência localmente pra continuar aplicada nas próximas
/// vezes que o app abrir.
class FontScaleController extends ChangeNotifier {
  static const _prefsKey = 'font_scale_step';
  static const double _stepSize = 0.1;
  static const int minStep = -3;
  static const int maxStep = 3;

  int _step = 0;

  int get step => _step;
  double get scale => 1.0 + (_step * _stepSize);
  bool get canIncrease => _step < maxStep;
  bool get canDecrease => _step > minStep;

  /// Lê o passo salvo (se houver) — chamado uma vez no boot do app.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefsKey);
    if (saved != null) {
      _step = saved.clamp(minStep, maxStep);
      notifyListeners();
    }
  }

  Future<void> increase() => _setStep(_step + 1);

  Future<void> decrease() => _setStep(_step - 1);

  Future<void> _setStep(int next) async {
    final clamped = next.clamp(minStep, maxStep);
    if (clamped == _step) return;
    _step = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, _step);
  }
}
