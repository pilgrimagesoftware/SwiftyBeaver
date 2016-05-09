//
//  CrashReporter.swift
//  SwiftyBeaver
//
//  Created by Gregory Hutchinson on 5/7/16.
//  Copyright © 2016 Sebastian Kreutzberger
//  Some rights reserved: http://opensource.org/licenses/MIT
//

import Foundation

struct Crash {

    var timestamp = 0.0
    var message = ""
    var thread = ""
    var trace = ""

    mutating func setupFromDict(dict: [String: AnyObject]) {
        if let val = dict["timestamp"] as? Double {
            timestamp = val
        }
        if let val = dict["message"] as? String {
            message = val
        }
        if let val = dict["thread"] as? String {
            thread = val
        }
        if let val = dict["trace"] as? String {
            trace = val
        }
    }
}


class CrashReporter {

    var showNSLog = true // set to true to debug the class

    /// Crash Log File Name
    private static let crashLogFileName = "swiftybeaver_crashes.json"
    private static let fileManager = NSFileManager.defaultManager()

    /// The Location of the Crash Log
    private class var crashLogURL: NSURL {
        get {
            var logsBaseDir: NSSearchPathDirectory = .CachesDirectory
            var crashLogFileURL: NSURL

            if OS == "OSX" {
                logsBaseDir = .DocumentDirectory
            }

            if let url = fileManager.URLsForDirectory(logsBaseDir, inDomains: .UserDomainMask).first {
                crashLogFileURL = url.URLByAppendingPathComponent(crashLogFileName, isDirectory: false)
            } else {
                crashLogFileURL = NSURL()
            }

            return crashLogFileURL
        }
    }


    /// Init
    init() {
        installCrashReporters()
    }

    /// Installs NSException, Signal Handlers
    func installCrashReporters() {
        // just Objective-C exceptions are caught!
        NSSetUncaughtExceptionHandler(exceptionHandler)

        // see signal.h for any other signals
        signal(SIGABRT, SignalHandler)
        signal(SIGILL, SignalHandler)
        signal(SIGSEGV, SignalHandler)
        signal(SIGFPE, SignalHandler)
        signal(SIGBUS, SignalHandler)
        signal(SIGPIPE, SignalHandler)
    }

    /// Checks if CrashLog File exists or not
    ///
    /// `true` if crash log exists, `false` otherwise
    /// - returns: `Bool`
    func appDidCrash() -> Bool {
        let fileManager = NSFileManager.defaultManager()
        return fileManager.fileExistsAtPath(CrashReporter.crashLogURL.path!)
    }

    /// Processes new crash log, writes crash as JSON to file
    private func processNewCrash(crashLog: [String: AnyObject]) {
        if let jsonString = jsonStringFromDict(crashLog) {
            do {
                try jsonString.writeToURL(CrashReporter.crashLogURL, atomically: true, encoding: NSUTF8StringEncoding)
            } catch let error as NSError {
                toNSLog("could not write new crash to \(CrashReporter.crashLogURL). \(error)")
            }
        }
    }

    /// Sends Crash Report to all added destinations. Return boolean about success
    func sendCrashReport() -> Bool {
        if let jsonString = jsonStringFromFile(CrashReporter.crashLogURL) {
            SwiftyBeaver.crash(jsonString)

            // delete crash log file
            do {
                try CrashReporter.fileManager.removeItemAtURL(CrashReporter.crashLogURL)
                return true
            } catch let error as NSError {
                toNSLog("could not delete \(CrashReporter.crashLogURL). \(error)")
            }
        }
        return false
    }

    /// returns optional dict from a json encoded file
    func jsonStringFromFile(url: NSURL) -> String? {
        do {
            // try to read file, decode every JSON line and put dict from each line in array
            let jsonString = try NSString(contentsOfFile: url.path!, encoding: NSUTF8StringEncoding) as String
            return jsonString
        } catch let error {
            toNSLog("could not read file \(url). \(error)")
        }
        return nil
    }

    /// turns a dict into optional JSON-encoded string
    func jsonStringFromDict(dict: [String: AnyObject]) -> String? {
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(dict, options: [])
            if let str = NSString(data: jsonData, encoding: NSUTF8StringEncoding) as? String {
                return str
            }
        } catch let error as NSError {
            toNSLog("could not create JSON from dict. \(error)")
        }
        return nil
    }

    /// Returns optional crash struct from JSON message. Called by destinations
    func crashFromJSON(jsonString: String) -> Crash? {
        // try to parse json string into dict
        if let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding) {
            do {
                let dict = try NSJSONSerialization.JSONObjectWithData(data,
                    options: .MutableContainers) as? [String:AnyObject]
                if let dict = dict {
                    var crash = Crash()
                    crash.setupFromDict(dict)
                    return crash
                }
            } catch let error {
                toNSLog("could not create dict from JSON \(jsonString). \(error)")
            }
        }
        return nil
    }

    /// log String to toNSLog. Used to debug the class logic
    private func toNSLog(str: String) {
        if showNSLog {
            NSLog("SwiftyBeaver Crash Reporter: \(str)")
        }
    }
}


//MARK: Global Crash Handlers

/// Global NSException Handler
///
/// creates a dictionary with pertinent crash info (including stack trace)
/// then processes the crash based on the `SwiftyBeaver Destination`s that are added
func exceptionHandler(exception: NSException) {
    let dict: [String: AnyObject] = [
        "timestamp": NSDate().timeIntervalSince1970,
        "level": SwiftyBeaver.Level.Crash.rawValue,
        "message": "\(exception)",
        "thread": SwiftyBeaver.threadName(),
        "fileName": "", //????: How to get this?
        "function": "", //????: How to get this?
        "line": "",     //????: How to get this?
        "trace": exception.callStackSymbols]

    SwiftyBeaver.crashReporter?.processNewCrash(dict)
}

/// Global Signal Handler
///
/// creates a dictionary with pertinent crash info (including stack trace)
/// then processes the crash based on the `SwiftyBeaver Destination`s that are added
func SignalHandler(signal: Int32) {

    //TODO: Provide a more helpful crash message here

    var message = ""
    switch signal {
    case SIGABRT:
        message = "crash: \(SIGABRT)"
        break
    case SIGILL:
        message = "crash: \(SIGILL)"
        break
    case SIGSEGV:
        message = "crash: \(SIGSEGV)"
        break
    case SIGFPE:
        message = "crash: \(SIGFPE)"
        break
    case SIGBUS:
        message = "crash: \(SIGBUS)"
        break
    case SIGPIPE:
        message = "crash: \(SIGPIPE)"
        break
    default:
        message = "unknown signal: \(signal)"
        break
    }

    let dict: [String: AnyObject] = [
        "timestamp": NSDate().timeIntervalSince1970,
        "level": SwiftyBeaver.Level.Crash.rawValue,
        "message": message,
        "thread": SwiftyBeaver.threadName(), //????: Is this accurate?
        "fileName": "", //????: How to get this?
        "function": "", //????: How to get this?
        "line": "",     //????: How to get this?
        "trace": ""] //????: How to get this here?

    SwiftyBeaver.crashReporter?.processNewCrash(dict)

    exit(signal)
}
