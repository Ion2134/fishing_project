import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'add_catch_page.dart';

// --- _StickyTripActionButtonHeader Class (Keep as is) ---
class _StickyTripActionButtonHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final VoidCallback onCompletePressed;
  final bool isCompleting;
  _StickyTripActionButtonHeader({required this.height, required this.onCompletePressed, required this.isCompleting});
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) { return Container( color: Theme.of(context).scaffoldBackgroundColor, alignment: Alignment.center, child: Padding( padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), child: SizedBox( width: double.infinity, child: ElevatedButton.icon( icon: Icon(Icons.check_circle_outline), onPressed: isCompleting ? null : onCompletePressed, label: isCompleting ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text("Mark Trip as Completed?"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 10.0), disabledBackgroundColor: Colors.orangeAccent.withOpacity(0.5)), ), ), ), ); }
  @override double get maxExtent => height;
  @override double get minExtent => height;
  @override bool shouldRebuild(covariant _StickyTripActionButtonHeader oldDelegate) { return height != oldDelegate.height || onCompletePressed != oldDelegate.onCompletePressed || isCompleting != oldDelegate.isCompleting; }
}


// --- TripDetailsPage Widget ---
class TripDetailsPage extends StatefulWidget {
  final String userId;
  final String tripId;
  const TripDetailsPage({super.key, required this.userId, required this.tripId});
  @override
  TripDetailsPageState createState() => TripDetailsPageState();
}

class TripDetailsPageState extends State<TripDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DocumentReference _tripDocRef;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _tripDocRef = _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('trips')
        .doc(widget.tripId);
  }

  // --- _promptAndCompleteTrip Function (Keep as is) ---
  Future<void> _promptAndCompleteTrip() async {
    if (_isCompleting) { print("Completion already in progress..."); return; }
    print("Showing complete trip dialog...");
    final reviewController = TextEditingController();
    String? result;
    try {
      result = await showDialog<String?>( context: context, barrierDismissible: false, builder: (BuildContext dialogContext) { return AlertDialog( title: Text("Complete Trip"), content: SingleChildScrollView(child: Column( mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("Would you like to add a review? (Optional)"), SizedBox(height: 15), TextField(controller: reviewController, maxLines: 3, decoration: InputDecoration(hintText: "Enter your review here...", border: OutlineInputBorder())), ], ), ), actions: <Widget>[ TextButton( child: Text("Cancel"), onPressed: () => Navigator.of(dialogContext).pop(null), ), TextButton( child: Text("Skip Review & Complete"), onPressed: () => Navigator.of(dialogContext).pop(''), ), ElevatedButton( child: Text("Save Review & Complete"), onPressed: () => Navigator.of(dialogContext).pop(reviewController.text), ), ], ); }, );
    } finally {
      print("Disposing review controller (in finally block)");
      reviewController.dispose();
    }
    if (!mounted) { print("Dialog closed but page is no longer mounted."); return; }
    print("Dialog closed with result: $result");
    if (result != null) { print("Proceeding with trip completion..."); await _performCompletion(result.isEmpty ? null : result); }
    else { print("Completion cancelled by user."); if (_isCompleting) { print("Warning: _isCompleting was true after cancel, resetting."); setState(() { _isCompleting = false; }); } }
  }


  // --- _performCompletion Function (Keep as is) ---
  Future<void> _performCompletion(String? reviewText) async {
    if (_isCompleting || !mounted) return;
    setState(() { _isCompleting = true; });
    print("Setting _isCompleting = true");
    try {
      final Map<String, dynamic> updateData = {'status': 'Completed'};
      if (reviewText != null && reviewText.trim().isNotEmpty) { updateData['review'] = reviewText.trim(); }
      await _tripDocRef.update(updateData);
      if (!mounted) return;
      print("Trip marked as completed successfully.");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Trip marked as completed!'), duration: Duration(seconds: 2)));
      Navigator.pop(context);
    } catch (e) {
      print("Error completing trip ${widget.tripId}: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error completing trip: ${e.toString()}'))); }
    } finally {
      if (mounted) { print("Setting _isCompleting = false in finally block"); setState(() { _isCompleting = false; }); }
      else { print("_performCompletion finished but widget not mounted. Skipping final setState."); }
    }
  }

  // --- Helper Widget _buildCatchListItem (with Logging) ---
  Widget _buildCatchListItem(DocumentSnapshot catchDoc) {
    // --- ADDED LOGGING ---
    print("Building catch list item for ID: ${catchDoc.id}");
    // --- END LOGGING ---

    Map<String, dynamic> data = {}; // Initialize empty map
    try {
      data = catchDoc.data() as Map<String, dynamic>? ?? {};
      print("  Data for ${catchDoc.id}: $data"); // Log the extracted data
    } catch (e) {
      print("Error casting data for catch ${catchDoc.id}: $e");
      return Container( padding: EdgeInsets.all(16), margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0), color: Colors.red.shade100, child: Text("Error loading data for this catch."), );
    }

    bool isPending = catchDoc.metadata.hasPendingWrites;
    String species = data['species'] ?? 'Unknown Species';
    int quantity = data['quantity'] ?? 1;
    double? length = data['length'] is num ? (data['length'] as num).toDouble() : null;
    String imageUrl = data['imageUrl'] ?? '';

    // --- ADDED LOGGING ---
    print("  Parsed -> Species: $species, Length: $length, ImageURL: '$imageUrl', Pending: $isPending");
    // --- END LOGGING ---

    String subtitle = "Quantity: $quantity";
    if (length != null) {
      subtitle += " | Length: $length inches";
    }

    try { // Wrap widget build
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: ListTile(
          leading: Container(
            width: 60, height: 60, decoration: BoxDecoration( color: Colors.grey[200], borderRadius: BorderRadius.circular(8) ),
            child: imageUrl.isNotEmpty ? ClipRRect( borderRadius: BorderRadius.circular(8.0), child: CachedNetworkImage( imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (context, url, error) => Icon(Icons.broken_image, color: Colors.grey), ), ) : Icon(Icons.image_not_supported, color: Colors.grey),
          ),
          title: Text(species, style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle),
          contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          trailing: isPending ? Tooltip( message: 'Saving...', child: Icon(Icons.sync_outlined, size: 18, color: Colors.grey), ) : null,
          onTap: () { print("Tapped on catch: ${catchDoc.id}"); },
          tileColor: isPending ? Colors.grey.shade50 : null,
        ),
      );
    } catch(e, stackTrace) {
      print("!!! Error building ListTile/Card for catch ${catchDoc.id}: $e");
      print(stackTrace);
      return Container( padding: EdgeInsets.all(16), margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0), color: Colors.orange.shade100, child: Text("Error displaying this catch item."), );
    }
  } // End _buildCatchListItem


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( title: Text('Trip Details'), ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _tripDocRef.snapshots(),
          builder: (context, tripSnapshot) {
            if (tripSnapshot.connectionState == ConnectionState.waiting) { return Center(child: CircularProgressIndicator()); }
            if (tripSnapshot.hasError) { return Center(child: Text("Error loading trip details.")); }
            if (!tripSnapshot.hasData || !tripSnapshot.data!.exists) { return Center(child: Text("Trip not found.")); }
            Map<String, dynamic> tripData = tripSnapshot.data!.data() as Map<String, dynamic>; String location = tripData['tripLocation'] ?? 'No Location'; DateTime? tripDateForDisplay; if (tripData['tripDate'] is Timestamp) { tripDateForDisplay = (tripData['tripDate'] as Timestamp).toDate(); } String formattedDate = tripDateForDisplay != null ? DateFormat.yMMMEd().format(tripDateForDisplay) : 'No Date'; String status = tripData['status'] ?? 'Unknown'; bool isAlreadyCompleted = status.toLowerCase() == 'completed'; String? review = tripData['review'] as String?;

            return CustomScrollView(
              slivers: <Widget>[
                // --- 1. Static Header Info ---
                SliverToBoxAdapter( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(location, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), SizedBox(height: 8.0), Row(children: [ Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[600]), SizedBox(width: 8.0), Text(formattedDate, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700])), ]), Divider(height: 20, thickness: 1), ], ), ), ),
                // --- 2. Sticky Complete Button (Conditional) ---
                if (!isAlreadyCompleted) SliverPersistentHeader( delegate: _StickyTripActionButtonHeader( height: 60.0, onCompletePressed: _promptAndCompleteTrip, isCompleting: _isCompleting, ), pinned: true, ),
                // --- Optional: Show Review ---
                if (isAlreadyCompleted && review != null && review.trim().isNotEmpty) SliverToBoxAdapter( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("Your Review:", style: Theme.of(context).textTheme.titleMedium), SizedBox(height: 4), Text(review, style: Theme.of(context).textTheme.bodyMedium), Divider(height: 20, thickness: 1), ], ), ), ),
                // --- Section Header for Catches ---
                SliverToBoxAdapter( child: Padding( padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), child: Text( "Catches Recorded:", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600), ), ), ),

                // --- 3. Catch List StreamBuilder (with Logging) ---
                StreamBuilder<QuerySnapshot>(
                  stream: _tripDocRef.collection('catches').orderBy('caughtAt', descending: true).snapshots(),
                  builder: (context, catchSnapshot) {
                    // --- ADDED LOGGING ---
                    print("Catch StreamBuilder received new snapshot. HasError: ${catchSnapshot.hasError}, HasData: ${catchSnapshot.hasData}, ConnectionState: ${catchSnapshot.connectionState}");
                    // --- END LOGGING ---

                    if (catchSnapshot.connectionState == ConnectionState.waiting) { return SliverToBoxAdapter( child: Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))))); }
                    if (catchSnapshot.hasError) { print("!!! Catch StreamBuilder Error: ${catchSnapshot.error}"); return SliverToBoxAdapter( child: Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text("Error loading catches.", style: TextStyle(color: Colors.red))))); }
                    if (!catchSnapshot.hasData || catchSnapshot.data!.docs.isEmpty) { print("Catch StreamBuilder: No documents found."); return SliverToBoxAdapter( child: Padding(padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0), child: Center( child: Text( "No catches recorded for this trip yet.\nTap 'Record a Catch' below to add one!", style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center)))); }

                    final catches = catchSnapshot.data!.docs;
                    // --- ADDED LOGGING ---
                    print("Catch StreamBuilder: Found ${catches.length} documents. Building SliverList...");
                    // --- END LOGGING ---

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                          // --- ADDED LOGGING ---
                          print("  -> Building item for index $index, Doc ID: ${catches[index].id}");
                          // --- END LOGGING ---
                          try { // Wrap item build
                            return _buildCatchListItem(catches[index]);
                          } catch(e, stackTrace) {
                            print("!!! Error building item at index $index (ID: ${catches[index].id}): $e");
                            print(stackTrace);
                            return Container(color: Colors.purple.shade100, padding: EdgeInsets.all(16), child: Text("Error displaying catch item $index."));
                          }
                        },
                        childCount: catches.length,
                      ),
                    );
                  },
                ),

                // --- Bottom Padding ---
                SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            );
          },
        ),
      ),
      // --- FAB (Keep wrapped in StreamBuilder as before) ---
      floatingActionButton: StreamBuilder<DocumentSnapshot>( stream: _tripDocRef.snapshots(), builder: (context, fabTripSnapshot) { if (!fabTripSnapshot.hasData || !fabTripSnapshot.data!.exists) { return FloatingActionButton.extended( onPressed: null, label: Text("Record a Catch"), icon: Icon(Icons.add_photo_alternate_outlined), backgroundColor: Colors.grey, ); } final fabTripData = fabTripSnapshot.data!.data() as Map<String, dynamic>; final Timestamp currentTripDate = fabTripData['tripDate'] as Timestamp? ?? Timestamp.now(); final String currentTripLocation = fabTripData['tripLocation'] as String? ?? 'Unknown Location'; return FloatingActionButton.extended( onPressed: _isCompleting ? null : () { Navigator.push( context, MaterialPageRoute( builder: (context) => AddCatchPage( userId: widget.userId, tripId: widget.tripId, tripDate: currentTripDate, tripLocation: currentTripLocation, ), ), ); print("Navigating to AddCatchPage for Trip ID: ${widget.tripId}"); }, label: Text("Record a Catch"), icon: Icon(Icons.add_photo_alternate_outlined), backgroundColor: _isCompleting ? Colors.grey : null, ); } ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}