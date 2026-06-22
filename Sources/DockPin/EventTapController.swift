import CoreGraphics

final class EventTapController {
    enum State: Equatable {
        case stopped
        case running
        case unavailable
    }

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private let handler: (CGEventType, CGEvent) -> CGEvent

    private(set) var state: State = .stopped

    init(handler: @escaping (CGEventType, CGEvent) -> CGEvent) {
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        guard eventTap == nil else {
            return
        }

        var mask: CGEventMask = 0
        mask |= CGEventMask(1) << CGEventType.mouseMoved.rawValue
        mask |= CGEventMask(1) << CGEventType.leftMouseDragged.rawValue
        mask |= CGEventMask(1) << CGEventType.rightMouseDragged.rawValue
        mask |= CGEventMask(1) << CGEventType.otherMouseDragged.rawValue
        mask |= CGEventMask(1) << CGEventType.tapDisabledByTimeout.rawValue
        mask |= CGEventMask(1) << CGEventType.tapDisabledByUserInput.rawValue

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let eventTap = controller.eventTap {
                        CGEvent.tapEnable(tap: eventTap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                let handledEvent = controller.handler(type, event)
                return Unmanaged.passUnretained(handledEvent)
            },
            userInfo: userInfo
        ) else {
            state = .unavailable
            return
        }

        eventTap = tap
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        state = .running
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        eventTap = nil
        eventTapSource = nil
        state = .stopped
    }

    func retryIfNeeded() {
        if state == .unavailable || eventTap == nil {
            stop()
            start()
        }
    }
}
