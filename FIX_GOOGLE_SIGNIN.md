# Fix Google Sign-In ApiException: 10 Error

## Problem
You're getting `ApiException: 10` (DEVELOPER_ERROR) when trying to sign in with Google.

## Solution: Add SHA-1 Fingerprints to Firebase Console

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com/
2. Select your project: **kasbill-19baf**

### Step 2: Add SHA-1 Fingerprints
1. Click the **⚙️ gear icon** (Project Settings) in the top left
2. Scroll down to **Your apps** section
3. Find your Android app: **com.kasbills.kasbill**
4. Click **Add fingerprint** button
5. Add these **TWO** SHA-1 fingerprints:

   **Debug SHA-1:**
   ```
   0B:69:29:E5:26:BF:6C:3E:48:55:43:6C:F8:7A:11:0C:50:83:1A:7A
   ```

   **Release SHA-1:**
   ```
   10:CB:5C:A6:4D:BA:87:DB:E9:96:D9:21:3F:E1:48:7C:DB:CE:BC:EC
   ```

### Step 3: Download Updated google-services.json
1. After adding the fingerprints, click **Download google-services.json**
2. Replace the file at: `android/app/google-services.json`

### Step 4: Verify Google Sign-In is Enabled
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Make sure **Google** is enabled
3. If not, click **Google** and enable it

### Step 5: Rebuild Your App
```bash
flutter clean
flutter pub get
flutter run
```

## Additional Check: Web Client ID (if still not working)

If the error persists after adding SHA-1 fingerprints:

1. Go to Firebase Console → **Project Settings** → **General** tab
2. Scroll to **Your apps** → Find or create a **Web app**
3. Copy the **Web client ID** (looks like: `xxxxx-xxxxx.apps.googleusercontent.com`)
4. Update `lib/auth/signup_page.dart` line 27-30:
   ```dart
   final GoogleSignIn _googleSignIn = GoogleSignIn(
     scopes: ['email', 'profile'],
     serverClientId: 'YOUR_WEB_CLIENT_ID_HERE', // Add the Web client ID
   );
   ```

## Current Configuration
- **Package Name:** com.kasbills.kasbill
- **Project ID:** kasbill-19baf
- **Project Number:** 174995240247

## After Fixing
The error message in the app will automatically update to show helpful information if this error occurs again.
