import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const DictionaryApplet());
}

// 1. EXTENSIBLE THEMES: Added darkSlate!
enum AppTheme { darkBrown, darkSlate, lightTeal, lightBlue, lightSand }

class DictionaryApplet extends StatefulWidget {
  const DictionaryApplet({super.key});

  @override
  State<DictionaryApplet> createState() => _DictionaryAppletState();
}

class _DictionaryAppletState extends State<DictionaryApplet> {
  AppTheme _currentTheme = AppTheme.darkBrown;

  ThemeData _getThemeData() {
    switch (_currentTheme) {
      case AppTheme.darkBrown:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color.fromARGB(255, 37, 34, 30),
          colorScheme: const ColorScheme.dark(
            primary: Colors.orangeAccent,
            surface: Color.fromARGB(255, 45, 37, 30),
            onPrimary: Colors.black,
          ),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF241C1A), foregroundColor: Colors.orangeAccent),
        );
      case AppTheme.darkSlate: // NEW DARK MODE
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1E2124),
          colorScheme: const ColorScheme.dark(
            primary: Colors.cyanAccent,
            surface: Color(0xFF282B30),
            onPrimary: Colors.black,
          ),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF111214), foregroundColor: Colors.cyanAccent),
        );
      case AppTheme.lightTeal:
        return ThemeData(brightness: Brightness.light, colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal));
      case AppTheme.lightBlue:
        return ThemeData(brightness: Brightness.light, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent));
      case AppTheme.lightSand:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFDFBF7),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD4B886)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dictionary CMS',
      theme: _getThemeData(),
      home: MainScreen(
        currentTheme: _currentTheme,
        onThemeChanged: (newTheme) => setState(() => _currentTheme = newTheme),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final AppTheme currentTheme;
  final Function(AppTheme) onThemeChanged;

  const MainScreen({super.key, required this.currentTheme, required this.onThemeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // --- STATE ---
  int _currentIndex = 0; // Tracks which tab is active
  final _pathCtrl = TextEditingController();
  List<dynamic> _dictionary = []; // Holds the loaded JSON data in memory

  // Form Controllers for "Add Word"
  final _formKey = GlobalKey<FormState>();
  final _wordCtrl = TextEditingController();
  final _translationCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _ipaCtrl = TextEditingController();
  final _simplePronunciationCtrl = TextEditingController();
  final _exampleSentenceCtrl = TextEditingController();
  final _exampleEnglishCtrl = TextEditingController();
  final _syllableCtrl = TextEditingController();
  final _rootWordCtrl = TextEditingController();
  final _masteryCtrl = TextEditingController(text: "0");
  final _lessonIdCtrl = TextEditingController();
  final _borrowedFromCtrl = TextEditingController();

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  // --- FILE MANAGEMENT ---
  Future<void> _pickExistingFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null) {
      setState(() => _pathCtrl.text = result.files.single.path!);
      await _loadDictionaryData();
    }
  }

  Future<void> _pickDirectoryForNewFile() async {
    String? directoryPath = await FilePicker.getDirectoryPath();
    if (directoryPath != null) {
      setState(() => _pathCtrl.text = '$directoryPath${Platform.pathSeparator}words.json');
      await _loadDictionaryData();
    }
  }

  Future<void> _loadDictionaryData() async {
    if (_pathCtrl.text.isEmpty) return;
    final file = File(_pathCtrl.text);
    
    try {
      if (await file.exists()) {
        final String contents = await file.readAsString();
        setState(() {
          _dictionary = contents.trim().isNotEmpty ? jsonDecode(contents) : [];
        });
      } else {
        setState(() => _dictionary = []); // File doesn't exist yet, start fresh
      }
    } catch (e) {
      _showSnack('Error loading file: $e', isError: true);
    }
  }

  Future<void> _writeDictionaryToFile() async {
    if (_pathCtrl.text.isEmpty) {
      _showSnack('Please select a file or folder at the top first!', isError: true);
      return;
    }

    final file = File(_pathCtrl.text);
    try {
      if (!await file.parent.exists()) await file.parent.create(recursive: true);
      
      final String jsonString = const JsonEncoder.withIndent('  ').convert(_dictionary);
      await file.writeAsString(jsonString);
    } catch (e) {
      _showSnack('Error writing file: $e', isError: true);
      rethrow;
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  // --- ADD DATA LOGIC ---
  Future<void> _saveNewWord() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pathCtrl.text.isEmpty) {
      _showSnack('Select a target file first!', isError: true);
      return;
    }

    final Map<String, dynamic> newWord = {
      "word": _wordCtrl.text,
      "translation": _translationCtrl.text,
      "partOfSpeech": _posCtrl.text,
      "ipaPronunciation": _ipaCtrl.text,
      "simplePronunciation": _simplePronunciationCtrl.text,
      "exampleSentence": _exampleSentenceCtrl.text,
      "exampleEnglish": _exampleEnglishCtrl.text,
      "syllableBreakdown": _syllableCtrl.text,
      "rootWord": _rootWordCtrl.text,
      "masteryLevel": int.tryParse(_masteryCtrl.text) ?? 0,
      "lessonId": _lessonIdCtrl.text,
    };

    if (_borrowedFromCtrl.text.isNotEmpty) newWord["borrowedFrom"] = _borrowedFromCtrl.text;

    setState(() => _dictionary.add(newWord)); // Update memory
    
    try {
      await _writeDictionaryToFile(); // Update file
      _showSnack('Saved "${_wordCtrl.text}" to JSON!');
      _clearForm();
      FocusScope.of(context).unfocus();
    } catch (e) {
      // Error handled in _writeDictionaryToFile
    }
  }

  void _clearForm() {
    _wordCtrl.clear();
    _translationCtrl.clear();
    _posCtrl.clear();
    _ipaCtrl.clear();
    _simplePronunciationCtrl.clear();
    _exampleSentenceCtrl.clear();
    _exampleEnglishCtrl.clear();
    _syllableCtrl.clear();
    _rootWordCtrl.clear();
    _borrowedFromCtrl.clear();
  }

  // --- EDIT DATA LOGIC ---
  void _openEditDialog(int index) {
    final wordData = _dictionary[index];
    
    // Create temporary controllers for the dialog
    final editWordCtrl = TextEditingController(text: wordData['word']);
    final editTransCtrl = TextEditingController(text: wordData['translation']);
    final editPosCtrl = TextEditingController(text: wordData['partOfSpeech']);
    final editIpaCtrl = TextEditingController(text: wordData['ipaPronunciation']);
    final editSimpleCtrl = TextEditingController(text: wordData['simplePronunciation']);
    final editSentenceCtrl = TextEditingController(text: wordData['exampleSentence']);
    final editEngCtrl = TextEditingController(text: wordData['exampleEnglish']);
    final editSyllableCtrl = TextEditingController(text: wordData['syllableBreakdown']);
    final editRootCtrl = TextEditingController(text: wordData['rootWord']);
    final editMasteryCtrl = TextEditingController(text: wordData['masteryLevel'].toString());
    final editLessonCtrl = TextEditingController(text: wordData['lessonId']);
    final editBorrowedCtrl = TextEditingController(text: wordData['borrowedFrom'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit "${wordData['word']}"'),
          content: SizedBox(
            width: 600, // Make it wide enough for desktop
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: editWordCtrl, decoration: const InputDecoration(labelText: 'Word')),
                  TextFormField(controller: editTransCtrl, decoration: const InputDecoration(labelText: 'Translation')),
                  TextFormField(controller: editPosCtrl, decoration: const InputDecoration(labelText: 'Part of Speech')),
                  TextFormField(controller: editIpaCtrl, decoration: const InputDecoration(labelText: 'IPA')),
                  TextFormField(controller: editSimpleCtrl, decoration: const InputDecoration(labelText: 'Simple Pronunciation')),
                  TextFormField(controller: editSentenceCtrl, decoration: const InputDecoration(labelText: 'Example Sentence')),
                  TextFormField(controller: editEngCtrl, decoration: const InputDecoration(labelText: 'Example English')),
                  TextFormField(controller: editSyllableCtrl, decoration: const InputDecoration(labelText: 'Syllable Breakdown')),
                  TextFormField(controller: editRootCtrl, decoration: const InputDecoration(labelText: 'Root Word')),
                  TextFormField(controller: editBorrowedCtrl, decoration: const InputDecoration(labelText: 'Borrowed From (Optional)')),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: editLessonCtrl, decoration: const InputDecoration(labelText: 'Lesson ID'))),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: editMasteryCtrl, decoration: const InputDecoration(labelText: 'Mastery Level'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () async {
                // Update the memory map
                _dictionary[index] = {
                  "word": editWordCtrl.text,
                  "translation": editTransCtrl.text,
                  "partOfSpeech": editPosCtrl.text,
                  "ipaPronunciation": editIpaCtrl.text,
                  "simplePronunciation": editSimpleCtrl.text,
                  "exampleSentence": editSentenceCtrl.text,
                  "exampleEnglish": editEngCtrl.text,
                  "syllableBreakdown": editSyllableCtrl.text,
                  "rootWord": editRootCtrl.text,
                  "masteryLevel": int.tryParse(editMasteryCtrl.text) ?? 0,
                  "lessonId": editLessonCtrl.text,
                };
                if (editBorrowedCtrl.text.isNotEmpty) {
                  _dictionary[index]["borrowedFrom"] = editBorrowedCtrl.text;
                }

                Navigator.pop(context); // Close dialog
                
                setState(() {}); // Trigger UI update for the list
                try {
                  await _writeDictionaryToFile();
                  _showSnack('Updated "${editWordCtrl.text}" successfully!');
                } catch (e) {
                  // Error handled in _writeDictionaryToFile
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      }
    );
  }

  void _deleteWord(int index) {
    final word = _dictionary[index]['word'];
    setState(() {
      _dictionary.removeAt(index);
    });
    _writeDictionaryToFile().then((_) {
      _showSnack('Deleted "$word"');
    });
  }

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON Dictionary CMS'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<AppTheme>(
              value: widget.currentTheme,
              dropdownColor: Theme.of(context).colorScheme.surface,
              underline: const SizedBox(),
              icon: Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
              items: AppTheme.values.map((AppTheme theme) {
                String themeName = theme.name.replaceAll('light', 'Light ').replaceAll('dark', 'Dark ');
                themeName = themeName[0].toUpperCase() + themeName.substring(1);
                return DropdownMenuItem<AppTheme>(value: theme, child: Text(themeName));
              }).toList(),
              onChanged: (AppTheme? newTheme) {
                if (newTheme != null) widget.onThemeChanged(newTheme);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. FILE PICKER HEADER (Always visible)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickExistingFile,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Select Existing File'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDirectoryForNewFile,
                          icon: const Icon(Icons.create_new_folder),
                          label: const Text('Choose Folder (Create New)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pathCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Target File Path',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _loadDictionaryData(), // Reload if path typed manually
                  ),
                ],
              ),
            ),
          ),
          
          // 2. TAB CONTENT
          Expanded(
            child: _currentIndex == 0 ? _buildAddTab() : _buildEditTab(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Add Word'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Edit Dictionary'),
        ],
      ),
    );
  }

  Widget _buildAddTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(controller: _wordCtrl, decoration: const InputDecoration(labelText: 'Word'), textInputAction: TextInputAction.next),
            TextFormField(controller: _translationCtrl, decoration: const InputDecoration(labelText: 'Translation'), textInputAction: TextInputAction.next),
            TextFormField(controller: _posCtrl, decoration: const InputDecoration(labelText: 'Part of Speech'), textInputAction: TextInputAction.next),
            TextFormField(controller: _ipaCtrl, decoration: const InputDecoration(labelText: 'IPA Pronunciation'), textInputAction: TextInputAction.next),
            TextFormField(controller: _simplePronunciationCtrl, decoration: const InputDecoration(labelText: 'Simple Pronunciation'), textInputAction: TextInputAction.next),
            TextFormField(controller: _exampleSentenceCtrl, decoration: const InputDecoration(labelText: 'Example Sentence'), textInputAction: TextInputAction.next),
            TextFormField(controller: _exampleEnglishCtrl, decoration: const InputDecoration(labelText: 'Example English'), textInputAction: TextInputAction.next),
            TextFormField(controller: _syllableCtrl, decoration: const InputDecoration(labelText: 'Syllable Breakdown'), textInputAction: TextInputAction.next),
            TextFormField(controller: _rootWordCtrl, decoration: const InputDecoration(labelText: 'Root Word'), textInputAction: TextInputAction.next),
            TextFormField(controller: _borrowedFromCtrl, decoration: const InputDecoration(labelText: 'Borrowed From (Optional)'), textInputAction: TextInputAction.next),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _lessonIdCtrl, decoration: const InputDecoration(labelText: 'Lesson ID'), textInputAction: TextInputAction.next)),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _masteryCtrl, decoration: const InputDecoration(labelText: 'Mastery Level'), keyboardType: TextInputType.number, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _saveNewWord())),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveNewWord, 
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
              child: const Text('SAVE WORD & NEXT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEditTab() {
    if (_dictionary.isEmpty) {
      return const Center(child: Text('No words found in this file. Go to the Add tab to create some!'));
    }

    return ListView.builder(
      itemCount: _dictionary.length,
      itemBuilder: (context, index) {
        final word = _dictionary[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Theme.of(context).colorScheme.surface,
          child: ListTile(
            title: Text(word['word'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${word['partOfSpeech'] ?? ''} • ${word['translation'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _openEditDialog(index),
                  tooltip: 'Edit Word',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteWord(index),
                  tooltip: 'Delete Word',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}