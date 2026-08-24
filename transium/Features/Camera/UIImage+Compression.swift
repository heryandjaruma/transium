//
//  UIImage+Compression.swift
//  transium
//

import UIKit

extension UIImage {
    /// Re-encodes (and, if needed, downscales) this image as JPEG until it fits under
    /// `maxBytes` — lowering quality first, then shrinking dimensions if quality alone isn't
    /// enough for a large source image. Shared by every upload path fed by a captured/picked
    /// photo (custom camera keepsakes, avatar), so none of them ship a full-resolution photo
    /// as-is. Synchronous and can take real CPU time on a full-resolution camera photo — call
    /// from a background task, not directly on the main actor.
    nonisolated func compressedJPEGData(maxBytes: Int = 1_000_000) -> Data? {
        var candidate = self
        var quality: CGFloat = 0.9

        for _ in 0..<6 {
            var data = candidate.jpegData(compressionQuality: quality)

            while let currentData = data, currentData.count > maxBytes, quality > 0.1 {
                quality -= 0.15
                data = candidate.jpegData(compressionQuality: quality)
            }

            if let data, data.count <= maxBytes {
                return data
            }

            // Still too big even at low quality; shrink the dimensions and try again.
            let smallerSize = CGSize(width: candidate.size.width * 0.7, height: candidate.size.height * 0.7)
            guard smallerSize.width > 50, smallerSize.height > 50, let resized = candidate.resized(to: smallerSize) else {
                return data
            }

            candidate = resized
            quality = 0.8
        }

        return candidate.jpegData(compressionQuality: 0.3)
    }
}
