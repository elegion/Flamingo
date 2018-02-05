//
//  NetworkClientMutaterTests.swift
//  FlamingoTests
//
//  Created by Nikolay Ischuk on 24.01.2018.
//  Copyright © 2018 ELN. All rights reserved.
//

import XCTest
import Flamingo

private final class MockEmptyMutater: NetworkClientMutater {
    var responseReplaceWasCalled: Bool = false

    func reponse<Request>(for request: Request) -> NetworkClientMutater.RawResponseTuple? where Request: NetworkRequest {
        responseReplaceWasCalled = true
        return nil
    }
}

private func ==(lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {

    switch (lhs, rhs) {
    case (.none, .none):
        return true
    case (.some(let left), .some(let right)):
        return NSDictionary(dictionary: left).isEqual(to: right)
    default:
        return false
    }
}

private final class MockMutater: NetworkClientMutater {
    let mockableRequest = RealFailedTestRequest()
    let testData = "Response is mocked"
    let testStatusCode = 212

    func reponse<Request>(for request: Request) -> NetworkClientMutater.RawResponseTuple? where Request: NetworkRequest {
        if request.URL == mockableRequest.URL &&
            request.parameters == mockableRequest.parameters &&
            request.baseURL == mockableRequest.baseURL &&
            (request.headers) == (mockableRequest.headers) {

            do {
                let response = HTTPURLResponse(url: try request.URL.asURL(),
                                               statusCode: testStatusCode,
                                               httpVersion: nil,
                                               headerFields: nil)
                let data = testData.data(using: .utf8)
                return (data, response, nil)
            } catch {
                return nil
            }
        }
        return nil
    }
}

class NetworkClientMutaterTests: XCTestCase {

    var networkClient: NetworkClientMutable!

    override func setUp() {
        super.setUp()

        let configuration = NetworkDefaultConfiguration(baseURL: "http://www.mocky.io/")
        networkClient = NetworkDefaultClient(configuration: configuration, session: .shared)
    }

    override func tearDown() {
        networkClient = nil
        super.tearDown()
    }

    func test_mutaterCalls() {
        let mutater1 = MockEmptyMutater()
        let mutater2 = MockEmptyMutater()

        networkClient.addMutater(mutater1)
        networkClient.addMutater(mutater2)

        let asyncExpectation = expectation(description: #function)

        networkClient.removeMutater(mutater2)
        let request = RealFailedTestRequest()
        networkClient.sendRequest(request) { (_, _) in
            asyncExpectation.fulfill()
        }

        waitForExpectations(timeout: 10) { (_) in
            XCTAssertTrue(mutater1.responseReplaceWasCalled)
            XCTAssertFalse(mutater2.responseReplaceWasCalled)
        }
    }

    func test_mutateAndPriority() {
        let mutater0 = MockEmptyMutater()
        let mutater1 = MockMutater()
        let mutater2 = MockEmptyMutater()

        networkClient.addMutater(mutater0)
        networkClient.addMutater(mutater1)
        networkClient.addMutater(mutater2)

        let asyncExpectation = expectation(description: #function)
        let request = RealFailedTestRequest()
        let operation = networkClient.sendRequest(request) {
            (result, context) in

            switch result {
            case .success(let value):
                XCTAssert(value == mutater1.testData, "Wrong replace data")
                XCTAssertEqual(context?.response?.statusCode, mutater1.testStatusCode)
            case .error(let error):
                XCTFail("No error expected, error \(error)")
            }
            asyncExpectation.fulfill()
        }

        waitForExpectations(timeout: 10) {
            (_) in

            if let task = operation as? URLSessionTask {
                XCTFail("Task shouldn't be called")
                XCTAssertNotEqual(task.state, .completed)
            }
            XCTAssertTrue(mutater0.responseReplaceWasCalled)
            XCTAssertFalse(mutater2.responseReplaceWasCalled)
        }
    }
}