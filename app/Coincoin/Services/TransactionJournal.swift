//
//  TransactionJournal.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Foundation
import Synchronization

nonisolated struct JournalEntry: Codable, Hashable, Sendable {
    let payload: Data
    let signature: Data
    let publicKey: Data
    let phase: TrackedTransaction.Phase
}

nonisolated protocol TransactionJournal: Sendable {
    func load() throws -> [JournalEntry]
    func save(_ entries: [JournalEntry]) throws
}

nonisolated struct FileJournal: TransactionJournal {
    let url: URL

    static func standard(for wallet: Address) -> FileJournal {
        let directory = URL.applicationSupportDirectory.appending(path: "Coincoin", directoryHint: .isDirectory)
        return FileJournal(url: directory.appending(path: "transactions-\(wallet.hex).json"))
    }

    func load() throws -> [JournalEntry] {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        return try JSONDecoder().decode([JournalEntry].self, from: Data(contentsOf: url))
    }

    func save(_ entries: [JournalEntry]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

nonisolated final class InMemoryJournal: TransactionJournal {
    private let entries = Mutex<[JournalEntry]>([])

    func load() throws -> [JournalEntry] {
        entries.withLock { $0 }
    }

    func save(_ newEntries: [JournalEntry]) throws {
        entries.withLock { $0 = newEntries }
    }
}
