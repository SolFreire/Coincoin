//
//  QRCode.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import CoreImage.CIFilterBuiltins
import UIKit

enum QRCode {
    static func image(for text: String, side: CGFloat, scale: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let pixels = side * scale
        let factor = (pixels / output.extent.width).rounded(.down)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
