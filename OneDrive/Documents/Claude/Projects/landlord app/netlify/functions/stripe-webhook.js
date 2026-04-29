// RentWise — Stripe Webhook Handler
// Updates user plan in Supabase when subscription events fire
// Environment variables required:
//   STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET,
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY  // service role bypasses RLS for server-side writes
);

exports.handler = async function(event, context) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const sig = event.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let stripeEvent;
  try {
    stripeEvent = stripe.webhooks.constructEvent(event.body, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return { statusCode: 400, body: `Webhook Error: ${err.message}` };
  }

  const { type, data } = stripeEvent;
  const obj = data.object;

  console.log(`Stripe event received: ${type}`);

  try {
    switch (type) {
      // Subscription created or updated
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const userId = obj.metadata?.supabase_user_id;
        if (!userId) break;

        const isActive = ['active', 'trialing'].includes(obj.status);
        const plan = isActive ? 'pro' : 'free';

        await supabase.from('profiles').update({
          plan,
          stripe_subscription_id: obj.id,
          subscription_status: obj.status
        }).eq('id', userId);

        console.log(`Updated user ${userId} plan → ${plan} (${obj.status})`);
        break;
      }

      // Subscription cancelled or expired
      case 'customer.subscription.deleted': {
        const userId = obj.metadata?.supabase_user_id;
        if (!userId) break;

        await supabase.from('profiles').update({
          plan: 'free',
          stripe_subscription_id: null,
          subscription_status: 'cancelled'
        }).eq('id', userId);

        console.log(`Downgraded user ${userId} to free (subscription deleted)`);
        break;
      }

      // Checkout completed — also capture stripe_customer_id
      case 'checkout.session.completed': {
        const userId = obj.metadata?.supabase_user_id;
        if (!userId) break;

        await supabase.from('profiles').update({
          stripe_customer_id: obj.customer
        }).eq('id', userId);

        console.log(`Saved customer ID for user ${userId}`);
        break;
      }

      // Payment failed — notify (future: send email)
      case 'invoice.payment_failed': {
        const customerId = obj.customer;
        const { data: profile } = await supabase
          .from('profiles')
          .select('id, email')
          .eq('stripe_customer_id', customerId)
          .single();

        if (profile) {
          await supabase.from('profiles').update({
            subscription_status: 'past_due'
          }).eq('id', profile.id);
          console.log(`Marked user ${profile.id} as past_due`);
        }
        break;
      }

      default:
        console.log(`Unhandled event type: ${type}`);
    }
  } catch (err) {
    console.error(`Error processing event ${type}:`, err);
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }

  return { statusCode: 200, body: JSON.stringify({ received: true }) };
};
