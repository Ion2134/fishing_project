import 'dart:io'; // Required for File type
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:image_picker/image_picker.dart'; // Image picker
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore

class AddCatchPage extends StatefulWidget {
  final String userId;
  final String tripId;
  final Timestamp tripDate; // Use Timestamp for consistency
  final String tripLocation;

  const AddCatchPage({
    Key? key,
    required this.userId,
    required this.tripId,
    required this.tripDate,     // <-- Make required
    required this.tripLocation,
  }) : super(key: key);

  @override
  AddCatchPageState createState() => AddCatchPageState();
}

class AddCatchPageState extends State<AddCatchPage> {
  final _formKey = GlobalKey<FormState>();
  final _speciesController = TextEditingController();
  final _lengthController = TextEditingController();
  final _quantityController = TextEditingController(text: '1'); // Default quantity to 1

  final ImagePicker _picker = ImagePicker();
  File? _imageFile; // To hold the selected/captured image file

  bool _isLoading = false; // Loading indicator state

  @override
  void dispose() {
    _speciesController.dispose();
    _lengthController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // --- Image Picking Logic ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Optional: Compress image slightly
        maxWidth: 1000, // Optional: Resize image
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')));
    }
  }

  // --- Save Catch Logic ---
  Future<void> _saveCatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    try {
      String? imageUrl;
      String? imagePath;

      // --- 1. Upload Image (if selected) ---
      if (_imageFile != null) {
        final String fileName = '${widget.userId}_${widget.tripId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = FirebaseStorage.instance.ref().child('catch_images').child(fileName);
        final UploadTask uploadTask = storageRef.putFile(_imageFile!);
        final TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
        imagePath = snapshot.ref.fullPath;
        print("Image uploaded: $imageUrl");
      }

      // --- Get Firestore instance and Batch ---
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // --- 2. Prepare Data and References ---
      final String species = _speciesController.text.trim();
      final String speciesLowercase = species.toLowerCase(); // For document ID

      // --- Ref 1: Original Catch Document (auto-ID) ---
      final catchRef = firestore
          .collection('users')
          .doc(widget.userId)
          .collection('trips')
          .doc(widget.tripId)
          .collection('catches')
          .doc(); // Let Firestore generate the ID

      final catchData = {
        'species': species,
        'length': double.tryParse(_lengthController.text.trim()),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'imageUrl': imageUrl,
        'imagePath': imagePath,
        'caughtAt': FieldValue.serverTimestamp(),
        // We have tripDate and tripLocation from widget now, can optionally store here too
        // 'tripDate': widget.tripDate,
        // 'tripLocation': widget.tripLocation,
      };
      batch.set(catchRef, catchData); // Add original catch to batch

      // --- Ref 2: Species Summary in userFishCatalog ---
      final speciesSummaryRef = firestore
          .collection('userFishCatalog')
          .doc(widget.userId)
          .collection('caughtSpecies')
          .doc(speciesLowercase); // Use lowercase species as ID

      final speciesSummaryData = {
        'speciesDisplayName': species, // Store the original casing for display
        'lastCaught': FieldValue.serverTimestamp(), // Update last caught time
        // Only set image URL if one was uploaded for *this* catch
        if (imageUrl != null) 'representativeImageUrl': imageUrl,
        'totalCaught': FieldValue.increment(int.tryParse(_quantityController.text.trim()) ?? 1), // Increment total count
      };
      // Use merge: true to create if doesn't exist, or update existing fields
      batch.set(speciesSummaryRef, speciesSummaryData, SetOptions(merge: true));

      // --- Ref 3: Associated Trip Link in userFishCatalog ---
      final associatedTripRef = speciesSummaryRef
          .collection('associatedTrips')
          .doc(widget.tripId); // Use tripId as the doc ID here

      final tripLinkData = {
        'tripDate': widget.tripDate, // Passed from TripDetailsPage
        'tripLocation': widget.tripLocation, // Passed from TripDetailsPage
        // Optional: Can store the specific catch ID if needed for linking back
        // 'lastCatchId': catchRef.id,
        // Optional: Increment count for this species *on this trip*
        // 'catchCount': FieldValue.increment(int.tryParse(_quantityController.text.trim()) ?? 1), // Careful if overwriting
      };
      // Just set (overwrite if exists) - this ensures the link exists
      // If you add the increment above, you might need SetOptions(merge:true)
      batch.set(associatedTripRef, tripLinkData);

      // --- 3. Commit the Batch ---
      await batch.commit(); // Atomically write all changes

      print("Catch data and fish catalog updated successfully!");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Catch recorded successfully!')));
      Navigator.pop(context);

    } catch (e) {
      print("Error saving catch with batch: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving catch: ${e.toString()}')));
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record New Catch'),
      ),
      body: SingleChildScrollView( // Allow scrolling if content overflows
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons full width
            children: [
              // --- Image Selection Area ---
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Show options to pick from gallery or camera
                    showModalBottomSheet(
                      context: context,
                      builder: (BuildContext bc) {
                        return SafeArea(
                          child: Wrap(
                            children: <Widget>[
                              ListTile(
                                  leading: Icon(Icons.photo_library),
                                  title: Text('Photo Library'),
                                  onTap: () {
                                    _pickImage(ImageSource.gallery);
                                    Navigator.of(context).pop();
                                  }),
                              ListTile(
                                leading: Icon(Icons.photo_camera),
                                title: Text('Camera'),
                                onTap: () {
                                  _pickImage(ImageSource.camera);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    height: 200,
                    width: double.infinity, // Take full width
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _imageFile != null
                        ? ClipRRect( // Clip image to rounded corners
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover, // Cover the area
                      ),
                    )
                        : Column( // Placeholder content
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 50, color: Colors.grey[600]),
                        SizedBox(height: 8),
                        Text("Tap to add picture", style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // --- Species Field ---
              TextFormField(
                controller: _speciesController,
                decoration: InputDecoration(
                  labelText: 'Species',
                  hintText: 'e.g., Largemouth Bass',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phishing),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the fish species';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // --- Length Field ---
              TextFormField(
                controller: _lengthController,
                decoration: InputDecoration(
                  labelText: 'Length',
                  hintText: 'e.g., 18.5',
                  suffixText: 'inches', // Or cm, be consistent!
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true), // Allow decimals
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Allow numbers and up to 2 decimal places
                ],
                // Optional: Add validation for numeric input
                // validator: (value) { ... }
              ),
              SizedBox(height: 15),

              // --- Quantity Field ---
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity Caught',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag), // Or format_list_numbered
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [ FilteringTextInputFormatter.digitsOnly ], // Only allow whole numbers
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity (at least 1)';
                  }
                  final int? quantity = int.tryParse(value);
                  if (quantity == null || quantity < 1) {
                    return 'Please enter a valid quantity (1 or more)';
                  }
                  return null;
                },
              ),
              SizedBox(height: 30),

              // --- Save Button ---
              ElevatedButton.icon(
                icon: Icon(Icons.save_alt),
                label: Text('Save Catch'),
                onPressed: _isLoading ? null : _saveCatch, // Disable if loading
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              // Show loading indicator if saving
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}