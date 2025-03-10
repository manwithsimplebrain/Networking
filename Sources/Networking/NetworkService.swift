//
//  NetworkService.swift
//  Networking
//
//  Created by Dat Doan on 4/3/25.
//

import Foundation

public protocol NetworkServiceConfig: Sendable {
    var session: URLSession { get }
    var authManager: AuthManager { get }
}

public struct DefaultNetworkServiceConfig: NetworkServiceConfig, Sendable {
    public var session: URLSession
    public var authManager: AuthManager
    
    public init(session: URLSession,
               authManager: AuthManager) {
        self.session = session
        self.authManager = authManager
    }
}

public actor NetworkService {
    private let session: URLSession
    private let cacheManager: CacheManager
    private let authManager: AuthManager
    private let retryHandler: RetryHandler
    
    public init(config: NetworkServiceConfig) {
        self.session = config.session
        self.cacheManager = CDCachingManager()
        self.authManager = config.authManager
        self.retryHandler = BackoffMultiplierRetryHandler()
    }
    
    public func requestObject<T: Decodable>(request: Request) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let data = try await requestData(request: request)
                    let object = try JSONDecoder().decode(T.self, from: data)
                    continuation.resume(returning: object)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func requestData(request: Request) async throws -> Data {
        switch request.cachePolicy {
        case .reloadIgnoringLocalCacheData:
            return try await execute(request)
        case .returnCacheDataElseLoad:
            if let cached = await cacheManager.get(for: request.cacheKey), cached.cacheValid {
                return cached.data
            }
            return try await execute(request)
        case .returnCacheDataDontLoad:
            if let cached = await cacheManager.get(for: request.cacheKey) {
                return cached.data
            }
            return try await execute(request)
        }
    }
    
    private func execute(_ request: Request) async throws -> Data {
        let urlRequest = makeURLRequest(from: request)
        
        // Handle authentication
        let authenticatedRequest = try await authManager.authenticate(for: urlRequest)
        
        // Execute with retry logic
        return try await retryHandler.retry(for: request) { [weak self] in
            guard let self else { throw NetworkError.serviceDeallocated }
            
            let (data, response) = try await self.session.data(for: authenticatedRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle token expiration
            if httpResponse.statusCode == 401 {
                try await self.authManager.refreshToken()
                return try await self.execute(request)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let error = BaseError(code: httpResponse.statusCode)
                throw NetworkError.serverError(error)
            }
            
            // Update cache
            if request.cachePolicy.shouldCache {
                let ttl: TimeInterval? = request.cachePolicy.ttl != nil
                    ? request.cachePolicy.ttl! + Date().timeIntervalSince1970
                    : nil
                let metadata = CacheMetadata(data: data, ttl: ttl)
                await self.cacheManager.save(metadata, for: request.cacheKey)
            }
            
            return data
        }
    }
    
    private func makeURLRequest(from request: Request) -> URLRequest {
        // Add query items
        var components = URLComponents(url: request.url, resolvingAgainstBaseURL: true)
        var queryItems = components?.queryItems ?? []
        for (key, value) in request.queryItems {
            queryItems += [URLQueryItem(name: key, value: value)]
        }
        components?.queryItems = queryItems
        
        var urlRequest = URLRequest(url: components?.url ?? request.url)
        
        // Add HTTP method
        urlRequest.httpMethod = request.method.rawValue
        
        // Add body
        urlRequest.httpBody = request.body
        
        // Add header
        var headers = urlRequest.allHTTPHeaderFields ?? [:]
        headers["Content-Type"] = "application/json"
        for (key, value) in request.headers {
            headers[key] = value
        }
        urlRequest.allHTTPHeaderFields = headers
        
        return urlRequest
    }
}
