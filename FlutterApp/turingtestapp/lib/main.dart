import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

// URL for the raw questions.txt file on GitHub
const String QUESTIONS_GITHUB_URL = "https://raw.githubusercontent.com/Jokku-gamma/TuringTestApp/main/questions.txt";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turing Test Challenge',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat', // Ensure you add this font to your pubspec.yaml and assets
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TuringTestScreen(),
    );
  }
}

class TuringTestScreen extends StatefulWidget {
  const TuringTestScreen({super.key});

  @override
  State<TuringTestScreen> createState() => _TuringTestScreenState();
}

class _TuringTestScreenState extends State<TuringTestScreen> {
  int _score = 0;
  int _currentRound = 0;
  List<Map<String, String>> _allQuestions = []; // Stores all questions fetched from GitHub
  List<Map<String, String>> _answersShuffled = []; // Answers for the current round
  int _correctAnswerIndex = -1;
  int? _userChoice;
  String _feedbackMessage = "";
  bool _isLoading = false;
  String _messageBoxContent = "";
  bool _apiKeyEntered = false;
  String? _selectedModel; // 'gemini' or 'openai'
  String _geminiApiKey = "";
  String _openaiApiKey = "";
  bool _apiErrorOccurred = false;

  final TextEditingController _geminiApiKeyController = TextEditingController();
  final TextEditingController _openaiApiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchQuestionsFromGithub();
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _openaiApiKeyController.dispose();
    super.dispose();
  }

  // --- GitHub Questions Integration ---
  Future<void> _fetchQuestionsFromGithub() async {
    setState(() {
      _isLoading = true;
      _messageBoxContent = "Loading questions from GitHub...";
    });

    try {
      print('Attempting to fetch from: $QUESTIONS_GITHUB_URL'); // Debug print
      final response = await http.get(Uri.parse(QUESTIONS_GITHUB_URL));
      print('Response status code: ${response.statusCode}'); // Debug print
      print('Response body (first 200 chars): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}'); // Debug print

      if (response.statusCode == 200) {
        // Attempt to decode JSON
        final List<dynamic> jsonList = json.decode(response.body);
        print('Successfully decoded JSON. Number of questions: ${jsonList.length}'); // Debug print

        List<Map<String, String>> fetchedQuestions = jsonList.map((item) {
          return {
            "question": item['question'] as String,
            "human_answer": item['human_answer'] as String,
          };
        }).toList();

        setState(() {
          _allQuestions = fetchedQuestions;
          _isLoading = false;
          _messageBoxContent = _allQuestions.isEmpty ? "No questions found in the GitHub file." : "";
        });
      } else {
        // Handle non-200 status codes
        setState(() {
          _isLoading = false;
          _messageBoxContent = "Error loading questions from GitHub: HTTP ${response.statusCode}. Response: ${response.body}."; // More detail
          _apiErrorOccurred = true;
        });
        _stopGame();
      }
    } catch (e) {
      // Handle network errors or JSON decoding errors
      print('Error during fetch or decode: $e'); // Debug print
      setState(() {
        _isLoading = false;
        _messageBoxContent = "Network error or failed to parse questions from GitHub: $e. Please ensure the file is valid JSON.";
        _apiErrorOccurred = true;
      });
      _stopGame();
    }
  }

  // --- Game State Management ---
  void _resetGame() {
    setState(() {
      _score = 0;
      _currentRound = 0;
      _answersShuffled = [];
      _correctAnswerIndex = -1;
      _userChoice = null;
      _feedbackMessage = "";
      _isLoading = false;
      _messageBoxContent = "";
      _apiErrorOccurred = false;
    });
  }

  void _stopGame() {
    _resetGame();
    setState(() {
      _apiKeyEntered = false;
      _selectedModel = null;
      _geminiApiKey = "";
      _openaiApiKey = "";
      _geminiApiKeyController.clear();
      _openaiApiKeyController.clear();
    });
  }

  // --- AI API Calls (Direct from Flutter) ---
  Future<String?> _getGeminiResponse(String promptText, String apiKeyVal) async {
    const apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";
    final payload = {
      "contents": [
        {"role": "user", "parts": [{"text": promptText}]}
      ],
      "generationConfig": {
        "temperature": 0.7,
        "top_p": 0.9,
        "top_k": 40,
        "max_output_tokens": 150,
        "responseMimeType": "text/plain"
      }
    };

    try {
      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKeyVal'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print("Gemini API Response Status: ${response.statusCode}"); // Debug print
      print("Gemini API Response Body: ${response.body}"); // Debug print

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['candidates'] != null && result['candidates'].isNotEmpty &&
            result['candidates'][0]['content'] != null && result['candidates'][0]['content']['parts'] != null &&
            result['candidates'][0]['content']['parts'].isNotEmpty) {
          print("Gemini AI response working!"); // Debug print
          return result['candidates'][0]['content']['parts'][0]['text'];
        } else {
          // New: Set error if response is 200 but content is unexpected
          final errorMsg = result.toString(); // Log full result for debugging
          _showMessageBox('Error generating Gemini response: Unexpected content. Result: $errorMsg. Please check your API key or connection.', true);
          _apiErrorOccurred = true;
          return null;
        }
      } else {
        final errorMsg = json.decode(response.body)['error']['message'] ?? 'Unknown API error from Gemini';
        _showMessageBox('Error generating Gemini response: $errorMsg. Please check your API key or connection.', true);
        _apiErrorOccurred = true;
        return null;
      }
    } catch (e) {
      _showMessageBox('Network error or Gemini API call failed: $e. Please check your API key or connection.', true);
      _apiErrorOccurred = true;
      return null;
    }
  }

  Future<String?> _getOpenAIResponse(String promptText, String apiKeyVal) async {
    const openaiApiUrl = "https://api.openai.com/v1/chat/completions";
    final headers = {
      "Authorization": "Bearer $apiKeyVal",
      "Content-Type": "application/json"
    };
    final messages = [
      {"role": "system", "content": "You are participating in a Turing Test. Your goal is to sound like a plain, practical human. Provide a concise, natural, and conversational response, typically 1-2 sentences long. Avoid conversational fillers like 'Hmm, that's a good question,' 'As an AI language model,' 'I'm glad you asked,' or similar overly chatty phrases. Do not use Gen Z slang or emojis. Be direct and answer as a normal person would."},
      {"role": "user", "content": promptText}
    ];
    final payload = {
      "model": "gpt-3.5-turbo",
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 150,
      "top_p": 0.9
    };

    try {
      final response = await http.post(
        Uri.parse(openaiApiUrl),
        headers: headers,
        body: json.encode(payload),
      );

      print("OpenAI API Response Status: ${response.statusCode}"); // Debug print
      print("OpenAI API Response Body: ${response.body}"); // Debug print

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['choices'] != null && result['choices'].isNotEmpty &&
            result['choices'][0]['message'] != null && result['choices'][0]['message']['content'] != null) {
          return result['choices'][0]['message']['content'];
        } else {
          // New: Set error if response is 200 but content is unexpected
          final errorMsg = result.toString(); // Log full result for debugging
          _showMessageBox('Error generating OpenAI response: Unexpected content. Result: $errorMsg. Please check your API key or connection.', true);
          _apiErrorOccurred = true;
          return null;
        }
      } else {
        final errorMsg = json.decode(response.body)['error']['message'] ?? 'Unknown API error from OpenAI';
        _showMessageBox('Error generating OpenAI response: $errorMsg. Please check your API key or connection.', true);
        _apiErrorOccurred = true;
        return null;
      }
    } catch (e) {
      _showMessageBox('Network error or OpenAI API call failed: $e. Please check your API key or connection.', true);
      _apiErrorOccurred = true;
      return null;
    }
  }

  // --- UI Message/Feedback Helpers ---
  void _showMessageBox(String message, bool isVisible) {
    setState(() {
      _messageBoxContent = message;
    });
  }

  void _showFeedbackMessage(String message, bool isCorrect) {
    setState(() {
      _feedbackMessage = message;
    });
  }

  void _hideFeedbackMessage() {
    setState(() {
      _feedbackMessage = "";
    });
  }

  // --- Game Flow Logic ---
  Future<void> _startNewRound() async {
    print('Starting new round. Current round: $_currentRound'); // Debug print
    if (_allQuestions.isEmpty) {
      _showMessageBox("No questions loaded. Please ensure questions.txt is correctly formatted and accessible on GitHub.", true);
      print('Error: _allQuestions is empty. Cannot start new round.'); // Debug print
      return;
    }
    if (_currentRound >= _allQuestions.length) {
      _showFeedbackMessage("Game Over! You've completed all questions.", true);
      print('Game Over: All questions completed.'); // Debug print
      return;
    }

    final questionData = _allQuestions[_currentRound];
    final questionText = questionData["question"]!;
    final humanAnswer = questionData["human_answer"]!;

    final aiPromptBase = (
        "You are participating in a Turing Test. Your goal is to sound like a plain, practical human. "
        "Provide a concise, natural, and conversational response, typically 1-2 sentences long. "
        "Avoid conversational fillers like 'Hmm, that's a good question,' 'As an AI language model,' "
        "'I'm glad you asked,' or similar overly chatty phrases. Do not use Gen Z slang or emojis. "
        "Be direct and answer as a normal person would. "
        "Answer the following question: '$questionText'"
    );

    setState(() {
      _isLoading = true;
      _showMessageBox('Generating AI response using ${_selectedModel!.capitalize()}...', true);
    });

    print('Calling AI API for model: $_selectedModel'); // Debug print
    String? aiAnswer;
    if (_selectedModel == 'gemini') {
      aiAnswer = await _getGeminiResponse(aiPromptBase, _geminiApiKey);
    } else if (_selectedModel == 'openai') {
      aiAnswer = await _getOpenAIResponse(aiPromptBase, _openaiApiKey);
    }

    setState(() {
      _isLoading = false;
      _showMessageBox('', false); // Hide loading message
    });

    if (_apiErrorOccurred) {
      print('API error occurred during AI response generation. Stopping game.'); // Debug print
      _stopGame(); // Immediately stop and reset if an error happened
      return;
    }

    if (aiAnswer == null) {
      // This case should now be covered by _apiErrorOccurred being set in the AI response functions
      // but as a final safeguard:
      print('AI answer is null after API call, but no explicit API error flag. Stopping game.'); // Debug print
      _showMessageBox("Failed to get a valid AI response. Please check your API keys and try again.", true);
      _stopGame();
      return;
    }

    print('AI Answer received: $aiAnswer'); // Debug print

    final answers = [
      {"text": humanAnswer, "type": "human"},
      {"text": aiAnswer, "type": "ai"}
    ];

    answers.shuffle(Random());
    
    setState(() {
      _answersShuffled = answers;
      _correctAnswerIndex = _answersShuffled.indexWhere((ans) => ans["type"] == "ai");
      _userChoice = null;
      _feedbackMessage = "";
    });
    print('Answers shuffled and state updated. Correct index: $_correctAnswerIndex'); // Debug print
    print('Answers for current round: $_answersShuffled'); // Debug print
  }

  void _submitGuess() {
    if (_userChoice == null) {
      _showMessageBox("Please select an answer before submitting.", true);
      return;
    }

    _showMessageBox("", false); // Hide any previous message box

    setState(() {
      if (_userChoice == _correctAnswerIndex) {
        _score += 1;
        _feedbackMessage = "Correct! You identified the AI.";
      } else {
        _feedbackMessage = "Incorrect. That was the human answer.";
      }
      _currentRound += 1;
    });
    print('Guess submitted. Score: $_score, Round: $_currentRound'); // Debug print
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Turing Test Challenge 🤖 vs 👤'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading && _allQuestions.isEmpty) // Show initial loading for questions
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(_messageBoxContent),
                  ],
                ),
              )
            else if (_allQuestions.isEmpty && !_isLoading) // Show message if no questions loaded after attempt
              Container(
                margin: const EdgeInsets.only(top: 25),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFfff3cd),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                  border: Border.all(color: const Color(0xFFffeeba)),
                ),
                child: Text(
                  _messageBoxContent.isNotEmpty ? _messageBoxContent : "Failed to load questions or no questions available. Please check the GitHub URL and file format.",
                  style: const TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!_apiKeyEntered) ...[
              const Text(
                '🔑 Enter Your API Keys',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFd1ecf1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFbee5eb)),
                ),
                child: const Text(
                  "To start the game, please enter your API keys for Google Gemini and OpenAI. These keys are used only for generating AI responses and are not stored.",
                  style: TextStyle(fontSize: 14, color: Color(0xFF0c5460)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _geminiApiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  _geminiApiKey = value;
                },
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _openaiApiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'OpenAI API Key',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  _openaiApiKey = value;
                },
              ),
              const SizedBox(height: 30),
              const Text(
                '🤖 Choose Your AI Model',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF34495e)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_geminiApiKey.isNotEmpty) {
                          setState(() {
                            _selectedModel = 'gemini';
                            _apiKeyEntered = true;
                          });
                          _resetGame();
                        } else {
                          _showMessageBox("Please enter your Gemini API key first!", true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedModel == 'gemini' ? const Color(0xFF28a745) : const Color(0xFF6c757d),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 6,
                        shadowColor: _selectedModel == 'gemini' ? const Color(0x4D28a745) : const Color(0x4D6c757d),
                      ),
                      child: const Text('Play with Gemini', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_openaiApiKey.isNotEmpty) {
                          setState(() {
                            _selectedModel = 'openai';
                            _apiKeyEntered = true;
                          });
                          _resetGame();
                        } else {
                          _showMessageBox("Please enter your OpenAI API key first!", true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedModel == 'openai' ? const Color(0xFF28a745) : const Color(0xFF6c757d),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 6,
                        shadowColor: _selectedModel == 'openai' ? const Color(0x4D28a745) : const Color(0x4D6c757d),
                      ),
                      child: const Text('Play with OpenAI', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
              if (_messageBoxContent.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 25),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfff3cd),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                    border: Border.all(color: const Color(0xFFffeeba)),
                  ),
                  child: Text(
                    _messageBoxContent,
                    style: const TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_apiKeyEntered && _selectedModel != null && !_isLoading && !_apiErrorOccurred && _feedbackMessage.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: ElevatedButton(
                    onPressed: _startNewRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007bff),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 6,
                      shadowColor: const Color(0x4D007bff),
                    ),
                    child: const Text('Start Game', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ),
            ] else ...[
              // Game Play Section
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFd1ecf1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                  border: Border.all(color: const Color(0xFFbee5eb)),
                ),
                child: Text(
                  'Score: $_score / $_currentRound',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0c5460)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Playing with: ${_selectedModel!.capitalize()}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF555555)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _stopGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFdc3545),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 6,
                  shadowColor: const Color(0x4Ddc3545),
                ),
                child: const Text('🛑 Stop Game and Reset', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              if (_messageBoxContent.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 25),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfff3cd),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                    border: Border.all(color: const Color(0xFFffeeba)),
                  ),
                  child: Text(
                    _messageBoxContent,
                    style: const TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_feedbackMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    _feedbackMessage,
                    style: TextStyle(
                      color: _feedbackMessage.contains("Correct") ? const Color(0xFF28a745) : const Color(0xFFdc3545),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_currentRound >= _allQuestions.length || _apiErrorOccurred) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfff3cd),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                    border: Border.all(color: const Color(0xFFffeeba)),
                  ),
                  child: Text(
                    _apiErrorOccurred ? "Game stopped due to API error. Please re-enter your API key." : "🎉 Game Over! Final Score: $_score / ${_allQuestions.length} 🎉",
                    style: const TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                if (!_apiErrorOccurred)
                  ElevatedButton(
                    onPressed: () {
                      _resetGame();
                      _startNewRound(); // Automatically start a new round after playing again
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007bff),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 6,
                      shadowColor: const Color(0x4D007bff),
                    ),
                    child: const Text('Play Again', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _stopGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6c757d),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 6,
                    shadowColor: const Color(0x4D6c757d),
                  ),
                  child: const Text('Change Model / API Key', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ] else if (_feedbackMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _hideFeedbackMessage();
                    _answersShuffled = []; // Clear answers to trigger new round
                    _startNewRound();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007bff),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 6,
                    shadowColor: const Color(0x4D007bff),
                  ),
                  child: const Text('Next Question', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ] else if (!_isLoading && !_apiErrorOccurred && _allQuestions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
                    border: Border.all(color: const Color(0xFFf0f0f0)),
                  ),
                  child: Text(
                    'Question: ${_allQuestions[_currentRound]["question"]}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF34495e)),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: _answersShuffled.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, String> answer = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _userChoice = index;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _userChoice == index ? const Color(0xFFe6f2ff) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _userChoice == index ? const Color(0xFF007bff) : const Color(0xFFe0e0e0)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              Radio<int>(
                                value: index,
                                groupValue: _userChoice,
                                onChanged: (int? value) {
                                  setState(() {
                                    _userChoice = value;
                                  });
                                },
                                activeColor: const Color(0xFF007bff),
                              ),
                              Expanded(
                                child: Text(
                                  '${String.fromCharCode(65 + index)}: ${answer["text"]}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _userChoice == index ? FontWeight.bold : FontWeight.normal,
                                    color: _userChoice == index ? const Color(0xFF007bff) : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitGuess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007bff),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 6,
                    shadowColor: const Color(0x4D007bff),
                  ),
                  child: const Text('Submit Guess', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// Extension to capitalize first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
