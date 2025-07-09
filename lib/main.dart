import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

// Page Model
class QuranPage {
  final int pageNumber;
  final List<QuranLine> lines;

  QuranPage({required this.pageNumber, required this.lines});
}

class QuranLine {
  final int lineNumber;
  final bool isCentered;
  final String text;

  QuranLine({
    required this.lineNumber,
    required this.isCentered,
    required this.text,
  });

  // Factory to create lines from text
  static List<QuranLine> fromText(String text, int pageNumber) {
    const int linesPerPage = 15;
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // Ensure exactly 15 lines
    List<QuranLine> result = [];
    for (int i = 0; i < linesPerPage; i++) {
      final idx = i + 1;
      final lineText = i < lines.length ? lines[i].trim() : '';
      final isCentered = idx == 1 || lineText.contains('بِسْمِ ٱللَّهِ') || lineText.contains('سُورَة');
      result.add(QuranLine(
        lineNumber: idx,
        isCentered: isCentered,
        text: lineText,
      ));
    }
    return result;
  }
}

// Main App
void main() {
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
  int _currentPage = 1;
  final int _totalPages = 604;

  Future<String> loadPageText(int pageNumber) async {
    try {
      return await rootBundle.loadString('assets/docs/$pageNumber.txt');
    } catch (e) {
      return 'Error loading text: $e';
    }
  }

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
          final pageNumber = index + 1;
          return FutureBuilder<String>(
            future: loadPageText(pageNumber),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(child: Text('Error loading page: ${snapshot.error ?? "No data"}'));
              }
              final text = snapshot.data!;
              final lines = QuranLine.fromText(text, pageNumber);
              return QuranPageWidget(
                page: QuranPage(pageNumber: pageNumber, lines: lines),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32.0; // 16.0 padding on each side
    const double lineHeight = 40.0;
    const int linesPerPage = 15;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(linesPerPage, (index) {
                final line = page.lines[index];
                return Container(
                  height: lineHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textSpan = TextSpan(
                        text: line.text.isEmpty ? ' ' : line.text,
                        style: TextStyle( fontFamily : 'Uthmani',
                          fontSize: 18.0, // Base font size
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      );
                      final textPainter = TextPainter(
                        text: textSpan,
                        textDirection: TextDirection.rtl,
                        textAlign: line.isCentered ? TextAlign.center : TextAlign.justify,
                        maxLines: 1,
                      );
                      textPainter.layout(maxWidth: availableWidth);

                      // Adjust font size and spacing
                      double fontSize = 18.0;
                      double letterSpacing = 0.0;
                      double wordSpacing = 0.0;

                      if (!line.isCentered && line.text.isNotEmpty) {
                        // Ensure text fits within width
                        if (textPainter.width > availableWidth) {
                          while (textPainter.width > availableWidth && fontSize > 14.0) {
                            fontSize -= 0.5;
                            textPainter.text = TextSpan(
                              text: line.text,
                              style: TextStyle( fontFamily : 'Uthmani',
                                fontSize: fontSize,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                            textPainter.layout(maxWidth: availableWidth);
                          }
                        } else {
                          // Increase font size to approach width
                          while (textPainter.width < availableWidth * 0.95 && fontSize < 22.0) {
                            fontSize += 0.2;
                            textPainter.text = TextSpan(
                              text: line.text,
                              style: TextStyle( fontFamily : 'Uthmani',
                                fontSize: fontSize,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                            textPainter.layout(maxWidth: availableWidth);
                          }
                        }

                        // Adjust spacing to exactly fit width
                        double targetWidth = availableWidth;
                        double currentWidth = textPainter.width;
                        if (currentWidth < targetWidth) {
                          double remainingWidth = targetWidth - currentWidth;
                          int wordCount = line.text.split(' ').length;
                          wordSpacing = remainingWidth / (wordCount > 0 ? wordCount : 1);
                          letterSpacing = remainingWidth / (line.text.length > 0 ? line.text.length : 1) * 0.3;

                          textPainter.text = TextSpan(
                            text: line.text,
                            style: TextStyle( fontFamily : 'Uthmani',
                              fontSize: fontSize,
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                              letterSpacing: letterSpacing,
                              wordSpacing: wordSpacing,
                            ),
                          );
                          textPainter.layout(maxWidth: availableWidth);

                          // If still exceeds, reduce font size slightly
                          if (textPainter.width > availableWidth) {
                            fontSize -= 0.2;
                            letterSpacing *= 0.9;
                            wordSpacing *= 0.9;
                            textPainter.text = TextSpan(
                              text: line.text,
                              style: TextStyle( fontFamily : 'Uthmani',
                                fontSize: fontSize,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                letterSpacing: letterSpacing,
                                wordSpacing: wordSpacing,
                              ),
                            );
                            textPainter.layout(maxWidth: availableWidth);
                          }
                        }
                      } else if (line.isCentered && line.text.isNotEmpty) {
                        // Ensure centered line has a reasonable size
                        if (textPainter.width < availableWidth * 0.5) {
                          while (textPainter.width < availableWidth * 0.6 && fontSize < 22.0) {
                            fontSize += 0.5;
                            textPainter.text = TextSpan(
                              text: line.text,
                              style: TextStyle( fontFamily : 'Uthmani',
                                fontSize: fontSize,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                            textPainter.layout(maxWidth: availableWidth);
                          }
                        }
                      }

                      return Text(
                        line.text.isEmpty ? '' : line.text,
                        textAlign: line.isCentered ? TextAlign.center : TextAlign.justify,
                        style: TextStyle( fontFamily : 'Uthmani',
                          fontSize: fontSize,
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                          letterSpacing: letterSpacing,
                          wordSpacing: wordSpacing,
                        ),
                        textDirection: TextDirection.rtl,
                        softWrap: false,
                        maxLines: 1,
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}