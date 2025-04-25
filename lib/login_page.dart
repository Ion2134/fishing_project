import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class LoginPage extends StatefulWidget {
  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers to manage the text field input
  final _emailController = TextEditingController(); // Renamed for clarity (usually email for Firebase)
  final _passwordController = TextEditingController();

  // Form key for validation (optional but recommended)
  final _formKey = GlobalKey<FormState>();

  // State variable for loading indicator
  bool _isLoading = false;

  // Error message state
  String? _errorMessage;

  // Dispose controllers when the widget is removed from the tree
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Login Logic ---
  Future<void> _login() async {
    // // Optional: Validate form inputs
    // if (!_formKey.currentState!.validate()) {
    //   return; // If form is not valid, do nothing
    // }

    // Show loading indicator
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      // Get email and password, trim whitespace
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      // Attempt to sign in with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // --- Login Successful ---
      print('Login successful: ${userCredential.user?.email}');

      // Check if the widget is still mounted before navigating
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main', // The route name for your main app page
              (Route<dynamic> route) => false, // This predicate removes all routes below the new one
        );
      }

    } on FirebaseAuthException catch (e) {
      // --- Handle Login Errors ---
      print('Login failed: ${e.code}'); // Log the error code
      print(e.message); // Log the error message

      // Determine user-friendly error message
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
        case 'wrong-password':
          message = 'Wrong password provided.';
        case 'invalid-email':
          message = 'The email address is not valid.';
        case 'user-disabled':
          message = 'This user account has been disabled.';
      // Add more specific cases as needed
        default:
          message = 'An error occurred. Please try again.';
      }

      // Check if mounted before updating state for error message
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
      }

    } catch (e) {
      // --- Handle other potential errors ---
      print('An unexpected error occurred: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    } finally {
      // Hide loading indicator regardless of success or failure
      // Check if mounted before updating state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToRegister() {
    // Navigate to the registration page
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          // Wrap content in a Form widget if using validation
          // child: Form(
          //   key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FlutterLogo(size: 80),
              SizedBox(height: 40.0),

              // --- Email Field ---
              TextFormField( // Changed to TextFormField for validation potential
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email', // Changed label
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email_outlined), // Changed icon
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                // --- Optional Validation ---
                // validator: (value) {
                //   if (value == null || value.isEmpty) {
                //     return 'Please enter your email';
                //   }
                //   if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) { // Basic email format check
                //      return 'Please enter a valid email address';
                //   }
                //   return null; // Return null if valid
                // },
                enabled: !_isLoading, // Disable field when loading
              ),
              SizedBox(height: 20.0),

              // --- Password Field ---
              TextFormField( // Changed to TextFormField for validation potential
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                // --- Optional Validation ---
                // validator: (value) {
                //   if (value == null || value.isEmpty) {
                //     return 'Please enter your password';
                //   }
                //   // Add more password rules if needed (e.g., length)
                //   return null; // Return null if valid
                // },
                enabled: !_isLoading, // Disable field when loading
              ),
              SizedBox(height: 15.0),

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

              // --- Login Button (conditionally show progress) ---
              ElevatedButton(
                // Disable button while loading, call _login otherwise
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.0),
                    textStyle: TextStyle(fontSize: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    )
                ),
                child: _isLoading
                    ? SizedBox( // Show progress indicator when loading
                  height: 20.0,
                  width: 20.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text('Login'), // Show 'Login' text otherwise
              ),
              SizedBox(height: 15.0),

              // --- Registration Link ---
              TextButton(
                // Disable button while loading
                onPressed: _isLoading ? null : _navigateToRegister,
                child: Text("Don't have an account? Register here"),
              ),
            ],
          ),
          // ), // End Form widget
        ),
      ),
    );
  }
}