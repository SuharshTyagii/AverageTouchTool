import Foundation

/// Controls Night Shift intensity via the private CoreBrightness class
/// `CBBlueLightClient`. We declare the selectors we need as an @objc protocol
/// and bind an instance to it (the object already implements these methods).
@objc private protocol CBBlueLightClientProtocol {
    func setStrength(_ strength: Float, commit: Bool) -> Bool
    func getStrength(_ strength: UnsafeMutablePointer<Float>) -> Bool
    func setEnabled(_ enabled: Bool) -> Bool
    // Fills a BlueLightStatus struct; its first byte is the `active` BOOL
    // (whether the warm tint is currently applied). We read just that byte, so
    // we don't depend on the rest of the (private) struct layout.
    func getBlueLightStatus(_ status: UnsafeMutableRawPointer) -> Bool
}

final class NightShift {
    static let shared = NightShift()

    private let client: CBBlueLightClientProtocol?

    private init() {
        if let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type {
            let instance = cls.init()
            client = unsafeBitCast(instance, to: CBBlueLightClientProtocol.self)
        } else {
            client = nil
        }
    }

    var isAvailable: Bool { client != nil }

    /// Current intensity 0…1.
    func strength() -> Float {
        var value: Float = 0
        _ = client?.getStrength(&value)
        return value
    }

    /// Set intensity. Raising above 0 enables Night Shift; dropping to 0 turns
    /// it off — so the slider acts as a true "intensity riser".
    func apply(_ value: Float) {
        let v = max(0, min(1, value))
        if v <= 0.001 {
            _ = client?.setEnabled(false)
        } else {
            _ = client?.setEnabled(true)
            _ = client?.setStrength(v, commit: true)
        }
    }

    /// Whether the warm tint is currently applied right now.
    func isEnabled() -> Bool {
        guard let client else { return false }
        var buffer = [UInt8](repeating: 0, count: 128)
        let ok = buffer.withUnsafeMutableBytes { client.getBlueLightStatus($0.baseAddress!) }
        return ok && buffer[0] != 0
    }

    /// Flip Night Shift on/off. When turning on with no configured intensity,
    /// bump it to full so the toggle has a visible effect.
    func toggle() {
        if isEnabled() {
            _ = client?.setEnabled(false)
        } else {
            _ = client?.setEnabled(true)
            if strength() <= 0.001 { _ = client?.setStrength(1.0, commit: true) }
        }
    }
}
