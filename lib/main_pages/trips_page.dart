import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Import the details page
import 'trip_details_page.dart'; // Ensure this file exists

class TripsPage extends StatefulWidget {
  @override
  TripsPageState createState() => TripsPageState();
}

class TripsPageState extends State<TripsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  Stream<QuerySnapshot>? _tripsStream;
  bool _isUpdatingStatus = false; // State to prevent double-clicks during update

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
      // Handle appropriately, maybe show different UI or navigate away
    }
  }

  // --- Function to show the Add Trip Bottom Sheet ---
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

  // --- Placeholder Function for Searching Trips ---
  void _searchTrips() {
    print("Search Trips triggered!");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Search functionality coming soon!")));
  }

  // --- Function to Update Trip Status in Firestore ---
  Future<void> _updateTripStatus(String tripId, String newStatus) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Not logged in.')));
      return;
    }
    if (_isUpdatingStatus) return; // Prevent concurrent updates

    setState(() { _isUpdatingStatus = true; }); // Indicate loading/processing

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('trips')
          .doc(tripId)
          .update({'status': newStatus});

      print("Trip $tripId status updated to $newStatus");
      // Optional: Show success feedback if needed, but StreamBuilder will update UI
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trip status updated!'), duration: Duration(seconds: 1),));

    } catch (e) {
      print("Error updating trip status for $tripId: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() { _isUpdatingStatus = false; }); // Reset loading state
      }
    }
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

  // --- Helper Function to Build Each Trip Item (Handles State Logic) ---
  Widget _buildTripItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    final String tripId = document.id; // Get trip ID

    // --- Data Extraction ---
    String destination = data['tripLocation'] as String? ?? 'Unknown Location';
    DateTime? tripDate;
    if (data['tripDate'] is Timestamp) {
      tripDate = (data['tripDate'] as Timestamp).toDate();
    }
    String formattedDate = tripDate != null ? DateFormat.yMMMd().format(tripDate) : 'No Date';
    String status = data['status'] as String? ?? 'Unknown'; // Get status

    // --- Determine Trailing Widget and Card Tap Action based on Status ---
    Widget trailingWidget;
    VoidCallback? cardOnTapAction; // Nullable callback

    switch (status.toLowerCase()) {
      case 'planned':
        trailingWidget = OutlinedButton( // Or ElevatedButton, TextButton etc.
          onPressed: _isUpdatingStatus // Disable if already updating
              ? null
              : () => _updateTripStatus(tripId, 'Ongoing'),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: TextStyle(fontSize: 13),
            side: BorderSide(color: Colors.blue), // Match planned color
            foregroundColor: Colors.blue,
          ),
          child: _isUpdatingStatus
              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Start'),
        );
        // No navigation when tapping the card itself in 'Planned' state
        cardOnTapAction = null;

      case 'ongoing':
        trailingWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_boat, color: Colors.green, size: 28), // Consistent icon
            SizedBox(height: 4),
            Text(status, style: TextStyle(fontSize: 11.0, color: Colors.green, fontWeight: FontWeight.w500)),
          ],
        );
        // Navigate to details when tapping the card in 'Ongoing' state
        cardOnTapAction = () {
          if (_currentUser != null) {
            print("Navigating to details for ONGOING Trip ID: $tripId");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailsPage(userId: _currentUser!.uid, tripId: tripId),
              ),
            );
          }
        };

      case 'completed':
        trailingWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.orange, size: 28), // Consistent icon
            SizedBox(height: 4),
            Text(status, style: TextStyle(fontSize: 11.0, color: Colors.orange, fontWeight: FontWeight.w500)),
          ],
        );
        // Navigate to details when tapping the card in 'Completed' state
        cardOnTapAction = () {
          if (_currentUser != null) {
            print("Navigating to details for COMPLETED Trip ID: $tripId");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailsPage(userId: _currentUser!.uid, tripId: tripId),
              ),
            );
          }
        };

      default: // Unknown status
        trailingWidget = Icon(Icons.help_outline, color: Colors.grey, size: 28);
        cardOnTapAction = null; // Or navigate if desired for unknown state
    }

    // --- Build the Card ---
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        // Use the determined onTap action
        onTap: cardOnTapAction,
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Left side: Text content
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
              SizedBox(width: 16), // Space between text and trailing widget
              // Right side: Conditional widget (Button or Status Icon)
              AnimatedSwitcher( // Optional: Animate transition between button/icon
                duration: Duration(milliseconds: 300),
                child: Container( // Wrap in container with a key for AnimatedSwitcher
                  key: ValueKey<String>(status), // Key changes when status changes
                  child: trailingWidget,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body uses StreamBuilder to listen for trip updates
      body: SafeArea(
        child: (_currentUser == null)
            ? Center(child: Text("Please log in to see trips."))
            : StreamBuilder<QuerySnapshot>(
          stream: _tripsStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            // --- Loading and Error States ---
            if (snapshot.hasError) {
              print("Firestore Error: ${snapshot.error}");
              return Center(child: Text('Error loading trips. Please try again.'));
            }
            // Show loading indicator only on initial load without any data
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            // --- Build List Content ---
            List<Widget> listChildren = [];
            // Add scrollable header items
            listChildren.add(_buildSearchButton());
            listChildren.add(Divider(height: 1, thickness: 1, indent: 16, endIndent: 16));

            // Handle empty list case
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              listChildren.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 16.0),
                    child: Center(
                      child: Text(
                        "No trips recorded yet. Tap '+' below to get started!",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  )
              );
            } else {
              // Add trip items from Firestore data
              listChildren.addAll(
                  snapshot.data!.docs.map((document) => _buildTripItem(document)).toList()
              );
              // Optional: Show loading indicator at bottom if still waiting for more data
              if (snapshot.connectionState == ConnectionState.waiting) {
                listChildren.add(Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ));
              }
            }

            // Return the ListView
            return ListView(
              padding: const EdgeInsets.only(bottom: 80.0), // Padding for FAB
              children: listChildren,
            );
          },
        ),
      ),

      // --- Floating Action Button (Remains the same) ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTripSheet,
        label: Text('Add Trip'),
        icon: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}


// --- WIDGET FOR THE BOTTOM SHEET CONTENT (AddTripFormSheet) ---
// Keep this exactly as before - no changes needed here.
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
  void initState() { super.initState(); _selectedDate = DateTime.now(); }
  @override
  void dispose() { _locationController.dispose(); super.dispose(); }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
    if (picked != null && picked != _selectedDate) { setState(() { _selectedDate = picked; }); }
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a trip date.'))); return; }
    setState(() { _isLoading = true; });
    try {
      final tripData = { 'tripLocation': _locationController.text.trim(), 'tripDate': Timestamp.fromDate(_selectedDate!), 'status': 'Planned', 'createdAt': FieldValue.serverTimestamp() };
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('trips').add(tripData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trip added successfully!'))); Navigator.pop(context);
    } catch (e) {
      print("Error adding trip: $e"); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding trip: ${e.toString()}')));
    } finally { if (mounted) { setState(() { _isLoading = false; }); } }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form( key: _formKey,
        child: Column( mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Start a New Trip', style: Theme.of(context).textTheme.titleLarge), SizedBox(height: 20),
            TextFormField( controller: _locationController, decoration: InputDecoration(labelText: 'Trip Location', hintText: 'E.g., Lake Clearwater, Pier 5', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on_outlined)), validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a location' : null ), SizedBox(height: 15),
            Row( mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [ Text(_selectedDate == null ? 'No date chosen!' : 'Date: ${DateFormat.yMd().format(_selectedDate!)}', style: TextStyle(fontSize: 16)), TextButton.icon(icon: Icon(Icons.calendar_today_outlined), label: Text('Select Date'), onPressed: () => _selectDate(context)) ]), SizedBox(height: 25),
            SizedBox( width: double.infinity, child: ElevatedButton.icon(icon: Icon(Icons.add_location_alt_outlined), label: Text('Save Trip'), onPressed: _isLoading ? null : _saveTrip, style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12.0), textStyle: TextStyle(fontSize: 16))) ),
            if (_isLoading) Padding(padding: const EdgeInsets.only(top: 16.0), child: Center(child: CircularProgressIndicator())), SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

