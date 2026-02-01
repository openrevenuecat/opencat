import Foundation

// MARK: - Migration Result

struct MigrationResult {
    let success: Bool
    let alreadyMigrated: Bool
    let message: String
    let stats: MigrationStats?
}

struct MigrationStats {
    let eventsMigrated: Int
    let tasksMigrated: Int
    let guestsMigrated: Int
    let agendasMigrated: Int
    let expensesMigrated: Int
    let vendorsMigrated: Int
    let devicesMigrated: Int

    var totalItemsMigrated: Int {
        eventsMigrated + tasksMigrated + guestsMigrated +
        agendasMigrated + expensesMigrated + vendorsMigrated + devicesMigrated
    }
}

// MARK: - Migration Service Protocol

protocol MigrationServiceProtocol {
    var hasMigrated: Bool { get }
    var lastMigrationVersion: String? { get }
    func migrateUserDataIfNeeded() async throws -> MigrationResult?
    func forceMigration() async throws -> MigrationResult
    func resetMigrationStatus()
}

// MARK: - Migration API Protocol

/// Protocol for gRPC migration API calls
protocol MigrationAPIProtocol {
    func migrateUserData(appVersion: String) async throws -> (
        success: Bool,
        alreadyMigrated: Bool,
        message: String,
        stats: MigrationStats?
    )
}

// MARK: - Migration Service Implementation

final class MigrationServiceImpl: MigrationServiceProtocol {

    // MARK: - Constants

    private enum Keys {
        static let hasMigrated = "rushday.migration.hasMigrated"
        static let lastMigrationVersion = "rushday.migration.lastVersion"
        static let migrationTimestamp = "rushday.migration.timestamp"
    }

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let migrationAPI: MigrationAPIProtocol?

    var hasMigrated: Bool {
        userDefaults.bool(forKey: Keys.hasMigrated)
    }

    var lastMigrationVersion: String? {
        userDefaults.string(forKey: Keys.lastMigrationVersion)
    }

    // MARK: - Init

    init(
        userDefaults: UserDefaults = .standard,
        migrationAPI: MigrationAPIProtocol? = nil
    ) {
        self.userDefaults = userDefaults
        self.migrationAPI = migrationAPI
    }

    // MARK: - Public Methods

    /// Migrates user data from Firestore to gRPC backend if not already migrated
    /// - Returns: MigrationResult if migration was attempted, nil if already migrated
    func migrateUserDataIfNeeded() async throws -> MigrationResult? {
        // Check if already migrated locally
        if hasMigrated {
            return nil
        }

        return try await performMigration()
    }

    /// Forces a migration attempt regardless of local status
    /// - Returns: MigrationResult with migration outcome
    func forceMigration() async throws -> MigrationResult {
        return try await performMigration()
    }

    /// Resets the local migration status (useful for testing or re-migration)
    func resetMigrationStatus() {
        userDefaults.removeObject(forKey: Keys.hasMigrated)
        userDefaults.removeObject(forKey: Keys.lastMigrationVersion)
        userDefaults.removeObject(forKey: Keys.migrationTimestamp)
    }

    // MARK: - Private Methods

    private func performMigration() async throws -> MigrationResult {
        guard let api = migrationAPI else {
            print("📦 [MigrationService] No migration API configured — marking as migrated")
            let appVersion = Bundle.main.appVersion
            markAsMigrated(version: appVersion)
            return MigrationResult(
                success: true,
                alreadyMigrated: true,
                message: "Migration API not configured",
                stats: nil
            )
        }

        let appVersion = Bundle.main.appVersion
        print("📦 [MigrationService] Calling gRPC MigrateUserData (appVersion: \(appVersion))...")

        let response = try await api.migrateUserData(appVersion: appVersion)
        print("📦 [MigrationService] gRPC response — success: \(response.success), alreadyMigrated: \(response.alreadyMigrated), message: \(response.message)")

        let result = MigrationResult(
            success: response.success,
            alreadyMigrated: response.alreadyMigrated,
            message: response.message,
            stats: response.stats
        )

        // Mark as migrated locally
        if response.success || response.alreadyMigrated {
            print("📦 [MigrationService] Marking as migrated locally (version: \(appVersion))")
            markAsMigrated(version: appVersion)
        } else {
            print("📦 [MigrationService] NOT marking as migrated — will retry on next sign-in")
        }

        return result
    }

    private func markAsMigrated(version: String) {
        userDefaults.set(true, forKey: Keys.hasMigrated)
        userDefaults.set(version, forKey: Keys.lastMigrationVersion)
        userDefaults.set(Date().timeIntervalSince1970, forKey: Keys.migrationTimestamp)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var fullVersion: String {
        return "\(appVersion)+\(buildNumber)"
    }
}

// MARK: - gRPC Migration API Implementation

/// Implementation of MigrationAPIProtocol using GRPCClientService
final class GRPCMigrationAPI: MigrationAPIProtocol {

    private let grpcService: GRPCClientService

    init(grpcService: GRPCClientService = .shared) {
        self.grpcService = grpcService
    }

    func migrateUserData(appVersion: String) async throws -> (
        success: Bool,
        alreadyMigrated: Bool,
        message: String,
        stats: MigrationStats?
    ) {
        let response = try await grpcService.migrateUserData(appVersion: appVersion)

        let stats: MigrationStats? = response.hasStats ? MigrationStats(
            eventsMigrated: Int(response.stats.eventsMigrated),
            tasksMigrated: Int(response.stats.tasksMigrated),
            guestsMigrated: Int(response.stats.guestsMigrated),
            agendasMigrated: Int(response.stats.agendasMigrated),
            expensesMigrated: Int(response.stats.expensesMigrated),
            vendorsMigrated: Int(response.stats.vendorsMigrated),
            devicesMigrated: Int(response.stats.devicesMigrated)
        ) : nil

        return (
            success: response.success,
            alreadyMigrated: response.alreadyMigrated,
            message: response.message,
            stats: stats
        )
    }
}
