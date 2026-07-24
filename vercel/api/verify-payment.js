const crypto = require('crypto');
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

const db = admin.firestore();

// Helper to send push notifications via FCM Admin SDK
async function sendPushNotification(recipientUid, title, body, type = 'general') {
  try {
    const userDoc = await db.collection('users').doc(recipientUid).get();
    if (!userDoc.exists) return;
    const token = userDoc.data().fcmToken;
    if (!token) return;

    const isBooking = type === 'booking';

    await admin.messaging().send({
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: isBooking ? 'booking' : 'general',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: isBooking ? 'mechtech_booking_alarm_v6' : 'mechtech_general_channel_v4',
          sound: isBooking ? 'content://settings/system/alarm_alert' : 'default',
          priority: 'max',
          visibility: 'public',
        },
      },
    });
    console.log(`Notification (${type}) sent to ${recipientUid}`);
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
    serviceObjects,
    discount,
    latitude,
    longitude,
    bookingLocation
  } = req.body;

  if (!orderId || !paymentId || !signature || !vehicleModel || !vehicleType || (!services && !serviceObjects)) {
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

    let mechanicName = 'Unassigned';
    if (mechanicId) {
      const mechanicDoc = await db.collection('users').doc(mechanicId).get();
      if (mechanicDoc.exists) {
        mechanicName = mechanicDoc.data().name || 'Mechanic';
      }
    }

    // 4. Resolve service rates and prices securely
    let serviceTotal = 0;
    let resolvedServices = [];

    if (Array.isArray(serviceObjects) && serviceObjects.length > 0) {
      resolvedServices = serviceObjects.map(s => {
        const p = Number(s.price) || 0;
        serviceTotal += p;
        return {
          id: s.id || `dyn_${Math.random().toString(36).substring(7)}`,
          name: s.name || 'Service',
          price: p,
        };
      });
    } else if (mechanicId) {
      const jobPostsRef = db.collection('job_posts');
      const snapshot = await jobPostsRef
        .where('mechanicId', '==', mechanicId)
        .where('vehicleCategory', '==', vehicleType.toLowerCase())
        .limit(1)
        .get();

      const specRates = !snapshot.empty ? (snapshot.docs[0].data().specializationRates || {}) : {};
      resolvedServices = (services || []).map(serviceName => {
        const rate = specRates[serviceName] || 0;
        serviceTotal += rate;
        return {
          id: `dyn_${Math.random().toString(36).substring(7)}`,
          name: serviceName,
          price: rate,
        };
      });
    } else {
      resolvedServices = (services || []).map(serviceName => ({
        id: `dyn_${Math.random().toString(36).substring(7)}`,
        name: serviceName,
        price: 0,
      }));
    }

    const platformFee = 5.0; // Flat ₹5 platform fee for customer
    const coinDiscount = Number(discount) || 0.0;
    const grandTotal = Math.max(0, serviceTotal + platformFee - coinDiscount);
    const commission = serviceTotal * 0.07; // 7% deduction from mechanic charges
    const mechanicEarnings = Math.max(0, serviceTotal - commission); // Mechanic net earnings
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
      discount: coinDiscount,
      commission: commission,
      totalAmount: grandTotal,
      mechanicEarnings: mechanicEarnings,
      ownerRevenue: ownerRevenue,
      bookingDate: admin.firestore.FieldValue.serverTimestamp(),
      status: 'Pending',
      mechanicId: mechanicId || null,
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
      `${customerName} has paid and requested a service for ${vehicleModel}.`,
      'booking'
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
