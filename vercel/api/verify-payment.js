const crypto = require('crypto');
const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (projectId && clientEmail && privateKey) {
    privateKey = privateKey.replace(/\\n/g, '\n');
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  } else {
    admin.initializeApp();
  }
}

const db = admin.firestore();

// Helper to send push notifications via FCM Admin SDK
async function sendPushNotification(recipientUid, title, body) {
  try {
    const userDoc = await db.collection('users').doc(recipientUid).get();
    if (!userDoc.exists) return;
    const token = userDoc.data().fcmToken;
    if (!token) return;

    await admin.messaging().send({
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      }
    });
    console.log(`Notification sent to ${recipientUid}`);
  } catch (err) {
    console.error(`Error sending notification to ${recipientUid}:`, err);
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

  // 1. Verify Authentication (Firebase ID Token)
  let customerUid;
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: Missing token' });
    }
    const token = authHeader.split('Bearer ')[1];
    const decodedUser = await admin.auth().verifyIdToken(token);
    customerUid = decodedUser.uid;
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized: Invalid token', details: err.message });
  }

  const {
    orderId,
    paymentId,
    signature,
    mechanicId,
    vehicleModel,
    vehicleType,
    services,
    latitude,
    longitude,
    bookingLocation
  } = req.body;

  if (!orderId || !paymentId || !signature || !mechanicId || !vehicleModel || !vehicleType || !services || !Array.isArray(services)) {
    return res.status(400).json({ error: 'Missing required booking verification payload' });
  }

  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
  if (!KEY_SECRET) {
    return res.status(500).json({ error: 'Server configuration error: Razorpay Key Secret is not set in the environment.' });
  }

  try {
    // 2. Validate Razorpay payment signature
    const text = orderId + '|' + paymentId;
    const expectedSignature = crypto
      .createHmac('sha256', KEY_SECRET)
      .update(text)
      .digest('hex');

    const isValid = expectedSignature === signature;

    if (!isValid) {
      return res.status(400).json({ verified: false, error: 'Signature verification failed' });
    }

    // 2.5. Check if a booking with the same paymentId already exists to prevent duplicate entries (idempotency check)
    const existingBookings = await db.collection('bookings')
      .where('paymentId', '==', paymentId)
      .limit(1)
      .get();

    if (!existingBookings.empty) {
      const existingBooking = existingBookings.docs[0].data();
      return res.status(200).json({
        verified: true,
        bookingId: existingBooking.id,
        booking: existingBooking,
      });
    }

    // 3. Resolve user profiles from database securely
    const customerDoc = await db.collection('users').doc(customerUid).get();
    const customerData = customerDoc.exists ? customerDoc.data() : {};
    const customerName = customerData.name || 'Customer';
    const customerPhone = customerData.phone || '';
    const customerEmail = customerData.email || '';

    const mechanicDoc = await db.collection('users').doc(mechanicId).get();
    const mechanicData = mechanicDoc.exists ? mechanicDoc.data() : {};
    const mechanicName = mechanicData.name || 'Mechanic';

    // 4. Resolve mechanic service rates to write the exact paid prices
    const jobPostsRef = db.collection('job_posts');
    const snapshot = await jobPostsRef
      .where('mechanicId', '==', mechanicId)
      .where('vehicleCategory', '==', vehicleType.toLowerCase())
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ error: 'Mechanic job post not found during verification' });
    }

    const jobPostData = snapshot.docs[0].data();
    const specRates = jobPostData.specializationRates || {};

    let serviceTotal = 0;
    const resolvedServices = services.map(serviceName => {
      const rate = specRates[serviceName] || 0;
      serviceTotal += rate;
      return {
        id: `dyn_${serviceName.hashCode || Math.random().toString(36).substring(7)}`,
        name: serviceName,
        price: rate,
      };
    });

    const platformFee = 5.0; // Flat ₹5 platform fee for customer
    const commission = serviceTotal * 0.07; // 7% deduction from mechanic charges
    const grandTotal = serviceTotal + platformFee; // Total paid by customer
    const mechanicEarnings = serviceTotal - commission; // Mechanic net earnings
    const ownerRevenue = platformFee + commission; // Total owner revenue (₹5 + 7%)

    // Generate Booking ID (MT- style)
    const bookingId = `MT-${Date.now().toString().substring(7)}`;

    const bookingData = {
      id: bookingId,
      customerId: customerUid,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      vehicleType: vehicleType,
      vehicleModel: vehicleModel,
      serviceTotal: serviceTotal,
      platformFee: platformFee,
      commission: commission,
      totalAmount: grandTotal,
      mechanicEarnings: mechanicEarnings,
      ownerRevenue: ownerRevenue,
      bookingDate: admin.firestore.FieldValue.serverTimestamp(),
      status: 'Pending',
      mechanicId: mechanicId,
      mechanicName: mechanicName,
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null,
      bookingLocation: bookingLocation || null,
      paymentId: paymentId,
      paymentStatus: 'paid',
      services: resolvedServices,
    };

    // Write to root 'bookings' collection
    await db.collection('bookings').doc(bookingId).set(bookingData);

    // Write to customer's subcollection 'users/<uid>/bookings'
    await db.collection('users').doc(customerUid).collection('bookings').doc(bookingId).set(bookingData);

    // 5. Trigger secure notifications server-side
    await sendPushNotification(
      mechanicId,
      'New Paid Booking!',
      `${customerName} has paid and requested a service for ${vehicleModel}.`
    );

    await sendPushNotification(
      customerUid,
      'Payment Successful!',
      `Your payment for ${vehicleModel} service was successful and booking is confirmed.`
    );

    return res.status(200).json({ verified: true, bookingId: bookingId, booking: bookingData });
  } catch (error) {
    console.error('Error verifying payment signature & writing booking:', error);
    return res.status(500).json({ error: 'Server error processing payment verification', details: error.message });
  }
};
