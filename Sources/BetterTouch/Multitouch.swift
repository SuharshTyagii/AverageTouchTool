import Foundation
import CoreFoundation

// Bridges Apple's private MultitouchSupport.framework to get RAW trackpad
// contact frames — finger count + normalized positions — so we can detect true
// N-finger swipes (3-finger, 4-finger) the way BetterTouchTool does. The public
// NSEvent API cannot report finger counts; this can.

// MARK: - Private framework struct layout

private struct MTPoint { var x: Float = 0; var y: Float = 0 }
private struct MTReadout { var pos = MTPoint(); var vel = MTPoint() }

/// Mirrors the framework's touch record. We only read `normalized.pos`.
private struct MTTouch {
    var frame: Int32 = 0
    var timestamp: Double = 0
    var pathIndex: Int32 = 0
    var state: Int32 = 0
    var fingerID: Int32 = 0
    var handID: Int32 = 0
    var normalized = MTReadout()
    var zTotal: Float = 0
    var unknown1: Int32 = 0
    var angle: Float = 0
    var majorAxis: Float = 0
    var minorAxis: Float = 0
    var absolute = MTReadout()
    var unknown2: Int32 = 0
    var unknown3: Int32 = 0
    var zDensity: Float = 0
}

// Touches arrive as a raw pointer (a typed Swift-struct pointer isn't
// C-representable); we rebind it to MTTouch inside the handler.
private typealias MTContactCallback =
    @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
private typealias MTRegisterFn = @convention(c) (UnsafeMutableRawPointer?, MTContactCallback) -> Void
private typealias MTDeviceFn = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void

/// Detects N-finger swipes from raw trackpad frames and reports them on the
/// main thread.
final class MultitouchGesture {
    static let shared = MultitouchGesture()

    /// Called on the main thread with (direction, fingerCount).
    var onSwipe: ((SwipeDirection, Int) -> Void)?
    /// Called on the main thread with the peak finger count of a quick tap.
    var onTap: ((Int) -> Void)?
    /// Called on the main thread with the pinch direction (2-finger).
    var onPinch: ((PinchDirection) -> Void)?
    /// Called on the main thread with the rotation direction (2-finger).
    var onRotate: ((RotateDirection) -> Void)?

    private var devices: [UnsafeMutableRawPointer] = []
    /// Retained for the process lifetime — the device pointers are owned by this
    /// array, so releasing it would free the devices and stop all frames.
    private var deviceList: CFMutableArray?
    private var started = false
    private var loggedFirstFrame = false

    // Gesture accumulation state (touched only on the framework's callback thread).
    private var tracking = false
    private var startX: Float = 0
    private var startY: Float = 0
    private var lastX: Float = 0
    private var lastY: Float = 0
    private var maxFingers = 0

    private let minFingers = 2            // ignore single-finger pointer movement
    private let threshold: Float = 0.10   // normalized trackpad units

    @discardableResult
    func start() -> Bool {
        guard !started else { return true }
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else {
            Log.line("MT: dlopen failed"); return false
        }
        guard
            let createListSym = dlsym(handle, "MTDeviceCreateList"),
            let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
            let startSym = dlsym(handle, "MTDeviceStart")
        else { Log.line("MT: missing symbols"); return false }

        let createList = unsafeBitCast(createListSym, to: MTDeviceCreateListFn.self)
        let register = unsafeBitCast(registerSym, to: MTRegisterFn.self)
        let startDevice = unsafeBitCast(startSym, to: MTDeviceFn.self)

        guard let list = createList()?.takeRetainedValue() else {
            Log.line("MT: device list nil"); return false
        }
        deviceList = list   // keep alive!
        let count = CFArrayGetCount(list)
        for i in 0..<count {
            guard let dev = CFArrayGetValueAtIndex(list, i) else { continue }
            let device = UnsafeMutableRawPointer(mutating: dev)
            register(device, MultitouchGesture.contactCallback)
            startDevice(device, 0)
            devices.append(device)
        }
        started = !devices.isEmpty
        Log.line("MT: started devices=\(devices.count)")
        return started
    }

    /// Re-arm the trackpad frame stream after the system stops it on sleep.
    /// macOS halts the MTDevices on sleep and does NOT re-register our callback
    /// on wake, so the handles in `devices` go dead and no more frames arrive
    /// (the app keeps running but gestures silently stop). Dropping the stale
    /// device list and running `start()` again recreates the list, re-registers
    /// the callback, and restarts the devices. This does NOT touch the swipe
    /// detection path — only the device plumbing the framework drops on sleep.
    @discardableResult
    func restart() -> Bool {
        Log.line("MT: restart requested (re-arming after sleep)")
        devices.removeAll()
        deviceList = nil
        started = false
        loggedFirstFrame = false
        // Any in-flight gesture state is stale across a sleep; clear it so the
        // first post-wake frame starts a fresh accumulation.
        tracking = false
        maxFingers = 0
        advTracking = false
        advPeakFingers = 0
        advStartSpread = 0
        return start()
    }

    // C callback: no captured context, so route through the singleton.
    // handleFrame() owns the (locked) swipe path; handleAdvanced() runs
    // alongside it for taps / pinch / rotate and never mutates swipe state.
    private static let contactCallback: MTContactCallback = { _, touchesRaw, numTouches, timestamp, _ in
        let typed = touchesRaw?.assumingMemoryBound(to: MTTouch.self)
        MultitouchGesture.shared.handleFrame(typed, Int(numTouches))
        MultitouchGesture.shared.handleAdvanced(typed, Int(numTouches), timestamp)
        return 0
    }

    private func handleFrame(_ touches: UnsafeMutablePointer<MTTouch>?, _ n: Int) {
        if !loggedFirstFrame && n > 0 {
            loggedFirstFrame = true
            Log.line("MT: receiving frames (fingers=\(n)) — capture is working")
        }

        // While 2+ fingers are down: accumulate. Record the start position and
        // track the peak finger count + latest position.
        if n >= minFingers, let touches {
            var sx: Float = 0, sy: Float = 0
            for i in 0..<n {
                sx += touches[i].normalized.pos.x
                sy += touches[i].normalized.pos.y
            }
            let avgX = sx / Float(n)
            let avgY = sy / Float(n)

            if !tracking {
                tracking = true
                startX = avgX
                startY = avgY
                maxFingers = n
            } else {
                maxFingers = max(maxFingers, n)
            }
            lastX = avgX
            lastY = avgY
            return
        }

        // Fewer than 2 fingers: the multi-finger gesture (if any) has ended.
        // Decide direction from total travel and the PEAK finger count.
        if tracking {
            let dx = lastX - startX
            let dy = lastY - startY
            let distance = (dx * dx + dy * dy).squareRoot()
            let fingers = maxFingers
            tracking = false
            maxFingers = 0

            guard distance >= threshold else { return }
            let direction: SwipeDirection
            if abs(dx) > abs(dy) {
                direction = dx > 0 ? .right : .left
            } else {
                direction = dy > 0 ? .up : .down   // normalized y increases upward
            }
            Log.line("MT: swipe \(direction) fingers=\(fingers) dx=\(dx) dy=\(dy)")
            DispatchQueue.main.async { [weak self] in
                self?.onSwipe?(direction, fingers)
            }
        }
    }

    // MARK: - Advanced gestures (taps / pinch / rotate)
    //
    // Independent of the swipe accumulator above. We track a touch from the
    // first finger down to the last finger up, recording peak finger count,
    // average-position travel, and (for two fingers) the spread + angle between
    // them. On release we classify: a big spread change -> pinch; a big angle
    // change -> rotate; otherwise low travel + short duration -> tap.

    private var advTracking = false
    private var advStartTime: Double = 0
    private var advStartX: Float = 0
    private var advStartY: Float = 0
    private var advLastX: Float = 0
    private var advLastY: Float = 0
    private var advPeakFingers = 0
    private var advStartSpread: Float = 0     // 0 until two fingers seen
    private var advLastSpread: Float = 0
    private var advStartAngle: Float = 0
    private var advLastAngle: Float = 0

    private let tapTravel: Float = 0.06       // normalized units; below = stationary
    private let tapMaxDuration: Double = 0.50 // seconds
    private let pinchThreshold: Float = 0.06  // spread delta in normalized units
    private let rotateThreshold: Float = 0.30 // radians (~17°)

    fileprivate func handleAdvanced(_ touches: UnsafeMutablePointer<MTTouch>?, _ n: Int, _ timestamp: Double) {
        if n >= 1, let touches {
            var sx: Float = 0, sy: Float = 0
            for i in 0..<n { sx += touches[i].normalized.pos.x; sy += touches[i].normalized.pos.y }
            let ax = sx / Float(n), ay = sy / Float(n)

            var spread: Float = 0, angle: Float = 0
            if n >= 2 {
                let dx = touches[1].normalized.pos.x - touches[0].normalized.pos.x
                let dy = touches[1].normalized.pos.y - touches[0].normalized.pos.y
                spread = (dx * dx + dy * dy).squareRoot()
                angle = atan2(dy, dx)
            }

            if !advTracking {
                advTracking = true
                advStartTime = timestamp
                advStartX = ax; advStartY = ay
                advLastX = ax; advLastY = ay
                advPeakFingers = n
                advStartSpread = spread; advLastSpread = spread
                advStartAngle = angle; advLastAngle = angle
            } else {
                if n > advPeakFingers {
                    // More fingers just landed — staggered landing shifts the
                    // centroid, so rebase to the "all fingers down" position.
                    advPeakFingers = n
                    advStartX = ax; advStartY = ay
                    advLastX = ax; advLastY = ay
                } else if n == advPeakFingers {
                    // Every peak finger still down: the genuinely stationary
                    // phase. This is the ONLY phase we measure tap travel over.
                    advLastX = ax; advLastY = ay
                }
                // n < advPeakFingers => fingers are lifting one by one; the
                // centroid of those remaining jumps, so don't count it as travel.
                if n >= 2 {
                    // Capture the baseline once two fingers are actually down.
                    if advStartSpread == 0 { advStartSpread = spread; advStartAngle = angle }
                    advLastSpread = spread
                    advLastAngle = angle
                }
            }
            return
        }

        // All fingers up: classify and reset.
        guard advTracking else { return }
        let dx = advLastX - advStartX
        let dy = advLastY - advStartY
        let travel = (dx * dx + dy * dy).squareRoot()
        let duration = timestamp - advStartTime
        let fingers = advPeakFingers
        let spreadDelta = advLastSpread - advStartSpread
        // Fold into (-π/2, π/2]: the two-finger line is undirected, so a frame
        // where the framework swaps finger order (a π flip) must read as ~0, not
        // as a half turn — that swap was a major source of rotate flakiness.
        var angleDelta = advLastAngle - advStartAngle
        while angleDelta > .pi / 2 { angleDelta -= .pi }
        while angleDelta < -.pi / 2 { angleDelta += .pi }
        advTracking = false
        advPeakFingers = 0
        advStartSpread = 0

        // Pinch / rotate are two-finger gestures; check before tap. Score each
        // against its threshold and fire the stronger, so they don't steal each
        // other's gestures (a rotation slightly changes spread and vice-versa).
        if fingers == 2 {
            let pinchScore = abs(spreadDelta) / pinchThreshold
            let rotateScore = abs(angleDelta) / rotateThreshold
            if pinchScore >= 1 || rotateScore >= 1 {
                if rotateScore >= pinchScore {
                    // normalized y increases upward -> increasing angle is CCW.
                    let dir: RotateDirection = angleDelta > 0 ? .counterclockwise : .clockwise
                    Log.line("MT: rotate \(dir.rawValue) delta=\(angleDelta)")
                    DispatchQueue.main.async { [weak self] in self?.onRotate?(dir) }
                } else {
                    let dir: PinchDirection = spreadDelta > 0 ? .pinchOut : .pinchIn
                    Log.line("MT: pinch \(dir.rawValue) delta=\(spreadDelta)")
                    DispatchQueue.main.async { [weak self] in self?.onPinch?(dir) }
                }
                return
            }
        }

        // Tap: 2+ fingers, stationary, brief.
        if fingers >= 2, travel < tapTravel, duration < tapMaxDuration {
            Log.line("MT: tap fingers=\(fingers) dur=\(duration)")
            DispatchQueue.main.async { [weak self] in self?.onTap?(fingers) }
        }
    }
}
