const MAX_HEADER_LENGTH = 320;

function clean(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || normalized.length > MAX_HEADER_LENGTH) return null;
  return normalized;
}

function safeProfileUrl(value) {
  const normalized = clean(value);
  if (!normalized) return null;

  try {
    const url = new URL(normalized);
    return url.protocol === "https:" ? url.href : null;
  } catch {
    return null;
  }
}

export function readIdentity(headers, trustIdentityHeaders = true) {
  if (!trustIdentityHeaders) {
    return { authenticated: false, login: null, name: null, profilePic: null };
  }

  const login = clean(headers.get("tailscale-user-login"));
  if (!login) {
    return { authenticated: false, login: null, name: null, profilePic: null };
  }

  return {
    authenticated: true,
    login,
    name: clean(headers.get("tailscale-user-name")) || login,
    profilePic: safeProfileUrl(headers.get("tailscale-user-profile-pic")),
  };
}
