// Vercel Serverless Function — Proxy to n8n Cloud webhooks
// Eliminates CORS issues by making n8n calls server-side.
//
// Frontend calls:  POST /api/n8n/eluxr-phase4-studio
// This function:   POST https://flowbound.app.n8n.cloud/webhook/eluxr-phase4-studio
//
// All headers (Authorization, Content-Type) are forwarded.
// The response from n8n is returned to the caller.

const N8N_BASE = 'https://flowbound.app.n8n.cloud/webhook';

// Webhooks that route to a different n8n instance (friend's device)
const EXTERNAL_ROUTES = {
  'eluxr-tools-video': 'https://n8n-dev.eluxr.com/webhook',
};

// Allowed webhook paths (whitelist to prevent open proxy abuse)
const ALLOWED_PATHS = new Set([
  'eluxr-phase1-analyzer',
  'eluxr-phase1-orchestrator',
  'eluxr-phase2-themes',
  'eluxr-phase2-get-themes',
  'eluxr-phase2-submit-content',
  'eluxr-phase3-approvals-list',
  'eluxr-phase3-approvals-action',
  'eluxr-phase3-clear-pending',
  'eluxr-phase4-studio',
  'eluxr-phase4-calendar-sync',
  'eluxr-generate-topics',
  'eluxr-regenerate-topic',
  'eluxr-generate-content',
  'eluxr-approval-list',
  'eluxr-approval-action',
  'eluxr-clear-pending',
  'eluxr-tools-video',
  'eluxr-tools-image',
  'eluxr-scrape-product',
  'eluxr-process-brand-doc',
  'eluxr-image-download',
]);

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  // Extract webhook path from the catch-all route segments
  // req.query.path is an array, e.g. ['eluxr-phase4-studio']
  // Fallback: parse from URL if query.path is empty (Vercel routing edge case)
  let pathSegments = req.query.path;
  if (!pathSegments || pathSegments.length === 0) {
    const urlPath = req.url.replace(/\?.*$/, ''); // strip query string
    const match = urlPath.match(/^\/api\/n8n\/(.+)/);
    if (match) {
      pathSegments = match[1].split('/');
    }
  }
  if (!pathSegments || pathSegments.length === 0) {
    return res.status(400).json({ error: 'Missing webhook path', debug: { url: req.url, query: req.query } });
  }

  const webhookPath = pathSegments.join('/');

  // Validate against whitelist (check first segment for security)
  if (!ALLOWED_PATHS.has(pathSegments[0])) {
    return res.status(403).json({ error: `Webhook path not allowed: ${webhookPath}` });
  }

  // Route to external n8n instance if configured, otherwise default
  const baseUrl = EXTERNAL_ROUTES[pathSegments[0]] || N8N_BASE;
  const targetUrl = `${baseUrl}/${webhookPath}`;

  // Build forwarded headers
  const isExternal = !!EXTERNAL_ROUTES[pathSegments[0]];
  const forwardHeaders = {
    'Content-Type': req.headers['content-type'] || 'application/json',
  };
  // Only forward auth to our own n8n instance, not external ones
  if (req.headers['authorization'] && !isExternal) {
    forwardHeaders['Authorization'] = req.headers['authorization'];
  }

  try {
    const fetchOptions = {
      method: req.method,
      headers: forwardHeaders,
    };

    // Forward body for non-GET requests
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      fetchOptions.body = JSON.stringify(req.body);
    }

    const n8nResponse = await fetch(targetUrl, fetchOptions);

    // Forward status code
    res.status(n8nResponse.status);

    // Forward content-type from n8n
    const contentType = n8nResponse.headers.get('content-type');
    if (contentType) {
      res.setHeader('Content-Type', contentType);
    }

    // Read response and send it back
    const responseText = await n8nResponse.text();
    return res.send(responseText);
  } catch (error) {
    console.error('n8n proxy error:', error.message);
    return res.status(502).json({
      error: 'Failed to reach n8n webhook',
      details: error.message,
    });
  }
};
