// Prefer the WebExtensions `browser` API, falling back to `chrome` for Chromium-based browsers.
// This provides a unified handle to the extension runtime messaging API.
const extensionAPI = globalThis.browser || globalThis.chrome;

(async () => {
  console.log("[Hostname Bridge] content loaded:", location.href);

  // Ask the background/service worker for the current hostname.
  // Using runtime messaging allows the background to compute or retrieve it in a single place.
  const pageHostName = await extensionAPI.runtime.sendMessage({ type: "NEED_HOSTNAME" });

  // Inject a <script> tag into the page's main JS context to expose the value on window.
  // Note: Content scripts run in an isolated world; assigning directly to window here would
  // not affect page scripts. Injecting a script element bridges that gap safely.
  const injectedScript = document.createElement("script");
  injectedScript.textContent = `window.__HOSTNAME=${JSON.stringify(pageHostName)};`;

  // Append to <head> if available, otherwise to <html> to ensure execution.
  (document.head || document.documentElement).appendChild(injectedScript);

  // Remove the node after execution to avoid leaking DOM artifacts.
  injectedScript.remove();

  console.log("[Hostname Bridge] window.__HOSTNAME =", pageHostName);
})();
