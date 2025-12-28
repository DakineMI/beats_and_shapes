import Foundation
import OSLog
import SwiftUI

/// Modern observability framework for Beats & Shapes (2025 standards)
@globalActor
actor Logger {
    static let shared = Logger()
    
    private let subsystem = "com.madbadbrax.beatsandshapes"
    private let gameLog = os.Logger(subsystem: "com.madbadbrax.beatsandshapes", category: "Game")
    private let audioLog = os.Logger(subsystem: "com.madbadbrax.beatsandshapes", category: "Audio")
    private let performanceLog = os.Logger(subsystem: "com.madbadbrax.beatsandshapes", category: "Performance")
    private let uiLog = os.Logger(subsystem: "com.madbadbrax.beatsandshapes", category: "UI")
    private let networkLog = os.Logger(subsystem: "com.madbadbrax.beatsandshapes", category: "Network")
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    enum Category {
        case game
        case audio
        case performance
        case ui
        case network
        
        var logger: os.Logger {
            switch self {
            case .game: return Logger.shared.gameLog
            case .audio: return Logger.shared.audioLog
            case .performance: return Logger.shared.performanceLog
            case .ui: return Logger.shared.uiLog
            case .network: return Logger.shared.networkLog
            }
        }
    }
    
    /// Thread-safe logging with structured data
    func log(
        _ message: String,
        level: LogLevel = .info,
        category: Category = .game,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        additionalInfo: [String: Any] = [:]
    ) async {
        let fileName = (file as NSString).lastPathComponent
        
        var logMessage = message
        var userInfo: [String: Any] = [
            "file": fileName,
            "function": function,
            "line": line
        ]
        
        userInfo.merge(additionalInfo) { (_, new) in new }
        
        #if DEBUG
        if additionalInfo.isEmpty {
            category.logger.log(level: level.osLogType, "\(message)")
        } else {
            category.logger.log(level: level.osLogType, "\(message) - \(additionalInfo)")
        }
        #else
        // In release, only log warnings and above
        if level != .debug && level != .info {
            category.logger.log(level: level.osLogType, "\(message)")
        }
        #endif
        
        // Store metrics for performance monitoring
        if category == .performance {
            await MetricsManager.shared.recordPerformanceMetric(
                name: "log_event",
                value: 1,
                metadata: userInfo
            )
        }
    }
    
    /// Performance logging with automatic timing
    func measure<T>(
        operation: String,
        category: Category = .performance,
        _ block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CACurrentMediaTime()
        
        let result = try await block()
        
        let duration = CACurrentMediaTime() - startTime
        
        await log(
            "Performance: \(operation) took \(String(format: "%.3f", duration))s",
            level: .debug,
            category: category,
            additionalInfo: [
                "operation": operation,
                "duration": duration,
                "start_time": startTime
            ]
        )
        
        await MetricsManager.shared.recordPerformanceMetric(
            name: operation,
            value: duration,
            metadata: ["category": String(describing: category)]
        )
        
        return result
    }
    
    /// Error logging with automatic context capture
    func logError(
        _ error: Error,
        operation: String = "unknown",
        category: Category = .game,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(
            "Error in \(operation): \(error.localizedDescription)",
            level: .error,
            category: category,
            file: file,
            function: function,
            line: line,
            additionalInfo: [
                "error_type": String(describing: type(of: error)),
                "operation": operation,
                "error_description": error.localizedDescription
            ]
        )
    }
}

/// Metrics collection for observability (2025 standards)
@MainActor
class MetricsManager: ObservableObject {
    static let shared = MetricsManager()
    
    @Published private(set) var frameRate: Double = 0
    @Published private(set) var memoryUsage: Double = 0
    @Published private(set) var audioLatency: Double = 0
    @Published private(set) var networkRequests: Int = 0
    @Published private(set) var errorCount: Int = 0
    
    private var frameTimeBuffer: [Double] = []
    private var performanceMetrics: [String: [Double]] = [:]
    private var lastUpdateTime: TimeInterval = 0
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    /// Setup performance monitoring timers
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                await self.updateMetrics()
            }
        }
    }
    
    /// Update all metrics
    private func updateMetrics() async {
        await updateFrameRate()
        await updateMemoryUsage()
        await calculateAggregates()
    }
    
    /// Calculate frame rate from buffer
    private func updateFrameRate() async {
        guard frameTimeBuffer.count > 0 else { return }
        
        let currentTime = CACurrentMediaTime()
        frameTimeBuffer.append(currentTime)
        
        // Keep only last second of data
        frameTimeBuffer.removeAll { currentTime - $0 > 1.0 }
        
        if frameTimeBuffer.count > 1 {
            let frameDifferences = zip(frameTimeBuffer.dropFirst(), frameTimeBuffer).map(-)
            let averageFrameTime = frameDifferences.reduce(0, +) / Double(frameDifferences.count)
            frameRate = 1.0 / averageFrameTime
        }
    }
    
    /// Update memory usage
    private func updateMemoryUsage() async {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / (1024 * 1024) // MB
        }
    }
    
    /// Record performance metric
    func recordPerformanceMetric(
        name: String,
        value: Double,
        metadata: [String: Any] = [:]
    ) async {
        if performanceMetrics[name] == nil {
            performanceMetrics[name] = []
        }
        performanceMetrics[name]?.append(value)
        
        // Keep only last 100 measurements
        if let metrics = performanceMetrics[name], metrics.count > 100 {
            performanceMetrics[name] = Array(metrics.suffix(100))
        }
        
        await Logger.shared.log(
            "Recorded metric: \(name) = \(value)",
            level: .debug,
            category: .performance,
            additionalInfo: metadata
        )
    }
    
    /// Calculate aggregates for dashboard
    private func calculateAggregates() async {
        // Could be expanded to send to monitoring service
        #if DEBUG
        for (name, values) in performanceMetrics {
            if values.count > 0 {
                let avg = values.reduce(0, +) / Double(values.count)
                let min = values.min() ?? 0
                let max = values.max() ?? 0
                
                await Logger.shared.log(
                    "Metric \(name): avg=\(String(format: "%.3f", avg)), min=\(String(format: "%.3f", min)), max=\(String(format: "%.3f", max))",
                    level: .debug,
                    category: .performance
                )
            }
        }
        #endif
    }
    
    /// Get metric statistics
    func getStatistics(for metricName: String) -> (average: Double, min: Double, max: Double, count: Int)? {
        guard let values = performanceMetrics[metricName], !values.isEmpty else {
            return nil
        }
        
        return (
            average: values.reduce(0, +) / Double(values.count),
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            count: values.count
        )
    }
    
    /// Increment error count
    func recordError() {
        errorCount += 1
    }
    
    /// Increment network requests
    func recordNetworkRequest() {
        networkRequests += 1
    }
}

/// Health monitoring for system status (2025 standards)
@MainActor
class HealthMonitor: ObservableObject {
    static let shared = HealthMonitor()
    
    @Published private(set) var systemHealth: HealthStatus = .healthy
    @Published private(set) var warnings: [String] = []
    @Published private(set) var errors: [String] = []
    
    enum HealthStatus {
        case healthy
        case warning
        case critical
        
        var color: Color {
            switch self {
            case .healthy: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
    
    private init() {
        setupHealthMonitoring()
    }
    
    /// Setup periodic health checks
    private func setupHealthMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                await self.performHealthCheck()
            }
        }
    }
    
    /// Perform comprehensive health check
    private func performHealthCheck() async {
        var newWarnings: [String] = []
        var newErrors: [String] = []
        
        // Check frame rate
        if MetricsManager.shared.frameRate < 30 {
            newErrors.append("Low frame rate: \(String(format: "%.1f", MetricsManager.shared.frameRate)) FPS")
        } else if MetricsManager.shared.frameRate < 45 {
            newWarnings.append("Reduced frame rate: \(String(format: "%.1f", MetricsManager.shared.frameRate)) FPS")
        }
        
        // Check memory usage
        if MetricsManager.shared.memoryUsage > 200 {
            newErrors.append("High memory usage: \(String(format: "%.1f", MetricsManager.shared.memoryUsage)) MB")
        } else if MetricsManager.shared.memoryUsage > 150 {
            newWarnings.append("Elevated memory usage: \(String(format: "%.1f", MetricsManager.shared.memoryUsage)) MB")
        }
        
        // Check error rate
        if MetricsManager.shared.errorCount > 10 {
            newErrors.append("High error count: \(MetricsManager.shared.errorCount)")
        }
        
        warnings = newWarnings
        errors = newErrors
        
        if !newErrors.isEmpty {
            systemHealth = .critical
        } else if !newWarnings.isEmpty {
            systemHealth = .warning
        } else {
            systemHealth = .healthy
        }
        
        if systemHealth != .healthy {
            await Logger.shared.log(
                "System health: \(systemHealth) - Warnings: \(newWarnings.count), Errors: \(newErrors.count)",
                level: .warning,
                category: .performance,
                additionalInfo: [
                    "health_status": String(describing: systemHealth),
                    "warnings": newWarnings,
                    "errors": newErrors
                ]
            )
        }
    }
}