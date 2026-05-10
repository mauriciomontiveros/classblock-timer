import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

// ==================== MODELOS ====================
enum BlockType { warmUp, strength, metcon, finisher, custom }
enum TimerType { forTime, amrap, emom, tabata }

class WorkoutClass {
  final String id;
  final String name;
  final List<WorkoutBlock> blocks;

  WorkoutClass({String? id, required this.name, required this.blocks})
      : id = id ?? const Uuid().v4();
}

class WorkoutBlock {
  final String id;
  final String name;
  final int durationMinutes;
  final BlockType blockType;
  final List<String> exercises;

  final int rounds;
  final int workMinutes;
  final int workSeconds;
  final int restMinutes;
  final int restSeconds;

  WorkoutBlock({
    String? id,
    required this.name,
    required this.durationMinutes,
    required this.blockType,
    List<String>? exercises,
    this.rounds = 4,
    this.workMinutes = 3,
    this.workSeconds = 0,
    this.restMinutes = 1,
    this.restSeconds = 0,
  })  : id = id ?? const Uuid().v4(),
        exercises = exercises ?? [];
}

// ==================== TIMER SERVICE ====================
class WorkoutTimerService extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentBlockIndex = 0;
  int _currentRound = 1;
  bool isWorkingPhase = true;
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
  bool get isWorkPhase => isWorkingPhase;

  WorkoutBlock? get currentBlock => currentClass?.blocks[_currentBlockIndex];

  Future<void> playTestBeep() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 1.0);
      print("✅ Beep OK");
    } catch (e) {
      print("❌ Error beep: $e");
    }
  }

  Future<void> _playBeep() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.8);
    } catch (e) {}
  }

  Future<void> _playFinish() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/finish.mp3'), volume: 1.0);
    } catch (e) {}
  }

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

// ==================== MAIN APP ====================
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkoutTimerService(),
      child: MaterialApp(
        title: 'ClassBlock Timer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(primaryColor: Colors.deepOrange),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ClassBlock Timer')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 30),
          label: const Text("Crear Nueva Clase", style: TextStyle(fontSize: 18)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassBuilderScreen())),
        ),
      ),
    );
  }
}

// ==================== CLASS BUILDER (mantengo el anterior) ====================
class ClassBuilderScreen extends StatefulWidget {
  const ClassBuilderScreen({super.key});
  @override
  State<ClassBuilderScreen> createState() => _ClassBuilderScreenState();
}

class _ClassBuilderScreenState extends State<ClassBuilderScreen> {
  final TextEditingController _className = TextEditingController(text: "Clase de Hoy");
  List<WorkoutBlock> blocks = [];

  void _addNewBlock() {
    setState(() {
      blocks.add(WorkoutBlock(
        name: "Nuevo Bloque",
        durationMinutes: 10,
        blockType: BlockType.metcon,
        exercises: ["Ejercicio 1"],
      ));
    });
  }

  void _editBlock(int index) {
    showDialog(
      context: context,
      builder: (context) => BlockEditorDialog(
        block: blocks[index],
        onSave: (updated) => setState(() => blocks[index] = updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Clase')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(controller: _className, decoration: const InputDecoration(labelText: "Nombre de la Clase")),
          ),
          Expanded(
            child: ReorderableListView.builder(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = blocks.removeAt(oldIndex);
                  blocks.insert(newIndex, item);
                });
              },
              itemCount: blocks.length,
              itemBuilder: (context, index) {
                final b = blocks[index];
                return Card(
                  key: ValueKey(b.id),
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: Text(b.name),
                    subtitle: Text("${b.durationMinutes} min"),
                    onTap: () => _editBlock(index),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text("Agregar Bloque"), onPressed: _addNewBlock)),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Iniciar Clase"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                    onPressed: blocks.isEmpty ? null : () {
                      final workout = WorkoutClass(name: _className.text, blocks: blocks);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTimerScreen(workoutClass: workout)));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== EDITOR (mantengo el anterior que te gustó) ====================
class BlockEditorDialog extends StatefulWidget {
  final WorkoutBlock block;
  final Function(WorkoutBlock) onSave;
  const BlockEditorDialog({super.key, required this.block, required this.onSave});

  @override
  State<BlockEditorDialog> createState() => _BlockEditorDialogState();
}

class _BlockEditorDialogState extends State<BlockEditorDialog> {
  late TextEditingController nameController;
  late TextEditingController exercisesController;
  late int rounds;
  late int workMinutes;
  late int workSeconds;
  late int restMinutes;
  late int restSeconds;
  bool hasCountdown = true;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.block.name);
    exercisesController = TextEditingController(text: widget.block.exercises.join("\n"));
    rounds = widget.block.rounds;
    workMinutes = widget.block.workMinutes;
    workSeconds = widget.block.workSeconds;
    restMinutes = widget.block.restMinutes;
    restSeconds = widget.block.restSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Configuración del Bloque"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nombre del Bloque")),
            TextField(
              controller: exercisesController,
              decoration: const InputDecoration(labelText: "Ejercicios (uno por línea)"),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            const Text("Rondas"),
            Slider(value: rounds.toDouble(), min: 1, max: 20, onChanged: (v) => setState(() => rounds = v.toInt())),
            Text("$rounds rondas"),

            const SizedBox(height: 16),
            const Text("Trabajar"),
            Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Min"), keyboardType: TextInputType.number, onChanged: (v) => workMinutes = int.tryParse(v) ?? 0, controller: TextEditingController(text: workMinutes.toString()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Seg"), keyboardType: TextInputType.number, onChanged: (v) => workSeconds = int.tryParse(v) ?? 0, controller: TextEditingController(text: workSeconds.toString()))),
              ],
            ),

            const SizedBox(height: 16),
            const Text("Descansar"),
            Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Min"), keyboardType: TextInputType.number, onChanged: (v) => restMinutes = int.tryParse(v) ?? 0, controller: TextEditingController(text: restMinutes.toString()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Seg"), keyboardType: TextInputType.number, onChanged: (v) => restSeconds = int.tryParse(v) ?? 0, controller: TextEditingController(text: restSeconds.toString()))),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        TextButton(
          onPressed: () {
            final newBlock = WorkoutBlock(
              name: nameController.text,
              durationMinutes: 10,
              blockType: widget.block.blockType,
              exercises: exercisesController.text.split('\n').where((e) => e.trim().isNotEmpty).toList(),
              rounds: rounds,
              workMinutes: workMinutes,
              workSeconds: workSeconds,
              restMinutes: restMinutes,
              restSeconds: restSeconds,
            );
            widget.onSave(newBlock);
            Navigator.pop(context);
          },
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}

// ==================== LIVE TIMER SCREEN CORREGIDA ====================
class LiveTimerScreen extends StatefulWidget {
  final WorkoutClass workoutClass;
  const LiveTimerScreen({super.key, required this.workoutClass});

  @override
  State<LiveTimerScreen> createState() => _LiveTimerScreenState();
}

class _LiveTimerScreenState extends State<LiveTimerScreen> {
  @override
  Widget build(BuildContext context) {
    final timer = Provider.of<WorkoutTimerService>(context);
    final block = timer.currentBlock;

    String formatTime(int seconds) {
      int min = seconds ~/ 60;
      int sec = seconds % 60;
      return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.workoutClass.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "Bloque ${timer.currentBlockIndex + 1}/${widget.workoutClass.blocks.length}",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                block?.name ?? "",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // ==================== CUENTA REGRESIVA ====================
              if (timer.isPreparingNext)
                Column(
                  children: [
                    const Text(
                      "¡PREPÁRATE!",
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "${timer.prepareSeconds}",
                      style: const TextStyle(fontSize: 140, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                )
              // ==================== TEMPORIZADOR NORMAL ====================
              else
                Column(
                  children: [
                    Text(
                      timer.isWorkPhase ? "TRABAJANDO" : "DESCANSANDO",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: timer.isWorkPhase ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatTime(timer.remainingSeconds),
                      style: const TextStyle(fontSize: 135, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Ronda
              Text(
                "Ronda ${timer.currentRound} de ${block?.rounds ?? 1}",
                style: const TextStyle(fontSize: 26, color: Colors.white),
              ),

              // Ejercicios
              if (block?.exercises.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    block!.exercises.join(" • "),
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!timer.isRunning) {
                        timer.startClass(widget.workoutClass);
                      } else if (timer.isPaused) {
                        timer.resumeTimer();
                      } else {
                        timer.pauseTimer();
                      }
                    },
                    icon: Icon(timer.isRunning && !timer.isPaused ? Icons.pause : Icons.play_arrow),
                    label: Text(timer.isRunning && !timer.isPaused ? "Pausar" : "Iniciar"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: timer.restartCurrentBlock,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text("Reiniciar Bloque"),
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