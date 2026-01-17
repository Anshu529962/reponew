// lib/screens/question_screen.dart - MARROW-STYLE UI (UPDATED WITH QUESTION-STATUS API)
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../config/api_endpoints.dart';
import 'test_results_screen.dart';
import 'dart:async';
import 'basic_review_screen.dart';

class QuestionScreen extends StatefulWidget {
  final int testId;
  final int questionNum;
  final String userId;
  final String testName;
  final int durationMinutes;
  final int remainingSeconds;
  final String dbFile;

  const QuestionScreen({
    Key? key,
    required this.testId,
    required this.questionNum,
    required this.userId,
    required this.testName,
    required this.durationMinutes,
    this.remainingSeconds = 0,
    required this.dbFile,
  }) : super(key: key);

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  Map<String, dynamic>? questionData;
  bool isLoading = true;
  String? error;
  String? selectedAnswer;
  bool isMarked = false;
  int currentQNum = 1;
  int totalQuestions = 0;
  int _timeLeft = 0;
  Timer? _timer;
  bool showTimer = true;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.remainingSeconds > 0 ? widget.remainingSeconds : widget.durationMinutes * 60;
    _startTimer();
    loadQuestion();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      }
      if (_timeLeft <= 0) {
        _showTimeUpDialog();
        timer.cancel();
      }
    });
  }

  Future<void> loadQuestion() async {
    try {
      setState(() => isLoading = true);
      final response = await http.get(
        Uri.parse(ApiEndpoints.singleQuestion(widget.testId, widget.questionNum, widget.dbFile)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        questionData = json.decode(response.body);
        currentQNum = questionData?['q_num'] ?? widget.questionNum;
        totalQuestions = questionData?['total'] ?? 0;
        selectedAnswer = questionData?['user_answer'];  // ✅ Load from backend
        isMarked = questionData?['is_marked'] ?? false; // ✅ Load from backend
        setState(() {});
      } else {
        setState(() => error = 'Failed to load question');
      }
    } catch (e) {
      setState(() => error = 'Network error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 🔥 NEW: Single unified API call for ALL actions
  Future<void> updateQuestionStatus(String action, {String? answer}) async {
    try {
      final body = {
        'question_id': currentQNum,
        'action': action,
      };
      if (answer != null) body['answer'] = answer;
      
      await http.post(
        Uri.parse(ApiEndpoints.questionStatus(widget.testId, widget.dbFile)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
    } catch (e) {
      print('Status update failed: $e');
    }
  }

  // 🔥 UPDATED: Uses new unified API
  Future<void> saveAnswer(String answer) async {
    setState(() => selectedAnswer = answer);
    await updateQuestionStatus('answer', answer: answer);
  }

  // 🔥 UPDATED: Uses new unified API + optimistic update
  Future<void> toggleMark() async {
    setState(() => isMarked = !isMarked);
    await updateQuestionStatus('mark');
  }

  Future<void> submitAnswer(String nav) async {
    // 🔥 NEW: Track skip action
    if (nav == 'skip' && selectedAnswer == null) {
      await updateQuestionStatus('skip');
    }

    if (nav == 'submit' || (currentQNum == totalQuestions && nav != 'previous')) {
      _showSubmitDialog();
      return;
    }

    int targetQNum = currentQNum;
    if (nav == 'next' || nav == 'skip') {
      targetQNum = currentQNum + 1;
    } else if (nav == 'previous' && currentQNum > 1) {
      targetQNum = currentQNum - 1;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionScreen(
          dbFile: widget.dbFile,
          testId: widget.testId,
          questionNum: targetQNum,
          userId: widget.userId,
          testName: widget.testName,
          durationMinutes: widget.durationMinutes,
          remainingSeconds: _timeLeft,
        ),
      ),
    );
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Submit Test'),
        content: Text('Are you sure you want to submit the test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            child: Text('Submit Test'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTest() async {
    _timer?.cancel();
    final response = await http.post(
      Uri.parse(ApiEndpoints.submitTest(widget.testId, widget.dbFile)),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TestResultsScreen(
            testId: widget.testId.toString(),
            scores: data['scores'],
            userId: widget.userId,
          ),
        ),
      );
    }
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Time Up!'),
        content: Text('Time is up! Submitting test automatically.'),
        actions: [
          ElevatedButton(
            onPressed: () => _submitTest(),
            child: Text('Submit'),
          ),
        ],
      ),
    );
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

    if (error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: Center(child: Text(error!, style: const TextStyle(color: Colors.red))),
      );
    }

    final question = questionData!['question'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // TOP TIMER BAR
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Q$currentQNum/$totalQuestions',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatTime(_timeLeft), 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          // SWIPE + MAIN CONTENT
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! > 500 && currentQNum > 1) {
                  submitAnswer('previous');
                } else if (details.primaryVelocity! < -500) {
                  submitAnswer(selectedAnswer != null ? 'next' : 'skip');
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(24),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IMAGE (Safe - Never breaks text below)
                      (question['images'] != null && (question['images'] as String).isNotEmpty)
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Builder(
                                  builder: (context) {
                                    try {
                                      String cleanBase64 = (question['images'] as String)
                                          .replaceAll(RegExp(r'[ \n\r\t]'), '')
                                          .replaceAll('data:image/png;base64,', '')
                                          .replaceAll('data:image/jpeg;base64,', '')
                                          .trim();
                                      
                                      return Image.memory(
                                        base64Decode(cleanBase64),
                                        height: 380,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                        cacheWidth: 800,
                                      );
                                    } catch (e) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[100],
                                        child: Icon(Icons.image_not_supported, size: 48),
                                      );
                                    }
                                  },
                                ),
                              ),
                            )
                          : SizedBox.shrink(),
                      
                      // TEXT (ALWAYS displays - independent of image)
                      Text(
                        question['question']?.toString() ?? 'Question not available',
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.58,
                          color: Color(0xFF222222),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 🔥 UPDATED: Uses new saveAnswer()
                      ...['A', 'B', 'C', 'D'].map((opt) {
                        final optionText = question['option_${opt.toLowerCase()}']?.toString() ?? '';
                        if (optionText.isEmpty) return const SizedBox.shrink();

                        final isSelected = selectedAnswer == opt;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              saveAnswer(opt);  // 🔥 NOW USES UNIFIED API
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFE9F1FF) : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(8),
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected ? const Color(0xFF003087) : const Color(0xFF6C757D),
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio(
                                    value: opt,
                                    groupValue: selectedAnswer,
                                    onChanged: (value) => saveAnswer(value as String),  // 🔥 UPDATED
                                    activeColor: const Color(0xFF003087),
                                  ),
                                  Expanded(child: Text(optionText)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // BOTTOM MENU ☰ + Next
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
            child: SafeArea(
              child: Row(
                children: [
                  // ☰ MENU BUTTON
                  PopupMenuButton<String>(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    offset: Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'mark') toggleMark();  // 🔥 NOW USES UNIFIED API
                      else if (value == 'review') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BasicReviewScreen(
                              testId: widget.testId,
                              userId: widget.userId,
                              dbFile: widget.dbFile,
                              remainingSeconds: _timeLeft,  // 🔥 PASS TIMER
                            ),
                          ),
                        );
                      } else if (value == 'submit') _showSubmitDialog();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'mark',
                        child: Row(children: [
                          Icon(Icons.star, color: isMarked ? Colors.amber : Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(isMarked ? 'Unmark' : 'Mark'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'review',
                        child: Row(children: [
                          Icon(Icons.list_alt, size: 20),
                          SizedBox(width: 12),
                          Text('Review'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'submit',
                        child: Row(children: [
                          Icon(Icons.assignment_turned_in, size: 20),
                          SizedBox(width: 12),
                          Text('Submit Test'),
                        ]),
                      ),
                    ],
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Color(0xFF6C757D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.menu, color: Colors.white, size: 22),
                    ),
                  ),
                  Spacer(),
                  // Next/Skip/Submit Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: selectedAnswer != null
                          ? () => submitAnswer(currentQNum == totalQuestions ? 'submit' : 'next')
                          : () => submitAnswer('skip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedAnswer != null
                            ? (currentQNum == totalQuestions ? Colors.green : const Color(0xFF003087))
                            : const Color(0xFF9E9E9E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        currentQNum == totalQuestions
                            ? 'Submit Test'
                            : (selectedAnswer != null ? 'Next →' : 'Skip'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}
