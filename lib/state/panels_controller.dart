import 'package:flutter/foundation.dart';

enum PanelKind { none, extensions, downloads, protection, sites, mail, site }

/// Какая выпадающая панель сейчас открыта (расширения / загрузки).
class PanelsController extends ChangeNotifier {
  PanelKind _open = PanelKind.none;
  PanelKind get open => _open;

  void toggle(PanelKind kind) {
    _open = _open == kind ? PanelKind.none : kind;
    notifyListeners();
  }

  void show(PanelKind kind) {
    if (_open == kind) return;
    _open = kind;
    notifyListeners();
  }

  void close() {
    if (_open == PanelKind.none) return;
    _open = PanelKind.none;
    notifyListeners();
  }
}
