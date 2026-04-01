// Vercel Serverless Function — Proxy to Zernio API
// Keeps ZERNIO_API_KEY server-side, never exposed to frontend.
//
// Frontend calls:  POST /api/zernio/profiles
// This function:   POST https://zernio.com/api/v1/profiles
//                  + Authorization: Bearer $ZERNIO_API_KEY
//
// All Zernio API calls MUST go through this proxy.

const ZERNIO_BASE = 'https://zernio.com/api/v1';

// Allowed first-segment paths (prevents open proxy abuse)
const ALLOWED_PATHS = new Set([
  'profiles',
  'connect',
  'accounts',
  'posts',
]);

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  const apiKey = process.env.ZERNIO_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'ZERNIO_API_KEY not configured on server' });
  }

  // Extract path segments from catch-all route
  let pathSegments = req.query.path;
  if (!pathSegments || pathSegments.length === 0) {
    const urlPath = req.url.replace(/\?.*$/, '');
    const match = urlPath.match(/^\/api\/zernio\/(.+)/);
    if (match) {
      pathSegments = match[1].split('/');
    }
  }
  if (!pathSegments || pathSegments.length === 0) {
    return res.status(400).json({ error: 'Missing API path' });
  }

  // Whitelist check on first segment
  if (!ALLOWED_PATHS.has(pathSegments[0])) {
    return res.status(403).json({ error: `Path not allowed: ${pathSegments[0]}` });
  }

  // Build target URL, preserving sub-paths and query params
  const apiPath = pathSegments.join('/');
  const url = new URL(req.url, 'http://localhost');
  const queryString = url.search || '';
  const targetUrl = `${ZERNIO_BASE}/${apiPath}${queryString}`;

  try {
    const fetchOptions = {
      method: req.method,
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
    };

    // Forward body for non-GET requests
    if (req.method !== 'GET' && req.method !== 'HEAD' && req.body) {
      fetchOptions.body = JSON.stringify(req.body);
    }

    const response = await fetch(targetUrl, fetchOptions);

    // Forward status and content-type
    res.status(response.status);
    const contentType = response.headers.get('content-type');
    if (contentType) {
      res.setHeader('Content-Type', contentType);
    }

    const responseText = await response.text();
    return res.send(responseText);
  } catch (error) {
    console.error('Zernio proxy error:', error.message);
    return res.status(502).json({
      error: 'Failed to reach Zernio API',
      details: error.message,
    });
  }
};
