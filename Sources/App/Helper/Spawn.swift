import Foundation
import NIOConcurrencyHelpers


enum SpawnError: Error {
    case commandFailed(cmd: String, returnCode: Int32, args: [String]?, stderr: String?)
    case executableDoesNotExist(cmd: String)
}

public extension Process {
    /// Get the absolute path of an executable
    static func findExecutable(cmd: String) async throws -> String {
        var command: String
        if !cmd.hasPrefix("/") {
            command = (try? await spawnWithOutput(cmd: "/usr/bin/which", args: [cmd]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? ""
        } else {
            command = cmd
        }
        if cmd == "cdo" && command == "" && FileManager.default.fileExists(atPath: "/opt/homebrew/bin/cdo") {
            // workaround for mac because cdo is not in PATH
            if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/cdo") {
                command = "/opt/homebrew/bin/cdo"
            }
            if FileManager.default.fileExists(atPath: "/usr/local/bin/cdo") {
                command = "/usr/local/bin/cdo"
            }
        }
        guard FileManager.default.fileExists(atPath: command) else {
            throw SpawnError.executableDoesNotExist(cmd: cmd)
        }
        return command
    }
    
    /// Spawn async. Returns termination status code
    static func spawn(cmd: String, args: [String]?, stdout: Pipe? = nil, stderr: Pipe? = nil) async throws -> Int32 {
        let command = try await findExecutable(cmd: cmd)
        let proc = Process()
        
        return try await withTaskCancellationHandler {
            proc.terminate()
        } operation: {
            return try await withCheckedThrowingContinuation { continuation in
                proc.executableURL = URL(fileURLWithPath: command)
                proc.arguments = args
                proc.terminationHandler = { task in
                    continuation.resume(returning: task.terminationStatus)
                }
                if let pipe = stdout {
                    proc.standardOutput = pipe
                }
                if let pipe = stderr {
                    proc.standardError = pipe
                }
                do {
                    try proc.run()
                } catch {
                    // somehow this crashes from time to time with a bad file descriptor
                    // retry once
                    do {
                        try proc.run()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    static func spawnOrDie(cmd: String, args: [String]?) async throws {
        let terminationStatus = try await Process.spawn(cmd: cmd, args: args)
        guard terminationStatus == 0 else {
            throw SpawnError.commandFailed(cmd: cmd, returnCode: terminationStatus, args: args, stderr: nil)
        }
    }
    
    static func spawnWithOutputData(cmd: String, args: [String]?) async throws -> Data {
        let pipe = Pipe()
        
        var data = Data()
        
        let eerror = Pipe()
        var errorData = Data()
        eerror.fileHandleForReading.readabilityHandler = { handle in
            errorData.append(handle.availableData)
        }
        pipe.fileHandleForReading.readabilityHandler = { handle in
            data.append(handle.availableData)
        }
        
        let terminationStatus = try await Process.spawn(cmd: cmd, args: args, stdout: pipe, stderr: eerror)
        
        if let end = try pipe.fileHandleForReading.readToEnd() {
            data.append(end)
        }
        if let end = try eerror.fileHandleForReading.readToEnd() {
            errorData.append(end)
        }
        
        // Somehow pipes do not seem to close automatically
        try pipe.fileHandleForReading.close()
        try pipe.fileHandleForWriting.close()
        try eerror.fileHandleForReading.close()
        try eerror.fileHandleForWriting.close()
        
        guard terminationStatus == 0 else {
            let error = String(data: errorData, encoding: .utf8)
            throw SpawnError.commandFailed(cmd: cmd, returnCode: terminationStatus, args: args, stderr: error)
        }
        return data
    }
    
    static func spawnWithOutput(cmd: String, args: [String]?) async throws -> String {
        return String(data: try await spawnWithOutputData(cmd: cmd, args: args), encoding: String.Encoding.utf8)!
    }
}
