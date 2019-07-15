//
//  CodableExtensionTestCase.swift
//  FlamingoTests
//
//  Created by Dmitrii Istratov on 05-04-2018.
//  Copyright © 2018 ELN. All rights reserved.
//

import XCTest
@testable import Flamingo

struct Person: Decodable {
    let name: String

    private enum CodingKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(.name)
    }
}

struct RegexWrapper: Codable {
    let regex: NSRegularExpression

    private enum CodingKeys: String, CodingKey {
        case regex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        regex = try container.decode(.regex, transformer: RegexCodableTransformer())
    }

    func encode(to encoder: Encoder) throws {
        var container =  encoder.container(keyedBy: CodingKeys.self)
        try container.encode(regex, forKey: .regex, transformer: RegexCodableTransformer())
    }
}

struct OptionalRegexWrapper: Decodable {
    let regex: NSRegularExpression?

    private enum CodingKeys: String, CodingKey {
        case regex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        regex = try? container.decode(.regex, transformer: RegexCodableTransformer())
    }
}
// swiftlint:disable force_try
class Tests: XCTestCase {
    func testDecodingStandardType() {
        let json = """
        {
         "name": "James Ruston"
        }
        """.data(using: .utf8)! // swiftlint:disable:this force_unwrapping

        let person = try! JSONDecoder().decode(Person.self, from: json)

        XCTAssertEqual(person.name, "James Ruston")
    }

    func testCustomTransformer() {
        let json = """
        {
         "regex": ".*"
        }
        """.data(using: .utf8)! // swiftlint:disable:this force_unwrapping

        let wrapper = try! JSONDecoder().decode(RegexWrapper.self, from: json)

        XCTAssertEqual(wrapper.regex.pattern, ".*")
    }

    func testInvalidType() {
        let json = """
        {
         "regex": true
        }
        """.data(using: .utf8)! // swiftlint:disable:this force_unwrapping

        let wrapper = try? JSONDecoder().decode(RegexWrapper.self, from: json)

        XCTAssertNil(wrapper)
    }

    func testInvalidRegex() {
        let json = """
        {
         "regex": "["
        }
        """.data(using: .utf8)! // swiftlint:disable:this force_unwrapping

        let wrapper = try! JSONDecoder().decode(OptionalRegexWrapper.self, from: json)

        XCTAssertNil(wrapper.regex)
    }

    func testEncoding() {
        let jsonString = "{\"regex\":\".*\"}"
        let json = jsonString.data(using: .utf8)! // swiftlint:disable:this force_unwrapping

        let wrapper = try! JSONDecoder().decode(RegexWrapper.self, from: json)
        let encoded = try! JSONEncoder().encode(wrapper)

        let output = String(data: encoded, encoding: .utf8)! // swiftlint:disable:this force_unwrapping

        XCTAssertEqual(jsonString, output)

    }
}
// swiftlint:enable force_try
