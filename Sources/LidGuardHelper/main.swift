import Foundation
import LidGuardCore
import LidGuardHelperKit
import os

let logger = Logger(subsystem: LidGuardConstants.bundleIdentifier, category: "helper")

do {
    let securityData = try Data(contentsOf: URL(fileURLWithPath: LidGuardConstants.securityPath))
    let security: SecurityConfiguration
    if let jsonConfiguration = try? LidGuardCoding.makeDecoder().decode(
        SecurityConfiguration.self,
        from: securityData
    ) {
        security = jsonConfiguration
    } else {
        security = try PropertyListDecoder().decode(SecurityConfiguration.self, from: securityData)
    }
    let engine = try GuardEngine(
        powerController: PMSetPowerController(),
        stateStore: JSONStateStore(),
        sensors: SystemSensors()
    )
    let service = HelperService(engine: engine)
    let delegate = HelperListenerDelegate(service: service, ownerUID: uid_t(security.ownerUID))
    let listener = NSXPCListener(machServiceName: LidGuardConstants.machServiceName)
    listener.setConnectionCodeSigningRequirement(security.clientRequirement)
    listener.delegate = delegate
    listener.resume()
    logger.info("LidGuard helper started")
    RunLoop.current.run()
} catch {
    logger.critical("Helper startup failed: \(error.localizedDescription, privacy: .public)")
    fputs("LidGuardHelper: \(error.localizedDescription)\n", stderr)
    exit(1)
}
