import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:parental_control_app/core/constants/app_colors.dart';
import 'package:parental_control_app/core/utils/media_query_helpers.dart';
import 'package:parental_control_app/features/user_management/presentation/blocs/auth_bloc/auth_bloc.dart';
import 'package:parental_control_app/features/user_management/presentation/blocs/auth_bloc/auth_event.dart';
import 'package:parental_control_app/features/user_management/presentation/blocs/auth_bloc/auth_state.dart';
import '../../presentation/widgets/responsive_logo.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _userType;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userType = prefs.getString('user_type');
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // Password validation function
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }

  Future<void> _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_userType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User type not found. Please select again.')),
        );
        return;
      }
      
      // Check network connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check your network and try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      context.read<AuthBloc>().add(
        SignUpEvent(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          password: _pass.text,
          userType: _userType!,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);
    return Scaffold(
      backgroundColor: AppColors.lightCyan,
      appBar: AppBar(
        backgroundColor: AppColors.lightCyan,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: mq.w(0.06)),
          child: Column(
            children: [
              SizedBox(height: mq.h(0.03)),
              ResponsiveLogo(sizeFactor: 0.16),
              SizedBox(height: mq.h(0.02)),
              Text(
                'Signup as ${_userType?.toUpperCase() ?? "USER"}',
                style: TextStyle(
                  fontSize: mq.sp(0.07),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: mq.h(0.02)),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // First Name Field
                    TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter first name';
                        }
                        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
                          return 'First name must contain only alphabetic characters';
                        }
                        if (v.trim().length > 50) {
                          return 'First name must not exceed 50 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: mq.h(0.015)),
                    // Last Name Field
                    TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter last name';
                        }
                        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
                          return 'Last name must contain only alphabetic characters';
                        }
                        if (v.trim().length > 50) {
                          return 'Last name must not exceed 50 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: mq.h(0.015)),
                    // Email Field
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter email address';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: mq.h(0.015)),
                    // Password Field
                    TextFormField(
                      controller: _pass,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        helperText: 'Min 8 chars, 1 uppercase, 1 number, 1 special char',
                      ),
                      validator: _validatePassword,
                    ),
                    SizedBox(height: mq.h(0.015)),
                    // Confirm Password Field
                    TextFormField(
                      controller: _confirm,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _pass.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: mq.h(0.025)),
                    BlocConsumer<AuthBloc, AuthState>(
                      listener: (context, state) {
                        if (state is AuthSuccess) {
                          // navigate to AddChild or Home later; for now go back to login
                          Navigator.pop(context);
                        } else if (state is AuthFailure) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(state.error)));
                        }
                      },
                      builder: (context, state) {
                        if (state is AuthLoading) {
                          return Column(
                            children: [
                              const CircularProgressIndicator(),
                              SizedBox(height: mq.h(0.01)),
                              Text(
                                'Creating account...',
                                style: TextStyle(
                                  fontSize: mq.sp(0.035),
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                'Please wait, this may take a moment',
                                style: TextStyle(
                                  fontSize: mq.sp(0.03),
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          );
                        }
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.darkCyan,
                              padding: EdgeInsets.symmetric(
                                vertical: mq.h(0.018),
                              ),
                            ),
                            child: Text(
                              'Signup',
                              style: TextStyle(fontSize: mq.sp(0.038)),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: mq.h(0.02)), // Extra space at bottom
            ],
          ),
        ),
      ),
    );
  }
}
