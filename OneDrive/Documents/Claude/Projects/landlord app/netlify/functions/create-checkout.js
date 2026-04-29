// RentWise — Create Stripe Checkout Session
// Called when user clicks "Upgrade to Pro"
// Environment variables required: STRIPE_SECRET_KEY, STRIPE_PRO_PRICE_ID, SITE_URL

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

exports.handler = async function(event, context) {
  const SITE_URL = process.env.SITE_URL || 'http://localhost:8888';
  const corsHeaders = {
    'Access-Control-Allow-Origin': SITE_URL,
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json'
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: corsHeaders, body: '' };
  }
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers: corsHeaders, body: JSON.stringify({ error: 'Method Not Allowed' }) };
  }

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return { statusCode: 400, headers: corsHeaders, body: JSON.stringify({ error: 'Invalid JSON' }) };
  }

  const { userId, email, customerName, plan } = body;

  if (!userId || !email) {
    return { statusCode: 400, headers: corsHeaders, body: JSON.stringify({ error: 'userId and email required' }) };
  }

  try {
    // Look up or create Stripe customer
    let customer;
    const existing = await stripe.customers.list({ email, limit: 1 });
    if (existing.data.length > 0) {
      customer = existing.data[0];
    } else {
      customer = await stripe.customers.create({
        email,
        name: customerName || '',
        metadata: { supabase_user_id: userId }
      });
    }

    const priceId = plan === 'pro'
      ? process.env.STRIPE_PRO_PRICE_ID
      : process.env.STRIPE_PRO_PRICE_ID; // expand for more plans later

    if (!priceId) {
      return { statusCode: 500, headers: corsHeaders, body: JSON.stringify({ error: 'Price ID not configured' }) };
    }

    const session = await stripe.checkout.sessions.create({
      customer: customer.id,
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${SITE_URL}/index.html?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url:  `${SITE_URL}/index.html?checkout=cancelled`,
      metadata: { supabase_user_id: userId },
      subscription_data: {
        metadata: { supabase_user_id: userId }
      },
      allow_promotion_codes: true,
    });

    return { statusCode: 200, headers: corsHeaders, body: JSON.stringify({ url: session.url }) };
  } catch (err) {
    console.error('Stripe checkout error:', err);
    return { statusCode: 500, headers: corsHeaders, body: JSON.stringify({ error: err.message }) };
  }
};
