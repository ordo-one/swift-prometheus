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

extension PrometheusCollectorRegistry {
    /// The values of the registered metrics, read in-process instead of parsing ``emitToString()``.
    public struct Snapshot: Sendable, Hashable {
        /// One sample per counter series.
        public var counters: [Sample]
        /// One sample per gauge series.
        public var gauges: [Sample]
    }

    /// One counter or gauge series.
    public struct Sample: Sendable, Hashable {
        /// The validated metric name, as written by ``PrometheusCollectorRegistry/emit(into:)``.
        public var name: String
        /// The validated label pairs, in registration order.
        public var labels: [(String, String)]
        /// The current value; for a counter, its integer and floating-point parts summed.
        public var value: Double

        public init(name: String, labels: [(String, String)], value: Double) {
            self.name = name
            self.labels = labels
            self.value = value
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.name == rhs.name && lhs.value == rhs.value && lhs.labels.elementsEqual(rhs.labels, by: ==)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(self.name)
            hasher.combine(self.value)
            for (key, value) in self.labels {
                hasher.combine(key)
                hasher.combine(value)
            }
        }
    }
}
