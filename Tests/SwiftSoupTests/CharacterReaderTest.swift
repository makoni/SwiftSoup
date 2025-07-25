//
//  CharacterReaderTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/10/16.
//

import XCTest
import SwiftSoup

class CharacterReaderTest: XCTestCase {
    func testConsume() {
        let r = CharacterReader("one")
        XCTAssertEqual(0, r.getPos())
        XCTAssertEqual("o", r.current())
        XCTAssertEqual("o", r.consume())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("n", r.current())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        XCTAssertEqual(CharacterReader.EOF, r.consume())
        XCTAssertTrue(r.isEmpty())
        XCTAssertEqual(CharacterReader.EOF, r.consume())
    }

    func testUnconsume() {
        let r = CharacterReader("one")
        XCTAssertEqual("o", r.consume())
        XCTAssertEqual("n", r.current())
        r.unconsume()
        XCTAssertEqual("o", r.current())

        XCTAssertEqual("o", r.consume())
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        r.unconsume()
        XCTAssertFalse(r.isEmpty())
        XCTAssertEqual("e", r.current())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())

        // Indexes beyond the end are not allowed in native indexing
        //
        // XCTAssertEqual(CharacterReader.EOF, r.consume())
        // r.unconsume()
        // XCTAssertTrue(r.isEmpty())
        // XCTAssertEqual(CharacterReader.EOF, r.current())
    }
    
    func testMultibyteUnconsume() {
        let r = CharacterReader("π>")
        XCTAssertEqual("π", r.consume())
        XCTAssertEqual(">", r.current())
        r.unconsume()
        XCTAssertEqual("π", r.current())
    }

    func testMark() {
        let r = CharacterReader("one")
        XCTAssertEqual("o", r.consume())
        r.markPos()
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        r.rewindToMark()
        XCTAssertEqual("n", r.consume())
    }

    func testConsumeToEnd() {
        let input = "one two three"
        let r = CharacterReader(input)
        let toEnd = r.consumeToEnd()
        XCTAssertEqual(input, toEnd)
        XCTAssertTrue(r.isEmpty())
    }

    func testNextIndexOfChar() {
        let input = "blah blah"
        let r = CharacterReader(input)

        XCTAssertEqual(nil, r.nextIndexOf("x"))
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 3), r.nextIndexOf("h"))
        let pull = String(decoding: r.consumeTo("h"), as: UTF8.self)
        XCTAssertEqual("bla", pull)
        XCTAssertEqual("h", r.consume())
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 6), r.nextIndexOf("l"))
        XCTAssertEqual(" blah", r.consumeToEnd())
        XCTAssertEqual(nil, r.nextIndexOf("x"))
    }

    func testNextIndexOfString() {
        let input = "One Two something Two Three Four"
        let r = CharacterReader(input)

        XCTAssertEqual(nil, r.nextIndexOf("Foo"))
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 4), r.nextIndexOf("Two"))
        XCTAssertEqual("One Two ", r.consumeTo("something"))
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 18), r.nextIndexOf("Two"))
        XCTAssertEqual("something Two Three Four", r.consumeToEnd())
        XCTAssertEqual(nil, r.nextIndexOf("Two"))
    }

    func testNextIndexOfUnmatched() {
        let r = CharacterReader("<[[one]]")
        XCTAssertEqual(nil, r.nextIndexOf("]]>"))
    }

    func testConsumeToChar() {
        let r = CharacterReader("One Two Three")
        XCTAssertEqual("One ", r.consumeTo("T"))
        XCTAssertEqual("", r.consumeTo("T")) // on Two
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo ", r.consumeTo("T"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("hree", r.consumeTo("T")) // consume to end
    }

    func testConsumeToString() {
        let r = CharacterReader("One Two Two Four")
        XCTAssertEqual("One ", r.consumeTo("Two"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo ", r.consumeTo("Two"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo Four", r.consumeTo("Qux"))
    }

    func testAdvance() {
        let r = CharacterReader("One Two Three")
        XCTAssertEqual("O", r.consume())
        r.advance()
        XCTAssertEqual("e", r.consume())
    }

    func testConsumeToAny() {
        let r = CharacterReader("One 二 &bar; qux 三")
        XCTAssertEqual("One 二 ", r.consumeToAny(ParsingStrings(["&", ";"])))
        XCTAssertTrue(r.matches("&"))
        XCTAssertTrue(r.matches("&bar;"))
        XCTAssertEqual("&", r.consume())
        XCTAssertEqual("bar", r.consumeToAny(ParsingStrings(["&", ";"])))
        XCTAssertEqual(";", String(decoding: Array(r.consume().utf8), as: UTF8.self))
        XCTAssertEqual(" qux 三", r.consumeToAny(ParsingStrings(["&", ";"])))
    }
    
    func testConsumeToAnyMultibyte() {
        let r = CharacterReader("若い\"")
        let value: ArraySlice<UInt8> = r.consumeToAny(ParsingStrings(["\"", UnicodeScalar.Ampersand, "\u{0000}"]))
        XCTAssertEqual(String(decoding: value, as: UTF8.self), "若い")
    }

    func testConsumeLetterSequence() {
        let r = CharacterReader("One &bar; qux")
        XCTAssertEqual("One", String(decoding: r.consumeLetterSequence(), as: UTF8.self))
        XCTAssertEqual(" &", r.consumeTo("bar;"))
        XCTAssertEqual("bar", String(decoding: r.consumeLetterSequence(), as: UTF8.self))
       XCTAssertEqual("; qux", r.consumeToEnd())
    }

    func testConsumeLetterThenDigitSequence() {
        let r = CharacterReader("One12 Two &bar; qux")
        XCTAssertEqual("One12", String(decoding: r.consumeLetterThenDigitSequence(), as: UTF8.self))
        XCTAssertEqual(" ", r.consume())
        XCTAssertEqual("Two", String(decoding: r.consumeLetterThenDigitSequence(), as: UTF8.self))
        XCTAssertEqual(" &bar; qux", r.consumeToEnd())
    }

    func testMatches() {
        let r = CharacterReader("One Two Three")
        XCTAssertTrue(r.matches("O"))
        XCTAssertTrue(r.matches("One Two Three"))
        XCTAssertTrue(r.matches("One"))
        XCTAssertFalse(r.matches("one"))
        XCTAssertEqual("O", r.consume())
        XCTAssertFalse(r.matches("One"))
        XCTAssertTrue(r.matches("ne Two Three"))
        XCTAssertFalse(r.matches("ne Two Three Four"))
        XCTAssertEqual("ne Two Three", r.consumeToEnd())
        XCTAssertFalse(r.matches("ne"))
    }

    func testMatchesIgnoreCase() {
        let r = CharacterReader("One Two Three")
        XCTAssertTrue(r.matchesIgnoreCase("O"))
        XCTAssertTrue(r.matchesIgnoreCase("o"))
        XCTAssertTrue(r.matches("O"))
        XCTAssertFalse(r.matches("o"))
        XCTAssertTrue(r.matchesIgnoreCase("One Two Three"))
        XCTAssertTrue(r.matchesIgnoreCase("ONE two THREE"))
        XCTAssertTrue(r.matchesIgnoreCase("One"))
        XCTAssertTrue(r.matchesIgnoreCase("one"))
        XCTAssertEqual("O", r.consume())
        XCTAssertFalse(r.matchesIgnoreCase("One"))
        XCTAssertTrue(r.matchesIgnoreCase("NE Two Three"))
        XCTAssertFalse(r.matchesIgnoreCase("ne Two Three Four"))
        XCTAssertEqual("ne Two Three", r.consumeToEnd())
        XCTAssertFalse(r.matchesIgnoreCase("ne"))
    }

    func testContainsIgnoreCase() {
        let r = CharacterReader("One TWO three")
        XCTAssertTrue(r.containsIgnoreCase("two"))
        XCTAssertTrue(r.containsIgnoreCase("three"))
        // weird one: does not find one, because it scans for consistent case only
        XCTAssertFalse(r.containsIgnoreCase("one"))
    }

    func testMatchesAny() {
        //let scan = [" ", "\n", "\t"]
        let r = CharacterReader("One\nTwo\tThree")
        XCTAssertFalse(r.matchesAny(" ", "\n", "\t"))
        XCTAssertEqual("One", r.consumeToAny(ParsingStrings([" ", "\n", "\t"])))
        XCTAssertTrue(r.matchesAny(" ", "\n", "\t"))
        XCTAssertEqual("\n", r.consume())
        XCTAssertFalse(r.matchesAny(" ", "\n", "\t"))
    }

    func testCachesStrings() {
        let r = CharacterReader("Check\tCheck\tCheck\tCHOKE\tA string that is longer than 16 chars")
        let one = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let two = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let three = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let four = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let five = r.consumeTo("\t")

        XCTAssertEqual("Check", one)
        XCTAssertEqual("Check", two)
        XCTAssertEqual("Check", three)
        XCTAssertEqual("CHOKE", four)
        XCTAssertTrue(one == two)
        XCTAssertTrue(two == three)
        XCTAssertTrue(three != four)
        XCTAssertTrue(four != five)
        XCTAssertEqual(five, "A string that is longer than 16 chars")
    }

    func testRangeEquals() {
//        let r = CharacterReader("Check\tCheck\tCheck\tCHOKE")
//        XCTAssertTrue(r.rangeEquals(0, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(0, 5, "CHOKE"))
//        XCTAssertFalse(r.rangeEquals(0, 5, "Chec"))
//
//        XCTAssertTrue(r.rangeEquals(6, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(6, 5, "Chuck"))
//
//        XCTAssertTrue(r.rangeEquals(12, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(12, 5, "Cheeky"))
//
//        XCTAssertTrue(r.rangeEquals(18, 5, "CHOKE"))
//        XCTAssertFalse(r.rangeEquals(18, 5, "CHIKE"))
    }
    
    func testJavaScriptParsingHangRegression() throws {
        let expectation = XCTestExpectation(description: "SwiftSoup parse should complete")
        
        DispatchQueue.global().async {
            do {
                let html = """
                    <!DOCTYPE html>
                    <script>
                    <!--//-->
                    &
                    </script>
                """
                _ = try SwiftSoup.parse(html)
                expectation.fulfill() // Fulfill the expectation if parse completes
            } catch {
                XCTFail("Parsing failed with error: \(error)")
                expectation.fulfill() // Fulfill the expectation to not block the waiter in case of error
            }
        }
        
        // Wait for the expectation with a timeout of 3 seconds
        let result = XCTWaiter().wait(for: [expectation], timeout: 3.0)
        
        switch result {
        case .completed:
            // Parse completed within the timeout, the test passes
            break
        case .timedOut:
            // Parse did not complete within the timeout, the test fails
            XCTFail("Parsing took too long; hang detected")
        default:
            break
        }
    }
    
    func testURLCrashRegression() throws {
        let html = """
            <!DOCTYPE html>
            <body>
                <a href="https://secure.imagemaker360.com/Viewer/95.asp?id=181293idxIDX&Referer=&referefull="></a>
            </body>
        """
        _ = try SwiftSoup.parse(html)
    }

    func testMultibyteConsume() throws {
        let r = CharacterReader("-本文-")
        XCTAssertEqual(0, r.getPos())
        XCTAssertEqual("-", r.consume())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("本", r.current())
        XCTAssertEqual("本", r.consume())
        XCTAssertEqual(4, r.getPos())
        XCTAssertEqual("文", r.current())
        XCTAssertEqual("文", r.consume())
        XCTAssertEqual(7, r.getPos())
        XCTAssertEqual("-", r.consume())
    }
}
