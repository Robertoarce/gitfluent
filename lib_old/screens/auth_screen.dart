import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/gestures.dart'; // Added for TapGestureRecognizer
import '../services/user_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register controllers
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _registerFirstNameController = TextEditingController();
  final _registerLastNameController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _registerFirstNameController.dispose();
    _registerLastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[100], // Changed background color to light grey
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Title
                  Container(
                    // Removed ShadCard, now directly in Column
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEBFF), // Changed color
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.security, // Changed icon to a shield
                      size: 48,
                      color: Color(0xFF6B47ED), // Changed icon color
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome Back', // Changed title
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your account to continue', // Changed subtitle
                    style: TextStyle(
                      fontSize: 16, // Increased font size
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Auth Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200], // Background for tabs
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.white, // Indicator color
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.black, // Label color
                      unselectedLabelColor:
                          Colors.grey[600], // Unselected label color
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Sign Up'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 500, // Increased height to accommodate new elements
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(),
                        _buildRegisterForm(),
                      ],
                    ),
                  ),

                  // "OR CONTINUE WITH" section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR CONTINUE WITH',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialLoginButton(Icons.mail, () {
                        // TODO: Implement Google/Email sign-in
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Email social login coming soon!')),
                        );
                      }),
                      _buildSocialLoginButton(Icons.auto_awesome, () {
                        // TODO: Implement GitHub sign-in
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('GitHub social login coming soon!')),
                        );
                      }),
                      _buildSocialLoginButton(Icons.apple, () {
                        // TODO: Implement Apple sign-in
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Apple social login coming soon!')),
                        );
                      }),
                    ],
                  ),

                  // Error Display - moved here
                  Consumer<UserService>(
                    builder: (context, userService, child) {
                      if (userService.error != null) {
                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          child: ShadAlert.destructive(
                            title: const Text('Error'),
                            description: Text(userService.error!),
                            icon: const Icon(Icons.error_outline),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),

                  const SizedBox(height: 24),

                  // Demo Users Section
                  _buildDemoUsersSection(),

                  const SizedBox(height: 24), // Added space

                  // Terms and Privacy Policy
                  Align(
                    alignment: Alignment.center,
                    child: Text.rich(
                      TextSpan(
                        text: 'By signing in, you agree to our ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        children: [
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                              color: Color(0xFF6B47ED),
                              decoration: TextDecoration.underline,
                            ),
                            // TODO: Add actual link
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Terms of Service coming soon!')),
                                );
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: Color(0xFF6B47ED),
                              decoration: TextDecoration.underline,
                            ),
                            // TODO: Add actual link
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Privacy Policy coming soon!')),
                                );
                              },
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureLoginPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                    () => _obscureLoginPassword = !_obscureLoginPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Consumer<UserService>(
            builder: (context, userService, child) {
              return SizedBox(
                width: double.infinity,
                child: ShadButton(
                  onPressed: userService.isLoading ? null : _handleLogin,
                  child: userService.isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ShadButton.ghost(
            onPressed: () {
              // TODO: Implement forgot password
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Forgot password feature coming soon!')),
              );
            },
            child: const Text('Forgot Password?'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _registerFirstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: const Icon(Icons.person_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _registerLastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureRegisterPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                    () => _obscureRegisterPassword = !_obscureRegisterPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerConfirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _registerPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Consumer<UserService>(
            builder: (context, userService, child) {
              return SizedBox(
                width: double.infinity,
                child: ShadButton(
                  onPressed: userService.isLoading ? null : _handleRegister,
                  child: userService.isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDemoUsersSection() {
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Demo Users for Testing',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Try these demo accounts:',
            style: TextStyle(color: Colors.blue[700], fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildDemoUserTile(
              'Regular User', 'regular@test.com', 'password123', false),
          _buildDemoUserTile(
              'Premium User', 'premium@test.com', 'password123', true),
        ],
      ),
    );
  }

  Widget _buildDemoUserTile(
      String name, String email, String password, bool isPremium) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.star : Icons.person,
            color: isPremium ? Colors.amber : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  email,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () => _fillDemoCredentials(email, password),
            child: const Text('Use', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _fillDemoCredentials(String email, String password) {
    if (_tabController.index == 1) {
      // Switch to login tab if on register
      _tabController.animateTo(0);
      setState(() {});
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _loginEmailController.text = email;
      _loginPasswordController.text = password;
    });
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final userService = context.read<UserService>();
    final result = await userService.signIn(
      _loginEmailController.text.trim(),
      _loginPasswordController.text,
    );

    if (result.success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final userService = context.read<UserService>();
    final result = await userService.signUp(
      _registerEmailController.text.trim(),
      _registerPasswordController.text,
      _registerFirstNameController.text.trim(),
      _registerLastNameController.text.trim(),
    );

    if (result.success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Widget _buildSocialLoginButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 30, color: Colors.grey[700]),
      ),
    );
  }
}
