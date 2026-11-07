import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { MailSettings } from '../src/lib/mailer.js';

test('mail settings: saved 0600, password never described, empty keeps it', () => {
  const file = join(mkdtempSync(join(tmpdir(), 'up-mail-')), '.mail.json');
  const settings = new MailSettings(file);
  assert.deepEqual(settings.describe(), { configured: false });
  settings.write({ user: 'a@b.co', pass: 'abcd efgh ijkl mnop', to: 'c@d.co' });
  assert.equal(statSync(file).mode & 0o777, 0o600);
  const seen = settings.describe();
  assert.equal(seen.configured, true);
  assert.equal(seen.pass, undefined);
  assert.equal(settings.read().pass, 'abcdefghijklmnop');
  settings.write({ to: 'x@y.co' });
  assert.equal(settings.read().pass, 'abcdefghijklmnop');
  assert.equal(settings.read().to, 'x@y.co');
});
