import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// ==================== MODELOS ====================
enum BlockType { warmUp, strength, metcon, finisher, custom }

class WorkoutClass {
  final String id;
  final String name;
  final List<WorkoutBlock> blocks;
  final DateTime createdAt;

  WorkoutClass({
    String? id,
    required this.name,
    required this.blocks,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkoutClass.fromJson(Map<String, dynamic> json) => WorkoutClass(
        id: json['id'],
        name: json['name'],
        blocks: (json['blocks'] as List)
            .map((b) => WorkoutBlock.fromJson(b))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
      );
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'durationMinutes': durationMinutes,
        'blockType': blockType.toString(),
        'exercises': exercises,
        'rounds': rounds,
        'workMinutes': workMinutes,
        'workSeconds': workSeconds,
        'restMinutes': restMinutes,
        'restSeconds': restSeconds,
      };

  factory WorkoutBlock.fromJson(Map<String, dynamic> json) => WorkoutBlock(
        id: json['id'],
        name: json['name'],
        durationMinutes: json['durationMinutes'],
        blockType: BlockType.values.firstWhere((e) => e.toString() == json['blockType']),
        exercises: List<String>.from(json['exercises'] ?? []),
        rounds: json['rounds'] ?? 4,
        workMinutes: json['workMinutes'] ?? 3,
        workSeconds: json['workSeconds'] ?? 0,
        restMinutes: json['restMinutes'] ?? 1,
        restSeconds: json['restSeconds'] ?? 0,
      );
}

// ==================== TIMER SERVICE CON SONIDOS (VERSIÓN DIAGNÓSTICO) ====================
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

  Future<void> _playShortBeep() async {
    try {
      print("🔊 Intentando reproducir beep corto...");
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
      print("✅ Beep corto reproducido");
    } catch (e) {
      print("❌ Error beep corto: $e");
    }
  }

  Future<void> _playLongBeep() async {
    try {
      print("🔊 Intentando reproducir beep largo...");
      await _audioPlayer.play(AssetSource('sounds/finish.mp3'));
      print("✅ Beep largo reproducido");
    } catch (e) {
      print("❌ Error beep largo: $e");
    }
  }

  Future<void> playTestBeep() async {
    print("🧪 Botón de prueba presionado");
    await _playShortBeep();
  }

  void startClass(WorkoutClass workoutClass, {int startFromBlock = 0}) {
    currentClass = workoutClass;
    _currentBlockIndex = startFromBlock;
    _currentRound = 1;
    isRunning = true;
    isPaused = false;
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
        if (_prepareSeconds <= 3 && _prepareSeconds > 0) _playShortBeep();
        if (_prepareSeconds == 0) _playLongBeep();
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
    _startTimer();
  }

  void _startRestPhase() {
    isWorkingPhase = false;
    final block = currentBlock!;
    _remainingSeconds = (block.restMinutes * 60) + block.restSeconds;
    notifyListeners();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        
        // Beep en los últimos 3 segundos de cada fase
        if (_remainingSeconds <= 3 && _remainingSeconds > 0) {
          _playShortBeep();
        }
        if (_remainingSeconds == 0) {
          _playLongBeep();
        }
        
        notifyListeners();
      } else {
        if (isWorkingPhase) {
          _startRestPhase();
        } else {
          _nextRoundOrBlock();
        }
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

  void pauseTimer() {
    isPaused = true;
    _timer?.cancel();
    notifyListeners();
  }

  void resumeTimer() {
    if (!isPaused) return;
    isPaused = false;
    notifyListeners();
    _startTimer();
  }

  void finishClass() {
    isRunning = false;
    isPaused = false;
    isPreparing = false;
    _timer?.cancel();
    _playLongBeep(); // Sonido final de clase
    notifyListeners();
  }

      void stopAllSounds() {
    try {
      _audioPlayer.stop();      // Detiene el sonido actual
      _audioPlayer.release();   // Libera los recursos de audio
      print("🔇 Sonidos detenidos");
    } catch (e) {
      print("Error al detener sonidos: $e");
    }
  }
}

// ==================== SERVICIO DE GUARDADO ====================
class ClassStorageService {
  static const String _key = 'saved_classes';

  static Future<void> saveClasses(List<WorkoutClass> classes) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = classes.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<WorkoutClass>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_key);
    if (jsonList == null || jsonList.isEmpty) return [];

    return jsonList.map((jsonStr) {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return WorkoutClass.fromJson(map);
    }).toList();
  }
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

// ==================== HOME SCREEN - ACTUALIZADO ====================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ClassBlock Timer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 30),
              label: const Text("Crear Nueva Clase", style: TextStyle(fontSize: 18)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassBuilderScreen())),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open, size: 30),
              label: const Text("Mis Clases Guardadas", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedClassesScreen(),
                  settings: const RouteSettings(name: 'SavedClasses'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ==================== NUEVO BOTÓN ====================
            ElevatedButton.icon(
              icon: const Icon(Icons.text_snippet, size: 30),
              label: const Text("Importar Rutina desde Texto", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportRoutineScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CLASS BUILDER - VERSIÓN COMPLETA Y CORREGIDA ====================
class ClassBuilderScreen extends StatefulWidget {
  final WorkoutClass? existingClass;
  final int? classIndex;           // Para saber si estamos editando

  const ClassBuilderScreen({
    super.key,
    this.existingClass,
    this.classIndex,
  });

  @override
  State<ClassBuilderScreen> createState() => _ClassBuilderScreenState();
}

class _ClassBuilderScreenState extends State<ClassBuilderScreen> {
  late TextEditingController _className;
  List<WorkoutBlock> blocks = [];

  @override
  void initState() {
    super.initState();
    _className = TextEditingController(text: widget.existingClass?.name ?? "Clase de Hoy");

    if (widget.existingClass != null) {
      blocks = List.from(widget.existingClass!.blocks);
    }
  }

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

    void _saveCurrentClass() async {
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega al menos un bloque")),
      );
      return;
    }

    final newWorkout = WorkoutClass(
      name: _className.text,
      blocks: List.from(blocks),
    );

    List<WorkoutClass> allSaved = await ClassStorageService.loadClasses();

    if (widget.classIndex != null && widget.classIndex! < allSaved.length) {
      // EDITAR clase existente
      allSaved[widget.classIndex!] = newWorkout;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Clase actualizada correctamente")),
      );
    } else {
      // NUEVA clase
      allSaved.add(newWorkout);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Clase guardada correctamente")),
      );
    }

    await ClassStorageService.saveClasses(allSaved);

    // Volver directamente a la pantalla de inicio
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear / Editar Clase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, size: 28),
            tooltip: "Guardar Clase",
            onPressed: _saveCurrentClass,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _className,
              decoration: const InputDecoration(labelText: "Nombre de la Clase"),
            ),
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
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: Text(b.name),
                    subtitle: Text("${b.durationMinutes} minutos", style: const TextStyle(color: Colors.grey)),
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
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar Bloque"),
                    onPressed: _addNewBlock,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Iniciar Clase"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                    onPressed: blocks.isEmpty ? null : () {
                      final workout = WorkoutClass(name: _className.text, blocks: blocks);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LiveTimerScreen(workoutClass: workout)),
                      );
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

// ==================== EDITOR DE BLOQUE ====================
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
            const SizedBox(height: 16),
            TextField(
              controller: exercisesController,
              decoration: const InputDecoration(labelText: "Ejercicios (uno por línea)"),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            const Text("Rondas", style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(value: rounds.toDouble(), min: 1, max: 20, divisions: 19, onChanged: (v) => setState(() => rounds = v.toInt())),
            Text("$rounds rondas"),

            const SizedBox(height: 16),
            const Text("Trabajar", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Minutos"), keyboardType: TextInputType.number, onChanged: (v) => workMinutes = int.tryParse(v) ?? 0, controller: TextEditingController(text: workMinutes.toString()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Segundos"), keyboardType: TextInputType.number, onChanged: (v) => workSeconds = int.tryParse(v) ?? 0, controller: TextEditingController(text: workSeconds.toString()))),
              ],
            ),

            const SizedBox(height: 16),
            const Text("Descansar", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Minutos"), keyboardType: TextInputType.number, onChanged: (v) => restMinutes = int.tryParse(v) ?? 0, controller: TextEditingController(text: restMinutes.toString()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: const InputDecoration(labelText: "Segundos"), keyboardType: TextInputType.number, onChanged: (v) => restSeconds = int.tryParse(v) ?? 0, controller: TextEditingController(text: restSeconds.toString()))),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        TextButton(
          onPressed: () {
            final totalSeconds = (workMinutes * 60 + workSeconds) + (restMinutes * 60 + restSeconds);
            final totalDurationMinutes = (totalSeconds * rounds) ~/ 60;

            final newBlock = WorkoutBlock(
              name: nameController.text,
              durationMinutes: totalDurationMinutes,
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

// ==================== MIS CLASES GUARDADAS - REFRESH FORZADO ====================
class SavedClassesScreen extends StatefulWidget {
  const SavedClassesScreen({super.key});
  @override
  State<SavedClassesScreen> createState() => _SavedClassesScreenState();
}

class _SavedClassesScreenState extends State<SavedClassesScreen> {
  List<WorkoutClass> savedClasses = [];
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    savedClasses = await ClassStorageService.loadClasses();
    setState(() {});
  }

  void _openClassDetail(WorkoutClass workout, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassDetailScreen(
          workoutClass: workout,
          classIndex: index,
        ),
      ),
    ).then((_) {
      _loadClasses();           // Refresh al volver
    });
  }

  void _deleteClass(int index) async {
    savedClasses.removeAt(index);
    await ClassStorageService.saveClasses(savedClasses);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Clases Guardadas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClasses,
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _loadClasses,
        child: savedClasses.isEmpty
            ? const Center(
                child: Text(
                  "Aún no tienes clases guardadas",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: savedClasses.length,
                itemBuilder: (context, index) {
                  final cls = savedClasses[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      title: Text(cls.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "${cls.blocks.length} bloques • ${cls.createdAt.day}/${cls.createdAt.month}/${cls.createdAt.year}",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteClass(index),
                      ),
                      onTap: () => _openClassDetail(cls, index),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ==================== DETALLE DE CLASE - CON EJERCICIOS Y TIMER FUNCIONAL ====================
class ClassDetailScreen extends StatelessWidget {
  final WorkoutClass workoutClass;
  final int classIndex;

  const ClassDetailScreen({
    super.key,
    required this.workoutClass,
    required this.classIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(workoutClass.name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: workoutClass.blocks.length,
        itemBuilder: (context, index) {
          final block = workoutClass.blocks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(                     // ← Hace todo el card clickeable
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveTimerScreen(
                      workoutClass: workoutClass,
                      startFromBlock: index,      // ← Inicia desde este bloque
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado del bloque
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.deepOrange,
                          radius: 18,
                          child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(block.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(
                                "${block.durationMinutes} min • ${block.rounds} rondas",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_arrow, color: Colors.deepOrange),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Lista de ejercicios
                    if (block.exercises.isNotEmpty) ...[
                      const Text("Ejercicios:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...block.exercises.map((exercise) => Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(exercise, style: const TextStyle(fontSize: 16))),
                              ],
                            ),
                          )),
                    ] else
                      const Text("No hay ejercicios configurados", 
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("Editar Clase"),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassBuilderScreen(
                        existingClass: workoutClass,
                        classIndex: classIndex,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text("Duplicar"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                onPressed: () async {
                  final duplicated = WorkoutClass(
                    name: "${workoutClass.name} (Copia)",
                    blocks: workoutClass.blocks.map((b) => WorkoutBlock(
                      name: b.name,
                      durationMinutes: b.durationMinutes,
                      blockType: b.blockType,
                      exercises: List.from(b.exercises),
                      rounds: b.rounds,
                      workMinutes: b.workMinutes,
                      workSeconds: b.workSeconds,
                      restMinutes: b.restMinutes,
                      restSeconds: b.restSeconds,
                    )).toList(),
                  );

                  List<WorkoutClass> all = await ClassStorageService.loadClasses();
                  all.add(duplicated);
                  await ClassStorageService.saveClasses(all);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Clase duplicada")),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== LIVE TIMER SCREEN - VERSIÓN ESTABLE Y RESPONSIVA ====================
class LiveTimerScreen extends StatefulWidget {
  final WorkoutClass workoutClass;
  final int startFromBlock;

  const LiveTimerScreen({
    super.key,
    required this.workoutClass,
    this.startFromBlock = 0,
  });

  @override
  State<LiveTimerScreen> createState() => _LiveTimerScreenState();
}

class _LiveTimerScreenState extends State<LiveTimerScreen> {
  bool isFullscreen = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timer = Provider.of<WorkoutTimerService>(context, listen: false);
      timer.startClass(widget.workoutClass, startFromBlock: widget.startFromBlock);
    });
  }

  @override
  void dispose() {
    final timer = Provider.of<WorkoutTimerService>(context, listen: false);
    timer.pauseTimer();
    timer.finishClass();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void toggleFullscreen() {
    setState(() => isFullscreen = !isFullscreen);
  }

  @override
  Widget build(BuildContext context) {
    final timer = Provider.of<WorkoutTimerService>(context);
    final block = timer.currentBlock;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    String formatTime(int seconds) {
      int min = seconds ~/ 60;
      int sec = seconds % 60;
      return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }

    // Tamaños responsivos
    final bool bigMode = isFullscreen;
    final double timerFontSize = bigMode 
        ? (isSmallScreen ? 165 : 240) 
        : (isSmallScreen ? 125 : 170);

    final double phaseFontSize = bigMode 
        ? (isSmallScreen ? 36 : 48) 
        : (isSmallScreen ? 28 : 34);

    final double blockNameSize = bigMode 
        ? (isSmallScreen ? 32 : 42) 
        : 26;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isFullscreen ? null : AppBar(title: Text(widget.workoutClass.name)),
      
      body: SafeArea(   // ← Importante para evitar problemas de tamaño
        child: GestureDetector(
          onDoubleTap: toggleFullscreen,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Padding(
              padding: EdgeInsets.all(bigMode ? 16 : 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!isFullscreen)
                    Text(
                      "Bloque ${timer.currentBlockIndex + 1}/${widget.workoutClass.blocks.length}",
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),

                  Text(
                    block?.name ?? "",
                    style: TextStyle(fontSize: blockNameSize, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  if (timer.isPreparingNext)
                    Column(
                      children: [
                        const Text("¡PREPÁRATE!", style: TextStyle(fontSize: 42, color: Colors.orange, fontWeight: FontWeight.bold)),
                        Text("${timer.prepareSeconds}", style: TextStyle(fontSize: timerFontSize, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Text(
                          timer.isWorkPhase ? "TRABAJANDO" : "DESCANSANDO",
                          style: TextStyle(
                            fontSize: phaseFontSize,
                            fontWeight: FontWeight.bold,
                            color: timer.isWorkPhase ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                        ),
                        Text(
                          formatTime(timer.remainingSeconds),
                          style: TextStyle(
                            fontSize: timerFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),

                  Text(
                    "Ronda ${timer.currentRound} de ${block?.rounds ?? 1}",
                    style: TextStyle(fontSize: bigMode ? 32 : 24, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),

                  if (block?.exercises.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Text(
                        block!.exercises.join(" • "),
                        style: TextStyle(fontSize: bigMode ? 20 : 18, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const Spacer(),

                  if (!isFullscreen)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            final t = Provider.of<WorkoutTimerService>(context, listen: false);
                            if (!t.isRunning) {
                              t.startClass(widget.workoutClass, startFromBlock: widget.startFromBlock);
                            } else if (t.isPaused) {
                              t.resumeTimer();
                            } else {
                              t.pauseTimer();
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

                  if (isFullscreen)
                    const Text("Doble tap para salir del modo TV",
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== IMPORTAR RUTINA CON IA (PARSER) ====================
class ImportRoutineScreen extends StatefulWidget {
  const ImportRoutineScreen({super.key});
  @override
  State<ImportRoutineScreen> createState() => _ImportRoutineScreenState();
}

class _ImportRoutineScreenState extends State<ImportRoutineScreen> {
  final TextEditingController _textController = TextEditingController();
  bool isProcessing = false;

  void _parseAndCreateClass() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pega una rutina primero")));
      return;
    }

    setState(() => isProcessing = true);

    // Parser inteligente
    final workout = _parseWorkoutText(_textController.text);

    setState(() => isProcessing = false);

    if (workout.blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudieron detectar bloques")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassBuilderScreen(existingClass: workout),
      ),
    );
  }

      WorkoutClass _parseWorkoutText(String text) {
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String className = "Rutina Importada";
    List<WorkoutBlock> blocks = [];
    List<String> currentExercises = [];
    String currentBlockName = "Bloque Principal";
    BlockType currentType = BlockType.metcon;

    for (String line in lines) {
      String upper = line.toUpperCase();

      // === DETECTAR NOMBRE DE LA CLASE ===
      if (upper.contains("LUNES") || upper.contains("MARTES") || upper.contains("MIÉRCOLES") ||
          upper.contains("JUEVES") || upper.contains("VIERNES") || upper.contains("SÁBADO") || 
          upper.contains("DOMINGO") || upper.contains("FECHA")) {
        className = line.replaceAll(RegExp(r'header image|Programación Lion Master', caseSensitive: false), "").trim();
        continue;
      }

      // === DETECTAR NUEVO BLOQUE ===
      if (upper.contains("WARM UP") || upper.contains("ACTIVACIÓN") || upper.contains("CALENTAMIENTO") ||
          upper.contains("BLOQUE") || upper.contains("FUERZA") || upper.contains("HIPERTROFIA") ||
          upper.contains("WEIGHTLIFTING") || upper.contains("STRENGTH") || upper.contains("CONDITIONING") ||
          upper.contains("WOD") || upper.contains("GYMNASTICS") || upper.contains("FINISHER") ||
          upper.contains("ACCESSORY") || upper.contains("DENSIDAD") || upper.contains("CIERRE")) {

        // Guardar bloque anterior
        if (currentExercises.isNotEmpty && currentBlockName.isNotEmpty) {
          blocks.add(WorkoutBlock(
            name: currentBlockName,
            durationMinutes: 12, // valor por defecto
            blockType: currentType,
            exercises: List.from(currentExercises),
            rounds: 4,
            workMinutes: 3,
            workSeconds: 0,
            restMinutes: 1,
            restSeconds: 0,
          ));
        }

        currentBlockName = line;
        currentExercises = [];

        // Detectar tipo de bloque
        if (upper.contains("WARM UP") || upper.contains("ACTIVACIÓN") || upper.contains("CALENTAMIENTO")) {
          currentType = BlockType.warmUp;
        } else if (upper.contains("FUERZA") || upper.contains("STRENGTH") || upper.contains("WEIGHTLIFTING")) {
          currentType = BlockType.strength;
        } else if (upper.contains("HIPERTROFIA")) {
          currentType = BlockType.strength;
        } else {
          currentType = BlockType.metcon;
        }

        continue;
      }

      // Agregar ejercicio o descripción
      if (line.isNotEmpty) {
        currentExercises.add(line);
      }
    }

    // Agregar el último bloque
    if (currentExercises.isNotEmpty) {
      blocks.add(WorkoutBlock(
        name: currentBlockName,
        durationMinutes: 12,
        blockType: currentType,
        exercises: List.from(currentExercises),
        rounds: 4,
        workMinutes: 3,
        workSeconds: 0,
        restMinutes: 1,
        restSeconds: 0,
      ));
    }

    // Si no detectó nada, crear un bloque genérico
    if (blocks.isEmpty) {
      blocks.add(WorkoutBlock(
        name: "Bloque Principal",
        durationMinutes: 30,
        blockType: BlockType.metcon,
        exercises: lines,
      ));
    }

    return WorkoutClass(name: className, blocks: blocks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar Rutina')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Pega aquí tu rutina completa:", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: "Ejemplo:\nVIERNES: CUÁDRICEPS\nACTIVACIÓN. 3 vueltas\nSentadilla x15\n...",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.auto_awesome),
              label: Text(isProcessing ? "Procesando..." : "Procesar Rutina con IA"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: isProcessing ? null : _parseAndCreateClass,
            ),
          ],
        ),
      ),
    );
  }
}