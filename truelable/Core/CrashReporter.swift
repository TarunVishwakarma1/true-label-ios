//
//  CrashReporter.swift
//  truelable
//
//  MetricKit, not a hand-rolled signal handler: a signal handler has to be
//  async-signal-safe (no malloc, no ARC, most of the Swift runtime is off
//  limits) to avoid crashing *harder* while reporting a crash — that's a
//  narrow, easy-to-get-wrong problem real crash reporters spend thousands
//  of lines getting right. The OS already solves it and hands the result
//  to MXMetricManagerSubscriber on a later launch, typically within a day.
//

import Foundation
import MetricKit
import UIKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()

    private override init() {}

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for diagnostic in payloads.flatMap({ $0.crashDiagnostics ?? [] }) {
            Task { try? await Self.submit(diagnostic) }
        }
    }

    private static func submit(_ diagnostic: MXCrashDiagnostic) async throws {
        let meta = diagnostic.metaData
        let stackTrace = String(data: diagnostic.callStackTree.jsonRepresentation(), encoding: .utf8)

        var title = "Crash"
        if let type = diagnostic.exceptionType { title = "Exception type \(type)" }
        else if let signal = diagnostic.signal { title = "Signal \(signal)" }

        try await API.submitCrashReport(.init(
            title: title,
            description: diagnostic.terminationReason,
            stackTrace: stackTrace,
            appVersion: meta.applicationBuildVersion,
            osVersion: meta.osVersion,
            deviceModel: meta.deviceType,
            deviceId: UIDevice.current.identifierForVendor?.uuidString
        ))
    }
}
