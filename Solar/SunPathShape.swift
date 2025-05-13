//
//  SunPathShape.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

struct SunPathShape: Shape {
    let progress: Double // Current sun progress (0.0 to 1.0)
    let solarNoonProgress: Double // Progress value for solar noon (e.g., 0.5 if path is symmetrical time-wise)

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        
        // Define the control points for the quadratic Bezier curve
        // The path starts from bottom-left, peaks, and ends at bottom-right
        let startPoint = CGPoint(x: width * 0.1, y: height * 0.85)
        let endPoint = CGPoint(x: width * 0.9, y: height * 0.85)
        
        // Peak of the sun path (solar noon)
        // Adjust peakHeightFactor to make the arc higher or lower
        let peakHeightFactor: CGFloat = 0.15
        let controlPoint = CGPoint(x: width / 2, y: height * peakHeightFactor)

        path.move(to: startPoint)
        path.addQuadCurve(to: endPoint, control: controlPoint)
        
        return path
    }
}
