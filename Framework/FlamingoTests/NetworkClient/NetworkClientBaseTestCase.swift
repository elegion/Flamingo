////
////  NetworkClientBaseTestCase.swift
////  FlamingoTests
////
////  Created by Dmitrii Istratov on 05-10-2017.
////  Copyright © 2017 ELN. All rights reserved.
////
//
import Flamingo

public protocol StubbableClient: class {
    var stubsManager: StubsManager? { get set }

    func enableStubs()
    func disableStubs()
}

final class NetworkDefaultClientStubs: NetworkDefaultClient, StubbableClient {
    var stubsManager: StubsManager? {
        didSet {
            if let oldValue = oldValue {
                removeMutater(oldValue)
            }
        }
    }

    func enableStubs() {
        if let stubsManager = stubsManager {
            addMutater(stubsManager)
        }
    }

    func disableStubs() {
        if let stubsManager = stubsManager {
            removeMutater(stubsManager)
        }
    }
}

extension NetworkDefaultClientStubs {
    static func defaultForTest() -> NetworkDefaultClientStubs {
        let configuration = NetworkDefaultConfiguration(baseURL: "http://example.com/", parallel: false)
        let result = NetworkDefaultClientStubs(configuration: configuration, session: .shared)
        result.stubsManager = StubsDefaultManager()
        result.enableStubs()
        return result
    }
}
