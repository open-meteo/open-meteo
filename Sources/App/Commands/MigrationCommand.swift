import Foundation
import Vapor

struct MigrationCommand: Command {
    struct Signature: CommandSignature {
        
    }
    
    var help: String {
        "Perform database migration"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        // loop over data directory
        
        let pathUrl = URL(fileURLWithPath: OpenMeteo.dataDirectory, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            fatalError("No files in \(pathUrl)")
        }
        
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let name = resourceValues.name, 
                  !name.contains("~"),
                  isDirectory
            else {
                continue
            }
            
            if name.starts(with: "omfile-") || name.starts(with: "archive-") || name.starts(with: "master-") {
                //print("found \(name)")
                let domain = name.split(separator: "-", maxSplits: 1)[1]
                let domainDirectory = "\(OpenMeteo.dataDirectory)\(domain)"
                print("Create domain directory \(domainDirectory)")
                let subPath = "\(OpenMeteo.dataDirectory)\(name)"
                
                guard let directoryEnumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: subPath, isDirectory: true), includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
                    fatalError("No files in \(pathUrl)")
                }
                for case let fileURL as URL in directoryEnumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                          let isDirectory = resourceValues.isDirectory,
                          let file = resourceValues.name,
                          !file.contains("~"),
                          !isDirectory
                    else {
                        continue
                    }
                    
                    //print("found file \(file)")
                    let type: String
                    if file.starts(with: "omfile-") {
                        type = "chunk"
                    } else if name.starts(with: "archive-") {
                        type = "year"
                    } else if name.starts(with: "master-") {
                        type = "master"
                    } else {
                        continue
                    }
                    
                    guard let new = transform(file: file, type: type) else {
                        continue
                    }
                    print("Move \(file) to \(new.directory)/\(new.file)")
                    
                }
                
                // create domain directory
                // loop over omfile-content
                // move Hsurf + soil
                // move create variables directory, move time chunks
            }
        }
        
    }
    
    func transform(file: String, type: String) -> (directory: String, file: String)? {
        let suffixWithOm = file.split(separator: "_").last!
        let suffix = suffixWithOm.split(separator: ".").first!
        
        if file.starts(with: "HSURF.om") || file.starts(with: "soil_type.om") {
            return ("static", file)
        }
        
        if file.hasSuffix("linear_bias_seasonal.om") {
            let variable = file.replacingOccurrences(of: "_linear_bias_seasonal.om", with: "")
            return (variable, "linear_bias_seasonal.om")
        }
        
        /*if file.contains("member") {
            // name = river_discharge_member02_89.om
            if #available(macOS 13.0, *) {
                /// member number e.g. "00"
                guard let member = file.split(separator: "_member").last?.split(separator: "_").first else {
                    fatalError("Could not split member file name")
                }
                guard let variable = file.split(separator: "_member").first else {
                    fatalError()
                }
                return (String(variable), "member\(member)_\(type)_\(suffix).om")
            } else {
                fatalError()
            }
        }*/
        
        if Int(suffix) != nil {
            let variable = file.replacingOccurrences(of: "_\(suffixWithOm)", with: "")
            if let last = variable.split(separator: "_").last, let member = Int(last) {
                // member file from CFS like "soil_moisture_100_to_200cm_3_97.om"
                let variable = file.replacingOccurrences(of: "_\(last)_\(suffixWithOm)", with: "")
                return ("\(variable)_member\(member.zeroPadded(len: 2))", "\(type)_\(suffix).om")
            }
            return (variable, "\(type)_\(suffix).om")
        }
        
        if file == "init.txt" || file == "HSURF.nc" {
            return nil
        }
        
        fatalError("No match for \(file)")
    }
}
