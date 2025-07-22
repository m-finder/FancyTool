//
//  PasterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/21.
//

import SwiftUI

struct PasterView: View {
  
    @ObservedObject var paster = Paster.shared
    @State private var isHovering: UUID?
    @State private var isPressed: UUID?

    var body: some View {
        if paster.history.isEmpty {
            Text("No paste history available.").frame(width: 300, height: 250)
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 15) {
                    ForEach(paster.history, id: \.self) { item in
                        HistoryItemView(
                            item: item,
                            isHovering: $isHovering,
                            isPressed: $isPressed
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(25)
        }
    }
}

struct HistoryItemView: View {
    let item: String
    @Binding var isHovering: UUID?
    @Binding var isPressed: UUID?
    
    private let itemId = UUID()
    
    var body: some View {
        VStack {
            Text(item).padding(10)
        }.frame(width: 300, height: 250)
        .background(Color.gray.opacity(0.2))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isHovering == itemId ? Color.blue : Color.clear, lineWidth: 2))
        .cornerRadius(8)
        .scaleEffect(isPressed == itemId ? 0.95 : 1.0)
        .opacity(isPressed == itemId ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onHover { hovering in
            isHovering = hovering ? itemId : nil
        }
        .onTapGesture {
            handleItemTap(item)
        }
        .id(itemId)
    }
    
    private func handleItemTap(_ item: String) {
        let success = Paster.shared.copyToClipboard(item)
        guard success, let targetApp = NSWorkspace.shared.frontmostApplication else { return }
        
        Paster.shared.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Paster.shared.simulatePaste(to: targetApp)
        }
    }
}

