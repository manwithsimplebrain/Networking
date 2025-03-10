//
//  Request.swift
//  Networking
//
//  Created by Dat Doan on 4/3/25.
//

import Foundation

public struct Request: Sendable {
    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let queryItems: [String: String]
    public let body: Data?
    public let cachePolicy: CachePolicy
    public let retryPolicy: RetryPolicy
    
    public init(
        url: URL,
        method: HTTPMethod = .GET,
        headers: [String : String] = [:],
        queryItems: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: CachePolicy = .reloadIgnoringLocalCacheData,
        retryPolicy: RetryPolicy = .default) {
        self.url = url
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.cachePolicy = cachePolicy
        self.retryPolicy = retryPolicy
    }
    
    var cacheKey: String {
        return url.absoluteString
    }
}

public enum CachePolicy: Sendable {
    case reloadIgnoringLocalCacheData
    case returnCacheDataElseLoad(ttl: TimeInterval)
    case returnCacheDataDontLoad
    
    var shouldCache: Bool {
        switch self {
        case .reloadIgnoringLocalCacheData:
            return false
        case .returnCacheDataElseLoad, .returnCacheDataDontLoad:
            return true
        }
    }
    
    var ttl: TimeInterval? {
        switch self {
        case .reloadIgnoringLocalCacheData, .returnCacheDataDontLoad:
            return nil
        case .returnCacheDataElseLoad(let ttl):
            return ttl
        }
    }
}

public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let delay: TimeInterval
    public let backoffMultiplier: Double
    
    public static let `default` = RetryPolicy(
        maxRetries: 3,
        delay: 0.5,
        backoffMultiplier: 2
    )
}
