// fish_caught_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import the next page
import 'species_details_page.dart';

class FishCaughtPage extends StatefulWidget {
  @override
  FishCaughtPageState createState() => FishCaughtPageState();
}

class FishCaughtPageState extends State<FishCaughtPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  Stream<QuerySnapshot>? _speciesStream;

  // --- State for Search ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  // --- End State for Search ---

  @override
  void initState() {
    super.initState();
    _getCurrentUserAndSetupStream();
    // Add listener to search controller
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  // --- Dispose Search Controller ---
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  // --- End Dispose ---

  void _getCurrentUserAndSetupStream() {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      // Fetch all species, filtering happens client-side
      _speciesStream = _firestore
          .collection('userFishCatalog')
          .doc(_currentUser!.uid)
          .collection('caughtSpecies')
          .orderBy('speciesDisplayName', descending: false)
          .snapshots();
    } else {
      print("FishCaughtPage: No user logged in.");
    }
  }

  // --- Helper Widget for the Search Bar ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search fish species...', // Updated hint text
          prefixIcon: Icon(Icons.search, color: Colors.blueGrey[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10.0),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[600]),
            onPressed: () {
              if (mounted) { _searchController.clear(); }
            },
          )
              : null,
        ),
        style: TextStyle(fontSize: 16.0),
      ),
    );
  }


  // --- Helper to build each species list item ---
  Widget _buildSpeciesListItem(DocumentSnapshot speciesDoc) {
    Map<String, dynamic> data = speciesDoc.data() as Map<String, dynamic>;
    String speciesNameLowercase = speciesDoc.id;
    String displayName = data['speciesDisplayName'] ?? speciesNameLowercase;
    String? imageUrl = data['representativeImageUrl'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: Container( /* ... Image display same as before ... */
          width: 55, height: 55, decoration: BoxDecoration( color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8), ),
          child: (imageUrl != null && imageUrl.isNotEmpty) ? ClipRRect( borderRadius: BorderRadius.circular(8.0), child: CachedNetworkImage( imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Padding(padding: const EdgeInsets.all(15.0), child: CircularProgressIndicator(strokeWidth: 2)), errorWidget: (context, url, error) => Icon(Icons.phishing, color: Colors.grey), ), ) : Icon(Icons.phishing, color: Colors.grey[600]),
        ),
        title: Text(displayName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        onTap: () { /* ... Navigation same as before ... */
          if (_currentUser != null) { print("Navigating to details for species: $speciesNameLowercase"); Navigator.push( context, MaterialPageRoute( builder: (context) => SpeciesDetailsPage( userId: _currentUser!.uid, speciesNameLowercase: speciesNameLowercase, speciesDisplayName: displayName, ), ), ); }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Center(child: Text("Please log in to view your caught fish."));
    }

    // Use a Column to place Search Bar above the StreamBuilder/List
    return Column(
      children: [
        // --- Add Search Bar ---
        _buildSearchBar(),
        Divider(height: 1, thickness: 1, indent: 16, endIndent: 16), // Optional separator

        // --- StreamBuilder wrapped in Expanded ---
        Expanded( // Allows the StreamBuilder/ListView to take remaining space
          child: StreamBuilder<QuerySnapshot>(
            stream: _speciesStream, // Reads the full species stream
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print("Error loading species: ${snapshot.error}");
                return Center(child: Text("Error loading fish catalog."));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              // --- Filter Data Client-Side ---
              List<DocumentSnapshot> filteredDocs = [];
              if (snapshot.hasData) {
                final allDocs = snapshot.data!.docs;
                if (_searchQuery.isEmpty) {
                  filteredDocs = allDocs;
                } else {
                  String lowerCaseQuery = _searchQuery.toLowerCase();
                  filteredDocs = allDocs.where((doc) {
                    // Get species display name, handle null safely
                    String name = (doc.data() as Map<String, dynamic>)['speciesDisplayName']?.toString().toLowerCase() ?? "";
                    // Check if name contains the query
                    return name.contains(lowerCaseQuery);
                  }).toList();
                }
              }
              // --- End Filter Data ---


              // Handle empty list case (AFTER filtering)
              if (filteredDocs.isEmpty && snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _searchQuery.isEmpty
                          ? "You haven't recorded any fish catches yet!"
                          : "No fish species found matching '$_searchQuery'",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                );
              }
              if (filteredDocs.isEmpty && snapshot.connectionState != ConnectionState.waiting){
                // Handle case where snapshot might not have data yet but isn't waiting (less likely but safe)
                return Center(child: Text("No fish data available.", style: TextStyle(color: Colors.grey)));
              }


              // Build the list using filtered data
              return ListView.builder(
                padding: EdgeInsets.only(top: 8.0, bottom: 80.0), // Padding top & for potential FAB
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  return _buildSpeciesListItem(filteredDocs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}