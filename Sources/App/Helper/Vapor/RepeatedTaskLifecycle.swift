import Foundation
import Vapor
import NIO
import NIOConcurrencyHelpers

/**
 Run a repeated task as a lifecycle handler. Repeated task is encosled by locks to be thread safe.
 */
final class RepeatedTaskLifecycle: LifecycleHandler {
    private let backgroundWatcher: NIOLockedValueBox<RepeatedTask?>
    private let initialDelay: TimeAmount
    private let delay: TimeAmount
    private let taskFn: @Sendable (Application) async throws -> Void
            
    public init(initialDelay: TimeAmount,
                 delay: TimeAmount,
                 _ task: @escaping @Sendable (Application) async throws -> Void) {
        self.backgroundWatcher = .init(nil)
        self.initialDelay = initialDelay
        self.delay = delay
        self.taskFn = task
    }
    
    /// Start background task
    func didBoot(_ application: Application) throws {
        let eventloop = application.eventLoopGroup.next()
        backgroundWatcher.withLockedValue({
            $0 = eventloop.scheduleRepeatedAsyncTask(
                initialDelay: initialDelay,
                delay: delay
            ) { repeatedTask in
                return application.eventLoopGroup.makeFutureWithTask({
                    return try await self.taskFn(application)
                })
            }
        })
    }
    
    ///
    func shutdown(_ application: Application) {
        backgroundWatcher.withLockedValue {
            $0?.cancel()
        }
    }
}

extension Application.Lifecycle {
    /// Repeat a background task every
    mutating func repeatedTask(initialDelay: TimeAmount,
                      delay: TimeAmount,
                      _ task: @escaping @Sendable (Application) async throws -> Void) {
        self.use(RepeatedTaskLifecycle(
            initialDelay: initialDelay,
            delay: delay,
            task)
        )
    }
}
