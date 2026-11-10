import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToDoListApp());
}

class TodoTask {
  TodoTask({
    required this.id,
    required this.title,
    this.description = '',
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

  factory TodoTask.fromJson(Map<String, dynamic> json) => TodoTask(
        id: json['id'],
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        deadline: DateTime.tryParse(json['deadline'] ?? '') ?? DateTime.now(),
        isComplete: json['isComplete'] ?? false,
      );
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315BEE)),
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

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('todo_tasks') ?? [];
    setState(() {
      _tasks.addAll(raw.map((e) => TodoTask.fromJson(jsonDecode(e))));
      _isLoading = false;
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'todo_tasks',
      _tasks.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  void _openTaskForm({TodoTask? task}) async {
    final result = await showDialog<TodoTask>(
      context: context,
      builder: (_) => TaskFormDialog(task: task),
    );
    if (result == null) return;

    setState(() {
      if (task == null) {
        _tasks.add(result);
      } else {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) _tasks[index] = result;
      }
    });
    _saveTasks();
  }

  void _deleteTask(TodoTask task) {
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    _tasks.sort((a, b) => a.isComplete == b.isComplete
        ? a.deadline.compareTo(b.deadline)
        : (a.isComplete ? 1 : -1));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskForm(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Your Task',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_tasks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text('You have no task.'),
                      ),
                    )
                  else
                    ..._tasks.map((task) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            leading: Checkbox(
                              value: task.isComplete,
                              onChanged: (val) {
                                setState(() => task.isComplete = val ?? false);
                                _saveTasks();
                              },
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: task.isComplete
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Due: ${_deadlineString(task.deadline)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 90,
                                    ),
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Text(
                                            task.description,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _openTaskForm(task: task),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () => _deleteTask(task),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  String _deadlineString(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }
}

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, this.task});
  final TodoTask? task;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late DateTime _deadline;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _deadline = widget.task?.deadline ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final hourStr = _deadline.hour.toString().padLeft(2, '0');
    final minStr = _deadline.minute.toString().padLeft(2, '0');

    return AlertDialog(
      title: Text(isEditing ? 'Edit Task' : 'New Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              keyboardType: TextInputType.multiline,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Write the description...',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Date: ${_deadline.day}/${_deadline.month}/${_deadline.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _deadline,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    _deadline = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      _deadline.hour,
                      _deadline.minute,
                    );
                  });
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Time: $hourStr:$minStr'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_deadline),
                );
                if (time != null) {
                  setState(() {
                    _deadline = DateTime(
                      _deadline.year,
                      _deadline.month,
                      _deadline.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              TodoTask(
                id: widget.task?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                title: _titleCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                deadline: _deadline,
                isComplete: widget.task?.isComplete ?? false,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}