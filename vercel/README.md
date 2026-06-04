# MechTech Firebase FCM Push Notification Proxy

This Node.js serverless project acts as a secure, free OAuth 2.0 gateway between your Flutter app and the **Google Firebase Cloud Messaging (FCM) HTTP v1 API**.

It allows your customer app to trigger push notifications to mechanics securely when they book a job, without exposing your Firebase private keys inside the Flutter application.

---

## Step 1: Generate Firebase Service Account Credentials

1. Open your **Firebase Console** (https://console.firebase.google.com).
2. Go to **Project Settings** (gear icon) -> **Service Accounts**.
3. Under **Firebase Admin SDK**, select **Node.js** and click **Generate New Private Key**.
4. A `.json` file containing your service account credentials will download.
5. Open this JSON file. You will need:
   - `project_id`
   - `client_email`
   - `private_key`

---

## Step 2: Deploy to Vercel (100% Free)

You can deploy this folder to Vercel in 2 minutes using either of these methods:

### Option A: GitHub (Easiest)
1. Push this `vercel/` folder into a private/public **GitHub repository**.
2. Go to **Vercel** (https://vercel.com) and sign in using your GitHub account.
3. Click **Add New** -> **Project**.
4. Import your repository.
5. Under **Environment Variables**, add the following 3 variables:
   - **`FIREBASE_PROJECT_ID`**: The `project_id` from your JSON file.
   - **`FIREBASE_CLIENT_EMAIL`**: The `client_email` from your JSON file.
   - **`FIREBASE_PRIVATE_KEY`**: The complete `private_key` block from your JSON file (include the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` wrapper lines).
6. Click **Deploy**.
7. Once finished, Vercel will give you a production URL (e.g. `https://your-project.vercel.app`). Your API endpoint will be:
   `https://your-project.vercel.app/api/send-notification`

### Option B: Vercel CLI
1. Open your terminal inside this `vercel/` directory.
2. Install the Vercel CLI:
   ```bash
   npm install -g vercel
   ```
3. Authenticate and deploy by running:
   ```bash
   vercel
   ```
4. Follow the prompts. Set up your environment variables on the Vercel web dashboard once the project is created.

---

## Step 3: Triggering from Flutter

Make a POST request in Dart to your deployed Vercel endpoint:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> triggerPushNotification({
  required String recipientFcmToken,
  required String title,
  required String message,
}) async {
  final url = Uri.parse('https://your-project.vercel.app/api/send-notification');
  
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': recipientFcmToken,
        'title': title,
        'body': message,
      }),
    );
    
    if (response.statusCode == 200) {
      print('Notification sent successfully!');
    } else {
      print('Failed to send notification: ${response.body}');
    }
  } catch (e) {
    print('Error calling Vercel API: $e');
  }
}
```
