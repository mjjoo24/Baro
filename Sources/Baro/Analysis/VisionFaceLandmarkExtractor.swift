import CoreGraphics
import Foundation
import BaroCore
import Vision

public final class VisionFaceLandmarkExtractor: @unchecked Sendable {
    public init() {}

    public func extract(from pixelBuffer: CVPixelBuffer) -> FaceLandmarkSnapshot? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first, let landmarks = face.landmarks else {
            return nil
        }

        guard let leftEye = averagedImagePoint(region: landmarks.leftEye, boundingBox: face.boundingBox),
              let rightEye = averagedImagePoint(region: landmarks.rightEye, boundingBox: face.boundingBox) else {
            return nil
        }

        let nose = averagedImagePoint(region: landmarks.nose, boundingBox: face.boundingBox)
            ?? CGPoint(x: (leftEye.x + rightEye.x) / 2, y: (leftEye.y + rightEye.y) / 2)

        return FaceLandmarkSnapshot(
            faceBoundingBoxWidth: Double(face.boundingBox.width),
            faceBoundingBoxHeight: Double(face.boundingBox.height),
            leftEyeX: Double(leftEye.x),
            leftEyeY: Double(leftEye.y),
            rightEyeX: Double(rightEye.x),
            rightEyeY: Double(rightEye.y),
            noseTipX: Double(nose.x),
            noseTipY: Double(nose.y)
        )
    }

    private func averagedImagePoint(region: VNFaceLandmarkRegion2D?, boundingBox: CGRect) -> CGPoint? {
        guard let region, region.pointCount > 0 else { return nil }
        let points = region.normalizedPoints
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let count = CGFloat(points.count)
        let avgInFaceSpace = CGPoint(x: sum.x / count, y: sum.y / count)

        let absoluteBottomLeft = CGPoint(
            x: boundingBox.origin.x + avgInFaceSpace.x * boundingBox.width,
            y: boundingBox.origin.y + avgInFaceSpace.y * boundingBox.height
        )

        return CGPoint(x: absoluteBottomLeft.x, y: 1 - absoluteBottomLeft.y)
    }
}
