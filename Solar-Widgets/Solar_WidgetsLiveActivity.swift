//
//  Solar_WidgetsLiveActivity.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct Solar_WidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

@available(iOSApplicationExtension 16.1, *)
struct Solar_WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Solar_WidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
extension Solar_WidgetsAttributes {
    fileprivate static var preview: Solar_WidgetsAttributes {
        Solar_WidgetsAttributes(name: "World")
    }
}

@available(iOSApplicationExtension 16.1, *)
extension Solar_WidgetsAttributes.ContentState {
    fileprivate static var smiley: Solar_WidgetsAttributes.ContentState {
        Solar_WidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Solar_WidgetsAttributes.ContentState {
         Solar_WidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Solar_WidgetsAttributes.preview) {
   Solar_WidgetsLiveActivity()
} contentStates: {
    Solar_WidgetsAttributes.ContentState.smiley
    Solar_WidgetsAttributes.ContentState.starEyes
}
