import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/src/ui/screen/forget_password_page.dart';
import 'package:get/get.dart';
import 'package:fyp_cinema_app/src/ui/screen/signup_page.dart';
import 'package:fyp_cinema_app/src/widget/custom_text_form_field.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/services/auth_service.dart';
import 'package:fyp_cinema_app/src/services/auth_wrapper.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _authWrapper = AuthWrapper();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final passwordIsObscure = true.obs;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("Attempting to sign in with email: ${_emailController.text.trim()}");
      
      // Add timeout to prevent infinite loading
      await Future.any([
        _performLogin(),
        Future.delayed(const Duration(seconds: 10), () => throw TimeoutException('Login timeout', const Duration(seconds: 10))),
      ]);
      
    } catch (e) {
      if (e is TimeoutException) {
        print("Login timeout: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login timeout. Please check your connection and try again.')),
          );
        }
      } else {
        print("Login error: $e");
        
        // Check if we got the PigeonUserDetails error but the user is actually logged in
        if (e.toString().contains('PigeonUserDetails') && 
            FirebaseAuth.instance.currentUser != null) {
          print("PigeonUserDetails error but user is authenticated");
          // The login succeeded despite the PigeonUserDetails error
          // No need to show an error message
        } else {
          // For other errors, show a generic message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: Please try again later.')),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performLogin() async {
    try {
      // Use the auth wrapper to avoid PigeonUserDetails error
      await _authWrapper.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      print("Sign in successful");
      // Don't need to navigate - StreamBuilder in App will handle it
      
      // Clear form fields after successful login
      _emailController.clear();
      _passwordController.clear();
      
    } on FirebaseAuthException catch (authError) {
      String message;
      switch (authError.code) {
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'invalid-email':
          message = 'Please provide a valid email address.';
          break;
        case 'user-disabled':
          message = 'This user has been disabled.';
          break;
        case 'operation-not-allowed':
          message = 'This operation is not allowed.';
          break;
        default:
          message = authError.message ?? 'An authentication error occurred.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      rethrow; // Re-throw to be caught by the outer catch block
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: ColorApp.primaryDarkColor,
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  constraints: BoxConstraints(
                    minHeight: 450,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(120),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25.0,
                            vertical: 50.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(
                              "Welcome Back!",
                              style: TextStyle(
                                fontSize: 36,
                                color: ColorApp.primaryDarkColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Login to continue",
                              style: TextStyle(
                                fontSize: 18.0,
                                color: Color(0xff787B82),
                              ),
                            ),
                            const SizedBox(height: 32),
                            CustomTextFormField(
                              controller: _emailController,
                              hintText: "Email",
                              showError: true,
                              prefixIcon: Icon(Icons.email_outlined, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Obx(
                              () => CustomTextFormField(
                                controller: _passwordController,
                                obscureText: passwordIsObscure.value,
                                isObscure: passwordIsObscure,
                                hintText: "Password",
                                showError: true,
                                prefixIcon: Icon(Icons.lock_outline, size: 24),
                              ),
                            ),
                            const SizedBox(height: 27),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                FilledButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: FilledButton.styleFrom(
                                    fixedSize: Size(162.0, 46),
                                    backgroundColor: ColorApp.primaryDarkColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          "LOGIN",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ForgetPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Forgot Password?",
                                    style: TextStyle(
                                      color: ColorApp.primaryDarkColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xffadb0b6),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignUpPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Create your account",
                              style: TextStyle(
                                color: ColorApp.primaryDarkColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20), // Add bottom padding
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

