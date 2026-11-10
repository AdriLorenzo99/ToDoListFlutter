import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToDoListApp());
}

const Color kInk = Color(0xFF19191D);
const Color kBlue = Color(0xFF315BEE);
const Color kLime = Color(0xFFB7F34A);
const Color kPaper = Color(0xFFF7F6FA);
const Color kMuted = Color(0xFF777780);
const Color kCardBg = Color(0xFFE5E5E7);
const String kStorageKey = 'todo_tasks';

class TodoTask {
  TodoTask({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    this.isComplete = false,
  });

  final String id;
  String title;
  String description;
  DateTime deadline;
  bool isComplete;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'deadline': deadline.toIso8601String(),
    'isComplete': isComplete,
  };

  factory TodoTask.fromJson(Map<String, dynamic> json) {
    DateTime parsedDeadline = DateTime.now();
    if (json['deadline'] != null) {
      parsedDeadline = DateTime.tryParse(json['deadline'].toString()) ?? DateTime.now();
    }
    return TodoTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deadline: parsedDeadline,
      isComplete: json['isComplete'] as bool? ?? false,
    );
  }
}

class ToDoListApp extends StatelessWidget {
  const ToDoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To Do List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBlue,
          primary: kBlue,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: kInk,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<TodoTask> _tasks = [];
  bool _isLoading = true;
  String? _expandedTaskId;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTasks = prefs.getStringList(kStorageKey) ?? [];
    final loaded = <TodoTask>[];

    for (final raw in rawTasks) {
      try {
        loaded.add(TodoTask.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {

      }
    }

    if (!mounted) return;
    setState(() {
      _tasks
        ..clear()
        ..addAll(loaded);
      _isLoading = false;
    });
  }

  /// Menyimpan task kembali ke SharedPreferences
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTasks = _tasks.map((task) => jsonEncode(task.toJson())).toList();
    await prefs.setStringList(kStorageKey, rawTasks);
  }

  /// CREATE & EDIT
  Future<void> _openTaskForm({TodoTask? task}) async {
    final result = await showDialog<TodoTask>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskFormDialog(task: task),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (task == null) {
        _tasks.add(result);
      } else {
        final index = _tasks.indexWhere((item) => item.id == task.id);
        if (index != -1) _tasks[index] = result;
      }
    });
    await _saveTasks();
  }

  /// Update
  Future<void> _toggleTaskComplete(TodoTask task) async {
    setState(() {
      if (_expandedTaskId == task.id) _expandedTaskId = null;
      task.isComplete = !task.isComplete;
    });
    await _saveTasks();
  }

  /// Delete
  Future<void> _deleteTask(TodoTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Apakah Anda yakin ingin menghapus task "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        if (_expandedTaskId == task.id) _expandedTaskId = null;
        _tasks.removeWhere((item) => item.id == task.id);
      });
      await _saveTasks();
    }
  }

  String _formatDeadlineCard(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year\n$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = _tasks.where((t) => !t.isComplete).toList();
    final completedTasks = _tasks.where((t) => t.isComplete).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tasks',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskForm(),
        backgroundColor: kMuted.withValues(alpha: 0.8),
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 36, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          children: [
            // ACTIVE TASKS SECTION
            if (activeTasks.isEmpty && completedTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    'Belum ada task, klik + untuk menambahkan',
                    style: TextStyle(color: kMuted, fontSize: 16),
                  ),
                ),
              ),

            for (final task in activeTasks) ...[
              _buildActiveTaskCard(task),
              const SizedBox(height: 16),
            ],

            // DIVIDER BETWEEN ACTIVE & COMPLETED TASKS
            if (completedTasks.isNotEmpty) ...[
              if (activeTasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFFD8D7DD), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Completed (${completedTasks.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kMuted,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFD8D7DD), thickness: 1)),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // COMPLETED TASKS SECTION
              for (final task in completedTasks) ...[
                _buildCompletedTaskCard(task),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Widget untuk task yang belum selesai
  Widget _buildActiveTaskCard(TodoTask task) {
    final isExpanded = _expandedTaskId == task.id;

    return Column(
      children: [
        // Task Card Body (Tap to expand/collapse action buttons)
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedTaskId = isExpanded ? null : task.id;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Deadline / Time Text
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatDeadlineCard(task.deadline),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                  ),
                  // Vertical Divider Line
                  Container(
                    width: 1.5,
                    color: kInk.withValues(alpha: 0.25),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  // Title and Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: kInk,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Tombol tandai selesai
                  IconButton(
                    icon: const Icon(Icons.check_rounded, size: 24, color: kMuted),
                    onPressed: () => _toggleTaskComplete(task),
                    tooltip: 'Mark as complete',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Action Buttons Row (Edit Task & Delete Task) - Only shown after tapping task
        if (isExpanded) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _openTaskForm(task: task),
                    style: FilledButton.styleFrom(
                      backgroundColor: kCardBg,
                      foregroundColor: kInk,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Edit Task',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _deleteTask(task),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Delete Task',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Widget Untuk Task Selesai
  Widget _buildCompletedTaskCard(TodoTask task) {
    final isExpanded = _expandedTaskId == task.id;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedTaskId = isExpanded ? null : task.id;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: kLime,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Deadline / Time Text
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatDeadlineCard(task.deadline),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                  ),
                  Container(
                    width: 1.5,
                    color: kInk.withValues(alpha: 0.25),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: kInk,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Checkmark Icon & Toggle back action
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: kInk, size: 24),
                    onPressed: () => _toggleTaskComplete(task),
                    tooltip: 'Mark uncomplete',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Action Buttons Row for Completed Task (Edit Task & Delete Task)
        if (isExpanded) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _openTaskForm(task: task),
                    style: FilledButton.styleFrom(
                      backgroundColor: kLime,
                      foregroundColor: kInk,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Edit Task',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _deleteTask(task),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Delete Task',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// form untuk buat & edit task
class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, this.task});

  final TodoTask? task;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDeadline;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _selectedDeadline = task?.deadline ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDeadline),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDeadline = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatDeadlineInput(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final task = TodoTask(
      id: widget.task?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      deadline: _selectedDeadline,
      isComplete: widget.task?.isComplete ?? false,
    );
    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit Task' : 'New Task',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              _buildLabel('Title'),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                decoration: _inputDecoration('Masukkan nama task'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              //Waktu deadline
              _buildLabel('Deadline / Time'),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: _inputDecoration('Pilih tanggal & waktu').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, size: 20, color: kMuted),
                  ),
                  child: Text(
                    _formatDeadlineInput(_selectedDeadline),
                    style: const TextStyle(fontSize: 14, color: kInk),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Description Field
              _buildLabel('Description'),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: _inputDecoration('Tulis deskripsi'),
              ),
              const SizedBox(height: 22),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: kMuted)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: kBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(_isEditing ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: kMuted,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: kPaper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD8D7DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD8D7DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBlue, width: 1.5),
      ),
    );
  }
}
