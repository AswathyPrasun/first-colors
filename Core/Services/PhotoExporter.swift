import Foundation
import Photos

/// Saves finished art to the Photos library. Only reachable from the parent area.
/// Uses add-only access: the app can add pictures but never read the library.
protocol PhotoExporting: Sendable {
    /// Asks for add-only access if needed. Returns whether saving is allowed.
    func requestAccess() async -> Bool
    func save(pngs: [Data]) async throws
}

struct PhotoExporter: PhotoExporting {
    func requestAccess() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return status == .authorized || status == .limited
        default:
            return false
        }
    }

    func save(pngs: [Data]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            for png in pngs {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil)
            }
        }
    }
}
