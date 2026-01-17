// lib/screens/review_screen.dart - FULLY FIXED FOR YOUR EXACT API
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/api_endpoints.dart';
import 'question_screen.dart';


class ReviewScreen extends StatefulWidget {
  final int testId;
  final String userId;
  final String testName;
  final int durationMinutes;
  final int remainingSeconds;
  final String dbFile;  // ← ADD THIS


  const ReviewScreen({
    Key? key,
    required this.testId,
    required this.userId,
    required this.testName,
    required this.durationMinutes,
    this.remainingSeconds = 0,
    
   required this.dbFile,  // ← ADD THIS
  }) : super(key: key);



  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<dynamic> questions = [];
  Map<String, dynamic> answers = {};
  List<String> marked = [];
  List<String> skipped = [];
  bool isLoading = true;
  String? error;
  int _timeLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.remainingSeconds > 0 ? widget.remainingSeconds : widget.durationMinutes * 60;
    _startTimer();
    _loadReviewData();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _timeLeft > 0) {
        setState(() => _timeLeft--);
      }
      if (_timeLeft <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _loadReviewData() async {
    try {
      setState(() => isLoading = true);
      error = null;
      
      final response = await http.get(
      Uri.parse(ApiEndpoints.testReview(widget.testId, widget.dbFile)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          questions = data['questions'] ?? [];
          answers = Map<String, dynamic>.from(data['answers'] ?? {});
          marked = List<String>.from(data['marked'] ?? []);
          skipped = List<String>.from(data['skipped'] ?? []);
        } else {
          throw Exception(data['error'] ?? 'API returned error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        error = 'Failed to load review data: $e';
        isLoading = false;
      });
    }
  }

  String _getQuestionStatus(dynamic question) {
    final qId = question['id']?.toString() ?? '';
    
    // Priority: skipped > answered+marked > answered > marked > not_visited
    if (skipped.contains(qId)) return 'skipped';
    if (answers.containsKey(qId)) {
      return marked.contains(qId) ? 'marked_review' : 'answered';
    }
    if (marked.contains(qId)) return 'marked';
    return 'not_visited';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'answered':
        return const Color(0xFF003087);
      case 'marked':
      case 'marked_review':
        return Colors.orange;
      case 'skipped':
        return const Color(0xFF6C757D);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'answered':
        return Icons.check_circle;
      case 'marked':
      case 'marked_review':
        return Icons.flag;
      case 'skipped':
        return Icons.schedule;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
              Text(error ?? 'No questions available', 
                   style: const TextStyle(color: Colors.red, fontSize: 16),
                   textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadReviewData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final answeredCount = questions.where((q) => 
        answers.containsKey(q['id']?.toString())).length;
    final totalQuestions = questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // 🔥 TOP BAR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 2))
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Text(
                        'Review (${answeredCount}/$totalQuestions)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatTime(_timeLeft),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔥 PROGRESS BAR
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: totalQuestions > 0 ? answeredCount / totalQuestions : 0,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF003087)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completed: $answeredCount/$totalQuestions',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showSubmitDialog(),
                      icon: const Icon(Icons.assignment_turned_in, size: 18),
                      label: const Text('Submit Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🔥 QUESTIONS GRID
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getGridColumns(totalQuestions),
                childAspectRatio: 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                final status = _getQuestionStatus(question);
                final qNum = index + 1;

                return GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuestionScreen(

                        dbFile: widget.dbFile,  // or your actual dbFile variable


                          testId: widget.testId,
                          questionNum: qNum,
                          userId: widget.userId,
                          testName: widget.testName,
                          durationMinutes: widget.durationMinutes,
                          remainingSeconds: _timeLeft,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$qNum',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(status).withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  int _getGridColumns(int totalQuestions) {
    if (totalQuestions <= 16) return 4;
    if (totalQuestions <= 25) return 5;
    return 6;
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Submit Test'),
        content: const Text('Are you sure you want to submit the test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            child: const Text('Submit Test'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTest() async {
    _timer?.cancel();
    
    try {
      final response = await http.post(
      Uri.parse(ApiEndpoints.submitTest(widget.testId, widget.dbFile)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Navigate to results screen with scores
        Navigator.pushReplacementNamed(
          context,
          '/results', // Update this route as needed
          arguments: {
            'testId': widget.testId.toString(),
            'scores': data['scores'],
            'testName': widget.testName,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submit failed. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }
}
