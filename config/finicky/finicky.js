// Mac counterpart of Scriptable's DeepLink.js. The HTTPS wrapper remains
// shareable in Basecamp; Finicky unwraps it before choosing the destination app.
// Home Manager substitutes this path with the bundled native URL opener.
const systemUrlOpener = "@deepLinkOpener@";

const hasScheme = (value) => /^[A-Za-z][A-Za-z0-9+.-]*:/.test(value);

const decodeUntilScheme = (value) => {
  let target = value.trim();
  for (let attempt = 0; attempt < 3; attempt += 1) {
    if (hasScheme(target)) return target;
    try {
      target = decodeURIComponent(target);
    } catch {
      return null;
    }
  }
  return null;
};

const normalizeMessageURL = (target) => {
  if (!/^message:/i.test(target)) return target;
  let decoded = target;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const next = decodeURIComponent(decoded);
      if (next === decoded) break;
      decoded = next;
    } catch {
      return target;
    }
  }
  const match = /^message:\/\/<([^<>\s]+)>$/i.exec(decoded);
  return match
    ? `message://%3C${encodeURIComponent(match[1])}%3E`
    : target;
};

const scriptableDestination = (url) => {
  if (
    !["https:", "http:"].includes(url.protocol) ||
    url.hostname !== "open.scriptable.app" ||
    url.pathname !== "/run/DeepLink"
  ) return null;

  // Keep the older explicit mail form working alongside Scriptable's url form.
  if (url.searchParams.get("type") === "mail") {
    const id = (url.searchParams.get("id") || "").trim().replace(/^<|>$/g, "");
    return id && !/[<>\s]/.test(id)
      ? `message://%3C${encodeURIComponent(id)}%3E`
      : null;
  }
  const target = decodeUntilScheme(url.searchParams.get("url") || "");
  if (!target) return null;
  try {
    const destination = new URL(normalizeMessageURL(target));
    // Never dispatch Finicky back to itself through LaunchServices.
    return destination.protocol === "finicky:" ? null : destination.href;
  } catch {
    return null;
  }
};

export default {
  defaultBrowser: "Safari",
  rewrite: [
    {
      match: (url) => Boolean(scriptableDestination(url)),
      url: (url) => scriptableDestination(url),
    },
  ],
  handlers: [
    {
      match: (url) => url.protocol === "message:",
      browser: "Mail",
    },
    {
      match: (url) => !["https:", "http:", "finicky:"].includes(url.protocol),
      browser: (url) => ({
        name: systemUrlOpener,
        appType: "path",
        // Finicky 4.2.2 passes these as argv to /usr/bin/open. A new helper
        // instance receives each URL as one argument, never as shell code.
        args: ["-n", "--args", url.href],
      }),
    },
  ],
};
