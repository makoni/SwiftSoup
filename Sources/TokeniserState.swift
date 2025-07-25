//
//  TokeniserState.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/10/16.
//

import Foundation

protocol TokeniserStateProtocol {
    func read(_ t: Tokeniser, _ r: CharacterReader)throws
}

public class TokeniserStateVars {
	public static let nullScalr: UnicodeScalar = "\u{0000}"
    public static let nullScalrUTF8 = "\u{0000}".utf8Array
    public static let nullScalrUTF8Slice = ArraySlice(nullScalrUTF8)

    static let attributeSingleValueChars = ParsingStrings(["'", UnicodeScalar.Ampersand, nullScalr])
    static let attributeDoubleValueChars = ParsingStrings(["\"", UnicodeScalar.Ampersand, nullScalr])
    static let attributeNameChars = ParsingStrings([UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "/", "=", ">", nullScalr, "\"", "'", UnicodeScalar.LessThan])
    static let attributeValueUnquoted = ParsingStrings([UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", UnicodeScalar.Ampersand, ">", nullScalr, "\"", "'", UnicodeScalar.LessThan, "=", "`"])
    
    static let dataDefaultStopChars = ParsingStrings([UnicodeScalar.Ampersand, UnicodeScalar.LessThan, TokeniserStateVars.nullScalr])
    static let scriptDataDefaultStopChars = ParsingStrings(["-", UnicodeScalar.LessThan, TokeniserStateVars.nullScalr])
    static let commentDefaultStopChars = ParsingStrings(["-", TokeniserStateVars.nullScalr])
    static let readDataDefaultStopChars = ParsingStrings([UnicodeScalar.LessThan, TokeniserStateVars.nullScalr])


    static let replacementChar: UnicodeScalar = Tokeniser.replacementChar
    static let replacementStr: [UInt8] = Array(Tokeniser.replacementChar.utf8)
    static let eof: UnicodeScalar = CharacterReader.EOF
    static let eofUTF8 = String(CharacterReader.EOF).utf8Array
    @usableFromInline
    static let eofUTF8Slice = ArraySlice(String(CharacterReader.EOF).utf8Array)
}

enum TokeniserState: TokeniserStateProtocol {
    case Data
    case CharacterReferenceInData
    case Rcdata
    case CharacterReferenceInRcdata
    case Rawtext
    case ScriptData
    case PLAINTEXT
    case TagOpen
    case EndTagOpen
    case TagName
    case RcdataLessthanSign
    case RCDATAEndTagOpen
    case RCDATAEndTagName
    case RawtextLessthanSign
    case RawtextEndTagOpen
    case RawtextEndTagName
    case ScriptDataLessthanSign
    case ScriptDataEndTagOpen
    case ScriptDataEndTagName
    case ScriptDataEscapeStart
    case ScriptDataEscapeStartDash
    case ScriptDataEscaped
    case ScriptDataEscapedDash
    case ScriptDataEscapedDashDash
    case ScriptDataEscapedLessthanSign
    case ScriptDataEscapedEndTagOpen
    case ScriptDataEscapedEndTagName
    case ScriptDataDoubleEscapeStart
    case ScriptDataDoubleEscaped
    case ScriptDataDoubleEscapedDash
    case ScriptDataDoubleEscapedDashDash
    case ScriptDataDoubleEscapedLessthanSign
    case ScriptDataDoubleEscapeEnd
    case BeforeAttributeName
    case AttributeName
    case AfterAttributeName
    case BeforeAttributeValue
    case AttributeValue_doubleQuoted
    case AttributeValue_singleQuoted
    case AttributeValue_unquoted
    case AfterAttributeValue_quoted
    case SelfClosingStartTag
    case BogusComment
    case MarkupDeclarationOpen
    case CommentStart
    case CommentStartDash
    case Comment
    case CommentEndDash
    case CommentEnd
    case CommentEndBang
    case Doctype
    case BeforeDoctypeName
    case DoctypeName
    case AfterDoctypeName
    case AfterDoctypePublicKeyword
    case BeforeDoctypePublicIdentifier
    case DoctypePublicIdentifier_doubleQuoted
    case DoctypePublicIdentifier_singleQuoted
    case AfterDoctypePublicIdentifier
    case BetweenDoctypePublicAndSystemIdentifiers
    case AfterDoctypeSystemKeyword
    case BeforeDoctypeSystemIdentifier
    case DoctypeSystemIdentifier_doubleQuoted
    case DoctypeSystemIdentifier_singleQuoted
    case AfterDoctypeSystemIdentifier
    case BogusDoctype
    case CdataSection

    @inlinable
    internal func read(_ t: Tokeniser, _ r: CharacterReader) throws {
        switch self {
        case .Data:
            switch (r.currentUTF8()) {
            case UTF8ArraySlices.ampersand:
                t.advanceTransition(.CharacterReferenceInData)
                break
            case UTF8ArraySlices.tagStart:
                t.advanceTransition(.TagOpen)
                break
            case TokeniserStateVars.nullScalrUTF8Slice:
                t.error(self) // NOT replacement character (oddly?)
                t.emit(r.consume())
                break
            case TokeniserStateVars.eofUTF8Slice:
                try t.emit(Token.EOF())
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeData()
                t.emit(data)
                break
            }
            break
        case .CharacterReferenceInData:
            try TokeniserState.readCharRef(t, .Data)
            break
        case .Rcdata:
            switch (r.currentUTF8()) {
            case UTF8ArraySlices.ampersand:
                t.advanceTransition(.CharacterReferenceInRcdata)
                break
            case UTF8ArraySlices.tagStart:
                t.advanceTransition(.RcdataLessthanSign)
                break
            case TokeniserStateVars.nullScalrUTF8Slice:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eofUTF8Slice:
                try t.emit(Token.EOF())
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.dataDefaultStopChars)
                t.emit(data)
                break
            }
            break
        case .CharacterReferenceInRcdata:
            try TokeniserState.readCharRef(t, .Rcdata)
            break
        case .Rawtext:
            try TokeniserState.readData(t, r, self, .RawtextLessthanSign)
            break
        case .ScriptData:
            try TokeniserState.readData(t, r, self, .ScriptDataLessthanSign)
            break
        case .PLAINTEXT:
            switch (r.currentUTF8()) {
            case TokeniserStateVars.nullScalrUTF8Slice:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eofUTF8Slice:
                try t.emit(Token.EOF())
                break
            default:
                let data = r.consumeTo(TokeniserStateVars.nullScalr)
                t.emit(data)
                break
            }
            break
        case .TagOpen:
            // from < in data
            switch r.currentUTF8() {
            case UTF8ArraySlices.bang:
                t.advanceTransition(.MarkupDeclarationOpen)
                break
            case UTF8ArraySlices.forwardSlash:
                t.advanceTransition(.EndTagOpen)
                break
            case UTF8ArraySlices.questionMark:
                t.advanceTransition(.BogusComment)
                break
            default:
                if r.matchesLetter() {
                    t.createTagPending(true)
                    t.transition(.TagName)
                } else {
                    t.error(self)
                    t.emit(UnicodeScalar.LessThan) // char that got us here
                    t.transition(.Data)
                }
                break
            }
            break
        case .EndTagOpen:
            if (r.isEmpty()) {
                t.eofError(self)
                t.emit(UTF8Arrays.endTagStart)
                t.transition(.Data)
            } else if (r.matchesLetter()) {
                t.createTagPending(false)
                t.transition(.TagName)
            } else if (r.matches(UTF8Arrays.tagEnd)) {
                t.error(self)
                t.advanceTransition(.Data)
            } else {
                t.error(self)
                t.advanceTransition(.BogusComment)
            }
            break
        case .TagName:
            // from < or </ in data, will have start or end tag pending
            // previous TagOpen state did NOT consume, will have a letter char in current
            //String tagName = r.consumeToAnySorted(tagCharsSorted).toLowerCase()
            let tagName: ArraySlice<UInt8> = r.consumeTagName()
            t.tagPending.appendTagName(tagName)

            switch (r.consume()) {
            case UnicodeScalar.BackslashT:
                t.transition(.BeforeAttributeName)
                break
            case "\n":
                t.transition(.BeforeAttributeName)
                break
            case "\r":
                t.transition(.BeforeAttributeName)
                break
            case UnicodeScalar.BackslashF:
                t.transition(.BeforeAttributeName)
                break
            case " ":
                t.transition(.BeforeAttributeName)
                break
            case "/":
                t.transition(.SelfClosingStartTag)
                break
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullScalr: // replacement
                t.tagPending.appendTagName(TokeniserStateVars.replacementStr)
                break
            case TokeniserStateVars.eof: // should emit pending tag?
                t.eofError(self)
                t.transition(.Data)
            // no default, as covered with above consumeToAny
            default:
                break
            }
        case .RcdataLessthanSign:
            if (r.matches("/")) {
                t.createTempBuffer()
                t.advanceTransition(.RCDATAEndTagOpen)
            } else if (r.matchesLetter() && t.appropriateEndTagName() != nil && !r.containsIgnoreCase("</".utf8Array + t.appropriateEndTagName()!)) {
                // diverge from spec: got a start tag, but there's no appropriate end tag (</title>), so rather than
                // consuming to EOF break out here
                t.tagPending = t.createTagPending(false).name(t.appropriateEndTagName()!)
                try t.emitTagPending()
                r.unconsume() // undo UnicodeScalar.LessThan
                t.transition(.Data)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.Rcdata)
            }
            break
        case .RCDATAEndTagOpen:
            if (r.matchesLetter()) {
                t.createTagPending(false)
                t.tagPending.appendTagName(r.currentUTF8())
                t.dataBuffer.append(r.currentUTF8())
                t.advanceTransition(.RCDATAEndTagName)
            } else {
                t.emit(UTF8Arrays.endTagStart)
                t.transition(.Rcdata)
            }
            break
        case .RCDATAEndTagName:
            if (r.matchesLetter()) {
                let name = r.consumeLetterSequence()
                t.tagPending.appendTagName(name)
                t.dataBuffer.append(name)
                return
            }

            func anythingElse(_ t: Tokeniser, _ r: CharacterReader) {
                t.emit(UTF8Arrays.endTagStart + t.dataBuffer.buffer)
                r.unconsume()
                t.transition(.Rcdata)
            }

            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case "\n":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case "\r":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case UnicodeScalar.BackslashF:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case " ":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case "/":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.SelfClosingStartTag)
                } else {
                    anythingElse(t, r)
                }
                break
            case ">":
                if (try t.isAppropriateEndTagToken()) {
                    try t.emitTagPending()
                    t.transition(.Data)
                } else {anythingElse(t, r)}
                break
            default:
                anythingElse(t, r)
                break
            }
            break
        case .RawtextLessthanSign:
            if (r.matches("/")) {
                t.createTempBuffer()
                t.advanceTransition(.RawtextEndTagOpen)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.Rawtext)
            }
            break
        case .RawtextEndTagOpen:
            TokeniserState.readEndTag(t, r, .RawtextEndTagName, .Rawtext)
            break
        case .RawtextEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .Rawtext)
            break
        case .ScriptDataLessthanSign:
            switch (r.consume()) {
            case "/":
                t.createTempBuffer()
                t.transition(.ScriptDataEndTagOpen)
                break
            case "!":
                t.emit("<!")
                t.transition(.ScriptDataEscapeStart)
                break
            default:
                t.emit(UnicodeScalar.LessThan)
                r.unconsume()
                t.transition(.ScriptData)
            }
            break
        case .ScriptDataEndTagOpen:
            TokeniserState.readEndTag(t, r, .ScriptDataEndTagName, .ScriptData)
            break
        case .ScriptDataEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .ScriptData)
            break
        case .ScriptDataEscapeStart:
            if (r.matches("-")) {
                t.emit("-")
                t.advanceTransition(.ScriptDataEscapeStartDash)
            } else {
                t.transition(.ScriptData)
            }
            break
        case .ScriptDataEscapeStartDash:
            if (r.matches("-")) {
                t.emit("-")
                t.advanceTransition(.ScriptDataEscapedDashDash)
            } else {
                t.transition(.ScriptData)
            }
            break
        case .ScriptDataEscaped:
            if (r.isEmpty()) {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            switch (r.currentUTF8()) {
            case UTF8ArraySlices.hyphen:
                t.emit(UTF8Arrays.hyphen)
                t.advanceTransition(.ScriptDataEscapedDash)
                break
            case UTF8ArraySlices.tagStart:
                t.advanceTransition(.ScriptDataEscapedLessthanSign)
                break
            case TokeniserStateVars.nullScalrUTF8Slice:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.scriptDataDefaultStopChars)
                t.emit(data)
            }
            break
        case .ScriptDataEscapedDash:
            if (r.isEmpty()) {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            let c = r.consume()
            switch (c) {
            case "-":
                t.emit(c)
                t.transition(.ScriptDataEscapedDashDash)
                break
            case UnicodeScalar.LessThan:
                t.transition(.ScriptDataEscapedLessthanSign)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataEscaped)
                break
            default:
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedDashDash:
            if (r.isEmpty()) {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            let c = r.consume()
            switch (c) {
            case "-":
                t.emit(c)
                break
            case UnicodeScalar.LessThan:
                t.transition(.ScriptDataEscapedLessthanSign)
                break
            case ">":
                t.emit(c)
                t.transition(.ScriptData)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataEscaped)
                break
            default:
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedLessthanSign:
            if (r.matchesLetter()) {
                t.createTempBuffer()
                t.dataBuffer.append(r.currentUTF8())
                t.emit(UTF8Arrays.tagStart + r.currentUTF8())
                t.advanceTransition(.ScriptDataDoubleEscapeStart)
            } else if (r.matches("/")) {
                t.createTempBuffer()
                t.advanceTransition(.ScriptDataEscapedEndTagOpen)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedEndTagOpen:
            if (r.matchesLetter()) {
                t.createTagPending(false)
                t.tagPending.appendTagName(r.currentUTF8())
                t.dataBuffer.append(r.currentUTF8())
                t.advanceTransition(.ScriptDataEscapedEndTagName)
            } else {
                t.emit(UTF8Arrays.endTagStart)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .ScriptDataEscaped)
            break
        case .ScriptDataDoubleEscapeStart:
            TokeniserState.handleDataDoubleEscapeTag(t, r, .ScriptDataDoubleEscaped, .ScriptDataEscaped)
            break
        case .ScriptDataDoubleEscaped:
            let c = r.currentUTF8()
            switch (c) {
            case UTF8ArraySlices.hyphen:
                t.emit(c)
                t.advanceTransition(.ScriptDataDoubleEscapedDash)
                break
            case UTF8ArraySlices.tagStart:
                t.emit(c)
                t.advanceTransition(.ScriptDataDoubleEscapedLessthanSign)
                break
            case TokeniserStateVars.nullScalrUTF8Slice:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eofUTF8Slice:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.scriptDataDefaultStopChars)
                t.emit(data)
            }
            break
        case .ScriptDataDoubleEscapedDash:
            let c = r.consume()
            switch (c) {
            case "-":
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedDashDash)
                break
            case UnicodeScalar.LessThan:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedLessthanSign)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataDoubleEscaped)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapedDashDash:
            let c = r.consume()
            switch (c) {
            case "-":
                t.emit(c)
                break
            case UnicodeScalar.LessThan:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedLessthanSign)
                break
            case ">":
                t.emit(c)
                t.transition(.ScriptData)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataDoubleEscaped)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapedLessthanSign:
            if (r.matches("/")) {
                t.emit("/")
                t.createTempBuffer()
                t.advanceTransition(.ScriptDataDoubleEscapeEnd)
            } else {
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapeEnd:
            TokeniserState.handleDataDoubleEscapeTag(t, r, .ScriptDataEscaped, .ScriptDataDoubleEscaped)
            break
        case .BeforeAttributeName:
            // from tagname <xxx
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break // ignore whitespace
            case "/":
                t.transition(.SelfClosingStartTag)
                break
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case "\"", "'", UnicodeScalar.LessThan, "=":
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
                break
            default: // A-Z, anything else
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
            }
            break
        case .AttributeName:
            let name: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeNameChars)
            t.tagPending.appendAttributeName(name)

            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT:
                t.transition(.AfterAttributeName)
                break
            case "\n":
                t.transition(.AfterAttributeName)
                break
            case "\r":
                t.transition(.AfterAttributeName)
                break
            case UnicodeScalar.BackslashF:
                t.transition(.AfterAttributeName)
                break
            case " ":
                t.transition(.AfterAttributeName)
                break
            case "/":
                t.transition(.SelfClosingStartTag)
                break
            case "=":
                t.transition(.BeforeAttributeValue)
                break
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case "\"":
                t.error(self)
                t.tagPending.appendAttributeName(c)
            case "'":
                t.error(self)
                t.tagPending.appendAttributeName(c)
            case UnicodeScalar.LessThan:
                t.error(self)
                t.tagPending.appendAttributeName(c)
                // no default, as covered in consumeToAny
            default:
                break
            }
            break
        case .AfterAttributeName:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                // ignore
                break
            case "/":
                t.transition(.SelfClosingStartTag)
                break
            case "=":
                t.transition(.BeforeAttributeValue)
                break
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                t.transition(.AttributeName)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case "\"", "'", UnicodeScalar.LessThan:
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
                break
            default: // A-Z, anything else
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
            }
            break
        case .BeforeAttributeValue:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                // ignore
                break
            case "\"":
                t.transition(.AttributeValue_doubleQuoted)
                break
            case UnicodeScalar.Ampersand:
                r.unconsume()
                t.transition(.AttributeValue_unquoted)
                break
            case "'":
                t.transition(.AttributeValue_singleQuoted)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                t.transition(.AttributeValue_unquoted)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitTagPending()
                t.transition(.Data)
                break
            case ">":
                t.error(self)
                try t.emitTagPending()
                t.transition(.Data)
                break
            case UnicodeScalar.LessThan, "=", "`":
                t.error(self)
                t.tagPending.appendAttributeValue(c)
                t.transition(.AttributeValue_unquoted)
                break
            default:
                r.unconsume()
                t.transition(.AttributeValue_unquoted)
            }
            break
        case .AttributeValue_doubleQuoted:
            let value: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeDoubleValueChars)
            if (value.count > 0) {
            t.tagPending.appendAttributeValue(value)
            } else {
            t.tagPending.setEmptyAttributeValue()
            }

            let c = r.consume()
            switch (c) {
            case "\"":
                t.transition(.AfterAttributeValue_quoted)
                break
            case UnicodeScalar.Ampersand:

                if let ref = try t.consumeCharacterReference("\"", true) {
                t.tagPending.appendAttributeValue(ref)
                } else {
                t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
                // no default, handled in consume to any above
            default:
                break
            }
            break
        case .AttributeValue_singleQuoted:
            let value: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeSingleValueChars)
            if (value.count > 0) {
            t.tagPending.appendAttributeValue(value)
            } else {
            t.tagPending.setEmptyAttributeValue()
            }

            let c = r.consume()
            switch (c) {
            case "'":
                t.transition(.AfterAttributeValue_quoted)
                break
            case UnicodeScalar.Ampersand:

                if let ref = try t.consumeCharacterReference("'", true) {
                t.tagPending.appendAttributeValue(ref)
                } else {
                t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
                // no default, handled in consume to any above
            default:
                break
            }
            break
        case .AttributeValue_unquoted:
            let value: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeValueUnquoted)
            if (value.count > 0) {
                t.tagPending.appendAttributeValue(value)
            }

            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeAttributeName)
                break
            case UnicodeScalar.Ampersand:
                if let ref = try t.consumeCharacterReference(">", true) {
                t.tagPending.appendAttributeValue(ref)
                } else {
                t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case "\"", "'", UnicodeScalar.LessThan, "=", "`":
                t.error(self)
                t.tagPending.appendAttributeValue(c)
                break
                // no default, handled in consume to any above
            default:
                break
            }
            break
        case .AfterAttributeValue_quoted:
            // CharacterReferenceInAttributeValue state handled inline
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeAttributeName)
                break
            case "/":
                t.transition(.SelfClosingStartTag)
                break
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.error(self)
                r.unconsume()
                t.transition(.BeforeAttributeName)
            }
            break
        case .SelfClosingStartTag:
            let c = r.consume()
            switch (c) {
            case ">":
                t.tagPending._selfClosing = true
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.error(self)
                r.unconsume()
                t.transition(.BeforeAttributeName)
            }
            break
        case .BogusComment:
            // todo: handle bogus comment starting from eof. when does that trigger?
            // rewind to capture character that lead us here
            r.unconsume()
            let comment: Token.Comment = Token.Comment()
            comment.bogus = true
            comment.data.append(r.consumeTo(">"))
            // todo: replace nullChar with replaceChar
            try t.emit(comment)
            t.advanceTransition(.Data)
            break
        case .MarkupDeclarationOpen:
            if (r.matchConsume("--".utf8Array)) {
                t.createCommentPending()
                t.transition(.CommentStart)
            } else if (r.matchConsumeIgnoreCase("DOCTYPE".utf8Array)) {
                t.transition(.Doctype)
            } else if (r.matchConsume("[CDATA[".utf8Array)) {
                // todo: should actually check current namepspace, and only non-html allows cdata. until namespace
                // is implemented properly, keep handling as cdata
                //} else if (!t.currentNodeInHtmlNS() && r.matchConsume("[CDATA[")) {
                t.transition(.CdataSection)
            } else {
                t.error(self)
                t.advanceTransition(.BogusComment) // advance so self character gets in bogus comment data's rewind
            }
            break
        case .CommentStart:
            let c = r.consume()
            switch (c) {
            case "-":
                t.transition(.CommentStartDash)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case ">":
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append(c)
                t.transition(.Comment)
            }
            break
        case .CommentStartDash:
            let c = r.consume()
            switch (c) {
            case "-":
                t.transition(.CommentStartDash)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case ">":
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append(c)
                t.transition(.Comment)
            }
            break
        case .Comment:
            let c = r.currentUTF8()
            switch (c) {
            case UTF8ArraySlices.hyphen:
                t.advanceTransition(.CommentEndDash)
                break
            case TokeniserStateVars.nullScalrUTF8Slice:
                t.error(self)
                r.advance()
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eofUTF8Slice:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                let value: ArraySlice<UInt8>  = r.consumeToAny(TokeniserStateVars.commentDefaultStopChars)
                t.commentPending.data.append(value)
            }
            break
        case .CommentEndDash:
            let c = r.consume()
            switch (c) {
            case "-":
                t.transition(.CommentEnd)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append("-").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append("-").append(c)
                t.transition(.Comment)
            }
            break
        case .CommentEnd:
            let c = r.consume()
            switch (c) {
            case ">":
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append("--").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case "!":
                t.error(self)
                t.transition(.CommentEndBang)
                break
            case "-":
                t.error(self)
                t.commentPending.data.append("-")
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.commentPending.data.append("--").append(c)
                t.transition(.Comment)
            }
            break
        case .CommentEndBang:
            let c = r.consume()
            switch (c) {
            case "-":
                t.commentPending.data.append("--!")
                t.transition(.CommentEndDash)
                break
            case ">":
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append("--!").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append("--!").append(c)
                t.transition(.Comment)
            }
            break
        case .Doctype:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeDoctypeName)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                // note: fall through to > case
                fallthrough
            case ">": // catch invalid <!DOCTYPE>
                t.error(self)
                t.createDoctypePending()
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.transition(.BeforeDoctypeName)
            }
            break
        case .BeforeDoctypeName:
            if (r.matchesLetter()) {
                t.createDoctypePending()
                t.transition(.DoctypeName)
                return
            }
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break // ignore whitespace
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.createDoctypePending()
                t.doctypePending.name.append(TokeniserStateVars.replacementChar)
                t.transition(.DoctypeName)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.createDoctypePending()
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.createDoctypePending()
                t.doctypePending.name.append(c)
                t.transition(.DoctypeName)
            }
            break
        case .DoctypeName:
            if (r.matchesLetter()) {
                let name = r.consumeLetterSequence()
                t.doctypePending.name.append(name)
                return
            }
            let c = r.consume()
            switch (c) {
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.AfterDoctypeName)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.name.append(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.doctypePending.name.append(c)
            }
            break
        case .AfterDoctypeName:
            if (r.isEmpty()) {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                return
            }
            if (r.matchesAny(UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ")) {
            r.advance() // ignore whitespace
            } else if (r.matches(">")) {
                try t.emitDoctypePending()
                t.advanceTransition(.Data)
            } else if (r.matchConsumeIgnoreCase(DocumentType.PUBLIC_KEY)) {
                t.doctypePending.pubSysKey = DocumentType.PUBLIC_KEY
                t.transition(.AfterDoctypePublicKeyword)
            } else if (r.matchConsumeIgnoreCase(DocumentType.SYSTEM_KEY)) {
                t.doctypePending.pubSysKey = DocumentType.SYSTEM_KEY
                t.transition(.AfterDoctypeSystemKeyword)
            } else {
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.advanceTransition(.BogusDoctype)
            }
            break
        case .AfterDoctypePublicKeyword:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeDoctypePublicIdentifier)
                break
            case "\"":
                t.error(self)
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_doubleQuoted)
                break
            case "'":
                t.error(self)
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_singleQuoted)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
            break
        case .BeforeDoctypePublicIdentifier:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case "\"":
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_doubleQuoted)
                break
            case "'":
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_singleQuoted)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
            break
        case .DoctypePublicIdentifier_doubleQuoted:
            let c = r.consume()
            switch (c) {
            case "\"":
                t.transition(.AfterDoctypePublicIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.doctypePending.publicIdentifier.append(c)
            }
            break
        case .DoctypePublicIdentifier_singleQuoted:
            let c = r.consume()
            switch (c) {
            case "'":
                t.transition(.AfterDoctypePublicIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.doctypePending.publicIdentifier.append(c)
            }
            break
        case .AfterDoctypePublicIdentifier:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BetweenDoctypePublicAndSystemIdentifiers)
                break
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case "\"":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case "'":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
            break
        case .BetweenDoctypePublicAndSystemIdentifiers:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case "\"":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case "'":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
            break
        case .AfterDoctypeSystemKeyword:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeDoctypeSystemIdentifier)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case "\"":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case "'":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
            }
            break
        case .BeforeDoctypeSystemIdentifier:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case "\"":
                // set system id to empty string
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case "'":
                // set public id to empty string
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
            break
        case .DoctypeSystemIdentifier_doubleQuoted:
            let c = r.consume()
            switch (c) {
            case "\"":
                t.transition(.AfterDoctypeSystemIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.doctypePending.systemIdentifier.append(c)
            }
            break
        case .DoctypeSystemIdentifier_singleQuoted:
            let c = r.consume()
            switch (c) {
            case "'":
                t.transition(.AfterDoctypeSystemIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.doctypePending.systemIdentifier.append(c)
            }
            break
        case .AfterDoctypeSystemIdentifier:
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.transition(.BogusDoctype)
                // NOT force quirks
            }
            break
        case .BogusDoctype:
            let c = r.consume()
            switch (c) {
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                // ignore char
                break
            }
            break
        case .CdataSection:
            let data = r.consumeTo("]]>".utf8Array)
            t.emit(data)
            r.matchConsume("]]>".utf8Array)
            t.transition(.Data)
            break
        }
    }

    var description: String {return String(describing: type(of: self))}
    /**
     * Handles RawtextEndTagName, ScriptDataEndTagName, and ScriptDataEscapedEndTagName. Same body impl, just
     * different else exit transitions.
     */
    private static func handleDataEndTag(_ t: Tokeniser, _ r: CharacterReader, _ elseTransition: TokeniserState)throws {
        if (r.matchesLetter()) {
            let name: ArraySlice<UInt8> = r.consumeLetterSequence()
            t.tagPending.appendTagName(name)
            t.dataBuffer.append(name)
            return
        }

        var needsExitTransition = false
        if (try t.isAppropriateEndTagToken() && !r.isEmpty()) {
            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(BeforeAttributeName)
                break
            case "/":
                t.transition(SelfClosingStartTag)
                break
            case ">":
                try t.emitTagPending()
                t.transition(Data)
                break
            default:
                t.dataBuffer.append(c)
                needsExitTransition = true
            }
        } else {
            needsExitTransition = true
        }

        if (needsExitTransition) {
            t.emit(UTF8Arrays.endTagStart + t.dataBuffer.buffer)
            t.transition(elseTransition)
        }
    }

    private static func readData(_ t: Tokeniser, _ r: CharacterReader, _ current: TokeniserState, _ advance: TokeniserState)throws {
        switch (r.currentUTF8()) {
        case UTF8ArraySlices.tagStart:
            t.advanceTransition(advance)
            break
        case TokeniserStateVars.nullScalrUTF8Slice:
            t.error(current)
            r.advance()
            t.emit(TokeniserStateVars.replacementChar)
            break
        case TokeniserStateVars.eofUTF8Slice:
            try t.emit(Token.EOF())
            break
        default:
            let data: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.readDataDefaultStopChars)
            t.emit(data)
            break
        }
    }

    private static func readCharRef(_ t: Tokeniser, _ advance: TokeniserState)throws {
        let c = try t.consumeCharacterReference(nil, false)
        if (c == nil) {
            t.emit(UnicodeScalar.Ampersand)
        } else {
            t.emit(c!)
        }
        t.transition(advance)
    }

    private static func readEndTag(_ t: Tokeniser, _ r: CharacterReader, _ a: TokeniserState, _ b: TokeniserState) {
        if (r.matchesLetter()) {
            t.createTagPending(false)
            t.transition(a)
        } else {
            t.emit(UTF8Arrays.endTagStart)
            t.transition(b)
        }
    }

    private static func handleDataDoubleEscapeTag(_ t: Tokeniser, _ r: CharacterReader, _ primary: TokeniserState, _ fallback: TokeniserState) {
        if (r.matchesLetter()) {
            let name = r.consumeLetterSequence()
            t.dataBuffer.append(name)
            t.emit(name)
            return
        }

        let c = r.consume()
        switch (c) {
        case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "/", ">":
            if (t.dataBuffer.buffer == ArraySlice(UTF8Arrays.script)) {
            t.transition(primary)
            } else {
            t.transition(fallback)
            }
            t.emit(c)
            break
        default:
            r.unconsume()
            t.transition(fallback)
        }
    }

}
