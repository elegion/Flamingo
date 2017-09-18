//
//  Configuration.swift
//  Flamingo 1.0
//
//  Created by Ilya Kulebyakin on 9/11/17.
//  Copyright © 2017 e-Legion. All rights reserved.
//

import Foundation

public protocol NetworkConfiguration {
    
    var baseURL: URLConvertible? { get }
    var completionQueue: DispatchQueue { get }
    var defaultTimeoutInterval: TimeInterval { get }
}

public struct NetworkDefaultConfiguration: NetworkConfiguration {
    
    public let baseURL: URLConvertible?
    public let completionQueue: DispatchQueue
    public let defaultTimeoutInterval: TimeInterval
    
    public init(baseURL: URLConvertible? = nil,
                completionQueue: DispatchQueue = .main,
                defaultTimeoutInterval: TimeInterval = 60.0) {
        
        self.baseURL = baseURL
        self.completionQueue = completionQueue
        self.defaultTimeoutInterval = defaultTimeoutInterval
    }
}
