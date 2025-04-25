import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Keep Firebase Auth import

// --- RENAME the Widget and State ---
class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

// --- RENAME the State class ---
class _RegistrationPageState extends State<RegistrationPage> {
  // Keep Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keep controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Optional: Add a confirm password controller if you want that validation
  // final _confirmPasswordController = TextEditingController();

  // Keep Form key for validation (Highly recommended for registration!)
  final _formKey = GlobalKey<FormState>();

  // Keep loading and error states
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    // _confirmPasswordController.dispose(); // Dispose if added
    super.dispose();
  }

  // --- RENAME the core logic function ---
  Future<void> _register() async {
    // --- VALIDATION (Strongly Recommended) ---
    // Uncomment this block once you add validators to your TextFormFields
    if (!_formKey.currentState!.validate()) {
      print("Form validation failed");
      return; // Stop registration if validation fails
    }
    // Optional: Add check for password confirmation match here if using confirm field

    // Show loading indicator and clear previous errors
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get email and password, trim whitespace
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      // --- CHANGE Firebase method to CREATE user ---
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // --- Registration Successful ---
      print('Registration successful: ${userCredential.user?.email}');

      // Optional: You might want to send a verification email here
      // await userCredential.user?.sendEmailVerification();
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Verification email sent. Please check your inbox.')),
      // );
      // // Navigate to login OR main page depending on your flow after verification
      // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false); // Example: back to login

      // Navigate to the main app page after successful registration
      // Use pushReplacementNamed to prevent going back to registration
      if (mounted) { // Check if widget is still mounted
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main', // The route name for your main app page
              (Route<dynamic> route) => false, // This predicate removes all routes below the new one
        );
      }

    } on FirebaseAuthException catch (e) {
      // --- Handle Registration Errors ---
      print('Registration failed: ${e.code}'); // Log error code
      print(e.message); // Log error message

      // Determine user-friendly error message for REGISTRATION
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'operation-not-allowed':
        // This usually means email/password auth isn't enabled in Firebase Console
          message = 'Registration is currently disabled. Please contact support.';
          break;
        default:
          message = 'An error occurred during registration. Please try again.';
      }

      // Check if mounted before updating state
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
      }

    } catch (e) {
      // --- Handle other potential errors ---
      print('An unexpected error occurred: $e');
      if (mounted) { // Check if mounted
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    } finally {
      // Hide loading indicator
      if (mounted) { // Check if mounted
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // We don't need the _navigateToRegister function here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional: Add AppBar for clarity
      appBar: AppBar(
        title: Text('Register New Account'),
        // Automatically adds a back button to navigate to the previous screen (login)
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          // --- WRAP with Form for validation ---
          child: Form(
            key: _formKey, // Assign the key
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Keep Logo or Title
                FlutterLogo(size: 80),
                SizedBox(height: 40.0),

                // --- Email Field (Add validator) ---
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration( /* ... same as login ... */
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  // Add validation for email format/non-empty
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                SizedBox(height: 20.0),

                // --- Password Field (Add validator) ---
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration( /* ... same as login ... */
                    labelText: 'Password',
                    hintText: 'Create your password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  // Add validation for password rules (e.g., non-empty, length)
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) { // Firebase default minimum
                      return 'Password must be at least 6 characters long';
                    }
                    // Add more complex rules here if needed (numbers, symbols etc.)
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                SizedBox(height: 15.0),

                // --- Optional: Confirm Password Field ---
                // TextFormField(
                //   controller: _confirmPasswordController,
                //   obscureText: true,
                //   decoration: InputDecoration(
                //     labelText: 'Confirm Password',
                //     hintText: 'Re-enter your password',
                //     prefixIcon: Icon(Icons.lock_outline),
                //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                //   ),
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Please confirm your password';
                //     }
                //     if (value != _passwordController.text) {
                //       return 'Passwords do not match';
                //     }
                //     return null;
                //   },
                //   enabled: !_isLoading,
                // ),
                // SizedBox(height: 15.0), // Add spacing if confirm field is used


                // --- Display Error Message ---
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                SizedBox(height: 15.0),

                // --- CHANGE Button Text and Action ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _register, // Call _register
                  child: _isLoading
                      ? SizedBox( /* ... same loading indicator ... */
                    height: 20.0,
                    width: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text('Register'), // Change text
                  style: ElevatedButton.styleFrom( /* ... same style ... */
                      padding: EdgeInsets.symmetric(vertical: 15.0),
                      textStyle: TextStyle(fontSize: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))
                  ),
                ),

                // --- REMOVE the 'Login here' TextButton ---
                // SizedBox(height: 15.0),
                // TextButton(...)

              ],
            ),
          ),
        ),
      ),
    );
  }
}