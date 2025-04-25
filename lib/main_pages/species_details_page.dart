// species_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Import the TripDetailsPage to navigate to
import 'trip_details_page.dart';

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
    // Set up the stream to listen to the associated trips for this species
    _associatedTripsStream = _firestore
        .collection('userFishCatalog')
        .doc(widget.userId)
        .collection('caughtSpecies')
        .doc(widget.speciesNameLowercase)
        .collection('associatedTrips')
        .orderBy('tripDate', descending: true) // Show most recent trips first
        .snapshots();
  }

  // --- Helper to build each associated trip list item ---
  Widget _buildAssociatedTripItem(DocumentSnapshot tripLinkDoc) {
    Map<String, dynamic> data = tripLinkDoc.data() as Map<String, dynamic>;
    String tripId = tripLinkDoc.id; // Doc ID is the tripId

    String location = data['tripLocation'] ?? 'Unknown Location';
    Timestamp? timestamp = data['tripDate'];
    String formattedDate = 'No Date';
    if (timestamp != null) {
      formattedDate = DateFormat.yMMMEd().format(timestamp.toDate()); // e.g. Wed, Jan 17, 2024
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ListTile(
        leading: Icon(Icons.location_on_outlined, color: Colors.blueGrey[400]),
        title: Text(location),
        subtitle: Text("Date: $formattedDate"),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () {
          print("Navigating to TripDetailsPage for trip: $tripId");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailsPage(
                userId: widget.userId,
                tripId: tripId,
              ),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Use the display name passed from the previous page
        title: Text('Trips with ${widget.speciesDisplayName}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _associatedTripsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("Error loading associated trips: ${snapshot.error}");
            return Center(child: Text("Error loading trip data for this species."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // This case *shouldn't* ideally happen if the species exists in the catalog,
            // but good to handle defensively.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "No trip data found where ${widget.speciesDisplayName} was caught.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            );
          }

          // Build the list of associated trips
          final tripLinkDocs = snapshot.data!.docs;
          return ListView.builder(
            padding: EdgeInsets.only(top: 8.0, bottom: 20.0),
            itemCount: tripLinkDocs.length,
            itemBuilder: (context, index) {
              return _buildAssociatedTripItem(tripLinkDocs[index]);
            },
          );
        },
      ),
    );
  }
}