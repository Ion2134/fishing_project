# Fishing Log App

A Flutter application designed for anglers to log fishing trips, record catches with details and photos, track species caught across different trips, and get AI-powered information about fish species. This app uses Firebase for backend services including authentication, Firestore database, and Storage.

## Features

*   **User Authentication:** Secure email/password login and registration.
*   **Trip Logging:** Record trip location and date. Manage trip status.
*   **Catch Recording:** Log individual fish catches with species, length, quantity, and photos.
*   **Offline Support:** Basic offline capability for viewing data and logging catches/trips (syncs when back online).
*   **Fish Catalog:** Automatically generated list of unique species caught by the user.
*   **Species Details:** View trips where a specific species was caught.
*   **FishAI Chatbot:** Get facts and ask questions about specific fish species via an integrated chatbot.
*   **Data Management:** Swipe-to-delete trips (with confirmation), manage account email and password.

## Prerequisites

Before you begin, ensure you have the following installed on your system:

1.  **Flutter SDK:** Follow the official Flutter installation guide: [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
2.  **Git:** For cloning the repository.
3.  **An Android Device or Emulator:** To run the application. Ensure USB Debugging is enabled on your physical device if using one.
4.  **An IDE:** Visual Studio Code (with Flutter extension) or Android Studio is recommended.

## Setup Instructions

Follow these steps to get the app running on your local Android device:

1.  **Clone the Repository:**
    Open your terminal or command prompt and run:
    ```bash
    git clone https://github.com/Ion2134/fishing_project.git
    cd fishing_project
    ```

<!-- 2.  **Firebase Configuration (IMPORTANT!)**

    This application requires configuration files to connect to the specific Firebase project backend used for development. **These files are NOT included in the public repository for security reasons.** You must obtain them from the project owner ([Your Name/Contact Info]).

    *   **`google-services.json` (for Android):**
        *   Obtain this file from the project owner.
        *   Place this file inside the `android/app/` directory within the cloned project. The path should look like: `[your-repo-directory-name]/android/app/google-services.json`.

    *   **`firebase_options.dart` (for Flutter):**
        *   Obtain this file from the project owner.
        *   Place this file inside the `lib/` directory within the cloned project. The path should look like: `[your-repo-directory-name]/lib/firebase_options.dart`.
        *   Verify that your `lib/main.dart` file imports and uses these options during Firebase initialization, like this:
            ```dart
            // lib/main.dart (near the top)
            import 'firebase_options.dart';
            // ... other imports

            void main() async {
              WidgetsFlutterBinding.ensureInitialized();
              await Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform, // Ensure this line uses the import
              );
              runApp(MyApp());
            }
            ```

    **⚠️ Security Warning:** Never commit `google-services.json` or `firebase_options.dart` files containing production or sensitive keys to a public Git repository. -->

3.  **Install Dependencies:**
    Open your terminal *in the root directory* of the cloned project (`[your-repo-directory-name]`) and run:
    ```bash
    flutter pub get
    ```
    This will download all the necessary packages defined in `pubspec.yaml`.

## Running the App

1.  **Connect an Android Device:**
    *   Ensure your Android device is connected to your computer via USB.
    *   Enable **Developer Options** and **USB Debugging** on your device.
    *   Authorize the connection on your device when prompted.
    *   **(OR)** Start an Android Emulator via Android Studio.

2.  **Verify Device Connection:**
    In your terminal (in the project root), run:
    ```bash
    flutter devices
    ```
    You should see your connected device or running emulator listed.

3.  **Run the App:**
    In your terminal (in the project root), run:
    ```bash
    flutter run
    ```
    Flutter will build the app and install it on your connected device/emulator. The first build might take a few minutes.

## Notes & Potential Issues

*   **Firebase Backend:** This setup uses my existing Firebase project. You will be reading/writing data to that project. Please use it responsibly for testing purposes. 
*   **FishAI:** The FishAI chatbot feature currently connects to a temporary URL provided by Ngrok. This URL will only work if I am manually set the transformer to run, as I do not have the paid version. The transformer runs from a google colab notebook.
*   **`flutter doctor`:** If you encounter build or run issues, run `flutter doctor -v` in your terminal to diagnose potential problems with your Flutter installation or Android setup.
*   **Clean Build:** Sometimes, cleaning the build cache can resolve issues. Run `flutter clean` and then `flutter pub get` again before trying `flutter run`.
