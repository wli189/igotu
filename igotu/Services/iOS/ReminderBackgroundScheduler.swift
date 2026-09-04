import BackgroundTasks
import Foundation
import IgotuCore

@MainActor
final class ReminderBackgroundScheduler {
    static let taskIdentifier = "brian.igotu.reminder-refresh"

    private let refresh: () async -> Void
    private var didRegister = false

    init(refresh: @escaping () async -> Void) {
        self.refresh = refresh
    }

    func register() {
        guard !didRegister else { return }
        didRegister = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self?.handle(task)
        }
    }

    func scheduleNextRefresh(
        after delay: TimeInterval? = nil
    ) {
        let delay = delay ?? ReminderTiming.backgroundRefreshEarliestInterval
        BGTaskScheduler.shared.cancel(
            taskRequestWithIdentifier: Self.taskIdentifier
        )

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date.now.addingTimeInterval(max(0, delay))

        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let refreshTask = Task { @MainActor [refresh] in
            await refresh()
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }

        Task { @MainActor in
            await refreshTask.value
            task.setTaskCompleted(success: !refreshTask.isCancelled)
        }
    }
}
