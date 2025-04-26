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
 * Phase 1: Deletes catches and trip links.
 * Phase 2: Checks affected species and deletes them if no trips remain.
 */
exports.onTripDeleted = onDocumentDeleted("users/{userId}/trips/{tripId}", async (event) => {
  const userId = event.params.userId;
  const tripId = event.params.tripId;

  logger.log(
      `Trip deleted: userId=${userId}, tripId=${tripId}. Starting cleanup Phase 1.`,
  );

  // --- Phase 1: Delete Catches and Trip Links (Atomic Batch) ---
  const batch = db.batch();
  const affectedSpeciesIds = new Set(); // Use a Set to store unique species IDs where links were found

  // 1a. Delete Catches associated with the Trip
  const catchesRef = db.collection("users").doc(userId)
      .collection("trips").doc(tripId)
      .collection("catches");
  try {
    const catchesSnapshot = await catchesRef.get();
    if (!catchesSnapshot.empty) {
      logger.log(`Phase 1: Found ${catchesSnapshot.size} catches to delete.`);
      catchesSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref); // Add delete operation to batch
      });
    } else {
      logger.log("Phase 1: No catches found for this trip.");
    }
  } catch (error) {
    logger.error("Phase 1: Error fetching catches for deletion:", error);
    // If we can't read catches, we probably shouldn't proceed, as the catalog might become inconsistent
    return; // Stop function execution
  }

  // 1b. Delete Trip Links from userFishCatalog and record affected species
  const speciesCatalogRef = db.collection("userFishCatalog").doc(userId)
      .collection("caughtSpecies");
  try {
    const speciesSnapshot = await speciesCatalogRef.get();
    if (!speciesSnapshot.empty) {
      logger.log(
          `Phase 1: Checking ${speciesSnapshot.size} species for trip link ${tripId}.`,
      );
      // Find which species have a link to the deleted trip
      const checkLinkPromises = speciesSnapshot.docs.map(async (speciesDoc) => {
        const speciesId = speciesDoc.id; // lowercase species name
        const tripLinkRef = speciesCatalogRef.doc(speciesId)
            .collection("associatedTrips").doc(tripId);

        const tripLinkDoc = await tripLinkRef.get();
        if (tripLinkDoc.exists) {
          logger.log(
              `Phase 1: Found link for trip ${tripId} under species ${speciesId}. Adding delete to batch and marking species as affected.`,
          );
          batch.delete(tripLinkRef); // Add delete operation to batch
          affectedSpeciesIds.add(speciesId); // Record that this species needs checking later
        }
      });
      await Promise.all(checkLinkPromises); // Wait for all checks
    } else {
      logger.log("Phase 1: User has no recorded species in catalog. Skipping link deletion.");
    }
  } catch (error) {
    logger.error(
        "Phase 1: Error fetching/checking species catalog for trip links:", error,
    );
    // If we can't check the catalog, stop to avoid inconsistencies
    return;
  }

  // 1c. Commit the Batch for catches and trip links
  try {
    logger.log("Phase 1: Committing batch delete for catches and trip links...");
    await batch.commit();
    logger.log(
        `Phase 1: Successfully deleted catches and trip links for trip: ${tripId}`,
    );
  } catch (error) {
    logger.error("Phase 1: Error committing batch delete:", error);
    // If the primary deletions fail, we shouldn't proceed to Phase 2
    return;
  }

  // --- Phase 2: Check affected species and delete if empty ---
  if (affectedSpeciesIds.size === 0) {
    logger.log("Phase 2: No species were affected by trip link deletion. Cleanup complete.");
    return null; // Nothing more to do
  }

  logger.log(`Phase 2: Checking ${affectedSpeciesIds.size} affected species for remaining trips...`, Array.from(affectedSpeciesIds));

  const cleanupPromises = Array.from(affectedSpeciesIds).map(async (speciesId) => {
    const speciesDocRef = speciesCatalogRef.doc(speciesId);
    const associatedTripsRef = speciesDocRef.collection("associatedTrips");

    try {
      // Check if any associatedTrips documents remain for this species
      const remainingTripsSnapshot = await associatedTripsRef.limit(1).get();

      if (remainingTripsSnapshot.empty) {
        // If no trips remain, delete the parent species document
        logger.log(`Phase 2: Species ${speciesId} has no remaining trips. Deleting species document.`);
        await speciesDocRef.delete(); // Perform the delete
      } else {
        logger.log(`Phase 2: Species ${speciesId} still has associated trips. Keeping species document.`);
      }
    } catch (error) {
      logger.error(`Phase 2: Error checking/deleting species ${speciesId}:`, error);
      // Log error but continue checking other species
    }
  });

  // Wait for all cleanup checks/deletions to finish
  try {
    await Promise.all(cleanupPromises);
    logger.log("Phase 2: Finished checking/cleaning up affected species.");
  } catch (error) {
    // This catch block might not be strictly necessary if individual errors are caught above,
    // but added for extra safety.
    logger.error("Phase 2: Unexpected error during Promise.all for species cleanup:", error);
  }

  return null; // Indicate successful completion of the function flow
}); // End of onTripDeleted function
