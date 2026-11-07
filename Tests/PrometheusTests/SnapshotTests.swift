//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftPrometheus open source project
//
// Copyright (c) 2018-2023 SwiftPrometheus project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftPrometheus project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Prometheus
import XCTest

final class SnapshotTests: XCTestCase {
    /// The snapshot must agree with the text export, series for series, or the mirrored values are
    /// not the values `/metrics` reports.
    func testSnapshotAgreesWithTextExport() {
        let registry = PrometheusCollectorRegistry()

        registry.makeCounter(name: "requests", labels: [("route", "/a")]).increment(by: Int64(7))
        registry.makeCounter(name: "requests", labels: [("route", "/b")]).increment(by: Int64(3))
        registry.makeCounter(name: "unlabeled_total").increment(by: Int64(5))
        let mixed = registry.makeCounter(name: "mixed_total")
        mixed.increment(by: Int64(2))
        mixed.increment(by: 0.25)
        registry.makeGauge(name: "in_flight", labels: [("route", "/a")]).set(to: 2)
        registry.makeGauge(name: "temperature").set(to: -0.5)
        registry.makeDurationHistogram(
            name: "latency",
            labels: [],
            buckets: [.milliseconds(1)]
        ).record(Duration.milliseconds(1))

        var exported = [String: Double]()
        for line in registry.emitToString().split(separator: "\n") {
            guard !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: " ")
            guard parts.count == 2, let value = Double(parts[1]) else { continue }
            exported[String(parts[0])] = value
        }

        let snapshot = registry.snapshot()
        XCTAssertEqual(snapshot.counters.count, 4)
        XCTAssertEqual(snapshot.gauges.count, 2, "histogram series must not be included")

        for sample in snapshot.counters + snapshot.gauges {
            let key: String
            if sample.labels.isEmpty {
                key = sample.name
            } else {
                let rendered = sample.labels.map { #"\#($0.0)="\#($0.1)""# }.joined(separator: ",")
                key = "\(sample.name){\(rendered)}"
            }
            XCTAssertEqual(exported[key], sample.value, "mismatch for \(key)")
        }

        XCTAssertEqual(Set(snapshot.counters.map(\.name)), ["requests", "unlabeled_total", "mixed_total"])
        XCTAssertEqual(Set(snapshot.gauges.map(\.name)), ["in_flight", "temperature"])
        XCTAssertEqual(snapshot.counters.first { $0.name == "mixed_total" }?.value, 2.25)
    }

    func testSnapshotUsesValidatedNamesAndDropsUnregisteredSeries() {
        let registry = PrometheusCollectorRegistry()
        registry.makeCounter(name: "my-metric", labels: [("a-b", "x")]).increment(by: Int64(1))
        let removed = registry.makeCounter(name: "removed_total")
        registry.unregisterCounter(removed)

        let counters = registry.snapshot().counters
        XCTAssertEqual(counters.count, 1)
        XCTAssertNotEqual(counters.first?.name, "my-metric")
        let line = #"\#(counters[0].name){\#(counters[0].labels[0].0)="x"} 1"#
        XCTAssertTrue(registry.emitToString().contains(line), "snapshot names must match the text export")
    }

    func testSampleEqualityComparesLabelsInOrder() {
        let ab = PrometheusCollectorRegistry.Sample(name: "m", labels: [("a", "1"), ("b", "2")], value: 1)
        let ba = PrometheusCollectorRegistry.Sample(name: "m", labels: [("b", "2"), ("a", "1")], value: 1)
        XCTAssertEqual(ab, PrometheusCollectorRegistry.Sample(name: "m", labels: [("a", "1"), ("b", "2")], value: 1))
        XCTAssertNotEqual(ab, ba)
    }
}
