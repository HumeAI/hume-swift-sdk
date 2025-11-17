#if HUME_IOS
  //
  //  AsyncLock.swift
  //  Hume
  //
  //  Created by Chris on 11/17/25.
  //

  import Foundation

  actor AsyncLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
      if !isLocked {
        isLocked = true
        return
      }

      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        waiters.append(continuation)
      }
    }

    func release() {
      if let next = waiters.first {
        waiters.removeFirst()
        next.resume()
      } else {
        isLocked = false
      }
    }

    func withLock<T>(_ operation: () async throws -> T) async rethrows -> T {
      await acquire()
      defer { release() }
      return try await operation()
    }
  }
#endif
