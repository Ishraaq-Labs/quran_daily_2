import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';

// Database Helper Class
class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'quran.db';
  static const String tablePages = 'pages';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), dbName);
    bool exists = await databaseExists(path);
    if (!exists) {
      ByteData data = await rootBundle.load('assets/quran.db');
      List<int> bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return await openDatabase(path, readOnly: true);
  }

  Future<List<Map<String, dynamic>>> getPageData(int pageNumber) async {
    final db = await database;
    return await db.query(
      tablePages,
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number',
    );
  }
}

// Text Helper Class (Using .txt files)
class TextHelper {
  static Future<String> loadPageText(int pageNumber) async {
    try {
      return await rootBundle.loadString('assets/docs/$pageNumber.txt');
    } catch (e) {
      return 'Error loading text: $e';
    }
  }
}

// Page Model
class QuranPage {
  final int pageNumber;
  final List<QuranLine> lines;

  QuranPage({required this.pageNumber, required this.lines});
}

class QuranLine {
  final int lineNumber;
  final String lineType;
  final bool isCentered;
  final int firstWordId;
  final int lastWordId;
  final int surahNumber;
  final String text;

  QuranLine({
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    required this.firstWordId,
    required this.lastWordId,
    required this.surahNumber,
    required this.text,
  });

  factory QuranLine.fromMap(Map<String, dynamic> map, String text) {
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      final stringValue = value.toString();
      if (stringValue.isEmpty) return defaultValue;
      try {
        return int.parse(stringValue);
      } catch (e) {
        print('Error parsing $stringValue: $e');
        return defaultValue;
      }
    }

    return QuranLine(
      lineNumber: parseInt(map['line_number']),
      lineType: map['line_type']?.toString() ?? '',
      isCentered: parseInt(map['is_centered']) == 1,
      firstWordId: parseInt(map['first_word_id']),
      lastWordId: parseInt(map['last_word_id']),
      surahNumber: parseInt(map['surah_number']),
      text: text,
    );
  }
}

// Main App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Reader',
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: TextTheme(
          bodyLarge: GoogleFonts.amiri(fontSize: 24, color: Colors.black),
        ),
      ),
      home: const QuranPageView(),
    );
  }
}

// Page View for Quran Pages
class QuranPageView extends StatefulWidget {
  const QuranPageView({super.key});

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  final PageController _pageController = PageController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  int _currentPage = 1;
  final int _totalPages = 604;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Reader'),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _totalPages,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index + 1;
          });
        },
        itemBuilder: (context, index) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _dbHelper.getPageData(index + 1),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading page: ${snapshot.error}'));
              }
              return FutureBuilder<String>(
                future: TextHelper.loadPageText(index + 1),
                builder: (context, textSnapshot) {
                  if (textSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (textSnapshot.hasError) {
                    return Center(child: Text('Error loading text: ${textSnapshot.error}'));
                  }
                  final text = textSnapshot.data ?? '';
                  final textLines = text.split('\n');
                  final lines = snapshot.data
                          ?.asMap()
                          .entries
                          .map((e) {
                            int idx = e.key;
                            var map = e.value;
                            var lineText = idx < textLines.length ? textLines[idx] : '';
                            return QuranLine.fromMap(map, lineText);
                          })
                          .toList() ??
                      [];
                  return QuranPageWidget(
                    page: QuranPage(pageNumber: index + 1, lines: lines),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _currentPage > 1
                  ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            Text('Page $_currentPage of $_totalPages'),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _currentPage < _totalPages
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// Widget to Display a Single Page
class QuranPageWidget extends StatelessWidget {
  final QuranPage page;

  const QuranPageWidget({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    // Get the available width for text, accounting for padding
    final screenWidth = MediaQuery.of(context).size.width;
    final textWidth = screenWidth - 32.0; // Subtract padding (16.0 * 2)

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Page ${page.pageNumber}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: page.lines.length,
              itemBuilder: (context, index) {
                final line = page.lines[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Container(
                    width: textWidth, // Fixed width for consistent stretching
                    child: Text(
                      line.text.isEmpty ? '[No text available]' : line.text,
                      textAlign: line.isCentered ? TextAlign.center : TextAlign.justify,
                      style: TextStyle(
                        fontFamily: 'Uthmani',
                        fontSize: 20,
                        height: 1.8, // Increased line spacing for readability
                        wordSpacing: 1.0, // Slight word spacing for better justification
                      ),
                      textDirection: TextDirection.rtl,
                      softWrap: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
