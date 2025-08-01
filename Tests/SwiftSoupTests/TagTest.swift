//
//  TagTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 17/10/16.
//

import XCTest
import SwiftSoup

class TagTest: XCTestCase {

    func testIsCaseSensitive() throws {
        let p1: Tag = try Tag.valueOf("P")
        let p2: Tag = try Tag.valueOf("p")
        XCTAssertFalse(p1.equals(p2))
    }

    func testCanBeInsensitive() throws {
        let p1: Tag = try Tag.valueOf("P", ParseSettings.htmlDefault)
        let p2: Tag = try Tag.valueOf("p", ParseSettings.htmlDefault)
        XCTAssertEqual(p1, p2)
    }

    func testTrims() throws {
        let p1: Tag = try Tag.valueOf("p")
        let p2: Tag = try Tag.valueOf(" p ")
        XCTAssertEqual(p1, p2)
    }

    func testEquality() throws {
        let p1: Tag = try Tag.valueOf("p")
        let p2: Tag = try Tag.valueOf("p")
        XCTAssertTrue(p1.equals(p2))
        XCTAssertTrue(p1 == p2)
    }

    func testDivSemantics() throws {
        let div = try Tag.valueOf("div")

        XCTAssertTrue(div.isBlock())
        XCTAssertTrue(div.formatAsBlock())
    }

    func testPSemantics() throws {
        let p = try Tag.valueOf("p")

        XCTAssertTrue(p.isBlock())
        XCTAssertFalse(p.formatAsBlock())
    }

    func testImgSemantics() throws {
        let img = try Tag.valueOf("img")
        XCTAssertTrue(img.isInline())
        XCTAssertTrue(img.isSelfClosing())
        XCTAssertFalse(img.isBlock())
    }

    func testDefaultSemantics() throws {
        let foo = try Tag.valueOf("FOO") // not defined
        let foo2 = try Tag.valueOf("FOO")

        XCTAssertEqual(foo, foo2)
        XCTAssertTrue(foo.isInline())
        XCTAssertTrue(foo.formatAsBlock())
    }

    func testValueOfChecksNotEmpty() {
        XCTAssertThrowsError(try Tag.valueOf(" "))
    }
}
