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
            let meta = diagnostic.metaData
            let submission = Self.submission(
                exceptionType: diagnostic.exceptionType,
                signal: diagnostic.signal,
                terminationReason: diagnostic.terminationReason,
                stackTraceJSON: String(data: diagnostic.callStackTree.jsonRepresentation(), encoding: .utf8),
                appBuildVersion: meta.applicationBuildVersion,
                osVersion: meta.osVersion,
                deviceType: meta.deviceType,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
            Task { try? await API.submitCrashReport(submission) }
        }
    }

    /// The actual mapping logic, pulled out of `didReceive` so it's
    /// testable without MetricKit's opaque, OS-only diagnostic types —
    /// `MXCrashDiagnostic` has no public initializer, so a test can never
    /// construct one to hand to this function directly.
    static func submission(
        exceptionType: NSNumber?,
        signal: NSNumber?,
        terminationReason: String?,
        stackTraceJSON: String?,
        appBuildVersion: String,
        osVersion: String,
        deviceType: String,
        deviceId: String?
    ) -> API.CrashReportSubmission {
        let title: String
        if let exceptionType {
            title = "Exception type \(exceptionType)"
        } else if let signal {
            title = "Signal \(signal)"
        } else {
            title = "Crash"
        }

        return API.CrashReportSubmission(
            title: title,
            description: terminationReason,
            stackTrace: stackTraceJSON,
            appVersion: appBuildVersion,
            osVersion: osVersion,
            deviceModel: deviceType,
            deviceId: deviceId
        )
    }
}
