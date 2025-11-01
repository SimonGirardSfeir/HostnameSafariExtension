// Listen for messages from content scripts or other extension parts.
// We respond to a specific message type to fetch the hostname from the native host.
browser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  // Only handle the specific request for hostname.
  if (message?.type === "NEED_HOSTNAME") {
    (async () => {
      try {
        // Forward the request to the native messaging host. The host identifier must
        // match the one declared in your native messaging manifest.
        const nativeReply = await browser.runtime.sendNativeMessage("application.id",
          { op: "getHostname" }
        );

        // Extract the hostname from the native reply; default to null if missing.
        const hostName = nativeReply?.hostName ?? null;
        sendResponse(hostName);
      } catch (error) {
        // Log and return null on failure so callers can handle the absence gracefully.
        console.error("[Hostname Bridge] native error:", error);
        sendResponse(null);
      }
    })();

    // Important: Returning true keeps the message channel open for the async response.
    // This is indispensable for Safari and required by the WebExtensions messaging contract.
    return true;
  }
});
