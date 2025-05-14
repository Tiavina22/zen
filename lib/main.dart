import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/database_service.dart';
import 'widgets/blur_dialog.dart';

// Couleurs personnalisées pour le thème sombre
const darkBackground = Color(0xFF1E1E2E);
const darkSurface = Color(0xFF2A2A3C);
const darkPrimary = Color(0xFF94E2D5);
const darkSecondary = Color(0xFFA6E3A1);
const darkText = Color(0xFFCDD6F4);
const darkTextSecondary = Color(0xFF9399B2);
const darkBorder = Color(0xFF313244);
const darkError = Color(0xFFF38BA8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await DatabaseService.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: darkPrimary,
          secondary: darkSecondary,
          surface: darkSurface,
          background: darkBackground,
          error: darkError,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackground,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            color: darkText,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkSurface.withOpacity(0.95),
          contentTextStyle: const TextStyle(color: darkText),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const ClipboardManagerScreen(),
    );
  }
}

class ClipboardManagerScreen extends StatefulWidget {
  const ClipboardManagerScreen({super.key});

  @override
  State<ClipboardManagerScreen> createState() => _ClipboardManagerScreenState();
}

class _ClipboardManagerScreenState extends State<ClipboardManagerScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _clipboardHistory = [];
  String? _lastCopiedText;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadClipboardHistory();
    _startClipboardListener();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadClipboardHistory() async {
    final items = await DatabaseService.getItems();
    setState(() {
      _clipboardHistory.clear();
      _clipboardHistory.addAll(items);
    });
  }

  void _startClipboardListener() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      
      if (text != null && text != _lastCopiedText && text.isNotEmpty) {
        _lastCopiedText = text;
        await DatabaseService.insertItem(text);
        await _loadClipboardHistory();
      }
      return true;
    });
  }

  Future<void> _deleteItem(int id) async {
    await DatabaseService.deleteItem(id);
    await _loadClipboardHistory();
  }

  Future<void> _clearHistory() async {
    await DatabaseService.deleteAllItems();
    await _loadClipboardHistory();
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_searchQuery.isEmpty) return _clipboardHistory;
    return _clipboardHistory
        .where((item) => item['content']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _clipboardHistory.removeAt(oldIndex);
    _clipboardHistory.insert(newIndex, item);
    await DatabaseService.reorderItems(oldIndex, newIndex);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 18,
                  color: darkText,
                ),
                decoration: const InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(
                    color: darkTextSecondary,
                    fontSize: 18,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Clipboard'),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: darkText),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: darkText,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          if (!_isSearching && _clipboardHistory.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: darkText,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.transparent,
                  builder: (context) => BlurDialog(
                    child: AlertDialog(
                      backgroundColor: darkSurface.withOpacity(0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Vider l\'historique',
                        style: TextStyle(
                          color: darkText,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: const Text(
                        'Voulez-vous vraiment supprimer tout l\'historique ?',
                        style: TextStyle(
                          color: darkTextSecondary,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: darkTextSecondary,
                          ),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () {
                            _clearHistory();
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: darkError,
                          ),
                          child: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _clipboardHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.content_paste_outlined,
                    size: 84,
                    color: darkTextSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Aucun élément copié',
                    style: TextStyle(
                      fontSize: 18,
                      color: darkTextSecondary,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Theme(
              data: Theme.of(context).copyWith(
                canvasColor: darkBackground,
                shadowColor: Colors.black.withOpacity(0.3),
              ),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.all(16),
                itemCount: _filteredHistory.length,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final double elevation = animation.value * 12;
                      return Material(
                        elevation: elevation,
                        color: darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final item = _filteredHistory[index];
                  return ReorderableDragStartListener(
                    key: Key(item['id'].toString()),
                    index: index,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: darkBorder,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: item['content']));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Copié dans le presse-papiers',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['content'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: darkText,
                                          letterSpacing: 0.1,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: darkBackground.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _formatTimestamp(item['timestamp']),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: darkTextSecondary,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: darkTextSecondary,
                                  ),
                                  onPressed: () => _deleteItem(item['id']),
                                  style: IconButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${difference.inMinutes} min';
      }
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class ClipboardSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> history;
  final Function(String) onItemSelected;

  ClipboardSearchDelegate({
    required this.history,
    required this.onItemSelected,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final filteredItems = history.where((item) =>
        item['content'].toString().toLowerCase().contains(query.toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems.elementAt(index);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              title: Text(
                item['content'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _formatTimestamp(item['timestamp']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              onTap: () {
                onItemSelected(item['content']);
                close(context, item['content']);
              },
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      }
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}
