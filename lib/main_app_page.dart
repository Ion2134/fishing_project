import 'package:flutter/material.dart';
import 'main_pages/trips_page.dart';
import 'main_pages/fish_caught_page.dart';
import 'main_pages/settings_page.dart';

class MainAppPage extends StatefulWidget {
  @override
  MainAppPageState createState() => MainAppPageState();
}

class MainAppPageState extends State<MainAppPage> {
  // Index for the currently selected tab
  int _selectedIndex = 0; // 0 = Trips (default), 1 = Fish, 2 = Settings

  // List of the pages/widgets to display for each tab
  static final List<Widget> _widgetOptions = <Widget>[
    TripsPage(),     // Index 0
    FishCaughtPage(),      // Index 1
    SettingsPage(),  // Index 2
  ];

  // Titles for the AppBar corresponding to each page (optional)
  static const List<String> _appBarTitles = <String>[
    'My Trips',
    'My Fish',
    'Settings',
  ];

  // Method called when a bottom navigation item is tapped
  void _onItemTapped(int index) {
    // Use setState to update the state (the selected index)
    // This will trigger a rebuild of the widget tree
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional: AppBar that changes title based on selected page
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        // Hides the automatic back button if MainAppPage was pushed onto stack
        // Only needed if you didn't use pushNamedAndRemoveUntil earlier
        // automaticallyImplyLeading: false,
      ),

      // Body displays the widget corresponding to the selected index
      body: Center( // Using Center just for structure, the page itself handles content
        child: _widgetOptions.elementAt(_selectedIndex),
      ),

      // --- The Bottom Navigation Bar ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined), // Placeholder icon for Trips
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phishing), // Placeholder icon for Fish
            label: 'Fish Caught',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), // Icon for Settings
            label: 'Settings', // Label is often omitted for settings icon, but can be included
          ),
        ],
        currentIndex: _selectedIndex,      // Highlights the current tab
        selectedItemColor: Colors.amber[800], // Color for selected icon/label
        unselectedItemColor: Colors.grey, // Color for unselected icons/labels
        onTap: _onItemTapped,             // Function to call when a tab is tapped
        // Optional: Style adjustments
        // type: BottomNavigationBarType.fixed, // Ensures labels are always visible
        // showUnselectedLabels: true,
      ),
    );
  }
}