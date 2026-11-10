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

enum TaskFilter { all, inProgress, complete }

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
        fontFamily: 'Manrope',
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
  TaskFilter _filter = TaskFilter.all;
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
        // Abaikan data yang tidak dapat dibaca agar aplikasi tetap terbuka.
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
    final result = _tasks.where((task) {
      switch (_filter) {
        case TaskFilter.all:
          return true;
        case TaskFilter.inProgress:
          return !task.isComplete;
        case TaskFilter.complete:
          return task.isComplete;
      }
    }).toList();

    result.sort((a, b) {
      if (a.isComplete != b.isComplete) {
        return a.isComplete ? 1 : -1;
      }
      return a.deadline.compareTo(b.deadline);
    });
    return result;
  }

  int get _completedCount => _tasks.where((task) => task.isComplete).length;
  int get _progressCount => _tasks.length - _completedCount;

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
        content: Text('Mark "${task.title}" as complete?'),
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

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To Do List App',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Make your daily activity count.',
                style: TextStyle(color: kMuted),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('About App'),
                subtitle: const Text('App Version 1.0'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateHeading(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timeText(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 100),
                children: [
                  _buildGreeting(),
                  const SizedBox(height: 22),
                  _buildActivity(),
                  const SizedBox(height: 25),
                  _buildTaskHeader(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                  const SizedBox(height: 17),
                  if (tasks.isEmpty)
                    _buildEmptyState()
                  else
                    ..._buildTaskGroups(tasks),
                ],
              ),
            ),
    );
  }

  Widget _buildGreeting() {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kInk, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ready for today activity?',
                style: TextStyle(fontSize: 13, color: kMuted),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Menu',
            onPressed: _showMenu,
            icon: const Icon(Icons.menu_rounded, size: 28, color: kInk),
          ),
        ],
      ),
    );
  }

  Widget _buildActivity() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kInk, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Progress',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _statCard(
                    title: 'Total Task',
                    count: _tasks.length,
                    large: true,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    children: [
                      _statCard(
                        title: 'On Progress',
                        count: _progressCount,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 7),
                      _statCard(
                        title: 'Complete',
                        count: _completedCount,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required int count,
    required Color color,
    bool large = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kInk, width: 1.0),
      ),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count Task',
                  style: const TextStyle(fontSize: 10, color: kInk),
                ),
              ],
            ),
    );
  }

  Widget _buildTaskHeader() {
    return const Text(
      'Tasks',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All', TaskFilter.all),
          const SizedBox(width: 7),
          _filterChip('On Progress', TaskFilter.inProgress),
          const SizedBox(width: 7),
          _filterChip('Complete', TaskFilter.complete),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TaskFilter filter) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _filter = filter;
        _expandedTaskId = null;
      }),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? Colors.white : kInk,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: Colors.white,
      selectedColor: kInk,
      side: const BorderSide(color: kInk, width: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      shape: const StadiumBorder(),
    );
  }

  Widget _buildEmptyState() {
    String message = 'You have no task yet';
    if (_filter == TaskFilter.inProgress && _tasks.isNotEmpty) {
      message = 'No task in progress';
    } else if (_filter == TaskFilter.complete && _tasks.isNotEmpty) {
      message = 'No completed task yet';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 105, bottom: 80),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.task_alt_rounded, size: 43, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
          padding: const EdgeInsets.only(bottom: 9, top: 12),
          child: Text(
            _dateHeading(entry.key),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
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
        border: Border.all(color: kInk, width: 1.0),
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!task.isComplete)
                    Row(
                      children: [
                        _actionButton(
                          label: 'Edit Task',
                          icon: Icons.edit_outlined,
                          onPressed: () => _openTaskForm(task: task),
                        ),
                        const SizedBox(width: 6),
                        _actionButton(
                          label: 'Mark as complete',
                          icon: Icons.check_circle_outline,
                          primary: true,
                          onPressed: () => _confirmComplete(task),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),

                  _actionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    danger: !task.isComplete,
                    dark: task.isComplete,
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
    bool dark = false,
  }) {
    Color fgColor = kInk;
    Color bgColor = Colors.white;
    Color borderColor = kInk;

    if (dark) {
      fgColor = Colors.white;
      bgColor = kInk;
      borderColor = kInk;
    } else if (primary) {
      fgColor = Colors.white;
      bgColor = kBlue;
      borderColor = kBlue;
    } else if (danger) {
      fgColor = const Color(0xFFD7473D);
      bgColor = Colors.white;
      borderColor = const Color(0xFFD7473D);
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: fgColor,
        backgroundColor: bgColor,
        side: BorderSide(color: borderColor, width: 1.0),
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
                      side: const BorderSide(color: kInk),
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