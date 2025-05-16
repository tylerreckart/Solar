//
//  ActivityView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    @Environment(\.dismiss) var dismiss // To dismiss the sheet after completion or cancellation
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            // Dismiss the sheet when the activity is completed or dismissed by the user
            // This is important to allow the sheet to be presented again.
            DispatchQueue.main.async { // Ensure UI updates on main thread
                self.dismiss()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed usually
    }
}
