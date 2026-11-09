import { readFileSync, writeFileSync, renameSync, existsSync } from 'node:fs';
import { connect as netConnect } from 'node:net';
import { connect as tlsConnect } from 'node:tls';

/**
 * Email for the operator, and nothing else.
 *
 * One reader (Avi), a handful of messages a day, so a small SMTP client
 * instead of a dependency. Port 587 with STARTTLS by default — Hetzner Cloud
 * blocks outgoing 25 and 465; 465 (implicit TLS) still works where allowed. Settings live in a 0600
 * JSON file the admin page writes — the password never passes through the
 * repository, the environment file or a log line.
 */

const b64 = (s) => Buffer.from(String(s), 'utf8').toString('base64');
/** RFC 2047, so a Hebrew subject survives every mail client. */
const header = (s) => `=?UTF-8?B?${b64(s)}?=`;

export class MailSettings {
  constructor(file) {
    this.file = file;
  }

  read() {
    try {
      if (!this.file || !existsSync(this.file)) return null;
      const s = JSON.parse(readFileSync(this.file, 'utf8'));
      return s && s.user && s.pass && s.to ? s : null;
    } catch {
      return null;
    }
  }

  /** Merges: leaving the password empty keeps the saved one. */
  write({ host, port, user, pass, to }) {
    const old = this.read() ?? {};
    const next = {
      host: String(host || old.host || 'smtp.gmail.com').trim(),
      port: Number(port || (old.port && old.port !== 465 ? old.port : 0) || 587),
      user: String(user || old.user || '').trim(),
      pass: String(pass || old.pass || '').replace(/\s+/g, ''),
      to: String(to || old.to || '').trim(),
    };
    const tmp = `${this.file}.tmp`;
    writeFileSync(tmp, JSON.stringify(next), { mode: 0o600 });
    renameSync(tmp, this.file);
    return next;
  }

  /** What the admin page may see. */
  describe() {
    const s = this.read();
    return s
      ? { configured: true, host: s.host, port: s.port, user: s.user, to: s.to }
      : { configured: false };
  }
}

/** Sends one message. Resolves, or rejects with the server's last reply. */
export function sendMail(settings, { subject, text }, timeoutMs = 20_000) {
  const implicit = Number(settings.port) === 465;
  const body = [
    `From: AppDate <${settings.user}>`,
    `To: <${settings.to}>`,
    `Subject: ${header(subject)}`,
    `Date: ${new Date().toUTCString()}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    b64(text).replace(/.{76}/g, '$&\r\n'),
  ].join('\r\n');

  // [what to send, the reply code it must get]. `null` = just wait for the greeting.
  const steps = [
    [null, 220],
    ['EHLO up.atar.co', 250],
    ...(implicit ? [] : [['STARTTLS', 220], ['__UPGRADE__', 0], ['EHLO up.atar.co', 250]]),
    ['AUTH LOGIN', 334],
    [b64(settings.user), 334],
    [b64(settings.pass), 235],
    [`MAIL FROM:<${settings.user}>`, 250],
    [`RCPT TO:<${settings.to}>`, 250],
    ['DATA', 354],
    [`${body}\r\n.`, 250],
    ['QUIT', 221],
  ];

  return new Promise((resolve, reject) => {
    let socket;
    let i = 0;
    let buffer = '';
    let done = false;
    const fail = (error) => {
      if (done) return;
      done = true;
      socket?.destroy();
      reject(error);
    };

    const onData = (chunk) => {
      buffer += chunk;
      // A reply is complete at a line "NNN text" (space, not dash, after the code).
      const lines = buffer.split('\r\n');
      const last = lines.length >= 2 ? lines[lines.length - 2] : '';
      if (!/^\d{3} /.test(last)) return;
      buffer = '';
      const code = Number(last.slice(0, 3));
      if (code !== steps[i][1]) {
        // The reply text only — never anything we sent.
        fail(new Error(`smtp_${code}: ${last.slice(4, 120)}`));
        return;
      }
      advance();
    };

    const attach = (s) => {
      s.setEncoding('utf8');
      s.setTimeout(timeoutMs, () => fail(new Error('smtp_timeout')));
      s.on('data', onData);
      s.on('error', fail);
    };

    const advance = () => {
      i += 1;
      if (i >= steps.length) {
        done = true;
        socket.end();
        resolve();
        return;
      }
      if (steps[i][0] === '__UPGRADE__') {
        const plain = socket;
        plain.removeAllListeners('data');
        plain.setTimeout(0);
        socket = tlsConnect({ socket: plain, servername: settings.host }, () => advance());
        attach(socket);
        return;
      }
      socket.write(`${steps[i][0]}\r\n`);
    };

    socket = implicit
      ? tlsConnect({ host: settings.host, port: settings.port, servername: settings.host })
      : netConnect({ host: settings.host, port: settings.port });
    attach(socket);
  });
}

/**
 * The app's mailer: reads settings at send time (so saving them in the admin
 * page works without a restart) and never throws into a request.
 */
export class Mailer {
  constructor(settings, send = sendMail) {
    this.settings = settings;
    this.send = send;
  }

  get configured() {
    return this.settings.read() !== null;
  }

  async deliver(message) {
    const s = this.settings.read();
    if (!s) return false;
    await this.send(s, message);
    return true;
  }

  /** Fire-and-forget for event notifications. */
  notify(message) {
    this.deliver(message).catch((error) => {
      console.error(`[mail] not sent: ${error.message}`);
    });
  }
}
