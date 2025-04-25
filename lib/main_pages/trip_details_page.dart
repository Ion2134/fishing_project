import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// removed firebase_auth import
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Import for better image handling

// Import the page for adding catches (should already be there)
import 'add_catch_page.dart';

// --- _StickyTripActionButtonHeader Class (Keep as is) ---
class _StickyTripActionButtonHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final VoidCallback onCompletePressed;
  final bool isCompleting;

  _StickyTripActionButtonHeader({required this.height, required this.onCompletePressed, required this.isCompleting});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container( /* ... same build method ... */
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Icons.check_circle_outline),
            onPressed: isCompleting ? null : onCompletePressed,
            label: isCompleting ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text("Mark Trip as Completed?"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 10.0), disabledBackgroundColor: Colors.orangeAccent.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
  @override double get maxExtent => height;
  @override double get minExtent => height;
  @override bool shouldRebuild(covariant _StickyTripActionButtonHeader oldDelegate) {
    return height != oldDelegate.height || onCompletePressed != oldDelegate.onCompletePressed || isCompleting != oldDelegate.isCompleting;
  }
}

// --- TripDetailsPage Widget (Keep StatefulWidget and State class structure) ---
class TripDetailsPage extends StatefulWidget {
  final String userId;
  final String tripId;
  const TripDetailsPage({Key? key, required this.userId, required this.tripId}) : super(key: key);
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

  // // --- _recordCatch Function (Keep as is, navigates to AddCatchPage) ---
  // void _recordCatch() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) =>
  //           AddCatchPage(
  //             userId: widget.userId,
  //             tripId: widget.tripId,
  //           ),
  //     ),
  //   );
  //   print("Navigating to AddCatchPage for Trip ID: ${widget.tripId}");
  // }

  // --- _promptAndCompleteTrip Function (Keep as is) ---
  Future<void> _promptAndCompleteTrip() async {
    /* ... same implementation ... */
    if (_isCompleting) return;
    final reviewController = TextEditingController();
    final result = await showDialog<String?>(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
        /* ... AlertDialog setup ... */
        return AlertDialog(
          title: Text("Complete Trip"),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Would you like to add a review? (Optional)"),
              SizedBox(height: 15),
              TextField(controller: reviewController,
                  maxLines: 3,
                  decoration: InputDecoration(
                      hintText: "Enter your review here...",
                      border: OutlineInputBorder())),
            ],),),
          actions: <Widget>[
            TextButton(child: Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(null)),
            TextButton(child: Text("Skip Review & Complete"),
                onPressed: () => Navigator.of(context).pop('')),
            ElevatedButton(child: Text("Save Review & Complete"),
                onPressed: () =>
                    Navigator.of(context).pop(reviewController.text))
          ],
        );
      },
    );
    if (!mounted) return;
    if (result != null) {
      _performCompletion(result.isEmpty ? null : result);
    }
    reviewController.dispose();
  }

  // --- _performCompletion Function (Keep as is) ---
  Future<void> _performCompletion(String? reviewText) async {
    /* ... same implementation ... */
    if (_isCompleting) return;
    setState(() {
      _isCompleting = true;
    });
    try {
      final Map<String, dynamic> updateData = {'status': 'Completed'};
      if (reviewText != null && reviewText
          .trim()
          .isNotEmpty) {
        updateData['review'] = reviewText.trim();
      }
      await _tripDocRef.update(updateData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Trip marked as completed!'),
          duration: Duration(seconds: 2)));
      Navigator.pop(context);
    } catch (e) {
      print("Error completing trip ${widget.tripId}: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error completing trip: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  // --- Helper Widget to Build Each Catch List Item ---
  Widget _buildCatchListItem(DocumentSnapshot catchDoc) {
    Map<String, dynamic> data = catchDoc.data() as Map<String, dynamic>;
    bool isPending = catchDoc.metadata.hasPendingWrites;

    String species = data['species'] ?? 'Unknown Species';
    int quantity = data['quantity'] ?? 1;
    double? length = data['length']; // Length might be null
    String imageUrl = data['imageUrl'] ?? ''; // Image URL might be empty/null

    String subtitle = "Quantity: $quantity";
    if (length != null) {
      subtitle += " | Length: $length inches"; // Adjust unit as needed
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ListTile(
        // --- Leading Image ---
        leading: Container(
          width: 60,
          height: 60, // Constrain image size
          decoration: BoxDecoration(
              color: Colors.grey[200], // Background if no image
              borderRadius: BorderRadius.circular(8)
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: CachedNetworkImage( // Use CachedNetworkImage
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Center(child: SizedBox(width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (context, url, error) =>
                  Icon(Icons.broken_image, color: Colors.grey),
            ),
          )
              : Icon(Icons.image_not_supported,
              color: Colors.grey), // Placeholder if no image URL
        ),

        // --- Title & Subtitle ---
        title: Text(species, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        // Adjust padding

        // --- Trailing Pending Indicator ---
        trailing: isPending
            ? Tooltip(
          message: 'Saving...',
          child: Icon(Icons.sync_outlined, size: 18, color: Colors.grey),
        )
            : null,
        // No indicator if synced

        // TODO: Add onTap for future actions like editing or deleting a catch
        onTap: () {
          print("Tapped on catch: ${catchDoc.id}");
          // Potential future navigation to edit catch details
        },
        tileColor: isPending
            ? Colors.grey.shade50
            : null, // Optional: Highlight pending items
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Details'),
      ),
      body: SafeArea(
        // The main StreamBuilder for trip details - builds the body content
        child: StreamBuilder<DocumentSnapshot>(
          stream: _tripDocRef.snapshots(),
          builder: (context,
              tripSnapshot) { // tripSnapshot contains the trip data

            // --- Trip Details Loading/Error/NotFound Handling ---
            if (tripSnapshot.connectionState == ConnectionState.waiting) {
              // Show loading indicator for the main body content
              return Center(child: CircularProgressIndicator());
            }
            if (tripSnapshot.hasError) {
              return Center(child: Text("Error loading trip details."));
            }
            if (!tripSnapshot.hasData || !tripSnapshot.data!.exists) {
              return Center(child: Text("Trip not found."));
            }

            // --- Extract Trip Data (Available in *this* scope for building the body) ---
            Map<String, dynamic> tripData = tripSnapshot.data!.data() as Map<
                String,
                dynamic>;
            String location = tripData['tripLocation'] ?? 'No Location';
            DateTime? tripDateForDisplay; // Renamed to avoid confusion with FAB's date
            if (tripData['tripDate'] is Timestamp) {
              tripDateForDisplay = (tripData['tripDate'] as Timestamp).toDate();
            }
            String formattedDate = tripDateForDisplay != null ? DateFormat
                .yMMMEd().format(tripDateForDisplay) : 'No Date';
            String status = tripData['status'] ?? 'Unknown';
            bool isAlreadyCompleted = status.toLowerCase() == 'completed';
            String? review = tripData['review'] as String?; // Get review if exists

            // --- Build UI with CustomScrollView ---
            // This CustomScrollView is returned as the body of the Scaffold
            return CustomScrollView(
              slivers: <Widget>[
                // --- 1. Static Header Info ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location, style: Theme
                            .of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8.0),
                        Row(children: [
                          Icon(Icons.calendar_today_outlined, size: 16,
                              color: Colors.grey[600]),
                          SizedBox(width: 8.0),
                          Text(formattedDate, style: Theme
                              .of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey[700])),
                        ]),
                        Divider(height: 20, thickness: 1),
                      ],
                    ),
                  ),
                ),

                // --- 2. Sticky Complete Button (Conditional) ---
                if (!isAlreadyCompleted)
                  SliverPersistentHeader(
                    delegate: _StickyTripActionButtonHeader(
                      height: 60.0,
                      onCompletePressed: _promptAndCompleteTrip,
                      // Uses state method
                      isCompleting: _isCompleting, // Uses state variable
                    ),
                    pinned: true,
                  ),

                // --- Optional: Show Review if Completed ---
                if (isAlreadyCompleted && review != null && review
                    .trim()
                    .isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Your Review:", style: Theme
                              .of(context)
                              .textTheme
                              .titleMedium),
                          SizedBox(height: 4),
                          Text(review, style: Theme
                              .of(context)
                              .textTheme
                              .bodyMedium),
                          Divider(height: 20, thickness: 1),
                        ],
                      ),
                    ),
                  ),

                // --- Section Header for Catches ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Text(
                      "Catches Recorded:",
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                // --- 3. Scrollable Catch List Area (StreamBuilder + SliverList) ---
                StreamBuilder<QuerySnapshot>(
                  stream: _tripDocRef.collection('catches').orderBy(
                      'caughtAt', descending: true).snapshots(),
                  builder: (context, catchSnapshot) {
                    // Handle catches loading/error/empty states within this builder
                    if (catchSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return SliverToBoxAdapter(
                          child: Padding(padding: const EdgeInsets.symmetric(
                              vertical: 20.0), child: Center(child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3)))));
                    }
                    if (catchSnapshot.hasError) {
                      return SliverToBoxAdapter(
                          child: Padding(padding: const EdgeInsets.all(16.0),
                              child: Center(child: Text(
                                  "Error loading catches.",
                                  style: TextStyle(color: Colors.red)))));
                    }
                    if (!catchSnapshot.hasData ||
                        catchSnapshot.data!.docs.isEmpty) {
                      return SliverToBoxAdapter(
                          child: Padding(padding: const EdgeInsets.symmetric(
                              vertical: 40.0, horizontal: 16.0), child: Center(
                              child: Text(
                                  "No catches recorded for this trip yet.\nTap 'Record a Catch' below to add one!",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 16),
                                  textAlign: TextAlign.center))));
                    }

                    // Build the list of catches if data exists
                    final catches = catchSnapshot.data!.docs;
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                          return _buildCatchListItem(
                              catches[index]); // Use helper method
                        },
                        childCount: catches.length,
                      ),
                    );
                  }, // End of StreamBuilder<QuerySnapshot> builder (for catches)
                ),
                // End of StreamBuilder<QuerySnapshot> (for catches)

                // Add bottom padding inside scroll view to avoid overlap with FAB
                SliverPadding(padding: EdgeInsets.only(bottom: 80)),

              ], // End of slivers list
            ); // End of CustomScrollView
          }, // End of StreamBuilder<DocumentSnapshot> builder (for trip details)
        ), // End of StreamBuilder<DocumentSnapshot> (for trip details)
      ),
      // End of SafeArea

      // --- Bottom Sticky Button ("Record a Catch") ---
      // Wrap the FAB in its own StreamBuilder to access trip data for navigation
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
          stream: _tripDocRef.snapshots(),
          // Listen to the *same* trip document stream
          builder: (context, fabTripSnapshot) {
            // Handle loading/error states JUST FOR THE FAB's data needs
            if (!fabTripSnapshot.hasData || !fabTripSnapshot.data!.exists) {
              // Return a disabled FAB if trip data isn't ready yet
              return FloatingActionButton.extended(
                onPressed: null, // Disabled
                label: Text("Record a Catch"),
                icon: Icon(Icons.add_photo_alternate_outlined),
                backgroundColor: Colors.grey, // Indicate disabled state
              );
            }

            // Extract data needed for navigation *inside this builder's scope*
            final fabTripData = fabTripSnapshot.data!.data() as Map<
                String,
                dynamic>;
            // Provide sensible defaults if data is missing (although it should exist if we got here)
            final Timestamp currentTripDate = fabTripData['tripDate'] as Timestamp? ??
                Timestamp.now();
            final String currentTripLocation = fabTripData['tripLocation'] as String? ??
                'Unknown Location';

            // Now build the actual FAB with the onPressed callback using the extracted data
            return FloatingActionButton.extended(
              // Access the _isCompleting state variable from the main State class
              onPressed: _isCompleting ? null : () {
                // Use the data extracted just above for navigation
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddCatchPage(
                          userId: widget.userId, // From widget properties
                          tripId: widget.tripId, // From widget properties
                          tripDate: currentTripDate, // Pass the extracted date
                          tripLocation: currentTripLocation, // Pass the extracted location
                        ),
                  ),
                );
                print(
                    "Navigating to AddCatchPage for Trip ID: ${widget.tripId}");
              },
              label: Text("Record a Catch"),
              icon: Icon(Icons.add_photo_alternate_outlined),
              // Dim the button if completing the trip
              backgroundColor: _isCompleting ? Colors.grey : null,
            );
          } // End of StreamBuilder builder (for FAB)
      ),
      // End of StreamBuilder (for FAB)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    ); // End of Scaffold
  } // End of build method
}