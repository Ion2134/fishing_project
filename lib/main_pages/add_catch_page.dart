import 'dart:io'; // Required for File type
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:image_picker/image_picker.dart'; // Image picker
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore

class AddCatchPage extends StatefulWidget {
  final String userId;
  final String tripId;

  const AddCatchPage({
    Key? key,
    required this.userId,
    required this.tripId,
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
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Optional: Check if an image was selected (make it mandatory?)
    // if (_imageFile == null) {
    //    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select an image.')));
    //    return;
    // }

    setState(() { _isLoading = true; });

    try {
      String? imageUrl;
      String? imagePath;

      // --- 1. Upload Image to Firebase Storage (if selected) ---
      if (_imageFile != null) {
        // Create a unique file path
        final String fileName = '${widget.userId}_${widget.tripId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('catch_images') // Optional: Subfolder for organization
            .child(fileName);

        // Upload the file
        final UploadTask uploadTask = storageRef.putFile(_imageFile!);

        // Wait for upload completion
        final TaskSnapshot snapshot = await uploadTask;

        // Get download URL
        imageUrl = await snapshot.ref.getDownloadURL();
        imagePath = snapshot.ref.fullPath; // Store path for potential future deletion
        print("Image uploaded: $imageUrl");
      }

      // --- 2. Prepare Catch Data for Firestore ---
      final catchData = {
        'species': _speciesController.text.trim(),
        'length': double.tryParse(_lengthController.text.trim()), // Store as number
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1, // Store as number, default 1
        'imageUrl': imageUrl, // Can be null if no image was selected
        'imagePath': imagePath, // Can be null
        'caughtAt': FieldValue.serverTimestamp(), // Timestamp of logging
        // Consider adding userId and tripId here IF your security rules need them,
        // but often they are implicitly known via the path.
        // 'userId': widget.userId,
        // 'tripId': widget.tripId,
      };

      // --- 3. Add Catch Data to Firestore Subcollection ---
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('trips')
          .doc(widget.tripId)
          .collection('catches') // The subcollection for catches
          .add(catchData);

      print("Catch data saved successfully!");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catch recorded successfully!')));
      Navigator.pop(context); // Go back to TripDetailsPage

    } catch (e) {
      print("Error saving catch: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving catch: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
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