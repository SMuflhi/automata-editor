import CoreGraphics

extension Array where Element == CGPoint {
    static func circle(
        center: CGPoint,
        radius: CGFloat
    ) -> Self {
        stride(from: CGFloat(0), to: 362, by: 2).map { index in
            let radians = index * CGFloat.pi / 180
            
            return CGPoint(
                x: CGFloat(center.x + radius * cos(radians)),
                y: CGFloat(center.y + radius * sin(radians))
            )
        }
    }
    
    static func arrow(
        startPoint: CGPoint,
        tipPoint: CGPoint
    ) -> Self {
        let vector = Vector(startPoint, tipPoint)
        let anchorPoint = vector.point(distance: -20, other: tipPoint)
        let perpendicularVector = vector.rotated(by: .pi / 2)
        let topPoint = perpendicularVector.point(distance: -30, other: anchorPoint)
        let bottomPoint = perpendicularVector.point(distance: 30, other: anchorPoint)
        let topVector = Vector(tipPoint, topPoint)
        let bottomVector = Vector(tipPoint, bottomPoint)
        return [
            startPoint,
            tipPoint,
            topVector.point(distance: 0.1, other: tipPoint),
            topVector.point(distance: 1, other: tipPoint),
            topPoint,
            topPoint,
            tipPoint,
            bottomVector.point(distance: 0.1, other: tipPoint),
            bottomVector.point(distance: 1, other: tipPoint),
            bottomPoint,
        ]
    }
}

/// Inspired from: https://github.com/nicklockwood/VectorMath/blob/master/VectorMath/VectorMath.swift
private struct Vector: Hashable {
    var x: CGFloat
    var y: CGFloat
    
    typealias Scalar = CGFloat
    
    init(x: Scalar, y: Scalar) {
        self.x = x
        self.y = y
    }
    
    init(_ x: Scalar, _ y: Scalar) {
        self.init(x: x, y: y)
    }
    
    init(_ pointA: CGPoint, _ pointB: CGPoint) {
        self.init(pointB.x - pointA.x, pointB.y - pointA.y)
    }
    
    var lengthSquared: Scalar {
        return x * x + y * y
    }
    
    func point(distance: Scalar, other point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x + distance * normalized().x,
            y: point.y + distance * normalized().y
        )
    }
    
    func rotated(by radians: Scalar) -> Vector {
        let cs = cos(radians)
        let sn = sin(radians)
        return Vector(x * cs - y * sn, x * sn + y * cs)
    }
    
    func normalized() -> Vector {
        let lengthSquared = self.lengthSquared
        if lengthSquared ~= 0 || lengthSquared ~= 1 {
            return self
        }
        return self / sqrt(lengthSquared)
    }
    
    static func / (lhs: Vector, rhs: Vector) -> Vector {
        return Vector(lhs.x / rhs.x, lhs.y / rhs.y)
    }
    
    static func / (lhs: Vector, rhs: Scalar) -> Vector {
        return Vector(lhs.x / rhs, lhs.y / rhs)
    }
    
    static prefix func - (v: Vector) -> Vector {
        return Vector(-v.x, -v.y)
    }
    
    static func + (lhs: Vector, rhs: Vector) -> Vector {
        return Vector(lhs.x + rhs.x, lhs.y + rhs.y)
    }
    
    static func - (lhs: Vector, rhs: Vector) -> Vector {
        return Vector(lhs.x - rhs.x, lhs.y - rhs.y)
    }
    
}

