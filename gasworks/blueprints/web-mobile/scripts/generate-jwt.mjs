#!/usr/bin/env node
// Generates Supabase anon or service_role JWTs from a JWT secret.
// Usage: node generate-jwt.mjs <jwt-secret> <role>
//   role: "anon" or "service_role"

import { createHmac } from "node:crypto";

const [, , secret, role] = process.argv;

if (!secret || !["anon", "service_role"].includes(role)) {
  console.error("Usage: node generate-jwt.mjs <jwt-secret> <anon|service_role>");
  process.exit(1);
}

function base64url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

const header = base64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));

const payload = base64url(
  JSON.stringify({
    role,
    iss: "supabase",
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 10 * 365 * 24 * 60 * 60, // 10 years
  })
);

const signature = base64url(
  createHmac("sha256", secret).update(`${header}.${payload}`).digest()
);

process.stdout.write(`${header}.${payload}.${signature}`);
