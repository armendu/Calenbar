//
//  NSImage+AssetCopy.swift
//  MeetingBarTests
//

import AppKit

extension NSImage {
    /// Whether this image draws the same pixels as the named asset at this
    /// image's size. The status bar shows resized copies of named assets,
    /// which keep the artwork but not the asset's name.
    func looksLike(assetNamed name: String) -> Bool {
        guard let asset = NSImage(named: name) else { return false }
        let mine = Self.pixels(of: self, size: size)
        return mine != nil && mine == Self.pixels(of: asset, size: size)
    }

    private static func pixels(of image: NSImage, size: NSSize) -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.tiffRepresentation
    }
}
