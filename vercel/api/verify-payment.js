const crypto = require('crypto');

module.exports = async (req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle CORS Preflight request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { orderId, paymentId, signature } = req.body;
  if (!orderId || !paymentId || !signature) {
    return res.status(400).json({ error: 'Missing orderId, paymentId, or signature in request body' });
  }

  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'lgqfSN8AZtUItZtYKN5VJqlQ';

  try {
    const text = orderId + '|' + paymentId;
    const expectedSignature = crypto
      .createHmac('sha256', KEY_SECRET)
      .update(text)
      .digest('hex');

    const isValid = expectedSignature === signature;

    if (isValid) {
      return res.status(200).json({ verified: true });
    } else {
      return res.status(400).json({ verified: false, error: 'Signature verification failed' });
    }
  } catch (error) {
    console.error('Error verifying payment signature:', error);
    return res.status(500).json({ error: 'Server error verifying signature', details: error.message });
  }
};
