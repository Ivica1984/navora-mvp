// SIG2 (ADR-076): Web Push without a third-party library, on Node's crypto only.
//   * Message encryption: RFC 8291 (aes128gcm content coding, RFC 8188), one record.
//   * Sender identification: VAPID, RFC 8292 (ES256 JWT, `Authorization: vapid t=…, k=…`).
// Pure functions (no I/O); unit-tested in tests/unit/push-webpush.test.ts, including a decryption from the
// receiving side. The private VAPID key is passed in by the server and never leaves it.

import { createCipheriv, createECDH, createHmac, createPrivateKey, randomBytes, sign as cryptoSign, type KeyObject } from "node:crypto";

export function b64url(buf: Uint8Array): string {
  return Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function fromB64url(s: string): Buffer {
  return Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

function hmac(key: Uint8Array, data: Uint8Array): Buffer {
  return createHmac("sha256", key).update(data).digest();
}

/** HKDF (RFC 5869) with one expand block, enough for outputs up to 32 bytes. */
function hkdf(salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, length: number): Buffer {
  const prk = hmac(salt, ikm);
  return hmac(prk, Buffer.concat([info, Buffer.from([1])])).subarray(0, length);
}

export type PushKeys = { p256dh: string; auth: string };

/**
 * RFC 8291 §3-4: encrypts `plaintext` for the subscription's keys. `salt` and `senderPrivate` are only passed in
 * by tests; normally both are random per message.
 */
export function encryptPayload(
  plaintext: Uint8Array,
  keys: PushKeys,
  opts: { salt?: Uint8Array; senderPrivate?: Uint8Array } = {},
): Buffer {
  const uaPublic = fromB64url(keys.p256dh);
  const authSecret = fromB64url(keys.auth);
  if (uaPublic.length !== 65 || uaPublic[0] !== 4) throw new Error("p256dh must be an uncompressed P-256 point");
  if (authSecret.length !== 16) throw new Error("auth must be 16 bytes");

  const ecdh = createECDH("prime256v1");
  if (opts.senderPrivate) ecdh.setPrivateKey(Buffer.from(opts.senderPrivate));
  else ecdh.generateKeys();
  const asPublic = ecdh.getPublicKey();
  const sharedSecret = ecdh.computeSecret(uaPublic);

  const keyInfo = Buffer.concat([Buffer.from("WebPush: info\0"), uaPublic, asPublic]);
  const ikm = hkdf(authSecret, sharedSecret, keyInfo, 32);
  const salt = opts.salt ? Buffer.from(opts.salt) : randomBytes(16);
  const cek = hkdf(salt, ikm, Buffer.from("Content-Encoding: aes128gcm\0"), 16);
  const nonce = hkdf(salt, ikm, Buffer.from("Content-Encoding: nonce\0"), 12);

  // One record: plaintext followed by the last-record delimiter 0x02, no padding.
  const cipher = createCipheriv("aes-128-gcm", cek, nonce);
  const body = Buffer.concat([cipher.update(Buffer.concat([Buffer.from(plaintext), Buffer.from([2])])), cipher.final(), cipher.getAuthTag()]);

  const rs = Buffer.alloc(4);
  rs.writeUInt32BE(4096);
  return Buffer.concat([salt, rs, Buffer.from([asPublic.length]), asPublic, body]);
}

/** A P-256 private key from its raw 32-byte form (base64url, as VAPID keys are exchanged) and the public point. */
export function vapidKeyObject(publicKeyB64: string, privateKeyB64: string): KeyObject {
  const pub = fromB64url(publicKeyB64);
  const d = fromB64url(privateKeyB64);
  if (pub.length !== 65 || pub[0] !== 4 || d.length !== 32) throw new Error("invalid VAPID key pair");
  return createPrivateKey({
    key: { kty: "EC", crv: "P-256", d: b64url(d), x: b64url(pub.subarray(1, 33)), y: b64url(pub.subarray(33, 65)) },
    format: "jwk",
  });
}

/** RFC 8292: the Authorization header value for one push service origin. Valid for 12 h (the maximum is 24 h). */
export function vapidAuthorization(
  endpoint: string,
  vapid: { publicKey: string; privateKey: KeyObject; subject: string },
  nowSeconds: number = Math.floor(Date.now() / 1000),
): string {
  const aud = new URL(endpoint).origin;
  const header = b64url(Buffer.from(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const claims = b64url(Buffer.from(JSON.stringify({ aud, exp: nowSeconds + 12 * 3600, sub: vapid.subject })));
  const signingInput = `${header}.${claims}`;
  const signature = cryptoSign("sha256", Buffer.from(signingInput), { key: vapid.privateKey, dsaEncoding: "ieee-p1363" });
  return `vapid t=${signingInput}.${b64url(signature)}, k=${vapid.publicKey}`;
}

export type PushRequest = { url: string; headers: Record<string, string>; body: Buffer };

/** The complete HTTP request for one message to one device. TTL 1 h; urgency high (a P1 safety signal). */
export function buildPushRequest(
  sub: { endpoint: string } & PushKeys,
  payload: string,
  vapid: { publicKey: string; privateKey: KeyObject; subject: string },
): PushRequest {
  const body = encryptPayload(Buffer.from(payload, "utf8"), sub);
  return {
    url: sub.endpoint,
    headers: {
      Authorization: vapidAuthorization(sub.endpoint, vapid),
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      TTL: "3600",
      Urgency: "high",
    },
    body,
  };
}
