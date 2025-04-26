// species_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Import the TripDetailsPage to navigate to
import 'trip_details_page.dart';
// Import the new Chat Sheet page
import 'fish_ai_chat_sheet.dart'; // Create this file next

class SpeciesDetailsPage extends StatefulWidget {
  final String userId;
  final String speciesNameLowercase;
  final String speciesDisplayName; // Passed for the AppBar title

  const SpeciesDetailsPage({
    super.key,
    required this.userId,
    required this.speciesNameLowercase,
    required this.speciesDisplayName,
  });

  @override
  SpeciesDetailsPageState createState() => SpeciesDetailsPageState();
}

class SpeciesDetailsPageState extends State<SpeciesDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _associatedTripsStream;

  @override
  void initState() {
    super.initState();
    _associatedTripsStream = _firestore
        .collection('userFishCatalog')
        .doc(widget.userId)
        .collection('caughtSpecies')
        .doc(widget.speciesNameLowercase)
        .collection('associatedTrips')
        .orderBy('tripDate', descending: true)
        .snapshots();
  }

  // --- Helper to build trip list item (Keep as is) ---
  Widget _buildAssociatedTripItem(DocumentSnapshot tripLinkDoc) { /* ... same as before ... */
    Map<String, dynamic> data = tripLinkDoc.data() as Map<String, dynamic>; String tripId = tripLinkDoc.id; String location = data['tripLocation'] ?? 'Unknown Location'; Timestamp? timestamp = data['tripDate']; String formattedDate = 'No Date'; if (timestamp != null) { formattedDate = DateFormat.yMMMEd().format(timestamp.toDate()); }
    return Card( margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0), elevation: 2.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ListTile( leading: Icon(Icons.location_on_outlined, color: Colors.blueGrey[400]), title: Text(location), subtitle: Text("Date: $formattedDate"), trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () { print("Navigating to TripDetailsPage for trip: $tripId"); Navigator.push( context, MaterialPageRoute( builder: (context) => TripDetailsPage( userId: widget.userId, tripId: tripId, ), ), ); },
      ),
    );
  }

  // --- Function to show the FishAI Chat Bottom Sheet ---
  void _showFishAiChat() {
    showModalBottomSheet(
      context: context,
      // Make sheet taller and scrollable
      isScrollControlled: true,
      // Prevent closing by dragging down initially while loading? Maybe not needed.
      // isDismissible: false, // Consider this based on UX preference
      // Make it take up a large portion of the screen height
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85 // 85% of screen height
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        // Pass the species display name to the chat sheet
        return FishAiChatSheet(speciesName: widget.speciesDisplayName);
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- UPDATED TITLE ---
        title: Text(widget.speciesDisplayName), // Just the species name
      ),
      // Use Column to place button below the list
      body: Column(
        children: [
          // --- Trip List (wrapped in Expanded) ---
          Expanded( // Make the StreamBuilder take available space
            child: StreamBuilder<QuerySnapshot>(
              stream: _associatedTripsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) { /* ... error handling ... */ return Center(child: Text("Error loading trip data.")); }
                if (snapshot.connectionState == ConnectionState.waiting) { /* ... loading ... */ return Center(child: CircularProgressIndicator()); }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { /* ... empty state ... */ return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text( "No trip data found where ${widget.speciesDisplayName} was caught.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600]), ), )); }

                final tripLinkDocs = snapshot.data!.docs;
                // Build the list of associated trips (ListView inside StreamBuilder)
                return ListView.builder(
                  padding: EdgeInsets.only(top: 8.0, bottom: 20.0), // Bottom padding adjusted
                  itemCount: tripLinkDocs.length,
                  itemBuilder: (context, index) {
                    return _buildAssociatedTripItem(tripLinkDocs[index]);
                  },
                );
              },
            ),
          ), // End Expanded for List

          // --- Add Divider and Button Below List ---
          Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.support_agent), // Or Icons.chat, Icons.smart_toy
              label: Text("Ask FishAI about ${widget.speciesDisplayName}!"),
              onPressed: _showFishAiChat, // Call the function to show sheet
              style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: TextStyle(fontSize: 16)
              ),
            ),
          ),
        ], // End Column children
      ), // End Column body
    ); // End Scaffold
  }
}