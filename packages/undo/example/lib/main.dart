import 'package:flutter/material.dart';
import 'package:undo/undo.dart';

void main() {
  runApp(const UndoExampleApp());
}

class UndoExampleApp extends StatelessWidget {
  const UndoExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const TodoListScreen(),
    );
  }
}

// ----------------------------------------------------------------------
// Domain Model
// ----------------------------------------------------------------------

class TodoItem {
  final String id;
  final String description;
  final bool isCompleted;

  TodoItem({
    required this.id,
    required this.description,
    this.isCompleted = false,
  });

  TodoItem copyWith({
    String? description,
    bool? isCompleted,
  }) {
    return TodoItem(
      id: id,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

// ----------------------------------------------------------------------
// Controller (Logic)
// ----------------------------------------------------------------------

class TodoListController extends ChangeNotifier {
  final ChangeStack _changes = ChangeStack();
  
  List<TodoItem> _items = [
    TodoItem(id: '1', description: 'Buy groceries'),
    TodoItem(id: '2', description: 'Walk the dog'),
    TodoItem(id: '3', description: 'Read a book'),
  ];

  List<TodoItem> get items => List.unmodifiable(_items);

  bool get canUndo => _changes.canUndo;
  bool get canRedo => _changes.canRedo;

  void undo() {
    if (canUndo) {
      _changes.undo();
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _changes.redo();
      notifyListeners();
    }
  }

  void addItem(String description) {
    final newItem = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: description,
    );
    
    _changes.add(
      Change<List<TodoItem>>(
        _items,
        () {
          _items = List.of(_items)..add(newItem);
          notifyListeners();
        },
        (oldList) {
          _items = oldList;
          notifyListeners();
        },
        description: 'Add item "$description"',
      ),
    );
  }

  void removeItem(String id) {
    final itemToRemove = _items.firstWhere((item) => item.id == id);
    
    _changes.add(
      Change<List<TodoItem>>(
        _items,
        () {
          _items = List.of(_items)..removeWhere((item) => item.id == id);
          notifyListeners();
        },
        (oldList) {
          _items = oldList;
          notifyListeners();
        },
        description: 'Remove item "${itemToRemove.description}"',
      ),
    );
  }

  void toggleItem(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    
    final item = _items[index];
    
    _changes.add(
      Change<List<TodoItem>>(
        _items,
        () {
          _items = List.of(_items);
          _items[index] = item.copyWith(isCompleted: !item.isCompleted);
          notifyListeners();
        },
        (oldList) {
          _items = oldList;
          notifyListeners();
        },
        description: 'Toggle "${item.description}"',
      ),
    );
  }
  
  void clearHistory() {
    _changes.clearHistory();
    notifyListeners();
  }
}

// ----------------------------------------------------------------------
// UI
// ----------------------------------------------------------------------

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TodoListController _controller = TodoListController();

  @override
  void initState() {
    super.initState();
    // Listen to controller changes to rebuild UI
    _controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  void _rebuild() {
    setState(() {});
  }

  void _showAddDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Task'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'What needs to be done?',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
             if (value.isNotEmpty) {
                _controller.addItem(value);
                Navigator.of(context).pop();
             }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                _controller.addItem(textController.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Undo/Redo Todos'),
        centerTitle: true,
        actions: [
           IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear History',
            onPressed: _controller.clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUndoRedoBar(),
          Expanded(
            child: _controller.items.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _controller.items.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final item = _controller.items[index];
                      return _buildTodoItem(item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildUndoRedoBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _controller.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              onPressed: _controller.canRedo ? _controller.redo : null,
              icon: const Icon(Icons.redo),
              label: const Text('Redo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'All items completed!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(TodoItem item) {
    return Dismissible(
      key: Key(item.id),
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _controller.removeItem(item.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ListTile(
          leading: Checkbox(
            value: item.isCompleted,
            onChanged: (_) => _controller.toggleItem(item.id),
          ),
          title: Text(
            item.description,
            style: TextStyle(
              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
              color: item.isCompleted
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          onTap: () => _controller.toggleItem(item.id),
        ),
      ),
    );
  }
}
