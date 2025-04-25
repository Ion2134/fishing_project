/* eslint-disable max-len */
// functions/index.js

// Import the necessary modules
const {onDocumentDeleted} = require("firebase-functions/v2/firestore"); // Use v2 trigger syntax
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger"); // Use the newer logger

// Initialize the Admin SDK
initializeApp();
const db = getFirestore(); // Get Firestore instance

/**
 * Cloud Function triggered when a trip document is deleted.
 * Cleans up associated catches and userFishCatalog entries.
 */
exports.onTripDeleted = onDocumentDeleted("users/{userId}/trips/{tripId}", async (event) => {
  // event.params contains the wildcards
  const userId = event.params.userId;
  const tripId = event.params.tripId;

  // event.data contains the snapshot *before* deletion if needed, but we just need IDs here.

  logger.log(
      `Trip deleted: userId=${userId}, tripId=${tripId}. Starting cleanup.`,
  );

  // Create a Firestore batch write operation for atomicity
  const batch = db.batch();

  // --- 1. Delete Catches associated with the Trip ---
  const catchesRef = db.collection("users").doc(userId)
      .collection("trips").doc(tripId)
      .collection("catches");

  try {
    const catchesSnapshot = await catchesRef.get();
    if (!catchesSnapshot.empty) {
      logger.log(`Found ${catchesSnapshot.size} catches to delete.`);
      catchesSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref); // Add delete operation to batch
      });
    } else {
      logger.log("No catches found for this trip.");
    }
  } catch (error) {
    logger.error("Error fetching catches for deletion:", error);
    return; // Stop function execution on error fetching catches
  }

  // --- 2. Delete Trip Links from userFishCatalog ---
  const speciesCatalogRef = db.collection("userFishCatalog").doc(userId)
      .collection("caughtSpecies");

  try {
    // Get all species recorded by the user
    const speciesSnapshot = await speciesCatalogRef.get();

    if (!speciesSnapshot.empty) {
      logger.log(
          `Checking ${speciesSnapshot.size} species for trip link.`,
      );
      // Use Promise.all to query trip links for all species concurrently
      const deleteLinkPromises = speciesSnapshot.docs.map(async (speciesDoc) => {
        const speciesId = speciesDoc.id; // lowercase species name
        const tripLinkRef = speciesCatalogRef.doc(speciesId)
            .collection("associatedTrips").doc(tripId);

        // Check if the link exists before adding delete to batch
        const tripLinkDoc = await tripLinkRef.get();
        if (tripLinkDoc.exists) {
          logger.log(
              `Found link for trip ${tripId} under species ${speciesId}. Adding delete to batch.`,
          );
          batch.delete(tripLinkRef); // Add delete operation to batch
        }
      });
      // Wait for all link checks to complete
      await Promise.all(deleteLinkPromises);
    } else {
      logger.log("User has no recorded species in catalog.");
    }
  } catch (error) {
    logger.error(
        "Error fetching/checking species catalog for deletion:", error,
    );
    return; // Stop function execution on error with catalog
  }

  // --- 3. Commit the Batch ---
  try {
    logger.log("Committing batch operations...");
    await batch.commit();
    logger.log(
        `Successfully cleaned up data for deleted trip: ${tripId}`,
    );
    return null; // Indicate successful execution
  } catch (error) {
    logger.error("Error committing batch delete:", error);
    return null; // Or throw error if needed
  }
}); // End of onTripDeleted function
