//
//  NetworkClient.swift
//  Flamingo
//
//  Created by Георгий Касапиди on 16.05.16.
//  Copyright © 2016 ELN. All rights reserved.
//

import Foundation
import Alamofire

private enum Error: Swift.Error {
    case inavlidRequestError
}

public protocol NetworkClient: class {
    
    @discardableResult
    func sendRequest<T: NetworkRequest>(_ networkRequest: T, completionHandler: ((T.T?, NSError?, NetworkContext?) -> Void)?) -> CancelableOperation?
}

open class NetworkDefaultClient: NetworkClient {
    
    private static let operationQueue = DispatchQueue(label: "com.flamingo.operation-queue", attributes: DispatchQueue.Attributes.concurrent)
    
    private let configuration: NetworkConfiguration
    private let offlineCacheManager: NetworkOfflineCacheManager?
    
    open let networkManager: SessionManager
    
    public init(configuration: NetworkConfiguration,
                offlineCacheManager: NetworkOfflineCacheManager? = nil,
                networkManager: SessionManager = SessionManager.default) {
        
        self.configuration = configuration
        self.offlineCacheManager = offlineCacheManager
        self.networkManager = networkManager
    }
    
    open func handleDefaultDataResponse<T: NetworkRequest>(_ nResponse: DefaultDataResponse,
                                        forRequest networkRequest: T,
                                        _ useCache: Bool,
                                        _ urlRequest: URLRequest,
                                        _ completionQueue: DispatchQueue,
                                        completionHandler: ((T.T?, NSError?, NetworkContext?) -> Void)?) {
        
        let request = nResponse.request
        let response = nResponse.response
        let data = nResponse.data
        let error = nResponse.error as? NSError
        
        let context = NetworkContext(request: request, response: response, data: data, error: error)
        
        var _data: Data? = data
        
        if useCache && self.shouldUseCachedResponseDataIfError(error) {
            NetworkDefaultClient.operationQueue.sync {
                _data = self.offlineCacheManager!.responseDataForRequest(urlRequest)
            }
        }
        
        NetworkDefaultClient.operationQueue.async {
            let result = networkRequest.responseSerializer.serializeResponse(request, response, _data, nil)
            
            switch result {
            case .success(let value):
                if useCache {
                    self.offlineCacheManager!.setResponseData(_data!, forRequest: urlRequest)
                }
                
                if let completionHandler = completionHandler {
                    completionQueue.async {
                        completionHandler(value, error, context)
                    }
                }
            case .failure(let _error):
                if let completionHandler = completionHandler {
                    completionQueue.async {
                        completionHandler(nil, _error as NSError, context)
                    }
                }
            }
        }
    }
    
    @discardableResult
    open func sendRequest<T : NetworkRequest>(_ networkRequest: T, completionHandler: ((T.T?, NSError?, NetworkContext?) -> Void)?) -> CancelableOperation? {
        
        let _completionQueue = completionQueueForNetworkRequest(networkRequest)

        let urlRequest: URLRequest
        do {
            urlRequest = try urlRequestFromNetworkRequest(networkRequest)
        } catch {
            if let completionHandler = completionHandler {
                _completionQueue.async {
                    completionHandler(nil, error as NSError, nil)
                }
            }
            
            return nil
        }
        
        if configuration.useMocks {
            if let mock = networkRequest.mockObject {
                let mockOperation = NetworkMockOperation(URLRequest: urlRequest,
                                                         mock: mock,
                                                         dispatchQueue: NetworkDefaultClient.operationQueue,
                                                         completionQueue: _completionQueue,
                                                         responseSerializer: networkRequest.responseSerializer,
                                                         completionHandler: completionHandler)
                
                mockOperation.resume()
                
                return mockOperation
            }
        }
        
        let _useCache = useCacheForNetworkRequest(networkRequest)
        
        let _request = networkManager.request(urlRequest).validate().response(queue: _completionQueue) {
            (nResponse) in
            
            self.handleDefaultDataResponse(nResponse, forRequest: networkRequest, _useCache, urlRequest, _completionQueue, completionHandler: completionHandler)
        }
        
        if configuration.debugMode {
            debugPrint(_request)
        }
        
        if !networkManager.startRequestsImmediately {
            _request.resume()
        }
        
        return _request
    }
    
    open func completionQueueForNetworkRequest<T: NetworkRequest>(_ networkRequest: T) -> DispatchQueue {
        return networkRequest.completionQueue ?? configuration.completionQueue
    }
    
    open func useCacheForNetworkRequest<T: NetworkRequest>(_ networkRequest: T) -> Bool {
        return networkRequest.useCache && self.offlineCacheManager != nil
    }
    
    open func urlRequestFromNetworkRequest<T : NetworkRequest>(_ networkRequest: T) throws -> URLRequest {
        
        let _baseURL = networkRequest.baseURL ?? configuration.baseURL
        
        guard let urlString = try? networkRequest.URL.asURL().absoluteString,
            let baseURL = try? _baseURL?.asURL(),
            let url = URL(string: urlString, relativeTo: baseURL) else {
                throw Error.inavlidRequestError
        }
        var urlRequest = URLRequest(url: url)
        
        urlRequest.timeoutInterval = networkRequest.timeoutInterval ?? configuration.defaultTimeoutInterval
        
        urlRequest.httpMethod = networkRequest.method.rawValue
        
        if let headers = networkRequest.headers {
            for (headerName, headerValue) in headers {
                urlRequest.setValue(headerValue, forHTTPHeaderField: headerName)
            }
        }
        
        if let customHeaders = customHeadersForRequest(networkRequest) {
            for (headerName, headerValue) in customHeaders {
                urlRequest.setValue(headerValue, forHTTPHeaderField: headerName)
            }
        }
        
        let encodedMutableURLRequest: URLRequest
        do {
            encodedMutableURLRequest = try networkRequest.parametersEncoding.encode(urlRequest, with: networkRequest.parameters)
        } catch {
            throw Error.inavlidRequestError
        }
        
        return encodedMutableURLRequest
    }
    
    open func uploadMultipartDataWithRequest<T: NetworkRequest>(networkRequest: T,
                                             usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
                                             completionHandler: ((T.T?, NSError?, NetworkContext?) -> Void)?) where T: UploadMultipartRequest {
        
        let _completionQueue = completionQueueForNetworkRequest(networkRequest)

        let urlRequest: URLRequest
        do {
            urlRequest = try urlRequestFromNetworkRequest(networkRequest)
        } catch {
            if let completionHandler = completionHandler {
                _completionQueue.async {
                    completionHandler(nil, error as NSError, nil)
                }
            }
            
            return
        }
        
        let _useCache = useCacheForNetworkRequest(networkRequest)

        networkManager.upload(multipartFormData: {
            (multipartFormData) in
            
            networkRequest.addPartsToMultipartFormData(multipartFormData: multipartFormData)
        }, usingThreshold: encodingMemoryThreshold,
           with: urlRequest,
           encodingCompletion: {
            encodingResult in
            
            switch encodingResult {
            case .success(request: let upload, streamingFromDisk: _, streamFileURL: _):
                upload.validate().response(queue: _completionQueue) {
                    (nResponse) in
                    
                    self.handleDefaultDataResponse(nResponse, forRequest: networkRequest, _useCache, urlRequest, _completionQueue, completionHandler: completionHandler)
                }
            case .failure(let error as NSError):
                if let completionHandler = completionHandler {
                    _completionQueue.async {
                        completionHandler(nil, error, nil)
                    }
                }
            default: break
            }
        })
    }
    
    open func customHeadersForRequest<T : NetworkRequest>(_ networkRequest: T) -> [String : String]? {
        return nil
    }
    
    open func shouldUseCachedResponseDataIfError(_ error: NSError?) -> Bool {
        if let error = error {
            return error.isNetworkConnectionError
        }
        
        return false
    }
}
