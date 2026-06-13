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

  const { amount } = req.body; // in paise
  if (!amount) {
    return res.status(400).json({ error: 'Missing amount in request body' });
  }

  const KEY_ID = process.env.RAZORPAY_KEY_ID || 'rzp_live_T0c78F2TcNcIwJ';
  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'lgqfSN8AZtUItZtYKN5VJqlQ';

  try {
    const authString = Buffer.from(`${KEY_ID}:${KEY_SECRET}`).toString('base64');
    
    // In Node.js 18+, fetch is available globally
    const response = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${authString}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: Math.round(amount), // must be integer
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
