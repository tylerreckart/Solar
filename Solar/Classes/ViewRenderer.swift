//
//  ViewRenderer.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import SwiftUI
import UIKit

@MainActor
class ViewRenderer {
    // Renders a SwiftUI view to a UIImage.
    // The view should have a specific frame size defined before calling this.
    static func renderViewToImage<Content: View>(_ view: Content, size: CGSize) -> UIImage? {
        // Create a UIHostingController to host the SwiftUI view.
        let hostingController = UIHostingController(rootView: view)

        // Set the frame of the hosting controller's view.
        hostingController.view.frame = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = .clear // Ensure transparency if needed

        // Make sure the view's layout is up to date.
        hostingController.view.layoutIfNeeded()

        // Use UIGraphicsImageRenderer to capture the view.
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            hostingController.view.layer.render(in: context.cgContext)
        }

        return image
    }
}
