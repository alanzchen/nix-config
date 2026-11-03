// Basecamp-safe HTTPS mail links are also Scriptable Universal Links on iOS.
// On macOS, accept the explicit mail form or a nested URL only when it resolves
// to a message:// URL, then hand that message to Mail directly.
const messageIDFromNestedURL = (value) => {
  if (!value) {
    return null;
  }

  let destination = value;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const decoded = decodeURIComponent(destination);
      if (decoded === destination) {
        break;
      }
      destination = decoded;
    } catch {
      return null;
    }
  }

  const match = /^message:\/\/\<([^<>\s]+)\>$/.exec(destination);
  return match ? match[1] : null;
};

const scriptableMailMessageID = (url) => {
  if (
    url.hostname !== "open.scriptable.app" ||
    url.pathname !== "/run/DeepLink"
  ) {
    return null;
  }

  if (url.searchParams.get("type") === "mail") {
    return url.searchParams.get("id");
  }

  return messageIDFromNestedURL(url.searchParams.get("url"));
};

export default {
  defaultBrowser: "Safari",

  rewrite: [
    {
      match: (url) => Boolean(scriptableMailMessageID(url)),

      url: (url) => {
        const messageID = scriptableMailMessageID(url)
          .trim()
          .replace(/^<|>$/g, "");
        return `message://%3C${encodeURIComponent(messageID)}%3E`;
      },
    },
  ],

  handlers: [
    {
      match: (url) => url.protocol === "message:",
      browser: "Mail",
    },
  ],
};
