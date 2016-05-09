//
//  CrashReporterTests.swift
//  SwiftyBeaver
//
//  Created by Sebastian Kreutzberger on 5/8/16.
//  Copyright © 2016 Sebastian Kreutzberger
//  Some rights reserved: http://opensource.org/licenses/MIT
//

import XCTest
@testable import SwiftyBeaver

class CrashReporterTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testCrash() {
        let log = SwiftyBeaver.self
        // add console
        let console = ConsoleDestination()
        console.asynchronously = false
        console.useNSLog = true
        log.addDestination(console)

        // add file
        let file = FileDestination()
        file.logFileURL = NSURL(string: "file:///tmp/testSwiftyBeaver.log")!
        file.asynchronously = false
        //file.detailOutput = false
        //file.dateFormat = "HH:mm:ss.SSS"
        log.addDestination(file)

        log.verbose("before crash")

        // some waiting
        var x = 1.0
        for index2 in 1...500000 {
            x = sqrt(Double(index2))
            XCTAssertEqual(x, sqrt(Double(index2)))
        }

        //let array = NSArray()
        //array.objectAtIndex(99) // uncaught error causes test to fail!?
        log.verbose("after crash")
    }

}
