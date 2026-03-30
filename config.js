// config.js -- Environment configuration for ELUXR v2
// Loaded before all other scripts. Detects environment by hostname.
window.ELUXR_CONFIG = (() => {
  const hostname = window.location.hostname;

  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return {
      SUPABASE_URL: 'https://llpnwaoxisfwptxvdfed.supabase.co',
      SUPABASE_ANON_KEY: 'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ',
      N8N_WEBHOOK_BASE: 'https://flowbound.app.n8n.cloud/webhook',
      GOOGLE_CLIENT_ID: '', // Set your Google OAuth Client ID here
      ENV: 'development'
    };
  }

  // Production (Vercel deployed domain)
  // N8N_WEBHOOK_BASE points to our Vercel proxy to avoid CORS issues.
  // The proxy at /api/webhook forwards requests to n8n Cloud server-side.
  return {
    SUPABASE_URL: 'https://llpnwaoxisfwptxvdfed.supabase.co',
    SUPABASE_ANON_KEY: 'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ',
    N8N_WEBHOOK_BASE: '/api/n8n',
    GOOGLE_CLIENT_ID: '', // Set your Google OAuth Client ID here
    ENV: 'production'
  };
})();
