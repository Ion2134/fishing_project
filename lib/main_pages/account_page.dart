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

  // Controllers
  final _newEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController(); // Also used for re-auth
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form Keys
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // Loading states
  bool _isChangingEmail = false;
  bool _isChangingPassword = false;
  bool _isSigningOut = false; // New state
  bool _isDeletingAccount = false; // New state

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) { /* ... keep as is ... */
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green, ), );
  }

  Future<void> _changeEmail() async { /* ... keep as is ... */
    if (!_emailFormKey.currentState!.validate()) { return; } if (_currentUser == null) { _showSnackbar("Error: Not logged in.", isError: true); return; } final newEmail = _newEmailController.text.trim(); if (newEmail == _currentUser!.email) { _showSnackbar("New email is the same as the current one.", isError: true); return; } setState(() { _isChangingEmail = true; }); try { await _currentUser!.verifyBeforeUpdateEmail(newEmail); _showSnackbar( "Verification email sent to $newEmail. Please verify to update your email address.", ); _newEmailController.clear(); } on FirebaseAuthException catch (e) { print("Email change error: ${e.code} - ${e.message}"); String errorMessage = "Failed to initiate email change."; if (e.code == 'email-already-in-use') { errorMessage = "This email address is already in use by another account."; } else if (e.code == 'requires-recent-login') { errorMessage = "This operation requires recent login. Please sign out and sign back in."; } else if (e.code == 'invalid-email') { errorMessage = "The new email address is not valid."; } _showSnackbar(errorMessage, isError: true); } catch (e) { print("Unexpected error changing email: $e"); _showSnackbar("An unexpected error occurred.", isError: true); } finally { if (mounted) { setState(() { _isChangingEmail = false; }); } }
  }

  Future<void> _changePassword() async { /* ... keep as is ... */
    if (!_passwordFormKey.currentState!.validate()) { return; } if (_currentUser == null) { _showSnackbar("Error: Not logged in.", isError: true); return; } setState(() { _isChangingPassword = true; }); final String currentPassword = _currentPasswordController.text; final String newPassword = _newPasswordController.text; try { AuthCredential credential = EmailAuthProvider.credential( email: _currentUser!.email!, password: currentPassword, ); await _currentUser!.reauthenticateWithCredential(credential); print("Re-authentication successful."); await _currentUser!.updatePassword(newPassword); print("Password updated successfully."); _showSnackbar("Password updated successfully!"); _currentPasswordController.clear(); _newPasswordController.clear(); _confirmPasswordController.clear(); } on FirebaseAuthException catch (e) { print("Password change error: ${e.code} - ${e.message}"); String errorMessage = "Failed to change password."; if (e.code == 'wrong-password') { errorMessage = "Incorrect current password provided."; } else if (e.code == 'user-mismatch') { errorMessage = "Credential does not match the user."; } else if (e.code == 'weak-password') { errorMessage = "The new password is too weak."; } else if (e.code == 'requires-recent-login') { errorMessage = "This operation requires recent login. Please sign out and sign back in."; } _showSnackbar(errorMessage, isError: true); } catch (e) { print("Unexpected error changing password: $e"); _showSnackbar("An unexpected error occurred.", isError: true); } finally { if (mounted) { setState(() { _isChangingPassword = false; }); } }
  }

  // --- Sign Out Logic (Moved Here) ---
  Future<void> _signOut() async {
    if (_isSigningOut) return; // Prevent multiple clicks
    setState(() { _isSigningOut = true; });

    try {
      print("Signing out...");
      await FirebaseAuth.instance.signOut();
      print("Sign out successful.");

      if (!mounted) return;
      // Navigate to login screen and remove all routes behind it
      Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
    } on FirebaseAuthException catch (e) {
      print("Error signing out: ${e.code} - ${e.message}");
      if (!mounted) return;
      _showSnackbar("Error signing out: ${e.message ?? 'Please try again.'}", isError: true);
    } catch (e) {
      print("Unexpected error during sign out: $e");
      if (!mounted) return;
      _showSnackbar("An unexpected error occurred during sign out.", isError: true);
    } finally {
      // Reset state even if not mounted, just in case
      if(mounted) setState(() { _isSigningOut = false; });
    }
  }

  // --- Delete Account Logic ---
  Future<void> _promptForPasswordAndDelete() async {
    if (_currentUser == null) { _showSnackbar("Error: Not logged in.", isError: true); return; }
    if (_isDeletingAccount) return;

    // --- Prompt for current password for re-authentication ---
    final passwordController = TextEditingController();
    final bool? reAuthConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Require interaction
      builder: (context) => AlertDialog(
        title: Text("Re-authenticate to Delete"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Please enter your current password to confirm account deletion."),
            SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Current Password", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Basic check: ensure password isn't empty before proceeding
              if (passwordController.text.isNotEmpty) {
                Navigator.of(context).pop(true);
              } else {
                // Optional: Show error within dialog if desired
              }
            },
            child: Text("Confirm"),
          ),
        ],
      ),
    );

    final String currentPassword = passwordController.text;
    passwordController.dispose(); // Dispose controller after use

    // If user cancelled password prompt
    if (reAuthConfirmed != true) return;


    // --- Show FINAL confirmation dialog ---
    final bool? deleteConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text("Delete Account Permanently?"),
          content: Text("Are you absolutely sure?\n\nThis will permanently delete your account, all your trips, catches, and other associated data. This action cannot be undone."),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Delete Account"),
            ),
          ],
        )
    );

    // If user cancelled final confirmation
    if (deleteConfirmed != true) return;

    // --- Perform Deletion ---
    await _performAccountDeletion(currentPassword);

  }

  Future<void> _performAccountDeletion(String currentPassword) async {
    if (_isDeletingAccount || _currentUser == null) return;
    setState(() { _isDeletingAccount = true; });

    try {
      // --- Step 1: Re-authenticate ---
      AuthCredential credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: currentPassword, // Use password from dialog
      );
      print("Re-authenticating user for deletion...");
      await _currentUser!.reauthenticateWithCredential(credential);
      print("Re-authentication successful for deletion.");

      // --- Step 2: Delete Auth User ---
      print("Deleting user account...");
      await _currentUser!.delete();
      print("User account deleted successfully.");

      // --- Step 3: Client-side cleanup & Navigation ---
      // NOTE: Actual data cleanup (Firestore, Storage) MUST be handled
      // by a Cloud Function triggered by auth user deletion (onUserDeleted).
      if (!mounted) return;
      _showSnackbar("Account deleted successfully.");
      // Navigate to login, remove history
      Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);

    } on FirebaseAuthException catch (e) {
      print("Account deletion error: ${e.code} - ${e.message}");
      String errorMessage = "Failed to delete account.";
      if (e.code == 'wrong-password') {
        errorMessage = "Incorrect password provided during re-authentication.";
      } else if (e.code == 'requires-recent-login') {
        // This shouldn't happen if re-auth succeeded, but handle defensively
        errorMessage = "Action requires recent login. Please sign out and sign back in.";
      } else if (e.code == 'network-request-failed') {
        errorMessage = "Network error. Please check connection and try again.";
      }
      _showSnackbar(errorMessage, isError: true);
    } catch (e) {
      print("Unexpected error deleting account: $e");
      _showSnackbar("An unexpected error occurred during account deletion.", isError: true);
    } finally {
      if (mounted) {
        setState(() { _isDeletingAccount = false; });
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
            // --- Current Email Display (Same as before) ---
            Text( "Current Email:", style: Theme.of(context).textTheme.titleMedium ), SizedBox(height: 4), Text( _currentUser?.email ?? "Not logged in", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]), ), SizedBox(height: 20), Divider(),

            // --- Change Email Section (Same as before) ---
            SizedBox(height: 20), Text( "Change Email Address", style: Theme.of(context).textTheme.titleLarge, ), SizedBox(height: 15), Form( key: _emailFormKey, child: Column( children: [ TextFormField( controller: _newEmailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration( labelText: "New Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined), ), validator: (v) { /*...*/ return null;}, ), SizedBox(height: 15), ElevatedButton( onPressed: _isChangingEmail ? null : _changeEmail, style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)), child: _isChangingEmail ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : Text("Send Verification to Change Email"), ), ], ), ), SizedBox(height: 30), Divider(),

            // --- Change Password Section (Same as before) ---
            SizedBox(height: 20), Text( "Change Password", style: Theme.of(context).textTheme.titleLarge, ), SizedBox(height: 15), Form( key: _passwordFormKey, child: Column( children: [ TextFormField( controller: _currentPasswordController, obscureText: true, decoration: InputDecoration( labelText: "Current Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline), ), validator: (v) { /*...*/ return null; }, ), SizedBox(height: 15), TextFormField( controller: _newPasswordController, obscureText: true, decoration: InputDecoration( labelText: "New Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline), ), validator: (v) { /*...*/ return null; }, ), SizedBox(height: 15), TextFormField( controller: _confirmPasswordController, obscureText: true, decoration: InputDecoration( labelText: "Confirm New Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline), ), validator: (v) { /*...*/ return null; }, ), SizedBox(height: 20), ElevatedButton( onPressed: _isChangingPassword ? null : _changePassword, style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)), child: _isChangingPassword ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : Text("Change Password"), ), ], ), ), SizedBox(height: 30), Divider(),

            // --- Sign Out Section ---
            SizedBox(height: 20),
            ListTile( // Using ListTile for consistent spacing/tap area
              contentPadding: EdgeInsets.zero, // Remove default padding
              leading: Icon(Icons.logout, color: Colors.blueGrey),
              title: Text("Sign Out"),
              onTap: _isSigningOut ? null : _signOut, // Disable while signing out
              trailing: _isSigningOut ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,)) : Icon(Icons.chevron_right),
            ),
            Divider(),

            // --- Delete Account Section ---
            SizedBox(height: 20),
            Text(
              "Delete Account",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            SizedBox(height: 8),
            Text(
              "Permanently delete your account and all associated data (trips, catches, etc.). This action cannot be undone.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: _isDeletingAccount ? null : _promptForPasswordAndDelete,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error, // Use error color
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  minimumSize: Size(double.infinity, 45)
              ),
              child: _isDeletingAccount
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.onError))
                  : Text("Delete My Account Permanently"),
            ),
            SizedBox(height: 20), // Bottom padding

            // // --- IMPORTANT NOTE ABOUT DATA DELETION ---
            // Padding(
            //   padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
            //   child: Text(
            //     "Note: Deleting your account here removes your login credentials. A separate Cloud Function is required on the backend to automatically delete your associated trip data, catch data, and stored images.",
            //     style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            //   ),
            // ),

          ],
        ),
      ),
    );
  }
}