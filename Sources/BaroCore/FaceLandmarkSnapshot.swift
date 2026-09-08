import Foundation

public struct FaceLandmarkSnapshot: Equatable, Sendable, Codable {
    public var faceBoundingBoxWidth: Double
    public var faceBoundingBoxHeight: Double
    public var leftEyeX: Double
    public var leftEyeY: Double
    public var rightEyeX: Double
    public var rightEyeY: Double
    public var noseTipX: Double
    public var noseTipY: Double

    public init(
        faceBoundingBoxWidth: Double,
        faceBoundingBoxHeight: Double,
        leftEyeX: Double,
        leftEyeY: Double,
        rightEyeX: Double,
        rightEyeY: Double,
        noseTipX: Double = 0,
        noseTipY: Double
    ) {
        self.faceBoundingBoxWidth = faceBoundingBoxWidth
        self.faceBoundingBoxHeight = faceBoundingBoxHeight
        self.leftEyeX = leftEyeX
        self.leftEyeY = leftEyeY
        self.rightEyeX = rightEyeX
        self.rightEyeY = rightEyeY
        self.noseTipX = noseTipX
        self.noseTipY = noseTipY
    }

    public static func average(_ samples: [FaceLandmarkSnapshot]) -> FaceLandmarkSnapshot? {
        guard !samples.isEmpty else { return nil }
        let n = Double(samples.count)
        var sum = FaceLandmarkSnapshot(
            faceBoundingBoxWidth: 0, faceBoundingBoxHeight: 0,
            leftEyeX: 0, leftEyeY: 0, rightEyeX: 0, rightEyeY: 0,
            noseTipX: 0, noseTipY: 0
        )
        for sample in samples {
            sum.faceBoundingBoxWidth += sample.faceBoundingBoxWidth
            sum.faceBoundingBoxHeight += sample.faceBoundingBoxHeight
            sum.leftEyeX += sample.leftEyeX
            sum.leftEyeY += sample.leftEyeY
            sum.rightEyeX += sample.rightEyeX
            sum.rightEyeY += sample.rightEyeY
            sum.noseTipX += sample.noseTipX
            sum.noseTipY += sample.noseTipY
        }
        return FaceLandmarkSnapshot(
            faceBoundingBoxWidth: sum.faceBoundingBoxWidth / n,
            faceBoundingBoxHeight: sum.faceBoundingBoxHeight / n,
            leftEyeX: sum.leftEyeX / n,
            leftEyeY: sum.leftEyeY / n,
            rightEyeX: sum.rightEyeX / n,
            rightEyeY: sum.rightEyeY / n,
            noseTipX: sum.noseTipX / n,
            noseTipY: sum.noseTipY / n
        )
    }

    public var averageEyeY: Double {
        (leftEyeY + rightEyeY) / 2
    }

    public var eyeCenterX: Double {
        (leftEyeX + rightEyeX) / 2
    }

    public var tiltAngleDegrees: Double {
        let dy = rightEyeY - leftEyeY
        let dx = rightEyeX - leftEyeX
        guard dx != 0 || dy != 0 else { return 0 }
        return atan2(dy, dx) * 180 / .pi
    }

    public var turnOffsetRatio: Double {
        guard faceBoundingBoxWidth > 0 else { return 0 }
        return (noseTipX - eyeCenterX) / faceBoundingBoxWidth
    }
}
