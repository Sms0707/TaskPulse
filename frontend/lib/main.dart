import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskPulseApp());
}

// --- INLINED TASK MODEL FOR LOCAL STORAGE ---
class Task {
  String id;
  String title;
  DateTime? deadline;
  DateTime? reminderTime;
  String priority;
  List<String> subtasks;
  DateTime createdAt;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.deadline,
    this.reminderTime,
    required this.priority,
    required this.subtasks,
    required this.createdAt,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'deadline': deadline?.toIso8601String(),
    'reminderTime': reminderTime?.toIso8601String(),
    'priority': priority,
    'subtasks': subtasks,
    'createdAt': createdAt.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    reminderTime: json['reminderTime'] != null ? DateTime.parse(json['reminderTime']) : null,
    priority: json['priority'],
    subtasks: List<String>.from(json['subtasks'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    isCompleted: json['isCompleted'],
  );
}
// ---------------------------------------------

class TaskPulseApp extends StatefulWidget {
  const TaskPulseApp({super.key});
  @override
  State<TaskPulseApp> createState() => _TaskPulseAppState();
}

class _TaskPulseAppState extends State<TaskPulseApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskPulse AI',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFE2E8F0),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(onToggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  const HomeScreen({super.key, required this.onToggleTheme, required this.isDarkMode});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();
  
  List<Task> activeTasks = [];
  List<Task> completedTasks = [];
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Update with your IP or 127.0.0.1
  final String backendUrl = "https://taskpulse-backend-21l4.onrender.com/"; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    _loadTasks(); // Load saved tasks on startup
  }

  // --- LOCAL STORAGE LOGIC ---
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final activeData = prefs.getString('activeTasks');
    final completedData = prefs.getString('completedTasks');

    if (activeData != null) {
      Iterable decoded = jsonDecode(activeData);
      activeTasks = decoded.map((task) => Task.fromJson(task)).toList();
    }
    if (completedData != null) {
      Iterable decoded = jsonDecode(completedData);
      completedTasks = decoded.map((task) => Task.fromJson(task)).toList();
    }
    setState(() {});
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeTasks', jsonEncode(activeTasks.map((t) => t.toJson()).toList()));
    await prefs.setString('completedTasks', jsonEncode(completedTasks.map((t) => t.toJson()).toList()));
  }
  // ---------------------------

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
      );

      if (available) {
        setState(() => _isListening = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "🎙️ Listening... Try 'Delete all tasks' or 'Add a massive project'",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 10,
          ),
        );

        _speech.listen(
          onResult: (val) {
            if (val.hasConfidenceRating && val.confidence > 0.7 && val.finalResult) {
              setState(() => _isListening = false);
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

  void _submitTextTask() {
    if (_textController.text.isNotEmpty) {
      _processIntentWithAI(_textController.text);
      _textController.clear();
      FocusScope.of(context).unfocus();
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
        } else if (data['intent'] == 'delete_task') {
          _deleteTaskByVoice(data['task_name']);
        } else if (data['intent'] == 'delete_all_tasks') {
          _deleteAllTasks();
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
      title: data['task_name'] ?? 'New Task',
      deadline: deadline,
      reminderTime: reminder,
      priority: data['priority'] ?? 'Low',
      subtasks: List<String>.from(data['subtasks'] ?? []),
      createdAt: DateTime.now(),
    );

    setState(() {
      activeTasks.insert(0, newTask); // Add to top
    });
    _saveTasks();
  }

  void _markTaskCompleteByVoice(String taskName) {
    final index = activeTasks.indexWhere((t) => t.title.toLowerCase().contains(taskName.toLowerCase()));
    if (index != -1) _toggleTaskCompletion(activeTasks[index]);
  }

  void _deleteTask(Task task) {
    setState(() {
      activeTasks.remove(task);
      completedTasks.remove(task);
    });
    _saveTasks();
  }

  void _deleteTaskByVoice(String identifier) {
    setState(() {
      if (identifier.toLowerCase().contains("first") && activeTasks.isNotEmpty) {
        activeTasks.removeAt(0);
      } else {
        activeTasks.removeWhere((t) => t.title.toLowerCase().contains(identifier.toLowerCase()));
        completedTasks.removeWhere((t) => t.title.toLowerCase().contains(identifier.toLowerCase()));
      }
    });
    _saveTasks();
  }

  void _deleteAllTasks() {
    setState(() {
      activeTasks.clear();
      completedTasks.clear();
    });
    _saveTasks();
  }

  void _toggleTaskCompletion(Task task) {
    setState(() {
      if (task.isCompleted) {
        task.isCompleted = false;
        completedTasks.remove(task);
        activeTasks.insert(0, task);
      } else {
        task.isCompleted = true;
        activeTasks.remove(task);
        completedTasks.insert(0, task);
      }
    });
    _saveTasks();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High': return const Color(0xFFF43F5E); // Neon Red
      case 'Medium': return const Color(0xFFFBBF24); // Neon Amber
      case 'Low': return const Color(0xFF10B981); // Neon Green
      default: return Colors.grey;
    }
  }

  Widget _buildGlassCard({required Widget child, required Color shadowColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(widget.isDarkMode ? 0.1 : 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: widget.isDarkMode 
                ? Colors.white.withOpacity(0.03) 
                : Colors.white.withOpacity(0.4),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, bool isCompletedList) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          isCompletedList ? "No completed tasks." : "No active tasks. Say something crazy!",
          style: TextStyle(color: widget.isDarkMode ? Colors.white38 : Colors.black38, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final priorityColor = _getPriorityColor(task.priority);
        final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

        Widget taskHeader = ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => _toggleTaskCompletion(task),
            activeColor: const Color(0xFF06B6D4), // Neon Cyan
            checkColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: widget.isDarkMode ? Colors.white54 : Colors.black54, width: 1.5),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: task.isCompleted ? Colors.grey : textColor,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flash_on_rounded, size: 12, color: priorityColor),
                      const SizedBox(width: 4),
                      Text(task.priority, style: TextStyle(color: priorityColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFFF43F5E)),
            onPressed: () => _deleteTask(task),
          ),
        );

        // CONDITIONAL RENDERING: Only show dropdown if AI generated subtasks
        Widget cardContent;
        if (task.subtasks.isEmpty) {
          cardContent = taskHeader;
        } else {
          cardContent = Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: taskHeader,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: task.subtasks.map((sub) => 
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 56),
                  title: Text(sub, style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14)),
                  leading: Icon(Icons.subdirectory_arrow_right, size: 18, color: priorityColor.withOpacity(0.7)),
                  dense: true,
                )
              ).toList(),
            ),
          );
        }

        return _buildGlassCard(
          child: cardContent,
          shadowColor: priorityColor,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: widget.isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2)),
          ),
        ),
        title: Text('TaskPulse AI', style: TextStyle(
          fontWeight: FontWeight.w900, 
          letterSpacing: 2, 
          foreground: Paint()..shader = const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0))
        )),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: widget.isDarkMode ? Colors.white : Colors.black),
            onPressed: widget.onToggleTheme,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF06B6D4),
          indicatorWeight: 4,
          labelColor: const Color(0xFF06B6D4),
          unselectedLabelColor: widget.isDarkMode ? Colors.grey : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [Tab(text: 'ACTIVE'), Tab(text: 'COMPLETED')],
        ),
      ),
      body: Stack(
        children: [
          // Crazy Background Design
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF8B5CF6).withOpacity(0.3), backgroundBlendMode: BlendMode.screen),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container()),
            ),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF06B6D4).withOpacity(0.3), backgroundBlendMode: BlendMode.screen),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container()),
            ),
          ),
          
          TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList(activeTasks, false),
              _buildTaskList(completedTasks, true),
            ],
          ),
          
          // Floating Holographic Input Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Type or command AI...',
                              hintStyle: TextStyle(color: widget.isDarkMode ? Colors.white54 : Colors.black54),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _submitTextTask(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF06B6D4)),
                          onPressed: _submitTextTask,
                        ),
                        
                        // Holographic Mic Button
                        GestureDetector(
                          onTap: _listen,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isListening 
                                    ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)] 
                                    : [const Color(0xFF8B5CF6), const Color(0xFF06B6D4)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _isListening ? const Color(0xFFF43F5E).withOpacity(0.5) : const Color(0xFF06B6D4).withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: _isListening
                                ? const WavyAudioIndicator()
                                : const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Wavy audio animation widget
class WavyAudioIndicator extends StatefulWidget {
  const WavyAudioIndicator({super.key});
  @override
  State<WavyAudioIndicator> createState() => _WavyAudioIndicatorState();
}

class _WavyAudioIndicatorState extends State<WavyAudioIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            double height = 8.0 + (14.0 * ((_controller.value + index * 0.3) % 1.0));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              width: 3.5,
              height: height,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
            );
          }),
        );
      },
    );
  }
}
