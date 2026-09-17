import Foundation

enum TestEnum: Codable {
    case mediaViewer(attachments: [String], selectedAttachment: String, useRemoteMedia: Bool)
    
    enum CodingKeys: CodingKey {
        case mediaViewer
    }
    
    enum MediaViewerCodingKeys: CodingKey {
        case attachments, selectedAttachment, useRemoteMedia
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.mediaViewer) {
            let nested = try container.nestedContainer(keyedBy: MediaViewerCodingKeys.self, forKey: .mediaViewer)
            self = .mediaViewer(attachments: ["1"], selectedAttachment: "1", useRemoteMedia: false)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: ""))
        }
    }
    
    func encode(to encoder: Encoder) throws {
    }
}
