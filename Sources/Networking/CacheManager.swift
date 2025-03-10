//
//  CacheManager.swift
//  Networking
//
//  Created by Dat Doan on 5/3/25.
//

import Foundation

public struct CacheMetadata: Sendable {
    public let data: Data
    public let ttl: TimeInterval?
    
    public init(data: Data, ttl: TimeInterval? = nil) {
        self.data = data
        self.ttl = ttl
    }
}

extension CacheMetadata {
    var cacheValid: Bool {
        guard let ttl else { return true }
        return Date().timeIntervalSince1970 < ttl
    }
}

public protocol CacheManager: Sendable {
    func save(_ metadata: CacheMetadata, for key: String) async
    func get(for key: String) async -> CacheMetadata?
}

actor InMemoryCacheManager: CacheManager {
    private var cache: [String: CacheMetadata] = [:]
    
    func save(_ metadata: CacheMetadata, for key: String) {
        cache[key] = metadata
    }
    
    func get(for key: String) async -> CacheMetadata? {
        cache[key]
    }
}
