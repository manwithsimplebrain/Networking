//
//  CacheManager.swift
//  Networking
//
//  Created by Dat Doan on 5/3/25.
//

import Foundation

public protocol CacheManager: Sendable {
    func save(_ data: Data, for key: String) async
    func get(for key: String) async -> Data?
}

actor InMemoryCacheManager: CacheManager {
    private var cache: [String: Data] = [:]
    
    func save(_ data: Data, for key: String) async {
        cache[key] = data
    }
    
    func get(for key: String) async -> Data? {
        cache[key]
    }
}
