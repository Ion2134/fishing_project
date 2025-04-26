// lib/main_pages/settings_page.dart
import 'package:flutter/material.dart';
// Remove FirebaseAuth import if no longer needed here
import 'account_page.dart';

class SettingsPage extends StatelessWidget {
  // REMOVED _signOut method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.account_circle_outlined),
            title: Text('Account'),
            subtitle: Text('Manage email, password, sign out, delete'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AccountPage()),
              );
            },
          ),
          Divider(),
          // --- Add other non-account settings options here ---
          // Example:
          // ListTile(
          //   leading: Icon(Icons.notifications_outlined),
          //   title: Text('Notifications'),
          //   trailing: Icon(Icons.chevron_right),
          //   onTap: () { /* Navigate to Notifications Settings */ },
          // ),
          // Divider(),

          // REMOVED Sign Out ListTile
        ],
      ),
    );
  }
}