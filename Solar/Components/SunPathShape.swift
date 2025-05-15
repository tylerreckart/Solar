//
//  SunPathShape.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

struct SunPathShape: Shape {
    let xInsetFactor: CGFloat     // How much to inset the start/end points from the view edges (e.g., 0.1 for 10%)
    let yBaseFactor: CGFloat      // Vertical position of the start/end points (e.g., 0.85 for 85% from the top)
    let peakHeightFactor: CGFloat // Vertical position of the control point (parabola's peak) (e.g., 0.15 for 15% from the top, lower is higher)

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        
        // Start point of the parabola (e.g., sunrise)
        let startPoint = CGPoint(x: width * xInsetFactor, y: height * yBaseFactor)
        
        // End point of the parabola (e.g., sunset)
        let endPoint = CGPoint(x: width * (1.0 - xInsetFactor), y: height * yBaseFactor)
        
        // Control point for the quadratic Bezier curve, determining the peak of the parabola
        let controlPoint = CGPoint(x: width / 2, y: height * peakHeightFactor)

        path.move(to: startPoint)
        path.addQuadCurve(to: endPoint, control: controlPoint)
        
        return path
    }
}
