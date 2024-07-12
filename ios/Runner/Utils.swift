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
    
    init() {
        LoggingService.Instance.logLevel = LogLevel.Debug
        let loggingService = LoggingService.Instance
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
        NSLog("onLogMessageWritten \(levelStr) [\(domain)] \(message)\n")
    }

    
}
