import CoreImage
import UIKit
import Vision

/// Reads a photographed letter on the device: the text (German, French, Italian, English) and any
/// payment QR code. Only the recognised text is sent on for explaining; the photo stays on the phone.
enum LetterReader {
    struct Result {
        var text: String
        var payment: PaymentSlip?
    }

    enum ReadError: LocalizedError {
        case noText

        var errorDescription: String? { "letters.error.no_text".localized }
    }

    static func read(_ pages: [UIImage]) async throws -> Result {
        try await Task.detached(priority: .userInitiated) {
            var texts: [String] = []
            var payment: PaymentSlip?
            for page in pages {
                guard let cgImage = page.cgImage else { continue }
                let textRequest = VNRecognizeTextRequest()
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = true
                textRequest.recognitionLanguages = ["de-DE", "fr-FR", "it-IT", "en-US"]
                let barcodeRequest = VNDetectBarcodesRequest()
                barcodeRequest.symbologies = [.qr]

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: page.cgOrientation)
                try handler.perform([textRequest])
                let lines = (textRequest.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                if !lines.isEmpty { texts.append(lines.joined(separator: "\n")) }

                // A slip that can't be decoded must not cost the user the explanation.
                if payment == nil, (try? handler.perform([barcodeRequest])) != nil {
                    payment = (barcodeRequest.results ?? [])
                        .compactMap(\.payloadStringValue)
                        .lazy
                        .compactMap(PaymentSlip.parse)
                        .first
                }
                if payment == nil {
                    payment = coreImageQRPayloads(cgImage).lazy.compactMap(PaymentSlip.parse).first
                }
            }
            let text = texts.joined(separator: "\n\n---\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 20 else { throw ReadError.noText }
            return Result(text: String(text.prefix(12000)), payment: payment)
        }.value
    }
}

/// Core Image's detector: a second chance for QR codes Vision misses (or can't run, as in some simulators).
private func coreImageQRPayloads(_ image: CGImage) -> [String] {
    let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    let features = detector?.features(in: CIImage(cgImage: image)) ?? []
    return features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
