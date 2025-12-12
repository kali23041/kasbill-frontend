# How to Find Your Web Client ID

## Method 1: Google Cloud Console (Recommended)

1. **Go to Google Cloud Console:**
   - Open: https://console.cloud.google.com/
   - Make sure you're in the correct project: **kasbill-19baf** (Project Number: 174995240247)

2. **Navigate to Credentials:**
   - In the left sidebar, click **APIs & Services** → **Credentials**

3. **Find OAuth 2.0 Client IDs:**
   - Scroll down to the **OAuth 2.0 Client IDs** section
   - Look for an entry with type **"Web application"** or **"Web client"**
   - The Client ID will look like: `xxxxx-xxxxx.apps.googleusercontent.com`

4. **If you don't see a Web client:**
   - Click **+ CREATE CREDENTIALS** → **OAuth client ID**
   - Application type: **Web application**
   - Name it (e.g., "Web Client for Google Sign-In")
   - Click **CREATE**
   - Copy the **Client ID**

## Method 2: Firebase Console (Alternative)

1. **Go to Firebase Console:**
   - Open: https://console.firebase.google.com/project/kasbill-19baf

2. **Enable Google Sign-In:**
   - Go to **Authentication** → **Sign-in method**
   - Click on **Google**
   - Enable it if not already enabled
   - This will automatically create the OAuth client

3. **Get the Web Client ID:**
   - After enabling, go to **Project Settings** → **General** tab
   - Scroll to **Your apps** → Find your **Web app**
   - The Web client ID might be shown there, OR
   - Go back to Google Cloud Console (Method 1) to find it

## Method 3: Check if Already in google-services.json

After adding SHA-1 fingerprints and downloading a new `google-services.json`, it might include the Web client ID. However, for Flutter Android apps, you typically need to get it from Google Cloud Console.

## Quick Link

**Direct link to your project's credentials:**
https://console.cloud.google.com/apis/credentials?project=kasbill-19baf

## What to Look For

The Web Client ID format:
```
174995240247-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
```

It will be different from your Android client ID which is:
```
174995240247-m08mfsc46is6o2g58ek0femtsfdodpc6.apps.googleusercontent.com
```

## After Finding It

Once you have the Web Client ID, update `lib/auth/signup_page.dart`:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: 'YOUR_WEB_CLIENT_ID_HERE', // Paste the Web Client ID here
);
```

Do the same for `lib/auth/login_page.dart` if it also uses Google Sign-In.
