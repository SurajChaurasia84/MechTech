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
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: Missing token' });
    }
    const token = authHeader.split('Bearer ')[1];
    await admin.auth().verifyIdToken(token);
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized: Invalid token', details: err.message });
  }

  const { mechanicId, vehicleModel, vehicleType, services, amount, discount, serviceObjects } = req.body;
  if (!vehicleModel || !vehicleType || (!services && !serviceObjects)) {
    return res.status(400).json({ error: 'Missing required booking details in body' });
  }

  const KEY_ID = process.env.RAZORPAY_KEY_ID;
  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;

  if (!KEY_ID || !KEY_SECRET) {
    return res.status(500).json({ error: 'Server configuration error: Razorpay keys are not set in the environment.' });
  }

  try {
    let serviceTotal = 0;

    // 2. Determine service total from serviceObjects, mechanic rates, or client payload
    if (Array.isArray(serviceObjects) && serviceObjects.length > 0) {
      serviceTotal = serviceObjects.reduce((sum, item) => sum + (Number(item.price) || 0), 0);
    } else if (mechanicId) {
      const jobPostsRef = db.collection('job_posts');
      const snapshot = await jobPostsRef
        .where('mechanicId', '==', mechanicId)
        .where('vehicleCategory', '==', vehicleType.toLowerCase())
        .limit(1)
        .get();

      if (!snapshot.empty) {
        const jobPostDoc = snapshot.docs[0];
        const jobPostData = jobPostDoc.data();
        const specRates = jobPostData.specializationRates || {};

        for (const serviceName of (services || [])) {
          const rate = specRates[serviceName];
          if (rate !== undefined && rate > 0) {
            serviceTotal += rate;
          }
        }
      }
    }

    // 3. Determine final amount in paise
    let amountInPaise = 0;
    if (amount && Number(amount) > 0) {
      amountInPaise = Math.round(Number(amount));
    } else {
      const platformFee = 5.0; // Flat ₹5 platform fee for customer
      const coinDiscount = Number(discount) || 0.0;
      const grandTotal = Math.max(0, serviceTotal + platformFee - coinDiscount);
      amountInPaise = Math.round(grandTotal * 100);
    }

    if (amountInPaise <= 0) {
      amountInPaise = 100; // Minimum 1 INR (100 paise)
    }

    // 4. Create order via Razorpay API
    const authString = Buffer.from(`${KEY_ID}:${KEY_SECRET}`).toString('base64');
    
    const response = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${authString}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountInPaise,
        currency: 'INR',
        receipt: `receipt_${Date.now()}`,
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      return res.status(response.status).json({ error: 'Razorpay API Error', details: data });
    }

    return res.status(200).json({ orderId: data.id, amount: data.amount });
  } catch (error) {
    console.error('Error creating Razorpay order:', error);
    return res.status(500).json({ error: 'Server error creating order', details: error.message });
  }
};
