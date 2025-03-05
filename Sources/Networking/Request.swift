//
//  Request.swift
//  Networking
//
//  Created by Dat Doan on 4/3/25.
//

import Foundation

public struct Request: Sendable {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [String: String]
    let body: Data?
    let cachePolicy: CachePolicy
    let retryPolicy: RetryPolicy
    
    public init(
        url: URL,
        method: HTTPMethod = .GET,
        headers: [String : String] = [:],
        queryItems: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: CachePolicy = .memory,
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
    case network
    case memory
    case disk
    
    var shouldCheckCache: Bool {
        switch self {
        case .network:
            return false
        case .disk, .memory:
            return true
        }
    }
    
    var shouldCache: Bool {
        switch self {
        case .network:
            return false
        case .memory, .disk:
            return true
        }
    }
}

public struct RetryPolicy: Sendable {
    let maxRetries: Int
    let delay: TimeInterval
    let backoffMultiplier: Double
    
    public static let `default` = RetryPolicy(
        maxRetries: 3,
        delay: 0.5,
        backoffMultiplier: 2
    )
}
