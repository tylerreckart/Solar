//
//  SunPathView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

struct SunPathView: View {
    let progress: Double
    let solarNoonProgress: Double = 0.5
    let skyCondition: SkyCondition

    private var gradientColors: [Color] {
        switch skyCondition {
        case .sunrise:
            return [AppColors.sunriseGradientEnd, AppColors.sunriseGradientStart]
        case .daylight:
            return [AppColors.daylightGradientStart, AppColors.daylightGradientEnd]
        case .sunset:
            return [AppColors.sunsetGradientStart, AppColors.sunsetGradientEnd]
        case .night:
            return [AppColors.nightGradientStart, AppColors.nightGradientEnd]
        }
    }

    var body: some View {
        ZStack {
            // Background gradient for the sky
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .animation(.easeInOut, value: skyCondition)
            
            SunPathShape(progress: progress, solarNoonProgress: solarNoonProgress)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundColor(.white)
            
            GeometryReader { geometry in
                let pathRect = CGRect(origin: .zero, size: geometry.size)
                // Use consistent factors for sun position calculation
                let sunPosition = calculateSunPosition(in: pathRect, progress: progress, pathHeightFactor: 0.85, peakHeightFactor: 0.15)

                // Sun circle
                Circle()
                    .fill(.yellow)
                    .frame(width: 24, height: 24)
                    .shadow(color: .yellow.opacity(0.6), radius: 8, x: 0, y: 0)
                    .position(sunPosition)
                    .animation(.spring(), value: progress)
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .frame(height: 250) // Keep explicit frame here if needed by parent
    }

    // Calculates the CGPoint for the sun on the quadratic Bezier path
    private func calculateSunPosition(in rect: CGRect, progress: Double, pathHeightFactor: CGFloat, peakHeightFactor: CGFloat) -> CGPoint {
        let t = CGFloat(progress)

        // Path starts from bottom-left (10% in), peaks (15% from top), ends bottom-right (10% in from right)
        // pathHeightFactor controls the Y position of sunrise/sunset points
        // peakHeightFactor controls the Y position of the noon peak (lower value = higher peak)
        let p0 = CGPoint(x: rect.width * 0.1, y: rect.height * pathHeightFactor)
        let p1 = CGPoint(x: rect.width / 2, y: rect.height * peakHeightFactor) // Control point (peak)
        let p2 = CGPoint(x: rect.width * 0.9, y: rect.height * pathHeightFactor)

        let x = pow(1-t, 2) * p0.x + 2 * (1-t) * t * p1.x + pow(t, 2) * p2.x
        let y = pow(1-t, 2) * p0.y + 2 * (1-t) * t * p1.y + pow(t, 2) * p2.y
        
        return CGPoint(x: x, y: y)
    }
}

// Simple line shape for horizon if needed, or use Rectangle
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

extension CGPoint {
    // Helper for y-scaling if needed, not directly used in position calculation as rect.height is dynamic
    var yScaled: CGFloat { self.y / 250.0 } // Assuming 250 is the standard height
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
