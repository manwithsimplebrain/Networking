//
//  NetworkService.swift
//  Networking
//
//  Created by Dat Doan on 4/3/25.
//

import Foundation

public protocol NetworkServiceConfig: Sendable {
    var session: URLSession { get }
    var cacheManager: CacheManager { get }
    var authManager: AuthManager { get }
    var retryHandler: RetryHandler { get }
}

public struct DefaultNetworkServiceConfig: NetworkServiceConfig, Sendable {
    public var session: URLSession
    public var cacheManager: CacheManager
    public var authManager: AuthManager
    public var retryHandler: RetryHandler
    
    public init(session: URLSession,
               cacheManager: CacheManager,
               authManager: AuthManager,
                retryHandler: RetryHandler) {
        self.session = session
        self.cacheManager = cacheManager
        self.authManager = authManager
        self.retryHandler = retryHandler
    }
    
    public init() {
        self.init(session: URLSession.shared,
                  cacheManager: InMemoryCacheManager(),
                  authManager: OathAuthManager(),
                  retryHandler: BackoffMultiplierRetryHandler())
    }
    
    public init(session: URLSession) {
        self.init(session: session,
                  cacheManager: InMemoryCacheManager(),
                  authManager: OathAuthManager(),
                  retryHandler: BackoffMultiplierRetryHandler())
    }
    
    public init(cacheManager: CacheManager) {
        self.init(session: URLSession.shared,
                  cacheManager: cacheManager,
                  authManager: OathAuthManager(),
                  retryHandler: BackoffMultiplierRetryHandler())
    }
}

public actor NetworkService {
    private let session: URLSession
    private let cacheManager: CacheManager
    private let authManager: AuthManager
    private let retryHandler: RetryHandler
    
    public init(config: NetworkServiceConfig = DefaultNetworkServiceConfig()) {
        self.session = config.session
        self.cacheManager = config.cacheManager
        self.authManager = config.authManager
        self.retryHandler = config.retryHandler
    }
    
    public func requestObject<T: Decodable>(request: Request) async throws -> T {
        // Check cache first if needed
        if request.cachePolicy.shouldCheckCache {
            if let cached = await cacheManager.get(for: request.cacheKey) {
                return try JSONDecoder().decode(T.self, from: cached)
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let data = try await execute(request)
                    let object = try JSONDecoder().decode(T.self, from: data)
                    continuation.resume(returning: object)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func requestData(request: Request) async throws -> Data {
        // Check cache first if needed
        if request.cachePolicy.shouldCheckCache {
            if let cached = await cacheManager.get(for: request.cacheKey) {
                return cached
            }
        }
        return try await execute(request)
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
                await self.cacheManager.save(data, for: request.cacheKey)
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
