#!/bin/bash

# Copy generate.js out of container
docker cp ai-seo-backend:/app/src/routes/generate.js /tmp/generate.js

# Inject proxy routes before module.exports
python3 << 'EOF'
with open('/tmp/generate.js', 'r') as f:
    content = f.read()

proxy_routes = '''
// ── PROXY /api/job → revolution-network (évite CORS côté browser) ──
router.post('/job', async (req, res) => {
  try {
    const { type, params } = req.body;
    if (!type) return res.status(400).json({ error: 'type requis' });
    const r = await fetch(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': API_KEY },
      body: JSON.stringify({ type, params })
    });
    const data = await r.json();
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/job/:id/result', async (req, res) => {
  try {
    const r = await fetch(`${API_BASE}/${req.params.id}/result`, {
      headers: { 'x-api-key': API_KEY }
    });
    const data = await r.json();
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

'''

# Insert before module.exports
content = content.replace('module.exports = router;', proxy_routes + 'module.exports = router;')

with open('/tmp/generate_patched.js', 'w') as f:
    f.write(content)

print("✅ Patched successfully")
EOF

# Copy back into container
docker cp /tmp/generate_patched.js ai-seo-backend:/app/src/routes/generate.js

# Restart container
docker restart ai-seo-backend

echo "✅ Done - waiting for restart..."
sleep 3

# Test the new route
curl -s -X POST http://localhost:4002/api/job \
  -H "Content-Type: application/json" \
  -d '{"type":"text_transform","params":{"text":"bonjour monde","action":"reformuler","language":"Français"}}' | head -100

