import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/workout_class.dart';   // ← Import relativo (más simple)

class WorkoutTimerService extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentBlockIndex = 0;
  bool isRunning = false;
  bool isPaused = false;
  WorkoutClass? currentClass;

  final AudioPlayer _audioPlayer = AudioPlayer();

  int get remainingSeconds => _remainingSeconds;
  int get currentBlockIndex => _currentBlockIndex;

  WorkoutBlock? get currentBlock => 
      currentClass != null && currentClass!.blocks.isNotEmpty 
          ? currentClass!.blocks[_currentBlockIndex] 
          : null;

  void startClass(WorkoutClass workoutClass) {
    currentClass = workoutClass;
    _currentBlockIndex = 0;
    _loadCurrentBlock();
    startTimer();
  }

  void _loadCurrentBlock() {
    if (currentClass == null || currentClass!.blocks.isEmpty) return;
    final block = currentClass!.blocks[_currentBlockIndex];
    _remainingSeconds = block.durationMinutes * 60;
    notifyListeners();
  }

  void startTimer() {
    isRunning = true;
    isPaused = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();

        if (_remainingSeconds <= 10 && _remainingSeconds > 0) {
          _audioPlayer.play(AssetSource('sounds/beep.mp3'));
        }
      } else {
        nextBlock();
      }
    });
  }

  void pauseTimer() {
    isPaused = true;
    _timer?.cancel();
    notifyListeners();
  }

  void resumeTimer() {
    if (isPaused) startTimer();
  }

  void nextBlock() {
    _timer?.cancel();
    if (currentClass != null && 
        _currentBlockIndex < currentClass!.blocks.length - 1) {
      _currentBlockIndex++;
      _loadCurrentBlock();
      startTimer();
    } else {
      finishClass();
    }
  }

  void finishClass() {
    isRunning = false;
    _timer?.cancel();
    _audioPlayer.play(AssetSource('sounds/finish.mp3'));
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    isRunning = false;
    isPaused = false;
    _remainingSeconds = 0;
    _currentBlockIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}