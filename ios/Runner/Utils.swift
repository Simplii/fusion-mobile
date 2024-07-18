//
//  Utils.swift
//  Runner
//
//  Created by Zaid on 12/4/23.
//

import Foundation
import linphonesw
import os

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

func sendLogsToServer(file:URL){
    let url = "https://zaid-fusion-dev.fusioncomm.net/api/v2/logging/log"
    let request = MultipartFormDataRequest(url: URL(string: url)!)

    do {
        try request.addDataField(
            fieldName: "fm_logs6695503dca9ca",
            fileName: "logs",
            data: Data(contentsOf: file),
            mimeType: "txt"
        )
        URLSession.shared.dataTask(
            with: request,
            completionHandler: {data, urlResponse, error in
                if(data != nil) {
                    do {
                        let resp:Resp = try JSONDecoder().decode(Resp.self, from: data!)
                        if (resp.success) {
                            NSLog("MDBM resp=\(resp.success)")
                            if #available(iOS 14.0, *) {
                                let logger =
                                    Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LoggingService")
                                logger.debug("MDBM resp=\(resp.success)")
                            } else {
                                NSLog("MDBM resp=\(resp.success)")
                            }
                        }
                    } catch {
                        if #available(iOS 14.0, *) {
                            let logger =
                                Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LoggingService")
                            logger.error("MDBM Error decoding server message \(error)")
                        } else {
                            NSLog("MDBM Error decoding server message \(error)")
                        }
                    }
                }
                if #available(iOS 14.0, *) {
                    let logger =
                        Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LoggingService")
                    logger.error("MDBM resposen error=\(String(describing: error))")
                } else {
                    NSLog("MDBM resposen error=\(String(describing: error))")
                }
            }).resume()
    } catch {
        if #available(iOS 14.0, *) {
            let logger =
                Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LoggingService")
            logger.error("MDBM Error sending logs to server \(error)")
        } else {
            NSLog("MDBM Error sending logs to server \(error)")
        }
    }
}


class LoggingServiceManager: LoggingServiceDelegate {
    let fileManager: FileManager = FileManager.default
    let userDomain: String = UserDefaults.standard.string(forKey: "domain") ?? ""
    var fileUrl: URL?
    init() {
        LoggingService.Instance.logLevel = LogLevel.Debug
        let loggingService = LoggingService.Instance
        do {
            let dirUrl = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            fileUrl = dirUrl.appendingPathComponent("TEXT_LOGGER").appendingPathExtension("txt")
        } catch {
            print("MDBM ERROR Getting fileUrl")
        }
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
        guard let log = "level=\(levelStr),package=[\(domain)],message=\(message),domain=\(userDomain)".data(using: .utf8) else {
            "Unable to convert string to data"
            return
        }
        DispatchQueue.main.async {
            do {
                if(self.fileUrl == nil) {
                    throw NSError(
                        domain: "FM",
                        code: NSFileNoSuchFileError ,
                        userInfo: [NSLocalizedDescriptionKey: "log file is nil"]
                    )
                }
                
                if self.fileManager.fileExists(atPath: self.fileUrl!.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.fileUrl!) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(log)
                        
                        let fileSize = try self.fileManager.attributesOfItem(
                            atPath: self.fileUrl!.path)[FileAttributeKey.size] as? UInt64
                        
                        if(fileSize ?? 0 >= 250000) {
                            sendLogsToServer(file: self.fileUrl!)
                            try fileHandle.truncate(atOffset: 0)
                            print("MDBM file truncated")
                        }
                        fileHandle.closeFile()
                    }
                } else {
                    try? log.write(to: self.fileUrl!, options: .atomic)
                }
                
            } catch {
                if #available(iOS 14.0, *) {
                    let logger =
                        Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LoggingService")
                    logger.log("MDBM Error writing logs to file \(error)")
                } else {
                    NSLog("MDBM ERROR Getting fileUrl")
                }
            }
        }
    }
}

struct Resp: Codable {
    let success: Bool
    let error: String?
}
