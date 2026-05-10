// ==================== TIMER SERVICE (VERSIÓN ESTABLE PARA WEB) ====================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';     // ← Necesario para vibración y sonido
import '../models/workout_class.dart';

class WorkoutTimerService extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentBlockIndex = 0;
  int _currentRound = 1;
  bool isWorkingPhase = true;      // true = trabajando, false = descansando
  bool isRunning = false;
  bool isPaused = false;
  bool isPreparing = false;
  int _prepareSeconds = 10;
  WorkoutClass? currentClass;

  final AudioPlayer _audioPlayer = AudioPlayer();

  int get remainingSeconds => _remainingSeconds;
  int get currentBlockIndex => _currentBlockIndex;
  int get currentRound => _currentRound;
  bool get isPreparingNext => isPreparing;
  int get prepareSeconds => _prepareSeconds;
  bool get isWorkPhase => isWorkingPhase;        // ← Getter importante

  WorkoutBlock? get currentBlock => currentClass?.blocks[_currentBlockIndex];

  // ... (mantengo los métodos de sonido que ya tenías)

  void startClass(WorkoutClass workoutClass, {int startFromBlock = 0}) {
    currentClass = workoutClass;
    _currentBlockIndex = startFromBlock;
    _currentRound = 1;
    _startPreparation();
  }

  void _startPreparation() {
    isPreparing = true;
    _prepareSeconds = 10;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepareSeconds > 0) {
        _prepareSeconds--;
        notifyListeners();
      } else {
        _startWorkPhase();
      }
    });
  }

  void _startWorkPhase() {
    isPreparing = false;
    isWorkingPhase = true;
    final block = currentBlock!;
    _remainingSeconds = (block.workMinutes * 60) + block.workSeconds;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _startRestPhase();
      }
    });
  }

  void _startRestPhase() {
    isWorkingPhase = false;
    final block = currentBlock!;
    _remainingSeconds = (block.restMinutes * 60) + block.restSeconds;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _nextRoundOrBlock();
      }
    });
  }

  void _nextRoundOrBlock() {
    final block = currentBlock!;
    if (_currentRound < block.rounds) {
      _currentRound++;
      _startWorkPhase();
    } else {
      nextBlock();
    }
  }

  void nextBlock() {
    _timer?.cancel();
    if (currentClass != null && _currentBlockIndex < currentClass!.blocks.length - 1) {
      _currentBlockIndex++;
      _currentRound = 1;
      _startPreparation();
    } else {
      finishClass();
    }
  }

  void restartCurrentBlock() {
    _timer?.cancel();
    _currentRound = 1;
    _startPreparation();
  }

  void pauseTimer() { isPaused = true; _timer?.cancel(); notifyListeners(); }
  void resumeTimer() { if (isPaused) { isPaused = false; notifyListeners(); } }
  void finishClass() { isRunning = false; isPreparing = false; _timer?.cancel(); notifyListeners(); }
}