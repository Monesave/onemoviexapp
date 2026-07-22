import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';
import 'package:flutter/foundation.dart';
import 'movies_page.dart';
import 'shortlist_page.dart';
import 'rooms_page.dart';
import 'subscription_page.dart';
import 'faq_page.dart';
import 'admin_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase once at app startup.
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const OnemoviexApp());
}

class OnemoviexApp extends StatelessWidget {
  const OnemoviexApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF7C4DFF), // vibrant purple
        secondary: Color(0xFFFFC72C), // popcorn yellow
        surface: Color(0xFF101216),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Onemoviex',
      theme: theme,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseClient _client;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          if (session.user.email?.trim().toLowerCase() == 'admin@onemoviex.com') {
            return const AdminPage();
          }
          return const OnemoviexHomePage();
        }

        return const AuthPage();
      },
    );
  }
}

enum AuthMode { signIn, signUp, forgotPassword, magicLink, phoneOtp }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _phoneCodeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String get _redirectUrl => kIsWeb
      ? 'https://www.onemoviex.com/'
      : 'io.supabase.flutterquickstart://login-callback/';

  Future<void> _handleOAuthSignIn(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: _redirectUrl,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${error.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailPasswordAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both email and password')),
      );
      return;
    }

    if (_mode == AuthMode.signUp && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final client = Supabase.instance.client;

    try {
      if (_mode == AuthMode.signUp) {
        final response = await client.auth.signUp(
          email: email,
          password: password,
          data: name.isNotEmpty ? {'display_name': name} : null,
          emailRedirectTo: _redirectUrl,
        );

        if (!mounted) return;

        if (response.session == null) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Verification Email Sent'),
              content: Text(
                'A confirmation link has been sent to $email.\n\n'
                'Please click the link in your email to activate your account, then sign in.',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() => _mode = AuthMode.signIn);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auth error: ${error.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirectUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _mode = AuthMode.signIn);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: _redirectUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Magic login link sent to $email! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePhoneAuth() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number with country code (e.g., +1234567890)')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final client = Supabase.instance.client;

    try {
      if (!_phoneCodeSent) {
        await client.auth.signInWithOtp(phone: phone);
        if (!mounted) return;
        setState(() => _phoneCodeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your phone!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final token = _otpController.text.trim();
        if (token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter the verification code')),
          );
          return;
        }
        await client.auth.verifyOTP(
          type: OtpType.sms,
          phone: phone,
          token: token,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone Auth error: ${error.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC72C),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFC72C).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.movie_filter_rounded,
                          size: 32,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Onemoviex',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Quickly agree on one movie to watch together.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: const Color(0xFF1A1D26),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Auth mode tabs
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Sign In')),
                                  selected: _mode == AuthMode.signIn,
                                  onSelected: (selected) {
                                    if (selected) setState(() => _mode = AuthMode.signIn);
                                  },
                                  selectedColor: const Color(0xFF7C4DFF),
                                  labelStyle: TextStyle(
                                    color: _mode == AuthMode.signIn ? Colors.white : Colors.white70,
                                    fontWeight: _mode == AuthMode.signIn ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Sign Up')),
                                  selected: _mode == AuthMode.signUp,
                                  onSelected: (selected) {
                                    if (selected) setState(() => _mode = AuthMode.signUp);
                                  },
                                  selectedColor: const Color(0xFF7C4DFF),
                                  labelStyle: TextStyle(
                                    color: _mode == AuthMode.signUp ? Colors.white : Colors.white70,
                                    fontWeight: _mode == AuthMode.signUp ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_mode == AuthMode.phoneOtp) ...[
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '+1234567890',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (_phoneCodeSent) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'SMS Verification Code',
                                  prefixIcon: const Icon(Icons.pin),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _isLoading ? null : _handlePhoneAuth,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(_phoneCodeSent ? 'Verify Code' : 'Send SMS Code'),
                            ),
                          ] else if (_mode == AuthMode.forgotPassword) ...[
                            Text(
                              'Reset Password',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter your email address and we will send you a password reset link.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _isLoading ? null : _handleForgotPassword,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Send Reset Link'),
                            ),
                          ] else if (_mode == AuthMode.magicLink) ...[
                            Text(
                              'Passwordless Sign In',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'We will send a magic link to your email to log in instantly.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _isLoading ? null : _handleMagicLink,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Send Magic Link'),
                            ),
                          ] else ...[
                            // Standard Email / Password Flow
                            if (_mode == AuthMode.signUp) ...[
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Display Name',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (_mode == AuthMode.signIn) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => setState(() => _mode = AuthMode.forgotPassword),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(color: Color(0xFFFFC72C), fontSize: 13),
                                  ),
                                ),
                              ),
                            ] else
                              const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isLoading ? null : _handleEmailPasswordAuth,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(_mode == AuthMode.signUp ? 'Create Account' : 'Sign In'),
                            ),
                          ],

                          if (_mode == AuthMode.forgotPassword ||
                              _mode == AuthMode.magicLink ||
                              _mode == AuthMode.phoneOtp) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => setState(() => _mode = AuthMode.signIn),
                              child: const Text('Back to Sign In'),
                            ),
                          ],

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or continue with',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Social & Alternative Auth Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : () => _handleOAuthSignIn(OAuthProvider.google),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.g_mobiledata, color: Colors.redAccent, size: 24),
                                  label: const Text('Google', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : () => _handleOAuthSignIn(OAuthProvider.apple),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.apple, color: Colors.white, size: 20),
                                  label: const Text('Apple', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _mode = AuthMode.magicLink),
                                  icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                                  label: const Text('Magic Link', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _mode = AuthMode.phoneOtp),
                                  icon: const Icon(Icons.phone_android, size: 18),
                                  label: const Text('Phone OTP', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class OnemoviexHomePage extends StatefulWidget {
  const OnemoviexHomePage({super.key});

  @override
  State<OnemoviexHomePage> createState() => _OnemoviexHomePageState();
}

class _OnemoviexHomePageState extends State<OnemoviexHomePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Scale animation for icon
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(context),
          const MoviesPage(),
          RoomsPage(onGoToPremium: () => _onNavItemTapped(4)),
          const ShortlistPage(),
          const SubscriptionPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101216).withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _onNavItemTapped(0),
                ),
                _NavItem(
                  icon: Icons.movie_rounded,
                  label: 'Movies',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _onNavItemTapped(1),
                ),
                _NavItem(
                  icon: Icons.group_rounded,
                  label: 'Rooms',
                  isSelected: _selectedIndex == 2,
                  onTap: () => _onNavItemTapped(2),
                ),
                _NavItem(
                  icon: Icons.favorite_rounded,
                  label: 'Shortlist',
                  isSelected: _selectedIndex == 3,
                  onTap: () => _onNavItemTapped(3),
                ),
                _NavItem(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Premium',
                  isSelected: _selectedIndex == 4,
                  onTap: () => _onNavItemTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserProfileDialog(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final email = user.email ?? 'No email';
    final displayName = user.userMetadata?['display_name'] as String? ?? email.split('@').first;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1D26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF7C4DFF),
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC72C).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'User ID: ${user.id.substring(0, 8)}...',
                    style: const TextStyle(color: Color(0xFFFFC72C), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.lock_reset_outlined, color: Colors.white70),
                  title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await Supabase.instance.client.auth.resetPasswordForEmail(email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reset link sent to $email')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onemoviex'),
        actions: [
          IconButton(
            onPressed: () => _showUserProfileDialog(context),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account Profile',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help & Support',
            onSelected: (value) {
              if (value == 'faq') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FAQPage()),
                );
              } else if (value == 'email') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FAQPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'faq',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 20),
                    SizedBox(width: 8),
                    Text('FAQ'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'email',
                child: Row(
                  children: [
                    Icon(Icons.email, size: 20),
                    SizedBox(width: 8),
                    Text('Email Support'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AuthGate(),
                  ),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2D3436),
              Color(0xFF000000),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // SEO / Landing Page Description
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
                    child: Text(
                      'Welcome to Onemoviex! The best app to easily decide what movie to watch next with your friends, family, or partner. Stop the endless scrolling, create a room, shortlist your favorites, and get an instant match for your movie night!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // Animated landing content
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Animated icon
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                                    const Color(0xFFFFC72C).withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.movie_filter_rounded,
                                size: 100,
                                color: Color(0xFFFFC72C),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Onemoviex',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Quickly agree on one movie to watch together.',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 48),
                          FilledButton.icon(
                            onPressed: () {
                              _onNavItemTapped(1);
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text(
                              'Get Started',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: const Color(0xFF7C4DFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF7C4DFF)
                  : Colors.white.withValues(alpha: 0.6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? const Color(0xFF7C4DFF)
                    : Colors.white.withValues(alpha: 0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


