import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animations/animations.dart';

/**
 * PACKSLIGHT - DREAM TO ACTION APP
 * Helping ambitious women turn dreams into daily micro-actions
 * Features: AI Challenges, Dream Board, Streak Tracking, Wins Journal,
 * Gamification, RevenueCat IAP, Gemini AI Coach
 */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RevenueCat
  await Purchases.configure(
    PurchasesConfiguration('goog_OuUYzKJRUrHNcpYcfzoXzgZzZSl'),
  );

  tz.initializeTimeZones();
  await _initNotifications();

  runApp(const PacksLightApp());
}

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await notificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );
}

class PacksLightApp extends StatelessWidget {
  const PacksLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PacksLight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63), // Bold pink
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// === MODELS ===

enum UserTier { free, pro, premium }

class UserSession {
  final String userId;
  final String email;
  int trialsRemaining;
  int aiCoachingRemaining;
  int dreamAnalysisRemaining;
  UserTier tier;
  int currentStreak;
  int totalWins;
  DateTime? lastCheckIn;
  bool dailyReminders;

  UserSession({
    required this.userId,
    required this.email,
    this.trialsRemaining = 5,
    this.aiCoachingRemaining = 0,
    this.dreamAnalysisRemaining = 0,
    this.tier = UserTier.free,
    this.currentStreak = 0,
    this.totalWins = 0,
    this.lastCheckIn,
    this.dailyReminders = true,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    userId: json['user_id'] ?? '',
    email: json['email'] ?? '',
    trialsRemaining: json['trials_remaining'] ?? 5,
    aiCoachingRemaining: json['ai_coaching_remaining'] ?? 0,
    dreamAnalysisRemaining: json['dream_analysis_remaining'] ?? 0,
    tier: UserTier.values.firstWhere(
      (t) => t.toString().split('.').last == (json['tier'] ?? 'free'),
      orElse: () => UserTier.free,
    ),
    currentStreak: json['current_streak'] ?? 0,
    totalWins: json['total_wins'] ?? 0,
    lastCheckIn:
        json['last_check_in'] != null
            ? DateTime.parse(json['last_check_in'])
            : null,
    dailyReminders: json['daily_reminders'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'trials_remaining': trialsRemaining,
    'ai_coaching_remaining': aiCoachingRemaining,
    'dream_analysis_remaining': dreamAnalysisRemaining,
    'tier': tier.toString().split('.').last,
    'current_streak': currentStreak,
    'total_wins': totalWins,
    'last_check_in': lastCheckIn?.toIso8601String(),
    'daily_reminders': dailyReminders,
  };
}

class Dream {
  final String id;
  final String title;
  final String category;
  final String description;
  final DateTime targetDate;
  final String imageUrl;
  final bool isCompleted;
  final int progressPercent;
  final List<MicroAction> microActions;

  Dream({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.targetDate,
    this.imageUrl = '',
    this.isCompleted = false,
    this.progressPercent = 0,
    this.microActions = const [],
  });

  factory Dream.fromJson(Map<String, dynamic> json) => Dream(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    category: json['category'] ?? '',
    description: json['description'] ?? '',
    targetDate: DateTime.parse(json['target_date']),
    imageUrl: json['image_url'] ?? '',
    isCompleted: json['is_completed'] ?? false,
    progressPercent: json['progress_percent'] ?? 0,
    microActions:
        (json['micro_actions'] as List?)
            ?.map((e) => MicroAction.fromJson(e))
            .toList() ??
        [],
  );
}

class MicroAction {
  final String id;
  final String dreamId;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime? completedAt;

  MicroAction({
    required this.id,
    required this.dreamId,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.completedAt,
  });

  factory MicroAction.fromJson(Map<String, dynamic> json) => MicroAction(
    id: json['id'] ?? '',
    dreamId: json['dream_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    isCompleted: json['is_completed'] ?? false,
    completedAt:
        json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
  );
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final String category;
  final int durationDays;
  final List<String> dailyTasks;
  final int participantCount;
  final bool isActive;
  final DateTime? startDate;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.durationDays,
    required this.dailyTasks,
    this.participantCount = 0,
    this.isActive = false,
    this.startDate,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    category: json['category'] ?? '',
    durationDays: json['duration_days'] ?? 7,
    dailyTasks: List<String>.from(json['daily_tasks'] ?? []),
    participantCount: json['participant_count'] ?? 0,
    isActive: json['is_active'] ?? false,
    startDate:
        json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
  );
}

class Win {
  final String id;
  final String title;
  final String description;
  final DateTime achievedAt;
  final String category;
  final String imageUrl;

  Win({
    required this.id,
    required this.title,
    required this.description,
    required this.achievedAt,
    required this.category,
    this.imageUrl = '',
  });

  factory Win.fromJson(Map<String, dynamic> json) => Win(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    achievedAt: DateTime.parse(json['achieved_at']),
    category: json['category'] ?? '',
    imageUrl: json['image_url'] ?? '',
  );
}

// === API SERVICE ===

class ApiService {
  static const String baseUrl =
      'https://packslight-eefpgge5hdh9befs.eastus-01.azurewebsites.net';

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user/$userId/profile'));
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> checkIn(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/$userId/checkin'),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<Dream>> getDreams(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user/$userId/dreams'));
    final List<dynamic> data = jsonDecode(response.body)['dreams'];
    return data.map((e) => Dream.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> createDream(
    String userId,
    Map<String, dynamic> dreamData,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/$userId/dreams'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dreamData),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> generateDreamPlan(
    String userId,
    String dreamDescription,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/dream-plan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'dream_description': dreamDescription,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<List<Challenge>> getChallenges() async {
    final response = await http.get(Uri.parse('$baseUrl/challenges'));
    final List<dynamic> data = jsonDecode(response.body)['challenges'];
    return data.map((e) => Challenge.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> joinChallenge(
    String userId,
    String challengeId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/$userId/challenges/$challengeId/join'),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getDailyChallenge(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/$userId/daily-challenge'),
    );
    return jsonDecode(response.body);
  }

  static Future<List<Win>> getWins(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user/$userId/wins'));
    final List<dynamic> data = jsonDecode(response.body)['wins'];
    return data.map((e) => Win.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> logWin(
    String userId,
    Map<String, dynamic> winData,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/$userId/wins'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(winData),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAICoaching(
    String userId,
    String question,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/coaching'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'question': question}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> researchDestination(
    String userId,
    String destination,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/research'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'query': 'travel guide for $destination',
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> completeMicroAction(
    String userId,
    String actionId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/$userId/micro-actions/$actionId/complete'),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }
}

// === AUTH WRAPPER ===

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserSession? session;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_session');

    if (userData != null) {
      setState(() {
        session = UserSession.fromJson(jsonDecode(userData));
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void handleAuth(UserSession user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_session', jsonEncode(user.toJson()));
    setState(() => session = user);

    // === SYNC WITH REVENUECAT ===
    try {
      await Purchases.logIn(user.userId);
      await Purchases.setEmail(user.email);

      // UPDATE THIS STRING FOR EACH APP:
      await Purchases.setAttributes({
        'app_name':
            'PacksLight', // Change to 'MumWise', 'AICoach', 'PacksLight', etc.
        'signup_tier': user.tier.toString(),
      });
    } catch (e) {
      debugPrint('RevenueCat user sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return session == null
        ? LoginScreen(onSuccess: handleAuth)
        : MainNavigation(
          user: session!,
          onSessionUpdate: (u) => setState(() => session = u),
        );
  }
}

// === LOGIN SCREEN ===

class LoginScreen extends StatefulWidget {
  final Function(UserSession) onSuccess;
  const LoginScreen({super.key, required this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response =
          isLogin
              ? await ApiService.login(
                _emailController.text,
                _passController.text,
              )
              : await ApiService.register(
                _emailController.text,
                _passController.text,
              );

      if (response['success'] == true) {
        widget.onSuccess(UserSession.fromJson(response['user']));
      } else {
        _showError(response['message'] ?? 'Authentication failed');
      }
    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final auth = await account.authentication;
        final response = await ApiService.loginWithGoogle(auth.idToken!);

        if (response['success'] == true) {
          widget.onSuccess(UserSession.fromJson(response['user']));
        }
      }
    } catch (e) {
      _showError('Google sign-in failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.pink.shade400,
              Colors.purple.shade600,
              Colors.deepPurple.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.flight_takeoff,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PacksLight',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      'Turn Dreams into Daily Wins',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 48),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (v) => v!.contains('@') ? null : 'Invalid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (v) => v!.length >= 6 ? null : 'Min 6 characters',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.purple.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            isLoading
                                ? const CircularProgressIndicator()
                                : Text(
                                  isLogin ? 'Login' : 'Start Your Journey',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin
                            ? 'New Dreamer? Create Account'
                            : 'Have an account? Login',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white54)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white54)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loginWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// === MAIN NAVIGATION ===

class MainNavigation extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onSessionUpdate;

  const MainNavigation({
    super.key,
    required this.user,
    required this.onSessionUpdate,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _updatePages();
  }

  @override
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _updatePages();
    }
  }

  void _updatePages() {
    _pages = [
      HomeScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      DreamsScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      ChallengesScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      TrackScreen(user: widget.user),
      UpgradeScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      ProfileScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Dreams',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Challenges',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Upgrade',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// === HOME SCREEN ===

class HomeScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const HomeScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ConfettiController _confettiController;
  Map<String, dynamic>? dailyChallenge;
  bool isLoading = true;
  bool showConfetti = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _loadDailyChallenge();
    _checkStreak();
  }

  Future<void> _checkStreak() async {
    final now = DateTime.now();
    final lastCheckIn = widget.user.lastCheckIn;

    if (lastCheckIn == null ||
        !_isSameDay(lastCheckIn, now) && _isConsecutiveDay(lastCheckIn, now)) {
      // New check-in
      try {
        final response = await ApiService.checkIn(widget.user.userId);
        if (response['success'] == true) {
          widget.user.currentStreak = response['new_streak'];
          widget.user.lastCheckIn = now;
          widget.onUpdate(widget.user);

          if (widget.user.currentStreak > 1) {
            setState(() => showConfetti = true);
            _confettiController.play();
          }
        }
      } catch (e) {
        // Handle error
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isConsecutiveDay(DateTime last, DateTime now) {
    final diff = now.difference(last).inDays;
    return diff == 1;
  }

  Future<void> _loadDailyChallenge() async {
    try {
      final response = await ApiService.getDailyChallenge(widget.user.userId);
      setState(() {
        dailyChallenge = response['challenge'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.pink.shade50, Colors.white],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadDailyChallenge,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStreakCard(),
                    const SizedBox(height: 20),
                    _buildDailyChallengeCard(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildMotivationalQuote(),
                  ],
                ),
              ),
            ),
          ),
          if (showConfetti)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                colors: const [
                  Colors.pink,
                  Colors.purple,
                  Colors.amber,
                  Colors.cyan,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    String greeting =
        hour < 12
            ? 'Good Morning'
            : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            Text(
              widget.user.email.split('@')[0].toUpperCase(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade400, Colors.pink.shade400],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 20),
              const SizedBox(width: 4),
              Text(
                '${widget.user.trialsRemaining}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade300, Colors.deepOrange.shade400],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Streak',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.user.currentStreak}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'days',
                      style: TextStyle(color: Colors.white70, fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.user.totalWins} Wins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChallengeCard() {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (dailyChallenge == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.check_circle, size: 60, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'All caught up!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back tomorrow for a new challenge',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.today, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Today\'s Micro-Action',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              dailyChallenge!['title'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              dailyChallenge!['description'] ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Mark as complete
                  setState(() => showConfetti = true);
                  _confettiController.play();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Complete Challenge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.star_border,
                label: 'Add Dream',
                color: Colors.purple,
                onTap: () {
                  // Navigate to add dream
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.emoji_events,
                label: 'Log Win',
                color: Colors.amber,
                onTap: () {
                  // Navigate to log win
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.psychology,
                label: 'AI Coach',
                color: Colors.blue,
                onTap: () {
                  // Navigate to AI coach
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.explore,
                label: 'Research',
                color: Colors.green,
                onTap: () {
                  // Navigate to research
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMotivationalQuote() {
    final quotes = [
      'The journey of a thousand miles begins with a single step.',
      'Your dreams don\'t work unless you do.',
      'Adventure is worthwhile in itself.',
      'Life is either a daring adventure or nothing at all.',
      'The world is a book, and those who do not travel read only one page.',
    ];

    final quote = quotes[Random().nextInt(quotes.length)];

    return Card(
      color: Colors.pink.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.format_quote, size: 40, color: Colors.pink),
            const SizedBox(height: 12),
            Text(
              quote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === DREAMS SCREEN ===

class DreamsScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const DreamsScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<DreamsScreen> createState() => _DreamsScreenState();
}

class _DreamsScreenState extends State<DreamsScreen> {
  List<Dream> dreams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDreams();
  }

  Future<void> _loadDreams() async {
    try {
      final loadedDreams = await ApiService.getDreams(widget.user.userId);
      setState(() {
        dreams = loadedDreams;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dreams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddDreamDialog(),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : dreams.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: dreams.length,
                itemBuilder: (context, index) {
                  final dream = dreams[index];
                  return _DreamCard(dream: dream);
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 100, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'No dreams yet!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start building your dream life.\nWhat\'s on your bucket list?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddDreamDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Dream'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDreamDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _AddDreamDialog(
            userId: widget.user.userId,
            onDreamAdded: _loadDreams,
          ),
    );
  }
}

class _DreamCard extends StatelessWidget {
  final Dream dream;

  const _DreamCard({required this.dream});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (dream.imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: dream.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.purple.shade100),
              errorWidget:
                  (_, __, ___) => Container(
                    color: Colors.purple.shade100,
                    child: const Icon(
                      Icons.star,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.purple.shade300, Colors.pink.shade300],
                ),
              ),
              child: const Icon(Icons.star, size: 60, color: Colors.white),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dream.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dream.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: dream.progressPercent / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dream.progressPercent}% Complete',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDreamDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onDreamAdded;

  const _AddDreamDialog({required this.userId, required this.onDreamAdded});

  @override
  State<_AddDreamDialog> createState() => _AddDreamDialogState();
}

class _AddDreamDialogState extends State<_AddDreamDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String selectedCategory = 'Travel';
  DateTime targetDate = DateTime.now().add(const Duration(days: 365));
  bool isGeneratingPlan = false;

  final categories = [
    'Travel',
    'Career',
    'Financial',
    'Health',
    'Relationships',
    'Learning',
    'Adventure',
  ];

  Future<void> _generateAIPlan() async {
    if (_descriptionController.text.isEmpty) return;

    setState(() => isGeneratingPlan = true);

    try {
      final response = await ApiService.generateDreamPlan(
        widget.userId,
        _descriptionController.text,
      );

      if (response['success'] == true) {
        // Show the generated plan
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('AI-Generated Action Plan'),
                  content: SingleChildScrollView(
                    child: Text(response['plan'] ?? 'Plan generated'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveDream();
                      },
                      child: const Text('Save Dream'),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => isGeneratingPlan = false);
    }
  }

  Future<void> _saveDream() async {
    final dreamData = {
      'title': _titleController.text,
      'category': selectedCategory,
      'description': _descriptionController.text,
      'target_date': targetDate.toIso8601String(),
    };

    await ApiService.createDream(widget.userId, dreamData);
    widget.onDreamAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Dream'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Dream Title',
                hintText: 'e.g., Solo trip to Japan',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (v) => setState(() => selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your dream in detail...',
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('MMM dd, yyyy').format(targetDate)),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: targetDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (date != null) setState(() => targetDate = date);
              },
            ),
            const SizedBox(height: 16),
            if (isGeneratingPlan)
              const CircularProgressIndicator()
            else
              OutlinedButton.icon(
                onPressed: _generateAIPlan,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate AI Action Plan'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveDream, child: const Text('Save')),
      ],
    );
  }
}

// === CHALLENGES SCREEN ===

class ChallengesScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const ChallengesScreen({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<Challenge> challenges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    try {
      final loadedChallenges = await ApiService.getChallenges();
      setState(() {
        challenges = loadedChallenges;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Challenges'), centerTitle: true),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: challenges.length,
                itemBuilder: (context, index) {
                  final challenge = challenges[index];
                  return _ChallengeCard(challenge: challenge);
                },
              ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    challenge.category,
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${challenge.participantCount}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              challenge.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              challenge.description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${challenge.durationDays} days',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Join challenge
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      challenge.isActive
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  challenge.isActive ? 'In Progress' : 'Join Challenge',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === TRACK SCREEN ===

class TrackScreen extends StatefulWidget {
  final UserSession user;

  const TrackScreen({super.key, required this.user});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  List<Win> wins = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWins();
  }

  Future<void> _loadWins() async {
    try {
      final loadedWins = await ApiService.getWins(widget.user.userId);
      setState(() {
        wins = loadedWins;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Progress')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsOverview(),
                  const SizedBox(height: 24),
                  _buildProgressChart(),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Wins',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...wins.map((win) => _WinCard(win: win)),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogWinDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Log Win'),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${widget.user.currentStreak}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text(
                    'Day Streak',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${widget.user.totalWins}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const Text(
                    'Total Wins',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 10,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          return Text(days[value.toInt() % 7]);
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (i + 1) * 1.5,
                          color: Colors.purple.shade300,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogWinDialog() {
    showDialog(
      context: context,
      builder:
          (context) =>
              _LogWinDialog(userId: widget.user.userId, onWinLogged: _loadWins),
    );
  }
}

class _WinCard extends StatelessWidget {
  final Win win;

  const _WinCard({required this.win});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.emoji_events, color: Colors.amber),
        ),
        title: Text(
          win.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(DateFormat('MMM dd, yyyy').format(win.achievedAt)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _LogWinDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onWinLogged;

  const _LogWinDialog({required this.userId, required this.onWinLogged});

  @override
  State<_LogWinDialog> createState() => _LogWinDialogState();
}

class _LogWinDialogState extends State<_LogWinDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String selectedCategory = 'Personal';

  final categories = [
    'Personal',
    'Career',
    'Travel',
    'Financial',
    'Health',
    'Learning',
  ];

  Future<void> _saveWin() async {
    final winData = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'category': selectedCategory,
      'achieved_at': DateTime.now().toIso8601String(),
    };

    await ApiService.logWin(widget.userId, winData);
    widget.onWinLogged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🎉 Log Your Win!'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'What did you accomplish?',
                hintText: 'e.g., Booked my solo trip!',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (v) => setState(() => selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveWin, child: const Text('Save Win')),
      ],
    );
  }
}

// === UPGRADE SCREEN (UNCHANGED) ===

class UpgradeScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const UpgradeScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _isProcessing = false;

  Future<void> _purchaseSubscription(String productId) async {
    setState(() => _isProcessing = true);

    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final package = offerings.current!.availablePackages.firstWhere(
          (p) => p.identifier == productId,
        );

        final purchaserInfo = await Purchases.purchasePackage(package);

        if (purchaserInfo.customerInfo.entitlements.all[productId]?.isActive ??
            false) {
          if (productId.contains('pro')) {
            widget.user.tier = UserTier.pro;
            widget.user.aiCoachingRemaining = 11;
            widget.user.dreamAnalysisRemaining = 11;
          } else if (productId.contains('premium')) {
            widget.user.tier = UserTier.premium;
            widget.user.aiCoachingRemaining = 20;
            widget.user.dreamAnalysisRemaining = 20;
          }

          widget.onUpdate(widget.user);
          _showSuccess('Subscription activated!');
        }
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _purchaseCredits(String productId, int credits) async {
    setState(() => _isProcessing = true);

    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final package = offerings.current!.availablePackages.firstWhere(
          (p) => p.identifier == productId,
        );

        await Purchases.purchasePackage(package);

        widget.user.trialsRemaining += credits;
        widget.onUpdate(widget.user);
        _showSuccess('$credits credits added!');
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body:
          _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      size: 80,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unlock Your Full Potential',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get unlimited AI coaching and dream planning',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars, color: Colors.pink),
                          const SizedBox(width: 8),
                          Text(
                            'Current: ${widget.user.tier.toString().split('.').last.toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Monthly Subscriptions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SubscriptionCard(
                      title: 'Pro Plan',
                      price: '\$25/month',
                      features: const [
                        '11 AI Coaching Sessions',
                        '11 Dream Analyses',
                        'Unlimited Challenges',
                        'Priority Support',
                      ],
                      color: Colors.blue,
                      onTap: () => _purchaseSubscription('pro_monthly'),
                    ),
                    const SizedBox(height: 16),
                    _SubscriptionCard(
                      title: 'Premium Plan',
                      price: '\$35/month',
                      features: const [
                        '20 AI Coaching Sessions',
                        '20 Dream Analyses',
                        'Unlimited Everything',
                        'Premium Support',
                        'Early Access to Features',
                        '1-on-1 Community Calls',
                      ],
                      color: Colors.purple,
                      onTap: () => _purchaseSubscription('premium_monthly'),
                      recommended: true,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'One-Time Credit Packs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CreditPackCard(
                      title: 'Dream Starter Pack',
                      credits: 25,
                      price: '\$40',
                      onTap: () => _purchaseCredits('credits_25', 25),
                    ),
                    const SizedBox(height: 12),
                    _CreditPackCard(
                      title: 'Quick Boost Pack',
                      credits: 10,
                      price: '\$15',
                      onTap: () => _purchaseCredits('credits_10', 10),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final Color color;
  final VoidCallback onTap;
  final bool recommended;

  const _SubscriptionCard({
    required this.title,
    required this.price,
    required this.features,
    required this.color,
    required this.onTap,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          elevation: recommended ? 8 : 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: color),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 20, color: color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (recommended)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreditPackCard extends StatelessWidget {
  final String title;
  final int credits;
  final String price;
  final VoidCallback onTap;

  const _CreditPackCard({
    required this.title,
    required this.credits,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.pink,
          child: Icon(Icons.add_shopping_cart, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$credits Action Credits'),
        trailing: Text(
          price,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// === PROFILE SCREEN ===

class ProfileScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const ProfileScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          Text(
            widget.user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Center(
            child: Chip(
              label: Text(
                '${widget.user.tier.toString().split('.').last.toUpperCase()} DREAMER',
              ),
              backgroundColor: Colors.pink.shade100,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Credits Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _CreditRow(
                    label: 'Action Credits',
                    value: widget.user.trialsRemaining.toString(),
                  ),
                  _CreditRow(
                    label: 'AI Coaching',
                    value: widget.user.aiCoachingRemaining.toString(),
                  ),
                  _CreditRow(
                    label: 'Dream Analysis',
                    value: widget.user.dreamAnalysisRemaining.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Daily Reminders'),
            subtitle: const Text('Get motivated every day'),
            value: widget.user.dailyReminders,
            onChanged: (value) {
              setState(() => widget.user.dailyReminders = value);
              widget.onUpdate(widget.user);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Achievements'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {},
          ),
          const SizedBox(height: 32),
          Card(
            color: Colors.purple.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Need Help?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('Email us at support@packslight.com'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String label;
  final String value;

  const _CreditRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.pink.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
