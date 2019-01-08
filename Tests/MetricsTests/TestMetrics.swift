@testable import CoreMetrics
@testable import protocol CoreMetrics.Timer
import Foundation

internal class TestMetrics: MetricsHandler {
    private let lock = NSLock() // TODO: consider lock per cache?
    var counters = [String: Counter]()
    var recorders = [String: Recorder]()
    var timers = [String: Timer]()

    public func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return self.make(label: label, dimensions: dimensions, cache: &self.counters, maker: TestCounter.init)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        let maker = { (label: String, dimensions: [(String, String)]) -> Recorder in
            TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        return self.make(label: label, dimensions: dimensions, cache: &self.recorders, maker: maker)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return self.make(label: label, dimensions: dimensions, cache: &self.timers, maker: TestTimer.init)
    }

    private func make<Item>(label: String, dimensions: [(String, String)], cache: inout [String: Item], maker: (String, [(String, String)]) -> Item) -> Item {
        let fqn = self.fqn(label: label, dimensions: dimensions)
        return self.lock.withLock {
            if let item = cache[fqn] {
                return item
            } else {
                let item = maker(label, dimensions)
                cache[fqn] = item
                return item
            }
        }
    }

    private func fqn(label: String, dimensions: [(String, String)]) -> String {
        return [[label], dimensions.compactMap { $0.1 }].flatMap { $0 }.joined(separator: ".")
    }
}

internal class TestCounter: Counter, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]

    let lock = NSLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func increment<DataType: BinaryInteger>(_ value: DataType) {
        self.lock.withLock {
            self.values.append((Date(), Int64(value)))
        }
        print("adding \(value) to \(self.label)")
    }

    public static func == (lhs: TestCounter, rhs: TestCounter) -> Bool {
        return lhs.id == rhs.id
    }
}

internal class TestRecorder: Recorder, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]
    let aggregate: Bool

    let lock = NSLock()
    var values = [(Date, Double)]()

    init(label: String, dimensions: [(String, String)], aggregate: Bool) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
    }

    func record<DataType: BinaryInteger>(_ value: DataType) {
        self.record(Double(value))
    }

    func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
        self.lock.withLock {
            // this may loose percision but good enough as an example
            values.append((Date(), Double(value)))
        }
        print("recoding \(value) in \(self.label)")
    }

    public static func == (lhs: TestRecorder, rhs: TestRecorder) -> Bool {
        return lhs.id == rhs.id
    }
}

internal class TestTimer: Timer, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]

    let lock = NSLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func recordNanoseconds(_ duration: Int64) {
        self.lock.withLock {
            values.append((Date(), duration))
        }
        print("recoding \(duration) \(self.label)")
    }

    public static func == (lhs: TestTimer, rhs: TestTimer) -> Bool {
        return lhs.id == rhs.id
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}