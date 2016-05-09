//
//  CrashReporter.swift
//  SwiftyBeaver
//
//  Created by Gregory Hutchinson on 5/7/16.
//  Copyright © 2016 Sebastian Kreutzberger
//  Some rights reserved: http://opensource.org/licenses/MIT
//

import Foundation

public class CrashReporter {

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

//MARK: Config

    /// Init
    public init() {
        installCrashReporters()
    }

    /// Installs NSException, Signal Handlers
    private func installCrashReporters() {
        //NOTE: This will only ever catch objective-c
        //      uncaught NSException(s), etc
        NSSetUncaughtExceptionHandler(exceptionHandler)

        //NOTE: These will handle the other crash
        //      signals - see signal.h for any other signals
        //      to handle...
        signal(SIGABRT, SignalHandler)
        signal(SIGILL, SignalHandler)
        signal(SIGSEGV, SignalHandler)
        signal(SIGFPE, SignalHandler)
        signal(SIGBUS, SignalHandler)
        signal(SIGPIPE, SignalHandler)
    }

//MARK: Did We Crash?!

    /// Checks if CrashLog File exists or not
    ///
    /// `true` if crash log exists, `false` otherwise
    /// - returns: `Bool`
    /// - seealso: `doesCrashLogExist()`
    public func appDidCrashLastLaunch() -> Bool {
        return doesCrashLogExist()
    }


    /// Checks if CrashLog File exists or not
    ///
    /// `true` if crash log exists, `false` otherwise
    /// - returns: `Bool`
    private func doesCrashLogExist() -> Bool {
        let fileManager = NSFileManager.defaultManager()

        return fileManager.fileExistsAtPath(CrashReporter.crashLogURL.path!)
    }

// MARK: Process & Send Crash Logs

    /// Processes new crash log, decides to either write a new crash log file
    /// or append new crash log (if we haven't sent it yet). After sending the log file
    /// will be deleted
    private func processNewCrash(crashLog: [String: AnyObject]) {
        let crashLogFileURL = CrashReporter.crashLogURL

        if !doesCrashLogExist() {
            let logs = logStringFromCrashLog(crashLog)
            writeToCrashLogFile(logs, crashLogFileURL: crashLogFileURL)
        } else {
            appendToCrashLogFile(crashLog, crashLogFileURL: crashLogFileURL)
        }
    }

    /// Sends Crash Report to any / all SwiftyBeaver destinations available
    private func sendCrashReport() {
        let crashLogFileURL = CrashReporter.crashLogURL
        guard let crashLogFilePath = crashLogFileURL.path else {
            //TODO: Replace with an CrashReporterError
            NSLog("SwiftyBeaver Crash Reporter could not get crash log file path.")
            return
        }
        do {
            let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: crashLogFilePath),
                                  options: .DataReadingMappedIfSafe)

            if let jsonString = String(data: data, encoding: NSUTF8StringEncoding) {


                /*
                 // needs refactoring to use log.crash

                for destination in SwiftyBeaver.destinations {
                    if destination.dynamicType === SBPlatformDestination.self {
                        sendCrashReportToSBPlatformDestination(destination as?
                 SBPlatformDestination, crashLog: jsonString)
                    } else if destination.dynamicType === FileDestination.self {
                        sendCrashReportToFileDestination(destination as?
                 FileDestination, crashLog: jsonString)
                    } else if destination.dynamicType === ConsoleDestination.self {
                        sendCrashReportToConsoleDestination(destination as!
                 ConsoleDestination, crashLog: jsonString)
                    } else {
                        //TODO: Replace with an CrashReporterError
                        NSLog("Unknown destionation type... unable to send crash logs.")
                    }
                }
                */

            } else {
                //TODO: Replace with an CrashReporterError
                NSLog("SwiftyBeaver Crash Reporter could not create a String from crash data to log")
            }
        } catch let error as NSError {
            //TODO: Replace with an CrashReporterError
            NSLog("SwiftyBeaver Crash Reporter could not read from crash log file \(crashLogFileURL). \(error)")
        }
    }

    /// Send Crash Report to SBPlatformDestination
    ///
    /// - parameter destination: SBPlatformDestination
    /// - parameter crashLog: String
    private func sendCrashReportToSBPlatformDestination(destination: SBPlatformDestination, crashLog: String) {
        let encryptedCrashLog = destination.encrypt(crashLog)

        destination.sendToServerAsync(encryptedCrashLog, complete: { [unowned self] (ok, status) in
            NSLog("Crash Logs sent to SBPlatform.")
            self.deleteCrashLog()
        })
    }

    /// Send Crash Report to FileDestination
    ///
    /// - parameter destination: FileDestination
    /// - parameter crashLog: String
    private func sendCrashReportToFileDestination(destination: FileDestination, crashLog: String) {
        //TODO: Handle file logging destination
        NSLog("TODO: Handle Sending Crash Reports to File Logging Destination")
    }

    /// Send Crash Report to ConsoleDestination
    ///
    /// - parameter destination: ConsoleDestination
    /// - parameter crashLog: String
    private func sendCrashReportToConsoleDestination(destination: ConsoleDestination, crashLog: String) {
        //TODO: Handle console logging destination
        //      although to be fair these should just work by crashing your app...
        NSLog("TODO: Handle Sending Crash Reports to Console Logging Destination")
    }

// MARK: Crash Log File Management

    /// Writes logs to the Crash Log File
    ///
    /// - parameter logs: String
    /// - parameter fileURL: NSURL defaults to `CrashReporter.crashLogURL()`
    private func writeToCrashLogFile(logs: String, crashLogFileURL: NSURL = CrashReporter.crashLogURL) {
        do {
            try logs.writeToURL(crashLogFileURL, atomically: true, encoding: NSUTF8StringEncoding)
        } catch let error as NSError {
            //TODO: Replace with an CrashReporterError
            NSLog("SwiftyBeaver Crash Reporter not could write new crash to \(crashLogFileURL). \(error)")
        }
    }

    /// Appends new logs to the Crash Log File
    ///
    /// expected a single crash log dictionary and determines if existing crash log file contains
    /// one crash log or several and makes sure to create valid json by wrapping everything in a root array
    /// element
    ///
    /// - parameter crashLog: [String: AnyObject] (a single crash log dictionary)
    /// - parameter fileURL: NSURL defaults to `CrashReporter.crashLogURL()`
    private func appendToCrashLogFile(crashLog: [String: AnyObject],
                                      crashLogFileURL: NSURL = CrashReporter.crashLogURL) {
        guard let crashLogFilePath = crashLogFileURL.path else {
            //TODO: Replace with an CrashReporterError
            NSLog("SwiftyBeaver Crash Reporter could not get crash log file path.")
            return
        }

        do {
            let existingCrashLogData = try NSData(contentsOfURL: NSURL(fileURLWithPath: crashLogFilePath),
                                                  options: .DataReadingMappedIfSafe)
            do {
                let existingCrashLogJSON = try NSJSONSerialization.JSONObjectWithData(existingCrashLogData,
                                                options: .AllowFragments)

                if let json = existingCrashLogJSON as? [[String: AnyObject]] {

                    var existingCrashLogs = json
                    existingCrashLogs.append(crashLog)
                    let updatedLogs = logsStringFromCrashLogs(existingCrashLogs)
                    writeToCrashLogFile(updatedLogs)

                } else if let json = existingCrashLogJSON as? [String: AnyObject] {

                    let existingCrashLogs = [json]
                    let updatedLogs = logsStringFromCrashLogs(existingCrashLogs)
                    writeToCrashLogFile(updatedLogs)

                } else {
                    //TODO: Replace with an CrashReporterError
                    NSLog("no idea what this existing JSON is... sorry... \(existingCrashLogJSON)")
                }
            } catch let error as NSError {
                //TODO: Replace with an CrashReporterError
                NSLog("SwiftyBeaver Crash Reporter could not create a JSON String from crash data. \(error)")
            }
        } catch let error as NSError {
            //TODO: Replace with an CrashReporterError
            NSLog("SwiftyBeaver Crash Reporter could not read existing crash logs to append to. \(error)")
        }
    }


    /// Removes the Crash Log file
    private func deleteCrashLog() {
        let fileManager = NSFileManager.defaultManager()

        do {
            try fileManager.removeItemAtURL(CrashReporter.crashLogURL)
        } catch let error as NSError {
            //TODO: Replace with an CrashReporterError
            var msg = "SwiftyBeaver Crash Reporter could not delete old crash log file"
            msg = msg + " \(CrashReporter.crashLogURL). \(error)"
            NSLog(msg)
        }
    }

// MARK: Log Helpers

    //TOOD: Refactor these, they share a bit too much code currently

    /// Generate a json string from an array of crash logs
    ///
    /// - parameter crashLogs: [[String: AnyObject]]
    /// - returns: `String`
    private func logsStringFromCrashLogs(crashLogs: [[String: AnyObject]]) -> String {
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(crashLogs, options: .PrettyPrinted)
            if let jsonString = String(data: jsonData, encoding: NSUTF8StringEncoding) {
                let line = "\(jsonString)"
                return line
            } else {
                //TODO: Replace with an CrashReporterError
                NSLog("SwiftyBeaver Crash Reporter could not create a JSON String from crash data")
                return ""
            }
        } catch let error as NSError {
            //TODO: Replace with an CrashReporterError
            NSLog("SwiftyBeaver Crash Reporter could not convert crash log to JSON. \(error)")
            return ""
        }
    }

    /// Generate a json string from a single of crash log
    ///
    /// - parameter crashLog: [String: AnyObject]
    /// - returns: `String`
    private func logStringFromCrashLog(crashLog: [String: AnyObject]) -> String {
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(crashLog, options: .PrettyPrinted)
            if let jsonString = String(data: jsonData, encoding: NSUTF8StringEncoding) {
                let line = "\(jsonString)"
                return line
            } else {
                //TODO: Replace with an CrashReporterError
                NSLog("SwiftyBeaver Crash Reporter could not create a JSON String from crash data")
                return ""
            }
        } catch let error as NSError {
            //TODO: Replace with an CrashReporterError
            NSLog("SwiftyBeaver Crash Reporter could not convert crash log to JSON. \(error)")
            return ""
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
        "level": 9999, //Crash Level (Int)
        "message": "\(exception)",
        "thread": SwiftyBeaver.threadName(),
        "fileName": "", //????: How to get this?
        "function": "", //????: How to get this?
        "line": "",     //????: How to get this?
        "stackTrace": exception.callStackSymbols]

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
        "level": 9999, //Crash Level (Int)
        "message": message,
        "thread": SwiftyBeaver.threadName(), //????: Is this accurate?
        "fileName": "", //????: How to get this?
        "function": "", //????: How to get this?
        "line": "",     //????: How to get this?
        "stackTrace": ""] //????: How to get this here?

    SwiftyBeaver.crashReporter?.processNewCrash(dict)

    exit(signal)
}
