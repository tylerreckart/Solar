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
        
        // Draw a simple arc using points along the sine curve (matching widgets)
        let points = (0...20).map { i in
            let progress = Double(i) / 20.0
            let x = width * progress
            let y = height - (height * 0.4 * sin(progress * .pi))
            return CGPoint(x: x, y: y)
        }
        
        if let firstPoint = points.first {
            path.move(to: firstPoint)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        
        return path
    }
}

// MARK: - Accurate Astronomical Sun Path Shape

struct AccurateSunPathShape: Shape {
    let solarInfo: SolarInfo
    let xInsetFactor: CGFloat
    let yBaseFactor: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard let lat = solarInfo.latitude,
              let lon = solarInfo.longitude,
              let timezone = solarInfo.timezoneIdentifier else {
            // Fallback to simple shape if data is unavailable
            return SunPathShape(
                xInsetFactor: xInsetFactor,
                yBaseFactor: yBaseFactor,
                peakHeightFactor: 0.3
            ).path(in: rect)
        }
        
        // Generate accurate sun path points using astronomical calculations
        let pathPoints = SunPositionCalculator.generateAccurateSunPath(
            date: solarInfo.currentDate,
            latitude: lat,
            longitude: lon,
            timezoneIdentifier: timezone,
            sunrise: solarInfo.sunrise,
            sunset: solarInfo.sunset,
            solarNoon: solarInfo.solarNoon,
            in: rect,
            xInsetFactor: xInsetFactor,
            yBaseFactor: yBaseFactor,
            pointCount: 50
        )
        
        guard !pathPoints.isEmpty else {
            // Fallback if calculation fails
            return SunPathShape(
                xInsetFactor: xInsetFactor,
                yBaseFactor: yBaseFactor,
                peakHeightFactor: 0.3
            ).path(in: rect)
        }
        
        // Create smooth curve through calculated points
        if let firstPoint = pathPoints.first {
            path.move(to: firstPoint)
            
            if pathPoints.count > 2 {
                // Use curve fitting for smooth path
                for i in 1..<pathPoints.count {
                    let point = pathPoints[i]
                    
                    if i == 1 {
                        // First curve segment
                        let midPoint = CGPoint(
                            x: (pathPoints[0].x + point.x) / 2,
                            y: (pathPoints[0].y + point.y) / 2
                        )
                        path.addLine(to: midPoint)
                    } else {
                        // Smooth curve using previous point as control
                        let previousPoint = pathPoints[i - 1]
                        let controlPoint = previousPoint
                        path.addQuadCurve(to: point, control: controlPoint)
                    }
                }
            } else {
                // Simple line if not enough points
                for point in pathPoints.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
        
        return path
    }
}
