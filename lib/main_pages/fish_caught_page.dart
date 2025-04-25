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

  @override
  void initState() {
    super.initState();
    _getCurrentUserAndSetupStream();
  }

  void _getCurrentUserAndSetupStream() {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _speciesStream = _firestore
          .collection('userFishCatalog')
          .doc(_currentUser!.uid) // Target the specific user's catalog
          .collection('caughtSpecies') // Get their unique species
          .orderBy('speciesDisplayName', descending: false) // Order alphabetically
      // Alternative: .orderBy('lastCaught', descending: true) // Order by most recently caught
          .snapshots();
    } else {
      // Handle user not logged in state (though should be handled by app flow)
      print("FishCaughtPage: No user logged in.");
    }
  }

  // --- Helper to build each species list item ---
  Widget _buildSpeciesListItem(DocumentSnapshot speciesDoc) {
    Map<String, dynamic> data = speciesDoc.data() as Map<String, dynamic>;
    String speciesNameLowercase = speciesDoc.id; // Document ID is lowercase name
    String displayName = data['speciesDisplayName'] ?? speciesNameLowercase; // Use display name if available
    String? imageUrl = data['representativeImageUrl']; // Optional image

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Padding(padding: const EdgeInsets.all(15.0), child: CircularProgressIndicator(strokeWidth: 2)),
              errorWidget: (context, url, error) => Icon(Icons.phishing, color: Colors.grey),
            ),
          )
              : Icon(Icons.phishing, color: Colors.grey[600]),
        ),
        title: Text(displayName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        // subtitle: Text("Caught X times"), // Optional: Could display 'totalCaught' if stored
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        onTap: () {
          if (_currentUser != null) {
            print("Navigating to details for species: $speciesNameLowercase");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpeciesDetailsPage(
                  userId: _currentUser!.uid,
                  speciesNameLowercase: speciesNameLowercase,
                  // Pass display name for AppBar title directly
                  speciesDisplayName: displayName,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The Scaffold is implicitly provided by MainAppPage's body switching
    // unless you need specific things like a FAB *only* on this page.
    // For simplicity, we assume it's just the body content here.

    if (_currentUser == null) {
      return Center(child: Text("Please log in to view your caught fish."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _speciesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("Error loading species: ${snapshot.error}");
          return Center(child: Text("Error loading fish catalog."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "You haven't recorded any fish catches yet!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          );
        }

        // Build the list
        final speciesDocs = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.only(top: 8.0, bottom: 80.0), // Padding top & for FAB if one existed
          itemCount: speciesDocs.length,
          itemBuilder: (context, index) {
            return _buildSpeciesListItem(speciesDocs[index]);
          },
        );
      },
    );
  }
}