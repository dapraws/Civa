//
//  ApplicationBoard.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import Foundation

/// The Applications board (DESIGN.md §8.7): one column per status, cards in list order.
enum ApplicationBoard {
    /// Show Closed, remembered between launches.
    static let showsClosedKey = "ApplicationsShowsClosed"
    /// Rejected and Withdrawn are closed: they show only with Show Closed on.
    static let closedStatuses: Set<ApplicationStatus> = [.rejected, .withdrawn]

    static func statuses(showsClosed: Bool) -> [ApplicationStatus] {
        ApplicationStatus.allCases.filter { showsClosed || !closedStatuses.contains($0) }
    }

    static func columns(
        _ applications: [JobApplication], showsClosed: Bool
    ) -> [(status: ApplicationStatus, applications: [JobApplication])] {
        let sorted = applications.sorted(by: JobApplication.listOrder)
        return statuses(showsClosed: showsClosed).map { status in
            (status, sorted.filter { $0.status == status })
        }
    }

    /// The column `offset` steps away among the visible ones, for ⌥⌘← and ⌥⌘→.
    static func neighbor(of status: ApplicationStatus, offset: Int, showsClosed: Bool) -> ApplicationStatus? {
        let visible = statuses(showsClosed: showsClosed)
        guard let index = visible.firstIndex(of: status), visible.indices.contains(index + offset) else { return nil }
        return visible[index + offset]
    }

    /// Moves the dropped card (its id as a string) to `status`. Returns the application that
    /// changed, or nil when the drop is unknown or lands on the card's own column. The caller saves.
    @discardableResult
    static func move(_ id: String, to status: ApplicationStatus, in applications: [JobApplication]) -> JobApplication? {
        guard let application = applications.first(where: { $0.id.uuidString == id }),
              application.status != status
        else { return nil }
        application.status = status
        application.updatedAt = .now
        return application
    }
}
