//
//  SunPathView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

struct SunPathView: View {
    let progress: Double
    let solarNoonProgress: Double

    var body: some View {
        ZStack {
            // Background gradient for the sky
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Horizon Line
            Rectangle()
                .frame(height: 2)
                .foregroundColor(Color.gray.opacity(0.5))
                .padding(.horizontal, 20) // Align with path start/end roughly
                .offset(y: (250 * 0.85) / 2 - 20) // Approximate vertical position of path ends

            SunPathShape(progress: progress, solarNoonProgress: solarNoonProgress)
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
                .foregroundColor(.blue.opacity(0.8))
            
            GeometryReader { geometry in
                // Sun Icon Position
                let pathRect = CGRect(origin: .zero, size: geometry.size)
                let sunPosition = calculateSunPosition(in: pathRect, progress: progress)

                // Sun circle
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 24, height: 24)
                    .shadow(color: .yellow.opacity(0.5), radius: 8, x: 0, y: 0)
                    .position(sunPosition)

                // Labels for Sunrise, Noon, Sunset
                let labelYOffset: CGFloat = pathRect.height * 0.85 + 15
                
                Text("Sunrise")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .position(x: pathRect.width * 0.1, y: labelYOffset)
                
                Text("Noon")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .position(x: pathRect.width * 0.5, y: labelYOffset)

                Text("Sunset")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .position(x: pathRect.width * 0.9, y: labelYOffset)
            }
        }
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // Calculates the CGPoint for the sun on the quadratic Bezier path
    private func calculateSunPosition(in rect: CGRect, progress: Double) -> CGPoint {
        let t = CGFloat(progress) // Ensure t is CGFloat

        let p0 = CGPoint(x: rect.width * 0.1, y: rect.height * 0.85)
        let p1 = CGPoint(x: rect.width / 2, y: rect.height * 0.15) // Control point
        let p2 = CGPoint(x: rect.width * 0.9, y: rect.height * 0.85)

        // Quadratic Bezier formula: (1-t)^2 * P0 + 2 * (1-t) * t * P1 + t^2 * P2
        let x = pow(1-t, 2) * p0.x + 2 * (1-t) * t * p1.x + pow(t, 2) * p2.x
        let y = pow(1-t, 2) * p0.y + 2 * (1-t) * t * p1.y + pow(t, 2) * p2.y
        
        return CGPoint(x: x, y: y)
    }
}
