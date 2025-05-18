//
//  SunPathView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 0, 0, 0) // Default to black with alpha 0 if parsing fails
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

import SwiftUI

struct SunPathView: View {
    let progress: Double
    let solarNoonProgress: Double = 0.5
    let skyCondition: SkyCondition

    private let pathXInsetFactor: CGFloat = 0.1
    private let pathYBaseFactor: CGFloat = 0.5
    private let pathPeakHeightFactor: CGFloat = 0.001


    private var gradientColors: [Color] {
        switch skyCondition {
        case .sunrise:
            return [AppColors.sunriseGradientStart, AppColors.sunriseGradientEnd]
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
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            
            SunPathShape(
                xInsetFactor: pathXInsetFactor,
                yBaseFactor: pathYBaseFactor,
                peakHeightFactor: pathPeakHeightFactor
            )
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .foregroundColor(.white.opacity(0.8))
            
            GeometryReader { geometry in
                let pathRect = CGRect(origin: .zero, size: geometry.size)
                let sunPosition = calculateSunPosition(
                    in: pathRect,
                    progress: progress,
                    xInsetFactor: pathXInsetFactor,
                    yBaseFactor: pathYBaseFactor,
                    peakHeightFactor: pathPeakHeightFactor
                )

                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 1.0, blue: 0.8),
                            Color(hex: "#FFEB3B"), // Bright yellow
                            Color(hex: "#FFD600") // Slightly deeper yellow edge
                        ]),
                        center: .top,
                        startRadius: 24 * 0.075,
                        endRadius: 24 / 2
                    )) // Sun color
                    .frame(width: 24, height: 24)
                    .shadow(color: .yellow.opacity(0.5), radius: 12, x: 0, y: 3)
                    .position(sunPosition)
                    .animation(.easeInOut, value: sunPosition)
            }
        }
        .frame(height: 250)
    }

    private func calculateSunPosition(
        in rect: CGRect,
        progress: Double,
        xInsetFactor: CGFloat,    // Added parameter
        yBaseFactor: CGFloat,     // Added parameter
        peakHeightFactor: CGFloat // Added parameter
    ) -> CGPoint {
        let t = CGFloat(progress) // The parameter for the Bezier curve (0.0 to 1.0)

        // Define P0, P1, P2 using the passed-in geometric factors
        // P0: Start point
        let p0 = CGPoint(x: rect.width * xInsetFactor, y: rect.height * yBaseFactor)
        // P1: Control point (determines the peak)
        let p1 = CGPoint(x: rect.width / 2, y: rect.height * peakHeightFactor)
        // P2: End point
        let p2 = CGPoint(x: rect.width * (1.0 - xInsetFactor), y: rect.height * yBaseFactor)

        // Quadratic Bezier curve formula: B(t) = (1-t)^2 * P0 + 2 * (1-t) * t * P1 + t^2 * P2
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
