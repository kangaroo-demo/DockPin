import XCTest
import CoreGraphics
@testable import DockPin

final class DockPinRecoveryControllerTests: XCTestCase {
    private let external = DisplayInfo(
        id: 3, uuid: "benq", name: "BenQ", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true
    )
    private let builtIn = DisplayInfo(
        id: 1, uuid: "built-in", name: "Built-in", bounds: CGRect(x: 172, y: 1080, width: 1512, height: 982), isMain: false
    )

    func testReconnectRestoresSavedExternalDisplayAfterTemporaryFallback() {
        let harness = Harness(selectedUUID: "benq")
        harness.ownerID = external.id
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 2.2)
        XCTAssertFalse(harness.controller.isRecovering)

        harness.ownerID = builtIn.id
        harness.updateDisplays([builtIn])
        harness.clock.advance(by: 2.2)
        XCTAssertEqual(harness.appliedIDs, [external.id, builtIn.id])
        XCTAssertEqual(harness.selectedUUID, "benq")

        let reconnected = DisplayInfo(
            id: 7, uuid: external.uuid, name: external.name, bounds: external.bounds, isMain: true
        )
        harness.updateDisplays([reconnected, builtIn])
        harness.clock.advance(by: 0.79)
        XCTAssertEqual(harness.appliedIDs.count, 2)
        harness.clock.advance(by: 0.02)
        XCTAssertEqual(harness.appliedIDs, [external.id, builtIn.id, reconnected.id])
        harness.ownerID = reconnected.id
        harness.clock.advance(by: 2)
        XCTAssertFalse(harness.controller.isRecovering)
        XCTAssertEqual(harness.selectedUUID, "benq")
        XCTAssertTrue(harness.restoreCursorValues.allSatisfy { $0 })
    }

    func testOwnershipNotificationsAndScreenOrderDoNotRestartRecovery() {
        let harness = Harness(selectedUUID: "benq")
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 0.8)
        harness.ownerID = external.id

        harness.updateDisplays([external, builtIn])
        harness.updateDisplays([builtIn, external])
        harness.clock.advance(by: 20)

        XCTAssertEqual(harness.appliedIDs, [external.id])
        XCTAssertEqual(harness.cancellationCount, 1)
        XCTAssertFalse(harness.controller.isRecovering)
    }

    func testRetriesWhenDockHasNotMovedYetAndStopsAfterSuccess() {
        let harness = Harness(selectedUUID: "benq")
        harness.ownerID = builtIn.id
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 3.3)
        XCTAssertEqual(harness.appliedIDs, [external.id, external.id])

        harness.ownerID = external.id
        harness.clock.advance(by: 20)
        XCTAssertEqual(harness.appliedIDs.count, 2)
        XCTAssertFalse(harness.controller.isRecovering)
    }

    func testRetriesAreBoundedWhenOwnershipIsWrongOrUnknown() {
        for ownerID in [builtIn.id, nil] {
            let harness = Harness(selectedUUID: "benq")
            harness.ownerID = ownerID
            harness.updateDisplays([external, builtIn])
            harness.clock.advance(by: 100)

            XCTAssertEqual(harness.appliedIDs, [external.id, external.id, external.id])
            XCTAssertFalse(harness.controller.isRecovering)
        }
    }

    func testRapidDisconnectAndReconnectCancelStaleFallback() {
        let harness = Harness(selectedUUID: "benq")
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 0.8)
        harness.updateDisplays([builtIn])
        harness.clock.advance(by: 0.3)
        harness.updateDisplays([external, builtIn])
        harness.ownerID = external.id
        harness.clock.advance(by: 10)

        XCTAssertEqual(harness.appliedIDs, [external.id, external.id])
        XCTAssertEqual(harness.cancellationCount, 3)
        XCTAssertFalse(harness.controller.isRecovering)
    }

    func testManualSelectionSupersedesPendingReconnect() {
        let harness = Harness(selectedUUID: "benq")
        harness.updateDisplays([external, builtIn])
        harness.selectedUUID = "built-in"
        harness.ownerID = builtIn.id
        harness.controller.requestPin(after: 0.08, restoreCursor: false)
        harness.clock.advance(by: 10)

        XCTAssertEqual(harness.appliedIDs, [builtIn.id])
        XCTAssertEqual(harness.restoreCursorValues, [false])
        XCTAssertFalse(harness.controller.isRecovering)
    }

    func testSleepOrQuitCancelsPendingApplyAndRetries() {
        for cancellationTime in [0.2, 1.0, 2.3] {
            let harness = Harness(selectedUUID: "benq")
            harness.updateDisplays([external, builtIn])
            harness.clock.advance(by: cancellationTime)
            let applyCount = harness.appliedIDs.count
            harness.controller.cancel()
            harness.clock.advance(by: 100)

            XCTAssertEqual(harness.appliedIDs.count, applyCount)
            XCTAssertFalse(harness.controller.isRecovering)
            XCTAssertEqual(harness.cancellationCount, 2)
        }
    }

    func testWakeCanReapplyWithoutTopologyChange() {
        let harness = Harness(selectedUUID: "benq")
        harness.ownerID = external.id
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 5)
        harness.controller.requestPin(after: 1, restoreCursor: true)
        harness.clock.advance(by: 5)

        XCTAssertEqual(harness.appliedIDs, [external.id, external.id])
        XCTAssertFalse(harness.controller.isRecovering)
    }

    func testUnavailablePermissionStopsWithoutRetries() {
        let harness = Harness(selectedUUID: "benq")
        harness.canApply = false
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 100)

        XCTAssertEqual(harness.applyCalls, 1)
        XCTAssertTrue(harness.appliedIDs.isEmpty)
        XCTAssertFalse(harness.controller.isRecovering)
    }

    func testLayoutChangeWithSameDisplayIDsStartsNewRecovery() {
        let harness = Harness(selectedUUID: "benq")
        harness.ownerID = external.id
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 5)
        let movedBuiltIn = DisplayInfo(
            id: builtIn.id, uuid: builtIn.uuid, name: builtIn.name,
            bounds: CGRect(x: 1920, y: 0, width: 1512, height: 982), isMain: false
        )
        harness.updateDisplays([external, movedBuiltIn])
        harness.clock.advance(by: 5)

        XCTAssertEqual(harness.appliedIDs, [external.id, external.id])
    }

    func testTemporaryAbsenceOfAllDisplaysDoesNotLoseSavedTarget() {
        let harness = Harness(selectedUUID: "benq")
        harness.updateDisplays([external, builtIn])
        harness.updateDisplays([])
        harness.clock.advance(by: 5)
        XCTAssertTrue(harness.appliedIDs.isEmpty)
        XCTAssertFalse(harness.controller.isRecovering)

        harness.ownerID = external.id
        harness.updateDisplays([external, builtIn])
        harness.clock.advance(by: 5)
        XCTAssertEqual(harness.appliedIDs, [external.id])
        XCTAssertEqual(harness.selectedUUID, "benq")
    }
}

private final class Harness {
    let clock = TestClock()
    var selectedUUID: String
    var ownerID: CGDirectDisplayID?
    var canApply = true
    var displays: [DisplayInfo] = []
    var appliedIDs: [CGDirectDisplayID] = []
    var restoreCursorValues: [Bool] = []
    var applyCalls = 0
    var cancellationCount = 0

    private var target: DisplayInfo? {
        displays.first { DisplayMatcher.matches(display: $0, uuid: selectedUUID, name: nil) }
            ?? displays.first(where: \.isMain) ?? displays.first
    }

    lazy var controller = DockPinRecoveryController(
        schedule: { [unowned self] delay, action in self.clock.schedule(after: delay, action: action) },
        applyPin: { [unowned self] restoreCursor in
            self.applyCalls += 1
            guard self.canApply, let target = self.target else { return false }
            self.appliedIDs.append(target.id)
            self.restoreCursorValues.append(restoreCursor)
            return true
        },
        isPinned: { [unowned self] in self.target?.id == self.ownerID },
        cancelNudge: { [unowned self] in self.cancellationCount += 1 }
    )

    init(selectedUUID: String) {
        self.selectedUUID = selectedUUID
    }

    func updateDisplays(_ displays: [DisplayInfo]) {
        self.displays = displays
        controller.updateDisplays(displays)
    }
}

private final class TestClock {
    private var now: TimeInterval = 0
    private var tasks: [(deadline: TimeInterval, action: () -> Void)] = []

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) {
        tasks.append((deadline: now + delay, action: action))
    }

    func advance(by interval: TimeInterval) {
        let end = now + interval
        while let index = tasks.indices.min(by: { tasks[$0].deadline < tasks[$1].deadline }),
              tasks[index].deadline <= end {
            let task = tasks.remove(at: index)
            now = task.deadline
            task.action()
        }
        now = end
    }
}
