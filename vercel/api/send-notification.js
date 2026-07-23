const { GoogleAuth } = require('google-auth-library');
const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const projectId = process.env.FIREBASE_PROJECT_ID || 'mechtech-8e83a';
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (clientEmail && privateKey) {
    privateKey = privateKey.replace(/\\n/g, '\n');
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
      projectId: projectId,
    });
  } else {
    admin.initializeApp({
      projectId: projectId,
    });
  }
}

module.exports = async (req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle CORS Preflight request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  // Verify Authentication (Firebase ID Token)
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: Missing token' });
    }
    const authToken = authHeader.split('Bearer ')[1];
    await admin.auth().verifyIdToken(authToken);
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized: Invalid token', details: err.message });
  }

  const { token, title, body, type } = req.body;
  if (!token || !title || !body) {
    return res.status(400).json({ error: 'Missing token, title, or body parameters in request body' });
  }

  // ONLY ring alarm when type is strictly 'booking' (new incoming booking request)
  const isBooking = type === 'booking';

  // Ensure environment variables are set
  if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIREBASE_CLIENT_EMAIL || !process.env.FIREBASE_PRIVATE_KEY) {
    return res.status(500).json({ 
      error: 'Vercel environment variables (FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY) are not configured.' 
    });
  }

  try {
    // Process key newlines safely from Vercel env settings
    const privateKey = process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');
    
    // Generate temporary Google OAuth 2.0 Access Token
    const auth = new GoogleAuth({
      credentials: {
        client_email: process.env.FIREBASE_CLIENT_EMAIL,
        private_key: privateKey,
      },
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });

    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    if (!accessToken) {
      throw new Error('Failed to retrieve OAuth2 access token from Google.');
    }

    const projectId = process.env.FIREBASE_PROJECT_ID;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    
    // Forward message to Firebase Cloud Messaging server
    const fcmResponse = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: token,
          notification: {
            title: title,
            body: body,
          },
          data: {
            type: isBooking ? 'booking' : 'general',
          },
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: isBooking ? 'mechtech_booking_alarm_channel_v3' : 'mechtech_general_channel',
              sound: isBooking ? 'alarm' : 'default',
              default_sound: !isBooking,
              notification_priority: 'PRIORITY_MAX',
              visibility: 'PUBLIC',
            },
          },
        },
      }),
    });

    const responseData = await fcmResponse.json();
    if (!fcmResponse.ok) {
      return res.status(fcmResponse.status).json({ 
        error: 'Google FCM API error', 
        details: responseData 
      });
    }

    return res.status(200).json({ success: true, messageId: responseData.name });
  } catch (error) {
    console.error('Error sending notification:', error);
    return res.status(500).json({ error: 'Server error sending push notification', details: error.message });
  }
};
