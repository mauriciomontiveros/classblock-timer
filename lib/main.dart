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
  final TimerType timerType;
  final int? rounds;          // ← Agregado
  final int? workSeconds;     // ← Agregado
  final int? restSeconds;     // ← Agregado
  final List<String> exercises;

  WorkoutBlock({
    String? id,
    required this.name,
    required this.durationMinutes,
    required this.blockType,
    required this.timerType,
    this.rounds,
    this.workSeconds,
    this.restSeconds,
    List<String>? exercises,
  })  : id = id ?? const Uuid().v4(),
        exercises = exercises ?? [];
}

// ==================== TIMER SERVICE (mismo) ====================
class WorkoutTimerService extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentBlockIndex = 0;
  bool isRunning = false;
  bool isPaused = false;
  bool isPreparing = false;
  int _prepareSeconds = 10;
  WorkoutClass? currentClass;

  final AudioPlayer _audioPlayer = AudioPlayer();

  int get remainingSeconds => _remainingSeconds;
  int get currentBlockIndex => _currentBlockIndex;
  bool get isPreparingNext => isPreparing;
  int get prepareSeconds => _prepareSeconds;

  WorkoutBlock? get currentBlock => currentClass?.blocks[_currentBlockIndex];

  void startClass(WorkoutClass workoutClass, {int startFromBlock = 0}) {
    currentClass = workoutClass;
    _currentBlockIndex = startFromBlock;
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
        _startBlock();
      }
    });
  }

  void _startBlock() {
    isPreparing = false;
    _remainingSeconds = currentBlock!.durationMinutes * 60;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        nextBlock();
      }
    });
  }

  void pauseTimer() { isPaused = true; _timer?.cancel(); notifyListeners(); }
  void resumeTimer() { if (isPaused) { isPaused = false; notifyListeners(); } }
  void nextBlock() {
    if (currentClass != null && _currentBlockIndex < currentClass!.blocks.length - 1) {
      _currentBlockIndex++;
      _startPreparation();
    } else {
      finishClass();
    }
  }

  void restartCurrentBlock() {
    _timer?.cancel();
    isPreparing = false;
    _remainingSeconds = currentBlock!.durationMinutes * 60;
    notifyListeners();
    _startBlock();
  }

  void finishClass() {
    isRunning = false;
    isPreparing = false;
    _timer?.cancel();
    notifyListeners();
  }
}

// ==================== MAIN Y PANTALLAS (Home, ClassBuilder, Editor, LiveTimer) ====================
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

// ... (ClassBuilderScreen y LiveTimerScreen se mantienen iguales que antes)

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
        timerType: TimerType.forTime,
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
                    subtitle: Text("${b.durationMinutes} min • ${b.timerType.name.toUpperCase()}"),
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

// ==================== EDITOR MEJORADO ====================
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
  late int durationMinutes;
  late TimerType timerType;
  late int? rounds;
  late int? workSeconds;
  late int? restSeconds;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.block.name);
    exercisesController = TextEditingController(text: widget.block.exercises.join("\n"));
    durationMinutes = widget.block.durationMinutes;
    timerType = widget.block.timerType;
    rounds = widget.block.rounds;
    workSeconds = widget.block.workSeconds ?? 20;
    restSeconds = widget.block.restSeconds ?? 10;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Editar Bloque"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nombre del Bloque")),
            const SizedBox(height: 12),

            Row(
              children: [
                const Text("Duración:", style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("$durationMinutes min", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ],
            ),
            Slider(
              value: durationMinutes.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: durationMinutes.toString(),
              onChanged: (v) => setState(() => durationMinutes = v.toInt()),
            ),

            TextField(
              controller: exercisesController,
              decoration: const InputDecoration(labelText: "Ejercicios (uno por línea)"),
              maxLines: 4,
            ),

            const SizedBox(height: 12),
            DropdownButtonFormField<TimerType>(
              value: timerType,
              decoration: const InputDecoration(labelText: "Tipo de Timer"),
              items: TimerType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => timerType = v!),
            ),

            if (timerType == TimerType.tabata) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: "Trabajo (seg)"), keyboardType: TextInputType.number, onChanged: (v) => workSeconds = int.tryParse(v), controller: TextEditingController(text: workSeconds.toString()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: "Descanso (seg)"), keyboardType: TextInputType.number, onChanged: (v) => restSeconds = int.tryParse(v), controller: TextEditingController(text: restSeconds.toString()))),
                ],
              ),
            ],

            if (timerType == TimerType.emom || timerType == TimerType.amrap)
              TextField(
                decoration: const InputDecoration(labelText: "Número de Rondas"),
                keyboardType: TextInputType.number,
                onChanged: (v) => rounds = int.tryParse(v),
                controller: TextEditingController(text: rounds?.toString() ?? ""),
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
              durationMinutes: durationMinutes,
              blockType: widget.block.blockType,
              timerType: timerType,
              exercises: exercisesController.text.split('\n').where((e) => e.trim().isNotEmpty).toList(),
              rounds: rounds,
              workSeconds: workSeconds,
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

// ==================== LIVE TIMER (con cuenta regresiva) ====================
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
              Text("Bloque ${timer.currentBlockIndex + 1}/${widget.workoutClass.blocks.length}"),
              const Spacer(),

              if (timer.isPreparingNext)
                Column(
                  children: [
                    const Text("¡PREPÁRATE!", style: TextStyle(fontSize: 40, color: Colors.orange, fontWeight: FontWeight.bold)),
                    Text("${timer.prepareSeconds}", style: const TextStyle(fontSize: 120, color: Colors.orange)),
                  ],
                )
              else
                Text(formatTime(timer.remainingSeconds), style: const TextStyle(fontSize: 140, fontWeight: FontWeight.bold, color: Colors.deepOrange)),

              const SizedBox(height: 20),
              Text(block?.name ?? "", style: const TextStyle(fontSize: 28)),
              if (block?.exercises.isNotEmpty ?? false)
                Text(block!.exercises.join(" • "), style: const TextStyle(fontSize: 18, color: Colors.white70)),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!timer.isRunning) timer.startClass(widget.workoutClass);
                      else if (timer.isPaused) timer.resumeTimer();
                      else timer.pauseTimer();
                    },
                    icon: Icon(timer.isRunning && !timer.isPaused ? Icons.pause : Icons.play_arrow),
                    label: Text(timer.isRunning && !timer.isPaused ? "Pausar" : "Iniciar"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  ),
                  const SizedBox(width: 12),
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