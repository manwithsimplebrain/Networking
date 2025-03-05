//
//  AuthManager.swift
//  Networking
//
//  Created by Dat Doan on 5/3/25.
//

import Foundation

public protocol AuthManager: Sendable {
    func authenticate(for request: URLRequest) async throws -> URLRequest
    func refreshToken() async throws
}

actor OathAuthManager: AuthManager {
    
    public func authenticate(for request: URLRequest) -> URLRequest {
        var request = request
        var headers = request.allHTTPHeaderFields ?? [:]
        headers["Authorization"] = "Bearer YOUR_ACCESS_TOKEN"
        request.allHTTPHeaderFields = headers
        return request
    }
    
    public func refreshToken() async throws {
        
    }
}
