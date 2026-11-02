import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'models/task.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskPulseApp());
}

class TaskPulseApp extends StatelessWidget {
  const TaskPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskPulse AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurpleAccent,
        hintColor: Colors.tealAccent,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  List<Task> activeTasks = [];
  List<Task> completedTasks = [];
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // Replace with your WSL IPv4 address for local device testing
  final String backendUrl = "http://192.168.1.X:8000/process_voice"; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    _clearOldCompletedTasks();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _clearOldCompletedTasks() {
    final today = DateTime.now();
    completedTasks.removeWhere((task) {
      // Wipes completed tasks that were not finished today
      return task.deadline != null && task.deadline!.day != today.day;
    });
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (val.hasConfidenceRating && val.confidence > 0.8 && val.finalResult) {
              _processIntentWithAI(val.recognizedWords);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _processIntentWithAI(String text) async {
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'current_time': DateTime.now().toIso8601String()
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['intent'] == 'add_task') {
          _addTask(data);
        } else if (data['intent'] == 'mark_complete') {
          _markTaskCompleteByVoice(data['task_name']);
        }
      }
    } catch (e) {
      print("Error communicating with AI Backend: $e");
    }
  }

  void _addTask(Map<String, dynamic> data) {
    DateTime? deadline = data['deadline'] != null ? DateTime.parse(data['deadline']) : null;
    DateTime? reminder = data['reminder_time'] != null ? DateTime.parse(data['reminder_time']) : null;

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: data['task_name'],
      deadline: deadline,
      reminderTime: reminder,
      priority: data['priority'] ?? 'Low',
      subtasks: List<String>.from(data['subtasks'] ?? []),
      createdAt: DateTime.now(),
    );

    setState(() {
      activeTasks.add(newTask);
    });

    if (reminder != null) {
      _scheduleNotification(newTask);
    }
  }

  void _markTaskCompleteByVoice(String taskName) {
    // Basic string matching to find the task requested via voice
    final index = activeTasks.indexWhere(
      (t) => t.title.toLowerCase().contains(taskName.toLowerCase())
    );
    
    if (index != -1) {
      _toggleTaskCompletion(activeTasks[index]);
    }
  }

  void _toggleTaskCompletion(Task task) {
    setState(() {
      if (task.isCompleted) {
        task.isCompleted = false;
        completedTasks.remove(task);
        activeTasks.add(task);
      } else {
        task.isCompleted = true;
        activeTasks.remove(task);
        completedTasks.add(task);
      }
    });
  }

  Future<void> _scheduleNotification(Task task) async {
    // Setup Android-specific notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'reminder_channel', 'Task Reminders',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Note: In production, use timezone package for accurate scheduling
    final timeDifference = task.reminderTime!.difference(DateTime.now());
    
    if (timeDifference.isNegative) return;

    Future.delayed(timeDifference, () async {
      await flutterLocalNotificationsPlugin.show(
        0,
        'Upcoming Task Reminder',
        '${task.title} is due in 30 minutes!',
        platformChannelSpecifics,
      );
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High': return Colors.redAccent;
      case 'Medium': return Colors.orangeAccent;
      case 'Low': return Colors.greenAccent;
      default: return Colors.grey;
    }
  }

  Widget _buildTaskList(List<Task> tasks, bool isCompletedList) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (_) => _toggleTaskCompletion(task),
              activeColor: Colors.tealAccent,
            ),
            title: RichText(
              text: TextSpan(
                text: task.title,
                style: TextStyle(
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  fontSize: 16,
                  color: Colors.white,
                ),
                children: [
                  if (task.overdueLabel.isNotEmpty && !isCompletedList)
                    TextSpan(
                      text: ' ${task.overdueLabel}',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                ],
              ),
            ),
            subtitle: Row(
              children: [
                Icon(Icons.circle, size: 10, color: _getPriorityColor(task.priority)),
                const SizedBox(width: 4),
                Text(task.priority),
              ],
            ),
            children: task.subtasks.map((sub) => 
              ListTile(
                title: Text("• $sub", style: const TextStyle(color: Colors.white70)),
                dense: true,
              )
            ).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskPulse AI'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          tabs: const [
            Tab(text: 'Tasks to Complete'),
            Tab(text: 'Completed Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList(activeTasks, false),
          _buildTaskList(completedTasks, true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        backgroundColor: _isListening ? Colors.red : Colors.deepPurpleAccent,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
