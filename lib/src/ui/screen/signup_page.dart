import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/ui/screen/login_page.dart';
// ignore: depend_on_referenced_packages
import 'package:get/get.dart';
import 'package:fyp_cinema_app/src/widget/custom_text_form_field.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/services/auth_wrapper.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPage createState() => _SignUpPage();
}

class _SignUpPage extends State<SignUpPage> {
  final _auth = FirebaseAuth.instance;
  final _authWrapper = AuthWrapper();
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  final con_password = TextEditingController();
  final email = TextEditingController();
  final mobileNum = TextEditingController();
  bool _isLoading = false;

  final passwordIsObscure = true.obs;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    con_password.dispose();
    email.dispose();
    mobileNum.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (password.text != con_password.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("Starting sign up process...");
      String? userId;
      
      // Use the auth wrapper to avoid PigeonUserDetails error
      try {
        // First create user via wrapper
        final UserCredential? userCredential = await _authWrapper.register(
          email.text.trim(), 
          password.text.trim()
        );
        
        // If we have a user (even if userCredential is null due to PigeonUserDetails error)
        final currentUser = _auth.currentUser;
        if (userCredential?.user != null || currentUser != null) {
          final User user = userCredential?.user ?? currentUser!;
          userId = user.uid;
          print("User created with ID: ${user.uid}");
          
          // Update display name as a separate step - catch PigeonUserInfo errors
          try {
            await _authWrapper.updateDisplayName(user, username.text.trim());
            print("Display name updated");
          } catch (displayNameError) {
            print("Error updating display name: $displayNameError");
            // Continue anyway as this isn't critical
          }
          
          // Save user data to Firestore - this is more important than the display name
          try {
            await _firestore.collection('users').doc(user.uid).set({
              'name': username.text.trim(),
              'email': email.text.trim(),
              'phone': mobileNum.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
            print("User data saved to Firestore");
          } catch (firestoreError) {
            print("Error saving to Firestore: $firestoreError");
            // This is more critical - show error if we can't save to Firestore
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving account information: $firestoreError')),
              );
            }
            return;
          }
          
          // Send email verification
          try {
            await user.sendEmailVerification();
            print("Email verification sent to: ${user.email}");
          } catch (emailError) {
            print("Error sending email verification: $emailError");
            // Continue anyway - user can verify later from profile
          }
          
          // Show success message with email verification info
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Account created successfully! Please check your email (${user.email}) to verify your account.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
            // Navigate to home page after successful signup
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // No user was created
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create account. Please try again.')),
            );
          }
          return;
        }
      } on FirebaseAuthException catch (authError) {
        print("Authentication error: ${authError.code} - ${authError.message}");
        String message;
        switch (authError.code) {
          case 'weak-password':
            message = 'The password provided is too weak.';
            break;
          case 'email-already-in-use':
            message = 'An account already exists for that email.';
            break;
          case 'invalid-email':
            message = 'Please provide a valid email address.';
            break;
          default:
            message = authError.message ?? 'Authentication error occurred.';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (authError) {
        if (authError.toString().contains('PigeonUserDetails') && 
            _auth.currentUser != null) {
          // The registration succeeded despite the PigeonUserDetails error
          // Still need to save user data and continue with the flow
          final User user = _auth.currentUser!;
          userId = user.uid;
          print("PigeonUserDetails error but user is created with ID: ${user.uid}");
          
          try {
            // Update display name - catch errors
            try {
              await user.updateDisplayName(username.text.trim());
              print("Display name updated directly");
            } catch (displayNameError) {
              print("Error updating display name directly: $displayNameError");
              // Continue anyway
            }
            
            // Save user data to Firestore
            await _firestore.collection('users').doc(user.uid).set({
              'name': username.text.trim(),
              'email': email.text.trim(),
              'phone': mobileNum.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
            print("User data saved to Firestore despite PigeonUserDetails error");
            
            // Send email verification
            try {
              await user.sendEmailVerification();
              print("Email verification sent to: ${user.email}");
            } catch (emailError) {
              print("Error sending email verification: $emailError");
              // Continue anyway - user can verify later from profile
            }
            
            // Show success message with email verification info
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Account created successfully! Please check your email (${user.email}) to verify your account.'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
              // Navigate to home page after successful signup
              Navigator.pushReplacementNamed(context, '/home');
            }
            
          } catch (e) {
            print("Error during recovery from PigeonUserDetails error: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error completing account setup: $e')),
              );
            }
          }
        } else {
          print("General auth error: $authError");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(authError.toString())),
            );
          }
        }
      }
    } catch (e) {
      print("General error in signup: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating account: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                  "Create Account",
                  style: TextStyle(
                    fontSize: 36,
                    color: ColorApp.primaryDarkColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Let's get started",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xff787B82),
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextFormField(
                  controller: username,
                  hintText: "Username",
                  showError: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                CustomTextFormField(
                  controller: email,
                  hintText: "Email address",
                  showError: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                CustomTextFormField(
                  controller: mobileNum,
                  hintText: "Mobile Number",
                  showError: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a mobile number';
                    }
                    return null;
                  },
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Obx(
                  () => CustomTextFormField(
                    controller: password,
                    obscureText: passwordIsObscure.value,
                    isObscure: passwordIsObscure,
                    hintText: "Password",
                    showError: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Obx(
                  () => CustomTextFormField(
                    controller: con_password,
                    obscureText: passwordIsObscure.value,
                    isObscure: passwordIsObscure,
                    hintText: "Confirm Password",
                    showError: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != password.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorApp.primaryDarkColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "SUBMIT",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
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
