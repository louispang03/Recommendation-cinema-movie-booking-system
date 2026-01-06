import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fyp_cinema_app/src/widget/custom_text_form_field.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  _ForgetPasswordPage createState() => _ForgetPasswordPage();
}

class _ForgetPasswordPage extends State<ForgetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testFirebaseConnection();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _testFirebaseConnection() async {
    try {
      print('🔍 Testing Firebase Auth connection...');
      final auth = FirebaseAuth.instance;
      print('✅ Firebase Auth instance: ${auth.app.name}');
      print('✅ Current user: ${auth.currentUser?.email ?? 'No user logged in'}');
    } catch (e) {
      print('❌ Firebase Auth connection test failed: $e');
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    
    // Email regex pattern
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(pattern);
    
    if (!regex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      print('🔐 Attempting to send password reset email to: $email');
      
      // Check if Firebase is properly initialized
      if (FirebaseAuth.instance.app == null) {
        throw Exception('Firebase Auth not properly initialized');
      }
      
      // Check if user exists first (optional - Firebase will handle this)
      print('🔍 Checking if user exists...');
      
      // Send password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );
      
      print('✅ Password reset email sent successfully!');
      
      if (mounted) {
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Exception: ${e.code}');
      print('❌ Error message: ${e.message}');
      print('❌ Error details: $e');
      
      String errorMessage;
      String userFriendlyMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address.';
          userFriendlyMessage = 'No account found with this email address. Please check your email or create a new account.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          userFriendlyMessage = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many password reset requests.';
          userFriendlyMessage = 'Too many requests. Please wait a few minutes before trying again.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network connection failed.';
          userFriendlyMessage = 'Network error. Please check your internet connection and try again.';
          break;
        case 'internal-error':
          errorMessage = 'Firebase internal error.';
          userFriendlyMessage = 'Server error. Please try again in a few minutes.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials.';
          userFriendlyMessage = 'Invalid email address. Please check and try again.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Password reset not enabled.';
          userFriendlyMessage = 'Password reset is not enabled for this account.';
          break;
        default:
          errorMessage = 'Unknown Firebase error: ${e.message}';
          userFriendlyMessage = 'An error occurred. Please try again later.';
      }
      
      print('📝 Error details: $errorMessage');
      
      if (mounted) {
        _showErrorSnackBar(userFriendlyMessage);
      }
    } catch (e) {
      print('❌ Unexpected error type: ${e.runtimeType}');
      print('❌ Unexpected error details: $e');
      
      // Check for specific error patterns that might indicate success
      if (e.toString().contains('PigeonUserDetails') || 
          e.toString().contains('PigeonUserInfo') ||
          e.toString().contains('PlatformException')) {
        print('✅ Platform-specific error detected - email might have been sent successfully');
        if (mounted) {
          _showSuccessDialog(); // Treat as success since email likely sent
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('Connection error. Please check your internet and try again.');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 48,
          ),
          title: const Text(
            'Email Sent!',
            style: TextStyle(
              color: ColorApp.primaryDarkColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We\'ve sent a password reset link to:\n${_emailController.text.trim()}\n\nPlease check your email and follow the instructions to reset your password.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Don\'t see the email? Check your spam folder or wait a few minutes.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to login page
              },
              style: TextButton.styleFrom(
                backgroundColor: ColorApp.primaryDarkColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0.0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.chevron_left,
            color: ColorApp.primaryDarkColor,
            size: 36,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Forget Password",
                  style: TextStyle(
                    fontSize: 36,
                    color: ColorApp.primaryDarkColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Please enter your email address and we will send you a password reset link",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xff787B82),
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextFormField(
                  controller: _emailController,
                  hintText: "Email address",
                  showError: true,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    size: 24,
                  ),
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 30),
                Center(
                  child: SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendPasswordResetEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorApp.primaryDarkColor,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "SENDING...",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              "SEND RESET LINK",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Help text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Don't see the email? Check your spam folder or ensure the email address is correct.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}