// config.js -- Environment configuration for ELUXR v2
// Loaded before all other scripts. Detects environment by hostname.
window.ELUXR_CONFIG = (() => {
  const hostname = window.location.hostname;

  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return {
      SUPABASE_URL: 'https://llpnwaoxisfwptxvdfed.supabase.co',
      SUPABASE_ANON_KEY: 'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ',
      N8N_WEBHOOK_BASE: 'https://flowbound.app.n8n.cloud/webhook',
      ENV: 'development'
    };
  }

  // Production (Vercel deployed domain)
  return {
    SUPABASE_URL: 'https://llpnwaoxisfwptxvdfed.supabase.co',
    SUPABASE_ANON_KEY: 'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ',
    N8N_WEBHOOK_BASE: 'https://flowbound.app.n8n.cloud/webhook',
    ENV: 'production'
  };
})();
