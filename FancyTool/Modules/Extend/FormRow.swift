//
//  FormRow.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

struct FormRow<Content: View>: View {
    var label: String
    var content: Content
    
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
      LabeledContent(label) {
          content
      }
    }
}
