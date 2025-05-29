import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../models/journal_entry.dart';

class DailyAssessmentScreen extends StatefulWidget {
  final DateTime date;
  final String userId;

  const DailyAssessmentScreen({
    super.key,
    required this.date,
    required this.userId,
  });

  @override
  State<DailyAssessmentScreen> createState() => _DailyAssessmentScreenState();
}

class _DailyAssessmentScreenState extends State<DailyAssessmentScreen> {
  final DatabaseService _dbService = DatabaseService.instance;
  bool _isLoading = true;
  String _summary = '';
  String _topics = '';
  String _moodAnalysis = '';

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  Future<String> _getAIResponse(String prompt) async {
    final uri = Uri.parse('http://10.0.2.2:11434/api/chat');
    debugPrint('Sending assessment request to Ollama...');

    final request = http.Request("POST", uri);
    request.headers["Content-Type"] = "application/json";
    request.body = jsonEncode({
      "model": "journalbud",
      "messages": [
        {"role": "user", "content": prompt}
      ]
    });

    try {
      final streamedResponse = await request.send();
      final content = StringBuffer();

      await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.trim().split(RegExp(r'\r?\n'));
        for (final line in lines) {
          try {
            final jsonLine = jsonDecode(line);
            final part = jsonLine["message"]?["content"];
            if (part != null) content.write(part);
          } catch (_) {}
        }
      }

      return content.toString().trim().isNotEmpty
          ? content.toString().trim()
          : "Unable to generate assessment at this time.";
    } catch (e) {
      debugPrint('Error getting AI response: $e');
      return "⚠️ Failed to generate assessment: $e";
    }
  }

  Future<void> _loadAssessment() async {
    try {
      // Get all entries for the day
      final entries =
          await _dbService.getConversation(widget.userId, widget.date);

      // Filter out AI responses and date headers, only keep user entries
      final userEntries = entries
          .where((e) => !e.isAI && !e.content.startsWith("Today,"))
          .toList();

      if (userEntries.isEmpty) {
        setState(() {
          _summary = "No journal entries found for this day.";
          _topics = "No topics to analyze.";
          _moodAnalysis = "No mood data available.";
          _isLoading = false;
        });
        return;
      }

      final entriesText = userEntries.map((e) => e.content).join('\n\n');

      // Enhanced prompts for better AI responses
      final summaryPrompt = """
As a journal analysis AI, please provide a concise summary of the user's day based on these journal entries (2-3 sentences). Use **bold** formatting for important words, emotions, or key points.

Journal Entries:
$entriesText

Please focus on the key events, activities, and overall narrative of the day.
""";

      final topicsPrompt = """
Based on these journal entries, identify and list the main topics or themes discussed (in bullet points). Use **bold** formatting for key terms or concepts.

Journal Entries:
$entriesText

Please format your response as bullet points and focus on the most significant themes.
""";

      final moodPrompt = """
Analyze the emotional tone and mood patterns in these journal entries. Use **bold** formatting for emotions and significant mood changes.

Journal Entries:
$entriesText

Please provide a thoughtful analysis of the overall emotional state and any mood changes throughout the day (2-3 sentences).
""";

      debugPrint('Sending requests to AI for analysis...');
      final responses = await Future.wait([
        _getAIResponse(summaryPrompt),
        _getAIResponse(topicsPrompt),
        _getAIResponse(moodPrompt),
      ]);

      setState(() {
        _summary = responses[0];
        _topics = responses[1];
        _moodAnalysis = responses[2];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading assessment: $e');
      setState(() {
        _summary = "Error loading summary: Unable to analyze journal entries.";
        _topics = "Error loading topics: Please try again later.";
        _moodAnalysis =
            "Error loading mood analysis: Service temporarily unavailable.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: const Color(0xFF6B2D06).withOpacity(0.7),
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with date and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(widget.date),
                      style: const TextStyle(
                        color: Color(0xFF6B2D06),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B2D06)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Owl and Title
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 80,
                        child: Lottie.asset(
                          'assets/owl.json',
                        ),
                      ),
                      const Text(
                        'Daily Assessment',
                        style: TextStyle(
                          color: Color(0xFF6B2D06),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF6B2D06)),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Generating your daily assessment...',
                                style: TextStyle(
                                  color: Color(0xFF6B2D06),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSection(
                                title: 'Summary',
                                content: _summary,
                                icon: Icons.summarize,
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title: 'Key Topics',
                                content: _topics,
                                icon: Icons.topic,
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title: 'Mood Analysis',
                                content: _moodAnalysis,
                                icon: Icons.mood,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFE8C2),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFFF79800),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF6B2D06),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFormattedText(content),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text) {
    final List<InlineSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int currentPosition = 0;

    // Find all bold patterns in the text
    for (final Match match in boldPattern.allMatches(text)) {
      // Add text before the bold pattern
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, match.start),
          style: const TextStyle(
            color: Color(0xFF8B4513),
            fontSize: 16,
            height: 1.5,
          ),
        ));
      }

      // Add the bold text without the asterisks
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          color: Color(0xFF8B4513),
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.bold,
        ),
      ));

      currentPosition = match.end;
    }

    // Add any remaining text after the last bold pattern
    if (currentPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPosition),
        style: const TextStyle(
          color: Color(0xFF8B4513),
          fontSize: 16,
          height: 1.5,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
