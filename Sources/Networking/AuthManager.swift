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
