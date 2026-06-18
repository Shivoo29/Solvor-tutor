import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/daos/sync_ledger_dao.dart';
import '../core/database/app_database.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  throw UnimplementedError('SyncService must be overridden in main()');
});

class SyncService {
  final AppDatabase _db;
  final SyncLedgerDao _syncDao;
  final String _baseUrl;
  final Connectivity _connectivity;
  StreamSubscription? _subscription;
  bool _pushing = false;

  SyncService(
    this._db, {
    required String baseUrl,
    Connectivity? connectivity,
  })  : _syncDao = SyncLedgerDao(_db),
        _baseUrl = baseUrl,
        _connectivity = connectivity ?? Connectivity();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> start() async {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        flushPending();
      }
    });

    final status = await _connectivity.checkConnectivity();
    if (status.any((r) => r != ConnectivityResult.none)) {
      flushPending();
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> flushPending() async {
    if (_pushing) return;
    _pushing = true;

    try {
      final token = await _getToken();
      if (token == null) return;

      final pending = await _syncDao.getUnprocessedEvents();
      if (pending.isEmpty) return;

      final events = pending
          .map((e) => {
                'id': e.id,
                'eventType': e.eventType,
                'payload': jsonDecode(e.payload),
                'clientTimestamp': e.clientTimestamp.toIso8601String(),
              })
          .toList();

      final response = await http.post(
        Uri.parse('$_baseUrl/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'events': events}),
      );

      if (response.statusCode == 200) {
        for (final entry in pending) {
          await _syncDao.markProcessed(entry.id);
        }
      }
    } catch (err) {
      debugPrint('SyncService: flush failed — $err');
    } finally {
      _pushing = false;
    }
  }
}
