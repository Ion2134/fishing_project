import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Import the details page
import 'trip_details_page.dart';

class TripsPage extends StatefulWidget {
  @override
  TripsPageState createState() => TripsPageState();
}

class TripsPageState extends State<TripsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  Stream<QuerySnapshot>? _tripsStream;
  bool _isUpdatingStatus = false; // For 'Start' button state

  // --- State for Search ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  // --- End State for Search ---

  @override
  void initState() {
    super.initState();
    _getCurrentUserAndSetupStream();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // --- Function to show the Add Trip Bottom Sheet ---
  void _showAddTripSheet() {
    if (_currentUser == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Must be logged in.'))); return; }
    showModalBottomSheet( context: context, isScrollControlled: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))), builder: (BuildContext context) { return Padding( padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: AddTripFormSheet(userId: _currentUser!.uid), ); }, );
  }

  // --- Function to Update Trip Status in Firestore ---
  Future<void> _updateTripStatus(String tripId, String newStatus) async {
    if (_currentUser == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Not logged in.'))); return; }
    if (_isUpdatingStatus) return;
    setState(() { _isUpdatingStatus = true; });
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).collection('trips').doc(tripId).update({'status': newStatus});
      print("Trip $tripId status updated to $newStatus");
    } catch (e) {
      print("Error updating trip status for $tripId: $e");
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: ${e.toString()}'))); }
    } finally { if (mounted) { setState(() { _isUpdatingStatus = false; }); } }
  }

  // --- Function to Handle Trip Deletion (Client-Side Trigger) ---
  Future<void> _deleteTrip(String tripId) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Cannot delete trip. Not logged in.')));
      return;
    }
    print("Attempting to delete trip: $tripId");
    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('trips')
          .doc(tripId)
          .delete();

      print("Trip $tripId deleted successfully from client.");
      // Don't show snackbar immediately, let StreamBuilder remove item visually first
      // Cloud Function will handle backend cleanup.

    } catch (e) {
      print("Error deleting trip $tripId from client: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting trip: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
        );
      }
    }
    // No loading state needed here as Dismissible handles the animation
  }

  // --- Helper Widget for the Search Bar Area ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search trips by location...',
          prefixIcon: Icon(Icons.search, color: Colors.blueGrey[700]),
          border: OutlineInputBorder( borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey.shade400), ),
          enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey.shade400), ),
          focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Theme.of(context).primaryColor), ),
          contentPadding: EdgeInsets.symmetric(vertical: 10.0),
          suffixIcon: _searchController.text.isNotEmpty ? IconButton( icon: Icon(Icons.clear, color: Colors.grey[600]), onPressed: () { if (mounted) { _searchController.clear(); } }, ) : null,
        ),
        style: TextStyle(fontSize: 16.0),
      ),
    );
  }

  // --- Helper Function to Build Each Trip Item (NOW WITH DISMISSIBLE) ---
  Widget _buildTripItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    final String tripId = document.id; // Get trip ID

    String destination = data['tripLocation'] as String? ?? 'Unknown Location';
    DateTime? tripDate; if (data['tripDate'] is Timestamp) { tripDate = (data['tripDate'] as Timestamp).toDate(); }
    String formattedDate = tripDate != null ? DateFormat.yMMMd().format(tripDate) : 'No Date';
    String status = data['status'] as String? ?? 'Unknown';

    // --- Determine Trailing Widget and Card Tap Action (Same as before) ---
    Widget trailingWidget; VoidCallback? cardOnTapAction;
    switch (status.toLowerCase()) {
      case 'planned': trailingWidget = OutlinedButton( onPressed: _isUpdatingStatus ? null : () => _updateTripStatus(tripId, 'Ongoing'), style: OutlinedButton.styleFrom( padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), textStyle: TextStyle(fontSize: 13), side: BorderSide(color: Colors.blue), foregroundColor: Colors.blue, ), child: _isUpdatingStatus ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Start'), ); cardOnTapAction = null;
      case 'ongoing': trailingWidget = Column( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.directions_boat, color: Colors.green, size: 28), SizedBox(height: 4), Text(status, style: TextStyle(fontSize: 11.0, color: Colors.green, fontWeight: FontWeight.w500)), ], ); cardOnTapAction = () { if (_currentUser != null) { print("Navigating to details for ONGOING Trip ID: $tripId"); Navigator.push( context, MaterialPageRoute( builder: (context) => TripDetailsPage(userId: _currentUser!.uid, tripId: tripId), ), ); } };
      case 'completed': trailingWidget = Column( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.check_circle_outline, color: Colors.orange, size: 28), SizedBox(height: 4), Text(status, style: TextStyle(fontSize: 11.0, color: Colors.orange, fontWeight: FontWeight.w500)), ], ); cardOnTapAction = () { if (_currentUser != null) { print("Navigating to details for COMPLETED Trip ID: $tripId"); Navigator.push( context, MaterialPageRoute( builder: (context) => TripDetailsPage(userId: _currentUser!.uid, tripId: tripId), ), ); } };
      default: trailingWidget = Icon(Icons.help_outline, color: Colors.grey, size: 28); cardOnTapAction = null;
    }


    // --- Wrap the Card in Dismissible ---
    return Dismissible(
      key: Key(tripId), // Unique key for each item
      direction: DismissDirection.startToEnd, // Allow swipe from left to right

      // --- Background shown during swipe ---
      background: Container(
        color: Colors.redAccent[700], // Red background
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        alignment: Alignment.centerLeft, // Align icon/text to the left
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.delete_forever, color: Colors.white),
            SizedBox(width: 8),
            Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),

      // --- Confirmation before dismissal ---
      confirmDismiss: (DismissDirection direction) async {
        // Show confirmation dialog
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Confirm Deletion"),
              content: Text("Are you sure you want to delete the trip to '$destination'?\n\nThis will also delete all associated catches and cannot be undone."),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // Return false if cancelled
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true), // Return true if confirmed
                  child: Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
        // Return the confirmation result (default to false if dialog is dismissed otherwise)
        return confirmed ?? false;
      },

      // --- Action after confirmed dismissal ---
      onDismissed: (DismissDirection direction) {
        // Only called if confirmDismiss returned true
        _deleteTrip(tripId); // Call the function to delete from Firestore
        // Optionally show a temporary snackbar (undo usually not feasible with backend cleanup)
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Trip deleted")));
      },

      // --- The actual trip item Card ---
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: InkWell(
          onTap: cardOnTapAction, // Use the determined onTap action
          borderRadius: BorderRadius.circular(10.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded( // Text content
                  child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(destination, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), SizedBox(height: 8.0), Text(formattedDate, style: TextStyle(fontSize: 14.0, color: Colors.grey[600])), ], ),
                ),
                SizedBox(width: 16), // Space
                AnimatedSwitcher( // Trailing widget (button/icon)
                  duration: Duration(milliseconds: 300),
                  child: Container( key: ValueKey<String>(status), child: trailingWidget ),
                ),
              ],
            ),
          ),
        ),
      ), // End Card
    ); // End Dismissible
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: (_currentUser == null)
            ? Center(child: Text("Please log in to see trips."))
            : StreamBuilder<QuerySnapshot>(
          stream: _tripsStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            // --- Loading and Error States ---
            if (snapshot.hasError) { return Center(child: Text('Error loading trips. Please try again.')); }
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) { return Center(child: CircularProgressIndicator()); }

            // --- Filter Data Client-Side ---
            List<DocumentSnapshot> filteredDocs = [];
            if (snapshot.hasData) {
              final allDocs = snapshot.data!.docs;
              if (_searchQuery.isEmpty) { filteredDocs = allDocs; } else {
                String lowerCaseQuery = _searchQuery.toLowerCase();
                filteredDocs = allDocs.where((doc) { String location = (doc.data() as Map<String, dynamic>)['tripLocation']?.toString().toLowerCase() ?? ""; return location.contains(lowerCaseQuery); }).toList();
              }
            }

            // --- Build List Content using Filtered Data ---
            List<Widget> listChildren = [];
            listChildren.add(_buildSearchBar()); // Search Bar
            listChildren.add(Divider(height: 1, thickness: 1, indent: 16, endIndent: 16));

            // Handle empty list case (AFTER filtering)
            if (filteredDocs.isEmpty && snapshot.hasData) {
              listChildren.add( Padding( padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 16.0), child: Center( child: Text( _searchQuery.isEmpty ? "No trips recorded yet. Tap '+' below to get started!" : "No trips found matching '$_searchQuery'", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600]), ), ), ) );
            } else {
              // Add trip items from FILTERED Firestore data
              // NOTE: _buildTripItem now returns a Dismissible wrapping the Card
              listChildren.addAll( filteredDocs.map((document) => _buildTripItem(document)).toList() );
            }

            // Return the ListView
            return ListView(
              padding: const EdgeInsets.only(bottom: 80.0),
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
  const AddTripFormSheet({super.key, required this.userId});
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
} // End of AddTripFormSheetState