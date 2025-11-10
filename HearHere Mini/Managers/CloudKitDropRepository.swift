import Foundation
import CloudKit
import CoreLocation

struct CloudKitDropRepository {
    private let database: CKDatabase
    private let recordType = "AudioDrop"

    init(container: CKContainer = .default(), scope: CKDatabase.Scope = .private) {
        self.database = container.database(with: scope)
    }

    func fetchAll() async throws -> [AudioDrop] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var drops: [AudioDrop] = []

        var cursor: CKQueryOperation.Cursor? = nil
        repeat {
            let batch: ([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?)
            if let existingCursor = cursor {
                batch = try await database.records(continuingMatchFrom: existingCursor)
            } else {
                batch = try await database.records(matching: query)
            }

            let (matchResults, newCursor) = batch
            cursor = newCursor

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let drop = try mapRecordToDrop(record) {
                        drops.append(drop)
                    }
                case .failure(let error):
                    throw error
                }
            }
        } while cursor != nil

        return drops
    }

    func save(_ drop: AudioDrop, audioFileURL: URL) async throws {
        let recordID = CKRecord.ID(recordName: drop.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        record[Field.createdAt.rawValue] = drop.createdAt as CKRecordValue
        record[Field.duration.rawValue] = drop.durationSec as CKRecordValue
        record[Field.location.rawValue] = CLLocation(latitude: drop.latitude, longitude: drop.longitude)
        record[Field.filename.rawValue] = drop.filename as CKRecordValue
        record[Field.identifier.rawValue] = drop.id.uuidString as CKRecordValue
        record[Field.audioAsset.rawValue] = CKAsset(fileURL: audioFileURL)

        _ = try await database.save(record)
    }

    private func mapRecordToDrop(_ record: CKRecord) throws -> AudioDrop? {
        guard
            let location = record[Field.location.rawValue] as? CLLocation,
            let createdAt = record[Field.createdAt.rawValue] as? Date,
            let duration = record[Field.duration.rawValue] as? Double,
            let filename = record[Field.filename.rawValue] as? String
        else {
            return nil
        }

        let identifierString = (record[Field.identifier.rawValue] as? String) ?? record.recordID.recordName
        guard let identifier = UUID(uuidString: identifierString) else { return nil }

        if let asset = record[Field.audioAsset.rawValue] as? CKAsset, let sourceURL = asset.fileURL {
            try persistAssetIfNeeded(from: sourceURL, filename: filename)
        }

        return AudioDrop(
            id: identifier,
            createdAt: createdAt,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            durationSec: duration,
            filename: filename
        )
    }

    private func persistAssetIfNeeded(from sourceURL: URL, filename: String) throws {
        let destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return
        }

        let tempURL = sourceURL
        do {
            try FileManager.default.copyItem(at: tempURL, to: destinationURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
            // Ignore race condition if the file was created between the existence check and copy.
        }
    }

    private enum Field: String {
        case createdAt
        case duration
        case location
        case filename
        case identifier
        case audioAsset
    }
}
