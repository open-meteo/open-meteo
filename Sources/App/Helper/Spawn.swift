import Foundation


enum SpawnError: Error {
    case commandFailed(cmd: String, returnCode: Int32, args: [String]?, stderr: String?)
    case executableDoesNotExist(cmd: String)
    case posixSpawnFailed(code: Int32)
}

public extension Process {
    static func spawnWithOutput(cmd: String, args: [String]?) throws -> String {
        let data = try spawnWithOutputData(cmd: cmd, args: args)
        return String(data: data, encoding: .utf8) ?? ""
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
    
    static func spawnWithOutputData(cmd: String, args: [String]?) throws -> Data {
        let pipe = Pipe()
        var data = Data()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            data.append(handle.availableData)
        }
        
        let eerror = Pipe()
        var errorData = Data()
        eerror.fileHandleForReading.readabilityHandler = { handle in
            errorData.append(handle.availableData)
        }
        
        let terminationStatus = try Process.spawnWithPipes(cmd: cmd, args: args, stdout: pipe, stderr: eerror)
        
        eerror.fileHandleForReading.readabilityHandler = nil
        if let end = try eerror.fileHandleForReading.readToEnd() {
            errorData.append(end)
        }
        try eerror.fileHandleForReading.close()
        try eerror.fileHandleForWriting.close()
        
        pipe.fileHandleForReading.readabilityHandler = nil
        if let end = try pipe.fileHandleForReading.readToEnd() {
            data.append(end)
        }
        try pipe.fileHandleForReading.close()
        try pipe.fileHandleForWriting.close()
        
        guard terminationStatus == 0 else {
            let error = String(data: errorData, encoding: .utf8) ?? ""
            throw SpawnError.commandFailed(cmd: cmd, returnCode: terminationStatus, args: args, stderr: error)
        }
        
        return data
    }
    
    /// Does not capture stderror. As soon as pipes are used, swift tends to crash from time to time on linux
    static func spawn(cmd: String, args: [String]?, stdout: Pipe? = nil, stderr: Pipe? = nil) throws {
        let terminationStatus = try Process.spawnWithPipes(cmd: cmd, args: args, stdout: stdout, stderr: stderr)
        
        guard terminationStatus == 0 else {
            throw SpawnError.commandFailed(cmd: cmd, returnCode: terminationStatus, args: args, stderr: "")
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
    
    /// Call `posix_spawn` directly and wait for child to finish. Uses PATH variable to find executable
    static func nativeSpawn(cmd: String, args: [String]) throws -> Int32 {
        /// Command and arguments as C string
        let argv = ([cmd] + args).map { $0.withCString(strdup) } + [nil]
        
        defer {
            for case let arg? in argv {
                free(arg)
            }
        }
        
        var pid: Int32 = 0
        let ret = posix_spawnp(&pid, cmd, nil, nil, argv, nil)
        guard ret == 0 else {
            throw SpawnError.posixSpawnFailed(code: ret)
        }
        
        var status: Int32 = -2
        var waitResult: Int32 = -1
        repeat {
            waitResult = waitpid(pid, &status, 0)
        } while waitResult == -1 && errno == EINTR
        
        return status
    }
}
