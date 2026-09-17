import Photos
import Foundation

func test() async {
    let data = Data()
    do {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    } catch {
    }
}
