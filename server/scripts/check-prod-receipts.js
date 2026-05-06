const https = require('https');

// Step 1: Login to get token
function apiCall(path, method, body) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'comp1682-3.onrender.com',
      path: path,
      method: method,
      timeout: 30000,
      headers: { 'Content-Type': 'application/json' },
    };
    if (body && body.token) {
      options.headers['Authorization'] = `Bearer ${body.token}`;
      delete body.token;
    }
    const req = https.request(options, (res) => {
      let d = '';
      res.on('data', (c) => (d += c));
      res.on('end', () => {
        try { resolve(JSON.parse(d)); } catch { resolve(d); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
    if (body && method === 'POST') req.write(JSON.stringify(body));
    req.end();
  });
}

async function main() {
  // Login
  const login = await apiCall('/api/auth/login', 'POST', {
    email: 'test1@example.com',
    password: 'Test@1234',
  });
  console.log('Login:', login.success ? 'OK' : login);
  
  if (!login.data) {
    console.log('Full login response:', JSON.stringify(login, null, 2));
    process.exit(1);
  }

  const token = login.data.user?.token || login.data.token;
  if (!token) {
    console.log('No token found:', JSON.stringify(login.data, null, 2));
    process.exit(1);
  }

  // Get month summary
  const summary = await apiCall('/api/receipts/month?month=2026-05', 'GET', { token });
  console.log('\nMonth Summary:');
  console.log(JSON.stringify(summary, null, 2));

  // Get day receipts for May 6
  const dayData = await apiCall('/api/receipts/day/2026-05-06', 'GET', { token });
  console.log('\nDay Receipts (May 6):');
  console.log(JSON.stringify(dayData, null, 2));
}

main().catch(console.error);
