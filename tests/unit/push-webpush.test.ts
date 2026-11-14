import { createDecipheriv, createECDH, createHmac, createPublicKey, randomBytes, verify } from "node:crypto";
import { describe, expect, it } from "vitest";
import { b64url, buildPushRequest, encryptPayload, fromB64url, vapidAuthorization, vapidKeyObject } from "@/features/push/webpush";
import { PUSH_PAYLOAD } from "@/features/push/rules";

// SIG2 (ADR-076): RFC 8291 encryption checked by decrypting as the browser would (RFC 8291 §3.4, RFC 8188 §2),
// and the RFC 8292 VAPID token checked with the public key. Synthetic keys only; no network.

function hkdf(salt: Buffer, ikm: Buffer, info: Buffer, len: number): Buffer {
  const prk = createHmac("sha256", salt).update(ikm).digest();
  return createHmac("sha256", prk).update(Buffer.concat([info, Buffer.from([1])])).digest().subarray(0, len);
}

function browser() {
  const ua = createECDH("prime256v1");
  ua.generateKeys();
  const auth = randomBytes(16);
  return { ua, keys: { p256dh: b64url(ua.getPublicKey()), auth: b64url(auth) }, auth };
}

function decrypt(body: Buffer, ua: ReturnType<typeof createECDH>, auth: Buffer): Buffer {
  const salt = body.subarray(0, 16);
  const rs = body.readUInt32BE(16);
  const idlen = body[20];
  const asPublic = body.subarray(21, 21 + idlen);
  const ciphertext = body.subarray(21 + idlen);
  expect(rs).toBe(4096);
  expect(idlen).toBe(65);
  const shared = ua.computeSecret(asPublic);
  const ikm = hkdf(auth, shared, Buffer.concat([Buffer.from("WebPush: info\0"), ua.getPublicKey(), asPublic]), 32);
  const cek = hkdf(salt, ikm, Buffer.from("Content-Encoding: aes128gcm\0"), 16);
  const nonce = hkdf(salt, ikm, Buffer.from("Content-Encoding: nonce\0"), 12);
  const d = createDecipheriv("aes-128-gcm", cek, nonce);
  d.setAuthTag(ciphertext.subarray(ciphertext.length - 16));
  const plain = Buffer.concat([d.update(ciphertext.subarray(0, ciphertext.length - 16)), d.final()]);
  expect(plain[plain.length - 1]).toBe(2);   // last-record delimiter, no padding
  return plain.subarray(0, plain.length - 1);
}

function vapidPair() {
  const e = createECDH("prime256v1");
  e.generateKeys();
  // Node returns the private scalar without leading zero bytes (about 1 key in 256 is 31 bytes);
  // a VAPID private key is exchanged as exactly 32 bytes, so pad it as a key generator would.
  const d = Buffer.concat([Buffer.alloc(32), e.getPrivateKey()]).subarray(-32);
  return { publicKey: b64url(e.getPublicKey()), privateKey: b64url(d) };
}

describe("encryptPayload (RFC 8291)", () => {
  it("decrypts on the receiving side to exactly the fixed payload", () => {
    const b = browser();
    const body = encryptPayload(Buffer.from(PUSH_PAYLOAD), b.keys);
    expect(decrypt(body, b.ua, b.auth).toString("utf8")).toBe(PUSH_PAYLOAD);
  });

  it("uses a fresh salt and sender key per message", () => {
    const b = browser();
    const one = encryptPayload(Buffer.from("x"), b.keys);
    const two = encryptPayload(Buffer.from("x"), b.keys);
    expect(one.subarray(0, 16).equals(two.subarray(0, 16))).toBe(false);
    expect(one.subarray(21, 86).equals(two.subarray(21, 86))).toBe(false);
  });

  it("is deterministic with an injected salt and sender key (test hook only)", () => {
    const b = browser();
    const salt = randomBytes(16);
    const sender = createECDH("prime256v1");
    sender.generateKeys();
    const opts = { salt, senderPrivate: sender.getPrivateKey() };
    expect(encryptPayload(Buffer.from("x"), b.keys, opts).equals(encryptPayload(Buffer.from("x"), b.keys, opts))).toBe(true);
  });

  it("refuses malformed subscription keys", () => {
    expect(() => encryptPayload(Buffer.from("x"), { p256dh: b64url(randomBytes(65)), auth: b64url(randomBytes(16)) })).toThrow();
    const b = browser();
    expect(() => encryptPayload(Buffer.from("x"), { p256dh: b.keys.p256dh, auth: b64url(randomBytes(8)) })).toThrow();
  });
});

describe("vapidAuthorization (RFC 8292)", () => {
  it("signs an ES256 token for the push service origin that verifies with the public key", () => {
    const pair = vapidPair();
    const header = vapidAuthorization("https://fcm.googleapis.com/fcm/send/syn-1",
      { publicKey: pair.publicKey, privateKey: vapidKeyObject(pair.publicKey, pair.privateKey), subject: "mailto:betrieb@navora.test" }, 1_800_000_000);
    const m = header.match(/^vapid t=([^.]+)\.([^.]+)\.([^,]+), k=(.+)$/);
    expect(m).not.toBeNull();
    const [, h, c, s, k] = m!;
    expect(k).toBe(pair.publicKey);
    expect(JSON.parse(fromB64url(h).toString())).toEqual({ typ: "JWT", alg: "ES256" });
    expect(JSON.parse(fromB64url(c).toString())).toEqual({ aud: "https://fcm.googleapis.com", exp: 1_800_000_000 + 43_200, sub: "mailto:betrieb@navora.test" });
    const pub = fromB64url(pair.publicKey);
    const key = createPublicKey({ key: { kty: "EC", crv: "P-256", x: b64url(pub.subarray(1, 33)), y: b64url(pub.subarray(33)) }, format: "jwk" });
    expect(verify("sha256", Buffer.from(`${h}.${c}`), { key, dsaEncoding: "ieee-p1363" }, fromB64url(s))).toBe(true);
  });

  it("refuses an invalid key pair", () => {
    expect(() => vapidKeyObject("abc", "def")).toThrow();
  });
});

describe("buildPushRequest", () => {
  it("posts the encrypted fixed payload with high urgency and a short TTL, and nothing in the URL beyond the endpoint", () => {
    const b = browser();
    const pair = vapidPair();
    const endpoint = "https://fcm.googleapis.com/fcm/send/syn-2";
    const req = buildPushRequest({ endpoint, ...b.keys }, PUSH_PAYLOAD,
      { publicKey: pair.publicKey, privateKey: vapidKeyObject(pair.publicKey, pair.privateKey), subject: "mailto:betrieb@navora.test" });
    expect(req.url).toBe(endpoint);
    expect(req.headers["Content-Encoding"]).toBe("aes128gcm");
    expect(req.headers.Urgency).toBe("high");
    expect(req.headers.TTL).toBe("3600");
    expect(decrypt(req.body, b.ua, b.auth).toString("utf8")).toBe(PUSH_PAYLOAD);
  });
});
