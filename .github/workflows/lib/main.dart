import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const BaddieApp());

class BaddieApp extends StatelessWidget {
  const BaddieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baddie',
      theme: ThemeData.dark(),
      home: const AuthCheck(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool? _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? hasAccess = prefs.getBool('baddie_authenticated');
    setState(() {
      _isAuthenticated = hasAccess ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_isAuthenticated == true) {
      return const BaddieHome();
    }
    
    return const PasswordGate();
  }
}

class PasswordGate extends StatefulWidget {
  const PasswordGate({super.key});

  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
  }

  void _speak(String text) {
    _tts.speak(text);
  }

  Future<void> _verifyPassword() async {
    String entered = _passwordController.text.trim();
    
    if (entered.isEmpty) {
      _speak("Enter password.");
      return;
    }
    
    setState(() => _isLoading = true);
    
    final url = Uri.parse("https://baddie-auth.vercel.app/api/verify");
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"password": entered}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('baddie_authenticated', true);
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BaddieHome()),
            );
          }
          return;
        }
      }
      
      _speak("Wrong password.");
      _passwordController.clear();
    } catch (e) {
      _speak("Network error.");
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.pinkAccent),
              const SizedBox(height: 20),
              const Text("BADDIE PROTECTED",
                  style: TextStyle(fontSize: 22, color: Colors.pinkAccent)),
              const SizedBox(height: 40),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Password",
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyPassword,
                      child: const Text("UNLOCK"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class BaddieHome extends StatefulWidget {
  const BaddieHome({super.key});

  @override
  State<BaddieHome> createState() => _BaddieHomeState();
}

class _BaddieHomeState extends State<BaddieHome> {
  late FlutterTts _tts;
  late stt.SpeechToText _speech;

  bool _isListening = true;
  String _lastResponse = "";

  final String _groqApiKey = "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";

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _speech = stt.SpeechToText();
    _init();
  }

  Future<void> _init() async {
    await Permission.microphone.request();
    _speak("Baddie is ready. Say something.");
    _startListeningLoop();
  }

  void _speak(String text) {
    _tts.speak(text);
    setState(() => _lastResponse = text);
  }

  void _startListeningLoop() {
    Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!_isListening) return;

      bool available = await _speech.initialize();
      if (!available) return;

      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _handleText(result.recognizedWords);
          }
        },
      );
    });
  }

  Future<void> _handleText(String text) async {
    if (text.isEmpty) return;
    
    String lowerText = text.toLowerCase();
    print("User said: $text");

    if (lowerText.contains("roast me")) {
      String response = await _getAIResponse("Roast me really hard, be mean but funny. Keep it under 15 words.");
      _speak(response);
    } else if (lowerText.contains("joke")) {
      String response = await _getAIResponse("Tell me a dark, sarcastic, funny joke. Keep it very short.");
      _speak(response);
    } else if (lowerText.contains("hello") || lowerText.contains("hi")) {
      _speak("Hey loser, what do you want?");
    } else {
      String response = await _getAIResponse("Respond to this like a savage, funny female friend: $text. Keep it very short (under 15 words).");
      _speak(response);
    }
  }

  Future<String> _getAIResponse(String prompt) async {
    final url = Uri.parse("https://api.groq.com/openai/v1/chat/completions");
    final headers = {
      "Authorization": "Bearer $_groqApiKey",
      "Content-Type": "application/json",
    };

    final body = {
      "model": "llama3-70b-8192",
      "messages": [
        {"role": "user", "content": prompt},
      ],
      "temperature": 1.2,
      "max_tokens": 60,
    };

    try {
      final response = await http.post(url, headers: headers, body: jsonEncode(body));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      }
      return "AI error. Try again.";
    } catch (e) {
      return "Network error.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("💅 BADDIE"),
        backgroundColor: Colors.pink,
        actions: [
          Switch(
            value: _isListening,
            onChanged: (v) {
              setState(() => _isListening = v);
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, size: 80, color: _isListening ? Colors.green : Colors.red),
              const SizedBox(height: 20),
              Text(
                _isListening ? "🎤 Listening..." : "🔇 Microphone Off",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _lastResponse.isEmpty ? "Say something..." : _lastResponse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
