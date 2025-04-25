import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Import the details page (it will be created next)
import 'trip_details_page.dart'; // Placeholder import - create this file

// (Keep the TripsPage StatefulWidget and _TripsPageState class structure)
class TripsPage extends StatefulWidget {
  @override
  TripsPageState createState() => TripsPageState();
}

class TripsPageState extends State<TripsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  Stream<QuerySnapshot>? _tripsStream;

  @override
  void initState() {
    super.initState();
    _getCurrentUserAndSetupStream();
  }

  void _getCurrentUserAndSetupStream() {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _tripsStream = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('trips')
          .orderBy('tripDate', descending: true)
          .snapshots();
    } else {
      print("TripsPage: Error - No user logged in!");
    }
  }

  void _showAddTripSheet() {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Must be logged in.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AddTripFormSheet(userId: _currentUser!.uid),
        );
      },
    );
  }

  void _searchTrips() {
    print("Search Trips triggered!");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Search functionality coming soon!")));
  }

  // --- Helper Widget for the Search Button Area (Remains scrollable) ---
  Widget _buildSearchButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: InkWell(
        onTap: _searchTrips,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, color: Colors.blueGrey[700], size: 26.0),
              SizedBox(width: 8.0),
              Text('Search Trips', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w500, color: Colors.blueGrey[700])),
            ],
          ),
        ),
      ),
    );
  }
  // --- REMOVED _buildAddTripButton helper ---

  // --- Helper Function to Build Each Trip Item (_buildTripItem) ---
  Widget _buildTripItem(DocumentSnapshot document) {
    // ... (Keep this exactly as in the previous version, including the onTap navigation) ...
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    String destination = data['tripLocation'] as String? ?? 'Unknown Location';
    DateTime? tripDate;
    if (data['tripDate'] is Timestamp) {
      tripDate = (data['tripDate'] as Timestamp).toDate();
    }
    String formattedDate = tripDate != null ? DateFormat.yMMMd().format(tripDate) : 'No Date';
    String status = data['status'] as String? ?? 'Unknown';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.schedule;

    switch (status.toLowerCase()) {
      case 'planned': statusColor = Colors.blue; statusIcon = Icons.event_note;
      case 'ongoing': statusColor = Colors.green; statusIcon = Icons.directions_boat;
      case 'completed': statusColor = Colors.orange; statusIcon = Icons.check_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        onTap: () {
          final String tripId = document.id;
          final String userId = _currentUser!.uid;
          print("Navigating to details for Trip ID: $tripId"); // Debug log
          Navigator.push(
            context,
            MaterialPageRoute(
              // Ensure TripDetailsPage is imported
              builder: (context) => TripDetailsPage(userId: userId, tripId: tripId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 8.0),
                    Text(formattedDate, style: TextStyle(fontSize: 14.0, color: Colors.grey[600])),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Column(
                children: [
                  Icon(statusIcon, color: statusColor, size: 28),
                  SizedBox(height: 4),
                  Text(status, style: TextStyle(fontSize: 11.0, color: statusColor, fontWeight: FontWeight.w500)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Add Scaffold here within TripsPage
    return Scaffold(
      // NOTE: The AppBar is still provided by MainAppPage, so no AppBar here.

      // --- Body remains largely the same, but without the Add Button in the list ---
      body: SafeArea(
        child: (_currentUser == null)
            ? Center(child: Text("Please log in to see trips."))
            : StreamBuilder<QuerySnapshot>(
          stream: _tripsStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              print("Firestore Error: ${snapshot.error}");
              return Center(child: Text('Error loading trips. Please try again.'));
            }

            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            List<Widget> listChildren = [];
            // --- Only add Search Button and Divider to the scrollable header ---
            listChildren.add(_buildSearchButton());
            listChildren.add(Divider(height: 1, thickness: 1, indent: 16, endIndent: 16));

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              listChildren.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 16.0),
                    child: Center(
                      child: Text(
                        "No trips recorded yet. Tap '+' below to get started!", // Updated text
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  )
              );
            } else {
              listChildren.addAll(
                  snapshot.data!.docs.map((document) => _buildTripItem(document)).toList()
              );
              if (snapshot.connectionState == ConnectionState.waiting) {
                listChildren.add(Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ));
              }
            }

            // Add padding at the bottom of the list to ensure the FAB doesn't overlap the last item *visually*
            // when scrolled all the way down. Adjust value as needed based on FAB size.
            return ListView(
              padding: const EdgeInsets.only(bottom: 80.0), // ADDED bottom padding
              children: listChildren,
            );
          },
        ),
      ),

      // --- ADD FloatingActionButton ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTripSheet, // Calls the function to show the bottom sheet
        label: Text('Add Trip'),
        icon: Icon(Icons.add),
        // backgroundColor: Colors.amber[800], // Optional: Match theme
      ),
      // --- Position the FAB ---
      // centerFloat positions it horizontally centered, vertically above the bottom nav bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

    );
  }
}


// --- WIDGET FOR THE BOTTOM SHEET CONTENT (AddTripFormSheet) ---
// Keep the AddTripFormSheet class exactly as defined in the previous step.
// No changes needed here.
class AddTripFormSheet extends StatefulWidget {
  final String userId;
  const AddTripFormSheet({Key? key, required this.userId}) : super(key: key);
  @override
  AddTripFormSheetState createState() => AddTripFormSheetState();
}
class AddTripFormSheetState extends State<AddTripFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
    }
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a trip date.')));
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final tripData = {
        'tripLocation': _locationController.text.trim(),
        'tripDate': Timestamp.fromDate(_selectedDate!),
        'status': 'Planned',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('trips').add(tripData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trip added successfully!')));
      Navigator.pop(context);
    } catch (e) {
      print("Error adding trip: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding trip: ${e.toString()}')));
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Start a New Trip', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 20),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(labelText: 'Trip Location', hintText: 'E.g., Lake Clearwater, Pier 5', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on_outlined)),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a location' : null,
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedDate == null ? 'No date chosen!' : 'Date: ${DateFormat.yMd().format(_selectedDate!)}', style: TextStyle(fontSize: 16)),
                TextButton.icon(icon: Icon(Icons.calendar_today_outlined), label: Text('Select Date'), onPressed: () => _selectDate(context)),
              ],
            ),
            SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(icon: Icon(Icons.add_location_alt_outlined), label: Text('Save Trip'), onPressed: _isLoading ? null : _saveTrip, style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12.0), textStyle: TextStyle(fontSize: 16))),
            ),
            if (_isLoading) Padding(padding: const EdgeInsets.only(top: 16.0), child: Center(child: CircularProgressIndicator())),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}


// --- Placeholder for TripDetailsPage (create trip_details_page.dart) ---
// Add this import at the top: import 'package:flutter/material.dart';
class TripDetailsPage extends StatelessWidget {
  final String userId;
  final String tripId;

  const TripDetailsPage({Key? key, required this.userId, required this.tripId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Details'),
      ),
      body: Center(
        child: Text('Details for Trip ID: $tripId\nUser ID: $userId\n(Content coming soon)'),
      ),
    );
  }
}