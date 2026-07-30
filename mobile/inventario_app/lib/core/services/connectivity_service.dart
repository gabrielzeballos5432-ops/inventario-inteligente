import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'sync_service.dart';
import 'local_db_service.dart';

class ConnectivityService {
  final SyncService _syncService;
  final LocalDbService _localDb;
  final VoidCallback _onSyncComplete;
  StreamSubscription? _subscription;
  bool _conectadoPreviamente = false;

  ConnectivityService({
    required SyncService syncService,
    required LocalDbService localDb,
    required VoidCallback onSyncComplete,
  })  : _syncService = syncService,
        _localDb = localDb,
        _onSyncComplete = onSyncComplete;

  Future<void> iniciar() async {
    final result = await Connectivity().checkConnectivity();
    _conectadoPreviamente =
        result.any((r) => r != ConnectivityResult.none);

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final conectado = results.any((r) => r != ConnectivityResult.none);
      if (conectado && !_conectadoPreviamente) {
        _syncService.sincronizarPendientes().then((count) {
          if (count > 0) {
            _onSyncComplete();
          }
        });
      }
      _conectadoPreviamente = conectado;
    });
  }

  void detener() {
    _subscription?.cancel();
  }
}
