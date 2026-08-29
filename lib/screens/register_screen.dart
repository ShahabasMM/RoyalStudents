import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _admissionController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _admissionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    final name = _nameController.text.trim();

    final admissionNumber = _admissionController.text.trim().toUpperCase();

    final email = _emailController.text.trim().toLowerCase();

    final password = _passwordController.text;

    final confirmPassword = _confirmPasswordController.text;

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (name.isEmpty) {
      _showMessage('Please enter your full name.');
      return;
    }

    if (admissionNumber.isEmpty) {
      _showMessage('Please enter your admission number.');
      return;
    }

    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter a password.');
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    if (!_termsAccepted) {
      _showMessage(
        'Please accept the account terms to continue.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // ========================================================
      // CALL SUPABASE EDGE FUNCTION
      // ========================================================

      final functionResponse = await Supabase.instance.client.functions.invoke(
        'register-student',
        body: {
          'name': name,
          'admissionNumber': admissionNumber,
          'email': email,
          'password': password,
        },
      );

      // ========================================================
      // READ RESPONSE
      // ========================================================

      final data = functionResponse.data;

      if (data == null) {
        throw Exception(
          'No response received from registration server.',
        );
      }

      final success = data['success'] == true;

      // ========================================================
      // REGISTRATION FAILED
      // ========================================================

      if (!success) {
        final message = data['message']?.toString() ?? 'Registration failed.';

        throw Exception(message);
      }

      // ========================================================
      // STUDENT VERIFIED + ACCOUNT CREATED
      // ========================================================

      if (!mounted) return;

      _showSuccessMessage(
        'Student verified. Account created successfully.',
      );

      // ========================================================
      // SIGN IN WITH THE NEW ACCOUNT
      //
      // Edge Function creates the Auth user, but it does NOT
      // return a Flutter Auth session.
      //
      // Therefore we sign in normally here.
      // ========================================================

      try {
        final loginResponse =
            await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        // ======================================================
        // SESSION AVAILABLE
        // ======================================================

        if (loginResponse.session != null) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );

          return;
        }

        // ======================================================
        // NO SESSION
        // ======================================================

        _showMessage(
          'Account created. Please verify your email and sign in.',
        );

        await Future.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          '/login',
        );
      } on AuthException catch (e) {
        if (!mounted) return;

        // ------------------------------------------------------
        // EMAIL CONFIRMATION ENABLED
        // ------------------------------------------------------

        if (e.message.toLowerCase().contains(
              'email not confirmed',
            )) {
          _showSuccessMessage(
            'Account created. Please verify your email, then sign in.',
          );
        } else {
          _showMessage(e.message);
        }

        await Future.delayed(
          const Duration(milliseconds: 900),
        );

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          '/login',
        );
      }
    } on FunctionException catch (e) {
      if (!mounted) return;

      String message = 'Registration failed. Please try again.';

      // --------------------------------------------------------
      // Try to extract Edge Function response
      // --------------------------------------------------------

      final details = e.details;

      if (details is Map) {
        final serverMessage = details['message']?.toString();

        if (serverMessage != null && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
      }

      _showMessage(message);
    } on AuthException catch (e) {
      if (!mounted) return;

      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // SUCCESS MESSAGE
  // ============================================================

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF15803D),
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: AppTheme.muted,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F7FA),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E2E8),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E2E8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppTheme.navy,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // FIELD LABEL
  // ============================================================

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.navy,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            24 + bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // BACK BUTTON
              // ==================================================

              IconButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.navy,
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // LOGO
              // ==================================================

              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE3E3E8),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/RoyalLogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.school_rounded,
                        size: 38,
                        color: AppTheme.navy,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // TITLE
              // ==================================================

              const Center(
                child: Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 7),

              const Center(
                child: Text(
                  'Join the Royal College student community',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // ==================================================
              // REGISTER CARD
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE3E3E8),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // FULL NAME
                    // ==================================================

                    _fieldLabel('Full name'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hint: 'Enter your full name',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 17),

                    // ==================================================
                    // ADMISSION NUMBER
                    // ==================================================

                    _fieldLabel(
                      'Admission number',
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _admissionController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                      decoration: _inputDecoration(
                        hint: 'Enter your Addmission No.',
                        icon: Icons.badge_outlined,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Enter the admission number provided by the college.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 17),

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    _fieldLabel(
                      'Email address',
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                      ),
                    ),

                    const SizedBox(height: 17),

                    // ==================================================
                    // PASSWORD
                    // ==================================================

                    _fieldLabel(
                      'Password',
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hint: 'Create a password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 17),

                    // ==================================================
                    // CONFIRM PASSWORD
                    // ==================================================

                    _fieldLabel(
                      'Confirm password',
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      decoration: _inputDecoration(
                        hint: 'Confirm your password',
                        icon: Icons.lock_reset_outlined,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // TERMS
                    // ==================================================

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _termsAccepted,
                            activeColor: AppTheme.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                5,
                              ),
                            ),
                            onChanged: _loading
                                ? null
                                : (value) {
                                    setState(() {
                                      _termsAccepted = value ?? false;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 2,
                            ),
                            child: Text(
                              'I agree to the Royal College account terms and conditions.',
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.4,
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // CREATE ACCOUNT BUTTON
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navy,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(
                            0x40000000,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // LOGIN LINK
              // ==================================================

              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: _loading
                          ? null
                          : () {
                              Navigator.pushReplacementNamed(
                                context,
                                '/login',
                              );
                            },
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // COLLEGE NAME
              // ==================================================

              const Center(
                child: Text(
                  'ROYAL COLLEGE OF ARTS AND SCIENCE THRITHALA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFF9A9AA4),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
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
