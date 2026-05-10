import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Imports absolutos
import 'package:classblock_timer/core/services/workout_timer_service.dart';
import 'package:classblock_timer/core/models/workout_class.dart';

class LiveTimerScreen extends StatefulWidget {
  const LiveTimerScreen({super.key});

  @override
  State<LiveTimerScreen> createState() => _LiveTimerScreenState();
}

class _LiveTimerScreenState extends State<LiveTimerScreen> {
  final WorkoutClass testClass = WorkoutClass(
    name: "Clase de Prueba - Fuerza + Metcon",
    totalDurationMinutes: 60,
    blocks: [
      WorkoutBlock(
        name: "Warm Up",
        durationMinutes: 10,
        type: BlockType.warmUp,
        exercises: ["Jogging", "Movilidad dinámica", "Activación"],
      ),
      WorkoutBlock(
        name: "Strength - Back Squat",
        durationMinutes: 20,
        type: BlockType.strength,
        exercises: ["Back Squat 5x5"],
      ),
      WorkoutBlock(
        name: "Metcon",
        durationMinutes: 25,
        type: BlockType.metcon,
        exercises: ["AMRAP 20 min", "Burpees", "Pull-ups", "Box Jump"],
      ),
      WorkoutBlock(
        name: "Finisher",
        durationMinutes: 5,
        type: BlockType.finisher,
        exercises: ["Plancha"],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<WorkoutTimerService>(context);

    String formatTime(int seconds) {
      int min = seconds ~/ 60;
      int sec = seconds % 60;
      return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timerService.currentClass?.name ?? testClass.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Bloque ${timerService.currentBlockIndex + 1}/${testClass.blocks.length}",
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatTime(timerService.remainingSeconds),
                        style: const TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        timerService.currentBlock?.name ?? "Sin bloque",
                        style: const TextStyle(fontSize: 28, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!timerService.isRunning) {
                        timerService.startClass(testClass);
                      } else if (timerService.isPaused) {
                        timerService.resumeTimer();
                      } else {
                        timerService.pauseTimer();
                      }
                    },
                    icon: Icon(timerService.isRunning && !timerService.isPaused 
                        ? Icons.pause : Icons.play_arrow),
                    label: Text(timerService.isRunning && !timerService.isPaused 
                        ? "Pausar" : "Iniciar"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: timerService.reset,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text("Reiniciar"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}