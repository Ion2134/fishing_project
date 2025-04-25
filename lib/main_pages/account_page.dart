// lib/main_pages/account_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountPage extends StatefulWidget {
  @override
  AccountPageState createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // Controllers for forms
  final _newEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form Keys for validation
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // Loading states
  bool _isChangingEmail = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // Optionally pre-fill email if needed for display, but not needed for verifyBeforeUpdateEmail
    // _newEmailController.text = _currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Show Snackbar Helper ---
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return; // Check if widget is still in the tree
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  // --- Change Email Logic ---
  Future<void> _changeEmail() async {
    if (!_emailFormKey.currentState!.validate()) {
      return;
    }
    if (_currentUser == null) {
      _showSnackbar("Error: Not logged in.", isError: true);
      return;
    }

    final newEmail = _newEmailController.text.trim();
    if (newEmail == _currentUser!.email) {
      _showSnackbar("New email is the same as the current one.", isError: true);
      return;
    }

    setState(() { _isChangingEmail = true; });

    try {
      // Preferred method: Sends verification link to the *new* email address.
      // The email in Firebase Auth Console updates only after verification.
      await _currentUser!.verifyBeforeUpdateEmail(newEmail);

      _showSnackbar(
        "Verification email sent to $newEmail. Please verify to update your email address.",
      );
      _newEmailController.clear(); // Clear field on success

    } on FirebaseAuthException catch (e) {
      print("Email change error: ${e.code} - ${e.message}");
      String errorMessage = "Failed to initiate email change.";
      if (e.code == 'email-already-in-use') {
        errorMessage = "This email address is already in use by another account.";
      } else if (e.code == 'requires-recent-login') {
        errorMessage = "This operation requires recent login. Please sign out and sign back in.";
        // TODO: Implement re-authentication prompt for better UX instead of just this message.
      } else if (e.code == 'invalid-email') {
        errorMessage = "The new email address is not valid.";
      }
      _showSnackbar(errorMessage, isError: true);
    } catch (e) {
      print("Unexpected error changing email: $e");
      _showSnackbar("An unexpected error occurred.", isError: true);
    } finally {
      if (mounted) {
        setState(() { _isChangingEmail = false; });
      }
    }
  }

  // --- Change Password Logic ---
  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }
    if (_currentUser == null) {
      _showSnackbar("Error: Not logged in.", isError: true);
      return;
    }

    setState(() { _isChangingPassword = true; });

    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;

    try {
      // --- Step 1: Re-authenticate user ---
      AuthCredential credential = EmailAuthProvider.credential(
        email: _currentUser!.email!, // Non-null assertion OK as user must be logged in
        password: currentPassword,
      );

      await _currentUser!.reauthenticateWithCredential(credential);
      print("Re-authentication successful.");

      // --- Step 2: Update password if re-authentication succeeds ---
      await _currentUser!.updatePassword(newPassword);
      print("Password updated successfully.");

      _showSnackbar("Password updated successfully!");

      // Clear password fields on success
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

    } on FirebaseAuthException catch (e) {
      print("Password change error: ${e.code} - ${e.message}");
      String errorMessage = "Failed to change password.";
      if (e.code == 'wrong-password') {
        errorMessage = "Incorrect current password provided.";
      } else if (e.code == 'user-mismatch') {
        errorMessage = "Credential does not match the user."; // Shouldn't happen here
      } else if (e.code == 'weak-password') {
        errorMessage = "The new password is too weak.";
      } else if (e.code == 'requires-recent-login') {
        errorMessage = "This operation requires recent login. Please sign out and sign back in.";
      }
      _showSnackbar(errorMessage, isError: true);

    } catch (e) {
      print("Unexpected error changing password: $e");
      _showSnackbar("An unexpected error occurred.", isError: true);
    } finally {
      if (mounted) {
        setState(() { _isChangingPassword = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Account Settings"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Display Current Email ---
            Text(
              "Current Email:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 4),
            Text(
              _currentUser?.email ?? "Not logged in",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
            ),
            SizedBox(height: 20),
            Divider(),

            // --- Change Email Section ---
            SizedBox(height: 20),
            Text(
              "Change Email Address",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 15),
            Form(
              key: _emailFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "New Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a new email address';
                      }
                      // Basic email format check
                      if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _isChangingEmail ? null : _changeEmail,
                    style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
                    child: _isChangingEmail
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Text("Send Verification to Change Email"),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            Divider(),

            // --- Change Password Section ---
            SizedBox(height: 20),
            Text(
              "Change Password",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 15),
            Form(
              key: _passwordFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Current Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 15),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 15),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Confirm New Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isChangingPassword ? null : _changePassword,
                    style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
                    child: _isChangingPassword
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Text("Change Password"),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }
}