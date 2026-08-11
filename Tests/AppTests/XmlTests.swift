//
//  XmlTests.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 01.08.2026.
//


import Testing
@testable import App

@Suite(.serialized)
struct XmlTests {
    @Test func xmlFirst_findsSimpleElement() {
        #expect("<name>John</name>".xmlFirst("name") == "John")
        #expect("<name>John</name>".xmlFirst("age") == nil)
        #expect("<name></name>".xmlFirst("name") == "")
        #expect("<name>John</name><name>Jane</name>".xmlFirst("name") == "John")
        #expect("<body><b>Hello</b> World</body>".xmlFirst("body") == "<b>Hello</b> World")
        #expect("""
    <name>
        John Smith
    </name>
    """.xmlFirst("name") == "\n    John Smith\n")
        #expect("<name>John".xmlFirst("name") == nil)
        #expect("<name>John</age>".xmlFirst("name") == nil)
        #expect("<a>1</a><b>2</b><c>3</c>".xmlFirst("b") == "2")
        #expect("".xmlFirst("name") == nil)
        #expect("Just some text".xmlFirst("name") == nil)
        #expect("<veryLongTagName>value</veryLongTagName>".xmlFirst("veryLongTagName") == "value")
    }
    
}
