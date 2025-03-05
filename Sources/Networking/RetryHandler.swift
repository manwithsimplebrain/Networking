//
//  RetryHandler.swift
//  Networking
//
//  Created by Dat Doan on 5/3/25.
//

import Foundation

public protocol RetryHandler: Sendable {
    func retry(for request: Request, operation: @Sendable @escaping () async throws -> Data) async throws -> Data
}

actor BackoffMultiplierRetryHandler: RetryHandler {
    public func retry(for request: Request, operation: @Sendable @escaping () async throws -> Data) async throws -> Data {
        var lastError: Error?
        var currentAttempt = 0
        
        repeat {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard shouldRetry(error, request: request) else { break }
                
                let delay = calculateDelay(attempt: currentAttempt, policy: request.retryPolicy)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            currentAttempt += 1
        } while currentAttempt < request.retryPolicy.maxRetries
        
        throw lastError ?? NetworkError.unknown
    }
    
    private func shouldRetry(_ error: Error, request: Request) -> Bool {
        return true // FIXME: Custom retry handle on-demand
    }
    
    private func calculateDelay(attempt: Int, policy: RetryPolicy) -> TimeInterval {
        let baseDelay = policy.delay
        let multiplier = policy.backoffMultiplier
        
        // Ensure minimum delay of 0.1 seconds to prevent immediate retries
        let minDelay: TimeInterval = 0.1
        
        // Calculate exponential backoff with jitter to prevent thundering herd
        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt))
        let jitter = Double.random(in: 0.8...1.2) // ±20% jitter
        
        let calculatedDelay = max(minDelay, exponentialDelay * jitter)
        
        // Optional: Enforce maximum delay if needed
        let maxDelay: TimeInterval = 5 // 5 seconds maximum
        return min(calculatedDelay, maxDelay)
    }
}
