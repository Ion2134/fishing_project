// lib/main_pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Import Firebase Auth
import 'account_page.dart';

class SettingsPage extends StatelessWidget {

  // --- Sign Out Method ---
  Future<void> _signOut(BuildContext context) async {
    // It's good practice to show a loading indicator or disable interactions
    // during async operations, but sign out is usually very fast.

    try {
      print("Signing out...");
      await FirebaseAuth.instance.signOut();
      print("Sign out successful.");

      // Check if the widget is still mounted before navigating
      if (!context.mounted) return;

      // Navigate to login screen and remove all routes behind it
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login', // Your route name for the LoginPage
            (Route<dynamic> route) => false, // Predicate to remove all routes
      );

    } on FirebaseAuthException catch (e) {
      // Handle potential errors during sign out (less common)
      print("Error signing out: ${e.code} - ${e.message}");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error signing out: ${e.message ?? 'Please try again.'}"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      // Handle unexpected errors
      print("Unexpected error during sign out: $e");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An unexpected error occurred during sign out."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) { // context is available here
    return Scaffold(
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.account_circle_outlined),
            title: Text('Account'),
            subtitle: Text('Manage email and password'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AccountPage()),
              );
            },
          ),
          Divider(),
          // --- Add more settings options here later ---

          // --- UPDATE Sign Out ListTile ---
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red), // Optional: Add color
            title: Text('Sign Out', style: TextStyle(color: Colors.red)), // Optional: Add color
            onTap: () {
              // Call the sign out method, passing the context
              _signOut(context);
            },
          ),
          Divider(),
        ],
      ),
    );
  }
}