import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SourcePhoto: Identifiable, Sendable {
    let id: Int
    let name: String
    let jpeg: Data

    static let maximumCount = 10

    var dataURL: String { "data:image/jpeg;base64," + jpeg.base64EncodedString() }

    static func load(_ urls: [URL], startingAt firstID: Int) throws -> [SourcePhoto] {
        try urls.enumerated().map { index, url in
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
                throw AppFailure.setup("Could not open \(url.lastPathComponent) as a photo.")
            }
            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3_000
            ] as CFDictionary
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
                throw AppFailure.setup("Could not decode \(url.lastPathComponent).")
            }
            let data = NSMutableData()
            guard let output = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw AppFailure.setup("Could not prepare \(url.lastPathComponent).")
            }
            let quality = [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary
            CGImageDestinationAddImage(output, try flattenTransparency(image, name: url.lastPathComponent), quality)
            guard CGImageDestinationFinalize(output), data.length <= 4_000_000 else {
                throw AppFailure.setup("\(url.lastPathComponent) is too large after processing. Crop the photo and try again.")
            }
            return SourcePhoto(id: firstID + index, name: url.lastPathComponent, jpeg: data as Data)
        }
    }

    private static func flattenTransparency(_ image: CGImage, name: String) throws -> CGImage {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: break
        }
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw AppFailure.setup("Could not prepare the background of \(name).")
        }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(image, in: bounds)
        guard let flattened = context.makeImage() else {
            throw AppFailure.setup("Could not prepare the background of \(name).")
        }
        return flattened
    }
}
