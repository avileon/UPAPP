import { createServer } from 'node:http';

import { createApp } from './app.js';
import { assertProd, config, revealsOtp } from './config.js';

assertProd();

const app = createApp({ database: config.databaseFile });

// Presence lives in memory and everything in it expires; this keeps the maps
// from growing across a long-running process.
const sweeper = setInterval(() => app.live.sweep(), 60_000);
sweeper.unref();

const server = createServer((req, res) => {
  // The phone talks to this over a Cloudflare tunnel, so the browser-style
  // preflight only matters for local web testing — but it costs nothing.
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', 'authorization, content-type');
  res.setHeader('access-control-allow-methods', 'GET, POST, PUT, DELETE, OPTIONS');
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  app.handle(req, res);
});

server.listen(config.port, config.host, () => {
  console.log(`UP server listening on http://${config.host}:${config.port}`);
  console.log(`  database : ${config.databaseFile}`);
  console.log(`  web app  : ${app.web.exists ? 'served from /' : 'not present (API only)'}`);
  console.log(`  sms      : ${config.smsProvider}${revealsOtp() ? ' (codes are returned in the response)' : ''}`);
  console.log('');
  console.log('  Expose it with:  cloudflared tunnel --url http://localhost:' + config.port);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
  });
}
