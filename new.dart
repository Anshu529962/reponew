// lib/screens/basic_review_screen.dart - MARROW-STYLE 6x6 GRID REVIEW
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_endpoints.dart';

class BasicReviewScreen extends StatefulWidget {
  final int testId;
  final String userId;
  final String dbFile;

  const BasicReviewScreen({
    Key? key,
    required this.testId,
    required this.userId,
    required this.dbFile,
  }) : super(key: key);

  @override
  _BasicReviewScreenState createState() => _BasicReviewScreenState();
}

class _BasicReviewScreenState extends State<BasicReviewScreen> {
  List<dynamic> questions = [];
  Map<String, dynamic> answers = {};
  List<int> markedQuestions = [];
  List<int> skippedQuestions = [];
  Map<String, dynamic>? testInfo;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadReviewData();
  }

  Future<void> loadReviewData() async {
    try {
      setState(() => isLoading = true);
      final response = await http.get(
        Uri.parse(ApiEndpoints.testReview(widget.testId, widget.dbFile)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          questions = data['questions'] ?? [];
          answers = Map<String, dynamic>.from(data['answers'] ?? {});
          markedQuestions = List<int>.from(data['marked_questions'] ?? []);
          skippedQuestions = List<int>.from(data['skipped_questions'] ?? []);
          testInfo = Map<String, dynamic>.from(data['test'] ?? {});
        });
      } else {
        setState(() => error = 'Failed to load review data');
      }
    } catch (e) {
      setState(() => error = 'Network error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Color _getQuestionColor(int qid) {
    if (answers.containsKey(qid.toString())) return const Color(0xFF28A745); // ✅ GREEN - Answered
    if (markedQuestions.contains(qid)) return const Color(0xFFFFC107);        // ⭐ YELLOW - Marked
    if (skippedQuestions.contains(qid)) return const Color(0xFF6C757D);      // ⏭️ GREY - Skipped
    return const Color(0xFFF8F9FA);                                          // ⚪ WHITE - Unvisited
  }

  String _getQuestionStatus(int qid) {
    if (answers.containsKey(qid.toString())) return '✅ Answered';
    if (markedQuestions.contains(qid)) return '⭐ Marked';
    if (skippedQuestions.contains(qid)) return '⏭️ Skipped';
    return '○ Unvisited';
  }

  void _navigateToQuestion(int qid) {
    Navigator.pop(context); // Back to QuestionScreen with new questionNum
    // QuestionScreen handles navigation via pushReplacement with targetQNum
  }

  List<Widget> _buildGrid() {
    List<Widget> gridItems = [];
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qid = q['id'] as int;
      
      gridItems.add(
        GestureDetector(
          onTap: () => _navigateToQuestion(qid),
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: _getQuestionColor(qid),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${qid}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getQuestionColor(qid) == const Color(0xFFF8F9FA) 
                        ? Colors.black87 
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getQuestionStatus(qid),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _getQuestionColor(qid) == const Color(0xFFF8F9FA) 
                        ? Colors.black54 
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return gridItems;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null || questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(error ?? 'No questions found', 
                   style: const TextStyle(color: Colors.red, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // 🔥 TOP BAR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF003087)),
                      ),
                      Text(
                        testInfo?['name'] ?? 'Test Review',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003087),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance back button space
                    ],
                  ),
                  const Text(
                    'Tap any question to review/answer',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6C757D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔥 PROGRESS STATS
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCard('Answered', answers.length, const Color(0xFF28A745)),
                _StatCard('Marked', markedQuestions.length, const Color(0xFFFFC107)),
                _StatCard('Skipped', skippedQuestions.length, const Color(0xFF6C757D)),
                _StatCard('Total', questions.length, const Color(0xFF003087)),
              ],
            ),
          ),

          // 🔥 6x6 GRID
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: _buildGrid(),
              ),
            ),
          ),

          // 🔥 BOTTOM ACTION BAR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    label: const Text('Continue Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003087),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _StatCard(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6C757D),
          ),
        ),
      ],
    );
  }
}
