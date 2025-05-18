//
//  ShimmerModifier.swift
//  Solar
//
//  Created by Tyler Reckart on 5/17/25.
//

import SwiftUI
import UIKit

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var active: Bool
    var duration: Double = 1.5
    var bounce: Bool = false

    func body(content: Content) -> some View {
        if active {
            content
                .modifier(AnimatedMask(phase: phase).animation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: bounce)
                ))
                .onAppear { phase = 0.8 }
        } else {
            content // Return content unmodified if shimmer is not active
        }
    }

    struct AnimatedMask: AnimatableModifier {
        var phase: CGFloat = 0

        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }

        func body(content: Content) -> some View {
            content
                .mask(GradientMask(phase: phase).scaleEffect(3))
        }
    }

    struct GradientMask: View {
        let phase: CGFloat
        let centerColor = Color.black
        let edgeColor = Color.black.opacity(0.3)

        var body: some View {
            LinearGradient(gradient:
                Gradient(stops: [
                    .init(color: edgeColor, location: phase - 0.1),
                    .init(color: centerColor, location: phase),
                    .init(color: edgeColor, location: phase + 0.1)
                ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

extension View {
    @ViewBuilder
    func shimmer(active: Bool, duration: Double = 1.5, bounce: Bool = false) -> some View {
        self.modifier(ShimmerModifier(active: active, duration: duration, bounce: bounce))
    }
}
