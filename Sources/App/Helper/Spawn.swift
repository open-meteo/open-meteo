import Foundation
import NIOConcurrencyHelpers
import NIOCore


enum SpawnError: Error {
    case commandFailed(cmd: String, returnCode: Int32, args: [String]?, stderr: String?)
    case executableDoesNotExist(cmd: String)
}

public extension Process {
    /// Get the absolute path of an executable
    static func findExecutable(cmd: String) async throws -> String {
        if cmd == "cdo" {
            // workaround for mac because cdo is not in PATH
            if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/cdo") {
                return "/opt/homebrew/bin/cdo"
            }
            if FileManager.default.fileExists(atPath: "/usr/local/bin/cdo") {
                return "/usr/local/bin/cdo"
            }
        }
        
        let command = cmd.hasPrefix("/") ? cmd : (try? await spawnWithOutput(cmd: "/usr/bin/which", args: [cmd]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? ""

        guard FileManager.default.fileExists(atPath: command) else {
            throw SpawnError.executableDoesNotExist(cmd: cmd)
        }
        return command
    }
    
    /// Spawn async. Returns termination status code
    static func spawnWithPipes(cmd: String, args: [String]?, stdout: Pipe? = nil, stderr: Pipe? = nil) async throws -> Int32 {
        let command = try await findExecutable(cmd: cmd)
        let proc = Process()
        
        return try await withTaskCancellationHandler {
            // unset terminationHandler to make sure `continuation` can be released
            proc.terminationHandler = nil
            proc.terminate()
        } operation: {
            return try await withCheckedThrowingContinuation { continuation in
                proc.executableURL = URL(fileURLWithPath: command)
                proc.arguments = args
                proc.terminationHandler = { task in
                    // unset terminationHandler to make sure `continuation` can be released
                    task.terminationHandler = nil
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
                        // unset terminationHandler to make sure `continuation` can be released
                        proc.terminationHandler = nil
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Always captures `stderr`. Otherwise it is just flooding logs.
    static func spawn(cmd: String, args: [String]?, stdout: Pipe? = nil) async throws {
        let eerror = Pipe()
        var errorData = ByteBuffer()
        eerror.fileHandleForReading.readabilityHandler = { handle in
            errorData.writeData(handle.availableData)
        }
        
        let terminationStatus = try await Process.spawnWithPipes(cmd: cmd, args: args, stdout: stdout, stderr: eerror)
        
        eerror.fileHandleForReading.readabilityHandler = nil
        if let end = try eerror.fileHandleForReading.readToEnd() {
            errorData.writeData(end)
        }
        try eerror.fileHandleForReading.close()
        try eerror.fileHandleForWriting.close()
        
        guard terminationStatus == 0 else {
            let error = errorData.readString(length: errorData.readableBytes) ?? ""
            throw SpawnError.commandFailed(cmd: cmd, returnCode: terminationStatus, args: args, stderr: error)
        }
    }
    
    static func spawnWithOutputData(cmd: String, args: [String]?) async throws -> ByteBuffer {
        let pipe = Pipe()
        var data = ByteBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            data.writeData(handle.availableData)
        }
        
        try await Process.spawn(cmd: cmd, args: args, stdout: pipe)
        
        pipe.fileHandleForReading.readabilityHandler = nil
        if let end = try pipe.fileHandleForReading.readToEnd() {
            data.writeData(end)
        }
        try pipe.fileHandleForReading.close()
        try pipe.fileHandleForWriting.close()
        return data
    }
    
    static func spawnWithOutput(cmd: String, args: [String]?) async throws -> String {
        var data = try await spawnWithOutputData(cmd: cmd, args: args)
        return data.readString(length: data.readableBytes) ?? ""
    }
    
    
    /*
     All synchornoious functions below
     */
    
    static func spawnWithOutput(cmd: String, args: [String]?) throws -> String {
        var data = try spawnWithOutputData(cmd: cmd, args: args)
        return data.readString(length: data.readableBytes) ?? ""
    }
    
    static func findExecutable(cmd: String) throws -> String {
        if cmd == "cdo" {
            // workaround for mac because cdo is not in PATH
            if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/cdo") {
                return "/opt/homebrew/bin/cdo"
            }
            if FileManager.default.fileExists(atPath: "/usr/local/bin/cdo") {
                return "/usr/local/bin/cdo"
            }
        }
        
        let command = cmd.hasPrefix("/") ? cmd : (try? spawnWithOutput(cmd: "/usr/bin/which", args: [cmd]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? ""

        guard FileManager.default.fileExists(atPath: command) else {
            throw SpawnError.executableDoesNotExist(cmd: cmd)
        }
        return command
    }
    
    /// TODO back to data
    static func spawnWithOutputData(cmd: String, args: [String]?) throws -> ByteBuffer {
        let pipe = Pipe()
        var data = ByteBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            data.writeData(handle.availableData)
        }
        
        try Process.spawn(cmd: cmd, args: args, stdout: pipe)
        
        pipe.fileHandleForReading.readabilityHandler = nil
        if let end = try pipe.fileHandleForReading.readToEnd() {
            data.writeData(end)
        }
        try pipe.fileHandleForReading.close()
        try pipe.fileHandleForWriting.close()
        return data
    }
    
    /// Always captures `stderr`. Otherwise it is just flooding logs.
    static func spawn(cmd: String, args: [String]?, stdout: Pipe? = nil) throws {
        let eerror = Pipe()
        var errorData = ByteBuffer()
        eerror.fileHandleForReading.readabilityHandler = { handle in
            errorData.writeData(handle.availableData)
        }
        
        let terminationStatus = try Process.spawnWithPipes(cmd: cmd, args: args, stdout: stdout, stderr: eerror)
        
        eerror.fileHandleForReading.readabilityHandler = nil
        if let end = try eerror.fileHandleForReading.readToEnd() {
            errorData.writeData(end)
        }
        try eerror.fileHandleForReading.close()
        try eerror.fileHandleForWriting.close()
        
        guard terminationStatus == 0 else {
            let error = errorData.readString(length: errorData.readableBytes) ?? ""
            throw SpawnError.commandFailed(cmd: cmd, returnCode: terminationStatus, args: args, stderr: error)
        }
    }
    
    static func spawnWithPipes(cmd: String, args: [String]?, stdout: Pipe? = nil, stderr: Pipe? = nil) throws -> Int32 {
        let command = try findExecutable(cmd: cmd)
        let proc = Process()
        
        proc.executableURL = URL(fileURLWithPath: command)
        proc.arguments = args
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
            try proc.run()
        }
        
        proc.waitUntilExit()
        
        return proc.terminationStatus
    }
}
