//
//  SafariWebExtensionHandler.swift
//  FirstExtension Extension
//
//  Created by Simon Girard on 01.11.2025.
//

import SafariServices
import os.log

/// Handles incoming messages from the Safari Web Extension and returns responses.
///
/// Expected input format (from JavaScript side):
///
/// [
///   SFExtensionMessageKey: [ "op": "getHostname" ]
/// ]
///
/// Success response format:
///
/// [
///   SFExtensionMessageKey: [ "hostName": "<device-hostname>" ]
/// ]
///
/// Error response format (unknown op, invalid payload, etc.):
///
/// [
///   SFExtensionMessageKey: [ "error": "<ErrorCode>" ]
/// ]
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SafariWebExtension", category: "ExtensionHandler")

    // Supported operations sent from the web extension.
    private enum Operation: String {
        case getHostname
    }

    func beginRequest(with context: NSExtensionContext) {
        // Extract the first input item and its message payload.
        guard
            let item = context.inputItems.first as? NSExtensionItem,
            let messagePayload = item.userInfo?[SFExtensionMessageKey] as? [String: Any]
        else {
            logger.error("Invalid or missing input items / payload.")
            complete(context, withError: "InvalidPayload")
            return
        }

        // Parse the operation type.
        guard let opString = messagePayload["op"] as? String, let operation = Operation(rawValue: opString) else {
            logger.error("Unknown or missing operation in payload: \(String(describing: messagePayload["op"]))")
            complete(context, withError: "UnknownOperation")
            return
        }

        // Dispatch based on operation.
        switch operation {
        case .getHostname:
            handleGetHostname(context: context)
        }
    }
    
    private func handleRunUname(context: NSExtensionContext) {
        do {
            let output = try runCommand("/usr/bin/uname", ["-a"])
            let response = NSExtensionItem()
            response.userInfo = [ SFExtensionMessageKey: [ "hostName": output ] ]
            context.completeRequest(returningItems: [response], completionHandler: nil)
        } catch {
            logger.error("Command failed: \(String(describing: error))")
            complete(context, withError: "CommandFailed")
        }
    }

    /// Retrieves the current device host name and returns it to the extension caller.
    private func handleGetHostname(context: NSExtensionContext) {
        // Use a C buffer to retrieve host name via gethostname(3).
        var buffer = [CChar](repeating: 0, count: Int(MAXHOSTNAMELEN))
        let result = gethostname(&buffer, Int(MAXHOSTNAMELEN))

        guard result == 0 else {
            logger.error("gethostname failed with errno: \(errno)")
            complete(context, withError: "HostNameUnavailable")
            return
        }

        let hostName = String(cString: buffer)
        logger.debug("Returning host name: \(hostName)")

        let response = NSExtensionItem()
        response.userInfo = [
            SFExtensionMessageKey: [
                "hostName": hostName
            ]
        ]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    // MARK: - Helpers

    /// Completes the request with a structured error payload.
    private func complete(_ context: NSExtensionContext, withError errorCode: String) {
        let response = NSExtensionItem()
        response.userInfo = [
            SFExtensionMessageKey: [
                "error": errorCode
            ]
        ]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
    
    private func runCommand(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let err = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "CommandError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: err])
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
