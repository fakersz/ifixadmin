//
//  CoverImage.swift
//  ifixadmin
//
//  Imagem de capa anexada às notificações.
//
//  Se existir um asset chamado "NotificationCover" no catálogo, ele é usado.
//  Caso contrário, desenha uma capa própria — assim o app funciona sem
//  depender de nenhum arquivo binário no repositório.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

enum CoverImage {
    /// Nome do asset opcional. Coloque uma imagem com esse nome no
    /// Assets.xcassets para usar sua própria foto de capa.
    static let assetName = "NotificationCover"

    private static let size = CGSize(width: 1024, height: 512)
    private static let fileName = "notification-cover.png"

    /// URL de um PNG pronto para virar `UNNotificationAttachment`.
    /// O arquivo é gerado uma vez e reaproveitado.
    static func url() -> URL? {
        let destination = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        guard let image = userProvidedImage() ?? generatedImage() else { return nil }
        guard write(image, to: destination) else { return nil }
        return destination
    }

    /// Apaga o arquivo em cache — chame se trocar a arte.
    static func invalidate() {
        let destination = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destination)
    }

    // MARK: - Fontes da imagem

    private static func userProvidedImage() -> CGImage? {
        #if canImport(UIKit)
        return UIImage(named: assetName)?.cgImage
        #else
        return nil
        #endif
    }

    /// Capa desenhada na mão: gradiente diagonal com alguns círculos soltos.
    private static func generatedImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let stops: [CGFloat] = [0, 1]
        let colors = [
            CGColor(red: 0.29, green: 0.24, blue: 0.72, alpha: 1),
            CGColor(red: 0.62, green: 0.29, blue: 0.75, alpha: 1)
        ] as CFArray

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: stops) {
            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        // Círculos decorativos, com posições fixas para a capa ser sempre igual.
        let circles: [(x: CGFloat, y: CGFloat, r: CGFloat, alpha: CGFloat)] = [
            (140, 380, 90, 0.14),
            (880, 150, 130, 0.10),
            (520, 430, 60, 0.12),
            (760, 400, 40, 0.16)
        ]
        for circle in circles {
            context.setFillColor(CGColor(gray: 1, alpha: circle.alpha))
            context.fillEllipse(in: CGRect(
                x: circle.x - circle.r,
                y: circle.y - circle.r,
                width: circle.r * 2,
                height: circle.r * 2
            ))
        }

        return context.makeImage()
    }

    private static func write(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return false }

        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}
