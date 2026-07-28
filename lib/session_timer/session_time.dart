import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SessionTimeManager extends StatefulWidget {
  final Widget child;
  
  const SessionTimeManager({super.key, required this.child});

  @override
  State<SessionTimeManager> createState() => _SessionTimeManagerState();
}

class _SessionTimeManagerState extends State<SessionTimeManager> with WidgetsBindingObserver {
  Timer? _bgTimer;
  // Waktu timeout: 15 menit
  final int _timeoutMinutes = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // Aplikasi masuk ke background
      _startBackgroundTimer();
    } else if (state == AppLifecycleState.resumed) {
      // Aplikasi kembali dibuka (foreground)
      _cancelBackgroundTimer();
    }
  }

  void _startBackgroundTimer() {
    _bgTimer?.cancel();
    _bgTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      // Menutup aplikasi secara paksa setelah 15 menit tidak aktif di background
      SystemNavigator.pop();
    });
  }

  void _cancelBackgroundTimer() {
    // Membatalkan timer jika pengguna kembali membuka aplikasi sebelum 15 menit
    _bgTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
