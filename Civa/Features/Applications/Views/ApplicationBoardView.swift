//
//  ApplicationBoardView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import SwiftData
import SwiftUI

/// Applications as a board (DESIGN.md §8.7): one column per status. Dragging a card to another
/// column changes its status and saves at once. The keyboard and VoiceOver get the same move:
/// ⌥⌘← and ⌥⌘→, the Move to menu, and a "Move to" action for each status.
struct ApplicationBoardView: View {
    /// In list order.
    let applications: [JobApplication]
    let open: (JobApplication) -> Void

    @Environment(\.modelContext) private var context
    @Environment(UnsavedChangesGuard.self) private var changes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ApplicationBoard.showsClosedKey) private var showsClosed = false
    /// The board takes focus as a whole, like a list; `selection` is the card the keys act on.
    /// A card is rebuilt when it changes column, and SwiftUI won't focus a view in the update that
    /// adds it, so focus can't live on the cards themselves.
    @FocusState private var isFocused: Bool
    @State private var selection: UUID?
    /// The keys picked `selection`, so its card shows the focus ring.
    @State private var usesKeyboard = false
    /// The column a card is being dragged over.
    @State private var target: ApplicationStatus?
    @State private var storeError: String?

    private static let laneMinWidth: CGFloat = 160

    var body: some View {
        let columns = ApplicationBoard.columns(applications, showsClosed: showsClosed)
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Space.m) {
                ForEach(columns, id: \.status) { column in
                    lane(column.status, column.applications)
                        // Lanes share the page width evenly, down to 160 pt; then the board scrolls.
                        .containerRelativeFrame(.horizontal) { width, _ in
                            let count = CGFloat(columns.count)
                            return max(Self.laneMinWidth, (width - Space.xl * 2 - Space.m * (count - 1)) / count)
                        }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.automatic)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onChange(of: isFocused) { _, focused in
            // Tabbing in starts on the first card.
            if focused, !applications.contains(where: { $0.id == selection }) {
                selection = columns.lazy.flatMap(\.applications).first?.id
            }
        }
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .return, .space], phases: .down) { press in
            handle(press, in: columns.map(\.applications))
        }
        .alert(
            "Civa Couldn't Save Your Changes",
            isPresented: Binding(get: { storeError != nil }, set: { if !$0 { storeError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(storeError ?? "")
        }
    }

    private func lane(_ status: ApplicationStatus, _ cards: [JobApplication]) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: 6) {
                StatusMark(status, emphasized: true)
                    .font(.bodyEmphasis)
                Text(cards.count, format: .number)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.xs)
            .padding(.top, Space.xs)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(spacing: Space.s) {
                    ForEach(cards) { application in
                        card(application)
                    }
                }
                // Room for the focus ring, which draws outside the card.
                .padding(Space.xs)
            }
            .scrollIndicators(.never)
        }
        .padding(Space.xs)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.sidebar, in: .rect(cornerRadius: Radius.card))
        .overlay {
            if target == status {
                RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.accent, lineWidth: 2)
            }
        }
        .animation(Motion.fast, value: target)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            return move(id, to: status)
        } isTargeted: { isTargeted in
            if isTargeted { target = status } else if target == status { target = nil }
        }
    }

    private func card(_ application: JobApplication) -> some View {
        ApplicationCard(application: application)
            .civaFocusRing(
                RoundedRectangle(cornerRadius: Radius.card),
                isFocused: isFocused && selection == application.id,
                byKeyboard: usesKeyboard
            )
            .onTapGesture {
                usesKeyboard = false
                selection = application.id
                open(application)
            }
            .draggable(application.id.uuidString) {
                ApplicationCard(application: application).frame(width: 200)
            }
            .contextMenu {
                Button("Open") { open(application) }
                Menu("Move to") {
                    ForEach(ApplicationStatus.allCases) { status in
                        Button(status.title) { move(application.id.uuidString, to: status) }
                            .disabled(status == application.status)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(application.status.title)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { open(application) }
            .accessibilityActions {
                ForEach(ApplicationStatus.allCases.filter { $0 != application.status }) { status in
                    Button("Move to \(status.title)") { move(application.id.uuidString, to: status) }
                }
            }
            .help("Open, or drag to another column to change the status (⌥⌘← ⌥⌘→)")
    }

    /// Arrows move between cards, Return or Space opens one, ⌥⌘← and ⌥⌘→ move it a column.
    private func handle(_ press: KeyPress, in lanes: [[JobApplication]]) -> KeyPress.Result {
        guard let id = selection,
              let column = lanes.firstIndex(where: { $0.contains { $0.id == id } }),
              let row = lanes[column].firstIndex(where: { $0.id == id })
        else { return .ignored }
        let application = lanes[column][row]
        usesKeyboard = true
        let movesCard = press.modifiers.isSuperset(of: [.command, .option])
        switch press.key {
        case .return, .space:
            open(application)
        case .leftArrow where movesCard, .rightArrow where movesCard:
            let offset = press.key == .leftArrow ? -1 : 1
            if let status = ApplicationBoard.neighbor(of: application.status, offset: offset, showsClosed: showsClosed) {
                move(application.id.uuidString, to: status)
            }
        case .upArrow, .downArrow:
            let next = row + (press.key == .upArrow ? -1 : 1)
            if lanes[column].indices.contains(next) { selection = lanes[column][next].id }
        case .leftArrow, .rightArrow:
            // The nearest card in the next column that has any, at about the same height.
            let step = press.key == .leftArrow ? -1 : 1
            var next = column + step
            while lanes.indices.contains(next), lanes[next].isEmpty { next += step }
            if lanes.indices.contains(next) { selection = lanes[next][min(row, lanes[next].count - 1)].id }
        default:
            return .ignored
        }
        return .handled
    }

    /// Changes the status and saves right away; the board never holds unsaved edits.
    @discardableResult
    private func move(_ id: String, to status: ApplicationStatus) -> Bool {
        guard applications.contains(where: { $0.id.uuidString == id && $0.status != status }) else { return false }
        changes.perform {
            withAnimation(reduceMotion ? nil : Motion.standard) {
                _ = ApplicationBoard.move(id, to: status, in: applications)
            }
            do {
                try context.save()
                AccessibilityNotification.Announcement(String(localized: "Moved to \(status.title)")).post()
            } catch {
                context.rollback()
                storeError = error.localizedDescription
            }
        }
        return true
    }
}

/// A board card (DESIGN.md §7.17): white, with the company and its logo above the role.
struct ApplicationCard: View {
    let application: JobApplication

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                OrganizationLogo(name: application.company, size: 20)
                Text(application.company.isBlank ? String(localized: "No Company") : application.company)
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            Text(application.position.isBlank ? String(localized: "New Application") : application.position)
                .font(.bodyEmphasis)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: .rect(cornerRadius: Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(isHovered ? Color.fieldBorder : Color.hairline)
        }
        .contentShape(.rect(cornerRadius: Radius.card))
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
    }
}

private struct BoardPreview: View {
    @Query private var applications: [JobApplication]

    var body: some View {
        ApplicationBoardView(applications: applications.sorted(by: JobApplication.listOrder), open: { _ in })
            .background(Color.canvas)
    }
}

#Preview("Board") {
    BoardPreview()
        .frame(width: 900, height: 560)
        .previewEnvironment()
}

#Preview("Board, Dark") {
    BoardPreview()
        .frame(width: 900, height: 560)
        .previewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Card") {
    ApplicationCard(application: JobApplication(company: "Grab", position: "Software Engineer II, iOS", status: .interview))
        .frame(width: 200)
        .padding()
        .background(Color.sidebar)
        .previewEnvironment()
}
