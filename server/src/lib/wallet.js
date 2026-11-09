import { createSign } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';

/**
 * Google Wallet "Save to Google Wallet" links for a business card.
 *
 * The whole pass — its class and its one object — rides inside a JWT signed
 * with a service account key, and the link is just
 * `https://pay.google.com/gp/v/save/<jwt>`. No API call, no stored pass: Google
 * creates the class and the object the first time someone saves.
 *
 * The pass is a QR, not NFC: Wallet's NFC (Smart Tap) talks to terminals, not
 * to another phone. Its value is that the QR opens from the lock screen.
 */

const b64url = (value) =>
  Buffer.from(typeof value === 'string' ? value : JSON.stringify(value)).toString('base64url');

export class WalletSigner {
  /**
   * @param {{issuerId: string, serviceAccount?: {client_email: string, private_key: string},
   *          serviceAccountFile?: string, publicUrl: string}} options
   */
  constructor({ issuerId, serviceAccount, serviceAccountFile, publicUrl }) {
    this.issuerId = issuerId;
    this.publicUrl = publicUrl;
    this.account = serviceAccount ?? null;
    if (!this.account && serviceAccountFile && existsSync(serviceAccountFile)) {
      try {
        this.account = JSON.parse(readFileSync(serviceAccountFile, 'utf8'));
      } catch {
        this.account = null;
      }
    }
  }

  get available() {
    return Boolean(this.issuerId && this.account?.client_email && this.account?.private_key);
  }

  get classId() {
    return `${this.issuerId}.up_business_card`;
  }

  /** The save link for one card. `objectSuffix` must be unique per pass. */
  saveUrl({ objectSuffix, firstName, cardUrl }) {
    if (!this.available) throw new Error('wallet not configured');
    const logo = `${this.publicUrl}/site/icon-192.png`;
    const genericClass = { id: this.classId };
    const genericObject = {
      id: `${this.issuerId}.${objectSuffix.replace(/[^A-Za-z0-9._-]/g, '_')}`,
      classId: this.classId,
      state: 'ACTIVE',
      hexBackgroundColor: '#0d0a14',
      logo: {
        sourceUri: { uri: logo },
        contentDescription: { defaultValue: { language: 'he', value: 'AppDate' } },
      },
      cardTitle: { defaultValue: { language: 'he', value: 'AppDate · כרטיס ביקור' } },
      subheader: { defaultValue: { language: 'he', value: 'סרקו ותנו UP' } },
      header: { defaultValue: { language: 'he', value: firstName || 'AppDate' } },
      barcode: { type: 'QR_CODE', value: cardUrl, alternateText: 'up.atar.co' },
      linksModuleData: {
        uris: [{ uri: cardUrl, description: 'הכרטיס שלי ב-AppDate', id: 'card' }],
      },
    };
    const header = { alg: 'RS256', typ: 'JWT' };
    const claims = {
      iss: this.account.client_email,
      aud: 'google',
      typ: 'savetowallet',
      iat: Math.floor(Date.now() / 1000),
      origins: [this.publicUrl],
      payload: { genericClasses: [genericClass], genericObjects: [genericObject] },
    };
    const unsigned = `${b64url(header)}.${b64url(claims)}`;
    const signature = createSign('RSA-SHA256').update(unsigned).sign(this.account.private_key, 'base64url');
    return `https://pay.google.com/gp/v/save/${unsigned}.${signature}`;
  }
}
