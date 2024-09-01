//
//  main.swift
//  qr - decode QR codes in an image
//
//  Created by Roland Crosby on 4/18/23.
//

import Foundation
import CoreImage
import ArgumentParser

extension String: Error {}

struct QR: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Decode QR codes in an image"
    )

    @Argument(help: "Image file to detect QR codes in", completion: .file())
    var filePath: String

    @Option(
        name: .shortAndLong,
        help: "If specified, path to write detected QR codes to as PNG files"
    )
    var out: String?

    mutating func run() throws {
        let context = CIContext()
        guard let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context) else {
            throw ExitCode.failure
        }
        let imageURL = URL(filePath: filePath)
        guard let image = CIImage(contentsOf: imageURL) else {
            throw ExitCode.failure
        }
        let features = detector.features(in: image)
        if features.count == 0 {
            FileHandle.standardError.write("No QR codes detected\n".data(using: .utf8)!)
            return
        }
        for (index, feature) in features.enumerated() {
            let feature = feature as! CIQRCodeFeature
            let descriptor = feature.symbolDescriptor!
            let payload = descriptor.errorCorrectedPayload
            if let message = feature.messageString {
                print(message)
                if var outFile = out {
                    if (outFile as NSString).pathExtension == "png" {
                        outFile = (outFile as NSString).deletingPathExtension
                    }
                    if features.count > 1 {
                        outFile = "\(outFile)-\(index + 1).png"
                    } else {
                        outFile = "\(outFile).png"
                    }
                    guard let qrGenFilter = CIFilter(name:"CIQRCodeGenerator") else {
                        throw ExitCode.failure
                    }
                    qrGenFilter.setDefaults()
                    // I don't think this is the right thing to write
                    qrGenFilter.setValue(message.data(using: .utf8), forKey: "inputMessage")
                    let output = qrGenFilter.outputImage!
                    let outCtx = CIContext()
                    do {
                        try outCtx.writePNGRepresentation(of: output, to: URL(filePath: outFile),
                                                          format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
                    } catch {
                        throw ExitCode.failure
                    }
                }
            } else {
                let hexPayload = payload.map { String(format: "%02hhx", $0) }.joined()
                print(hexPayload)
            }
        }
    }
}

QR.main()
