//
//  Utils.swift
//  Runner
//
//  Created by Zaid on 12/4/23.
//

import Foundation
import linphonesw

extension String {
    func applyPatternOnNumbers(pattern: String, replacementCharacter: Character) -> String {
        var pureNumber = self.replacingOccurrences( of: "[^0-9]", with: "", options: .regularExpression)
        for index in 0 ..< pattern.count {
            guard index < pureNumber.count else { return pureNumber }
            let stringIndex = String.Index(utf16Offset: index, in: pattern)
            let patternCharacter = pattern[stringIndex]
            guard patternCharacter != replacementCharacter else { continue }
            pureNumber.insert(patternCharacter, at: stringIndex)
        }
        return pureNumber
    }
}


class LoggingServiceManager: LoggingServiceDelegate {

    var fileUrl: URL?
    init() {
        LoggingService.Instance.logLevel = LogLevel.Debug
        let loggingService = LoggingService.Instance
        do {
            let dirUrl = try FileManager.default.url(for: .applicationDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            fileUrl = dirUrl.appendingPathComponent("TEXT_LOGGER").appendingPathExtension("txt")
        } catch {
            NSLog("MDBM ERROR Getting fileUrl")
        }
        
//        if(fileUrl != nil && FileManager.default.fileExists(atPath: fileUrl!.path)) {
//            NSLog("MDBM File exist")
//            let contents = try! String(contentsOfFile: fileUrl!.path)
//            let lines = contents.split(separator:"\n")
//            for line in lines {
//                print("MDBM line= \(line)")
//            }
//            let url = "https://zaid-fusion-dev.fusioncomm.net/api/v2/logging/log"
//
//            let request = MultipartFormDataRequest(url: URL(string: url)!)
//            request.addDataField(fieldName:  "fm_logs6695503dca9ca", fileName: "logs", data: fil, mimeType: mimeType)
//            URLSession.shared.dataTask(with: request, completionHandler: {data,urlResponse,error in
//                
//
//            }).resume()
//        }
        loggingService.addDelegate(delegate: self)
    }

    func onLogMessageWritten(
        logService: LoggingService,
        domain: String,
        level: LogLevel,
        message: String)
    {
        let levelStr: String

        switch level {
            case .Debug:
                levelStr = "Debug"
            case .Trace:
                levelStr = "Trace"
            case .Message:
                levelStr = "Message"
            case .Warning:
                levelStr = "Warning"
            case .Error:
                levelStr = "Error"
            case .Fatal:
                levelStr = "Fatal"
            default:
                levelStr = "unknown"
        }
        guard let log = "\(levelStr) [\(domain)] \(message)".data(using: .utf8) else {
            "Unable to convert string to data"
            return
        }
        DispatchQueue.main.async {
            do {

                if FileManager.default.fileExists(atPath: self.fileUrl!.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.fileUrl!) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(log)
                        fileHandle.closeFile()
                    }
                } else {
                    try? log.write(to: self.fileUrl!, options: .atomic)
                }
            } catch {
                NSLog("MDBM Error writing logs to file \(error)")
            }
        }
       
        
    }

    
}
