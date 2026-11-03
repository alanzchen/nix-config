// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-purple; icon-glyph: magic;
function hasScheme(value) {
  return /^[A-Za-z][A-Za-z0-9+.-]*:/.test(value);
}

function decodeUntilScheme(value) {
  let target = value.trim();

  for (let attempt = 0; attempt < 3; attempt += 1) {
    if (hasScheme(target)) return target;

    try {
      target = decodeURIComponent(target);
    } catch (error) {
      return null;
    }
  }

  return null;
}

function normalizeMessageURL(target) {
  if (!/^message:/i.test(target)) return target;

  let decoded = target;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const next = decodeURIComponent(decoded);
      if (next === decoded) break;
      decoded = next;
    } catch (error) {
      return target;
    }
  }

  const match = /^message:\/\/<([^<>\s]+)>$/i.exec(decoded);
  return match
    ? `message://%3C${encodeURIComponent(match[1])}%3E`
    : target;
}

const target = decodeUntilScheme(args.queryParameters.url || "");

if (!target) {
  throw new Error("Missing or invalid url parameter.");
}

Safari.open(normalizeMessageURL(target));
Script.complete();