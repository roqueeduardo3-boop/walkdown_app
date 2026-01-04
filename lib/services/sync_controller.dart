import 'package:flutter/material.dart';
import '../database.dart';

class SyncController extends ChangeNotifier {
  bool _isSyncing = false;
  double _progress = 0.0;
  int _totalItems = 0;
  int _syncedItems = 0;
  String _status = 'Pronto';

  bool get isSyncing => _isSyncing;
  double get progress => _progress;
  int get totalItems => _totalItems;
  int get syncedItems => _syncedItems;
  String get status => _status;

  final WalkdownDatabase _db = WalkdownDatabase.instance;

  Future<void> syncUpBackground(VoidCallback onComplete) async {
    if (_isSyncing) return;

    _isSyncing = true;
    _progress = 0.0;
    _status = 'Sincronizando...';
    notifyListeners();

    try {
      final count = await _db.syncNewWalkdownsToFirestore();
      _progress = 1.0;
      _status = '✅ $count walkdowns enviados';
      await Future.delayed(Duration(seconds: 1));
      onComplete();
    } catch (e) {
      _status = '❌ Erro: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> pullDownBackground(VoidCallback onComplete) async {
    if (_isSyncing) return;

    _isSyncing = true;
    _progress = 0.0;
    _status = 'Baixando do Firestore...';
    notifyListeners();

    try {
      final count = await _db.pullWalkdownsFromFirestore();
      _progress = 1.0;
      _status = '✅ $count walkdowns baixados';
      await Future.delayed(Duration(seconds: 1));
      onComplete();
    } catch (e) {
      _status = '❌ Erro: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
