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
const String kStorageKey = 'todo_tasks_v1';

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
    return TodoTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deadline: DateTime.tryParse(json['deadline'] as String? ?? '') ??
          DateTime.now(),
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
        scaffoldBackgroundColor: kPaper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBlue,
          primary: kBlue,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
  String? _expandedTaskId;
  bool _isLoading = true;

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
        loaded.add(
          TodoTask.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Abaikan data corrupt agar aplikasi tetap berjalan
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

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTasks = _tasks.map((task) => jsonEncode(task.toJson())).toList();
    await prefs.setStringList(kStorageKey, rawTasks);
  }

  List<TodoTask> get _sortedTasks {
    final result = List<TodoTask>.from(_tasks);
    result.sort((a, b) {
      if (a.isComplete != b.isComplete) {
        return a.isComplete ? 1 : -1;
      }
      return a.deadline.compareTo(b.deadline);
    });
    return result;
  }

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
      _expandedTaskId = null;
    });
    await _saveTasks();
  }

  Future<void> _confirmComplete(TodoTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark task as complete'),
        content: Text('Mark "${task.title}" task as complete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      task.isComplete = true;
      _expandedTaskId = null;
    });
    await _saveTasks();
  }

  Future<void> _confirmDelete(TodoTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard Task'),
        content: Text('Do you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE34D43),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _tasks.removeWhere((item) => item.id == task.id);
      _expandedTaskId = null;
    });
    await _saveTasks();
  }

  String _dateHeading(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timeText(DateTime date) {
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final displayHour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _sortedTasks;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskForm(),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 31),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: tasks.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                      children: [ const Text('Your Tasks',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                        const SizedBox(height: 12,),
                        ..._buildTaskGroups(tasks),
                        ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 105, bottom: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded, size: 43, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'You have no task yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kMuted,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Click + button to add new task.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTaskGroups(List<TodoTask> tasks) {
    final groups = <DateTime, List<TodoTask>>{};
    for (final task in tasks) {
      final day = DateTime(
        task.deadline.year,
        task.deadline.month,
        task.deadline.day,
      );
      groups.putIfAbsent(day, () => []).add(task);
    }

    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 9, top: 2),
          child: Text(
            _dateHeading(entry.key),
            style: const TextStyle(fontSize: 12, color: kMuted),
          ),
        ),
      );
      for (final task in entry.value) {
        widgets.add(_buildTaskCard(task));
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Widget _buildTaskCard(TodoTask task) {
    final expanded = _expandedTaskId == task.id;
    final background = task.isComplete ? kLime : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInk.withValues(alpha: 0.72), width: 0.8),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _expandedTaskId = expanded ? null : task.id;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      _timeText(task.deadline),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: task.description.isEmpty ? 33 : 49,
                    color: kInk.withValues(alpha: 0.28),
                    margin: const EdgeInsets.only(right: 12),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            decoration: task.isComplete
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, height: 1.3),
                          ),
                        ],
                        if (task.isComplete) ...[
                          const SizedBox(height: 5),
                          const Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.more_horiz,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: kInk.withValues(alpha: 0.18)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _actionButton(
                    label: 'Edit Task',
                    icon: Icons.edit_outlined,
                    onPressed: () => _openTaskForm(task: task),
                  ),
                  if (!task.isComplete)
                    _actionButton(
                      label: 'Mark as complete',
                      icon: Icons.check_circle_outline,
                      primary: true,
                      onPressed: () => _confirmComplete(task),
                    ),
                  _actionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    danger: true,
                    onPressed: () => _confirmDelete(task),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
    bool danger = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary
            ? Colors.white
            : danger
                ? const Color(0xFFD7473D)
                : kInk,
        backgroundColor: primary ? kBlue : Colors.white,
        side: BorderSide(
          color: primary
              ? kBlue
              : danger
                  ? const Color(0xFFD7473D)
                  : const Color(0xFFB9B8BF),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

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
  late DateTime _deadline;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController =
        TextEditingController(text: task?.description ?? '');
    _deadline = task?.deadline ?? DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kBlue),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    setState(() {
      _deadline = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _deadline.hour,
        _deadline.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kBlue),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    setState(() {
      _deadline = DateTime(
        _deadline.year,
        _deadline.month,
        _deadline.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    final task = TodoTask(
      id: widget.task?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      deadline: _deadline,
      isComplete: widget.task?.isComplete ?? false,
    );
    Navigator.pop(context, task);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 17),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 34,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Task' : 'Create New Task',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _fieldLabel('Title'),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration('Enter task title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _fieldLabel('Due Date & Time'),
              Row(
                children: [
                  Expanded(
                    child: _pickerField(
                      icon: Icons.calendar_today_outlined,
                      value: _formatDate(_deadline),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _pickerField(
                      icon: Icons.access_time,
                      value: _formatTime(_deadline),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _fieldLabel('Description'),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration('Write task description...'),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(_isEditing ? 'Save Changes' : 'Create Task'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kInk,
                      side: const BorderSide(color: Color(0xFFB9B8BF)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: kMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFAAA9B0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFB9B8BF)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: kBlue, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _pickerField({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        decoration: BoxDecoration(
          color: kPaper,
          border: Border.all(color: const Color(0xFFD8D7DD)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: kMuted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
      ),
    );
  }
}