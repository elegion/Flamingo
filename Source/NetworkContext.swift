//
//  NetworkContext.swift
//  Flamingo 1.0
//
//  Created by Ilya Kulebyakin on 9/11/17.
//  Copyright © 2017 e-Legion. All rights reserved.
//

import Foundation

public struct NetworkContext {
    
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let data: Data?
    public let error: NSError?
    
    init(request: URLRequest?,
         response: HTTPURLResponse?,
         data: Data?,
         error: NSError?) {
        
        self.request = request
        self.response = response
        self.data = data
        self.error = error
    }
}

extension NetworkContext: CustomStringConvertible {
    public var description: String {
        return """
        Network context: \(String(describing: type(of: self)))
            response: \(String(describing: self.response))
            data: \(String(describing: self.data))
            error: \(String(describing: self.error))

        """
    }
}
