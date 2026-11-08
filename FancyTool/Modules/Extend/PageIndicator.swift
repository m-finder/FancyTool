//
//  PasterPageIndicator.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import SwiftUI

struct PageIndicator: View {
  
  private let total: Int
  @Binding private var current: Int
  
  public init(total: Int, current: Binding<Int>){
    self.total = total
    self._current = current
  }
  
  var body: some View {
    if total > 1 {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) {
          nextPageHint
          pageDots
          previousPageHint
        }
        VStack(spacing: 6) {
          HStack(spacing: 16) {
            nextPageHint
            previousPageHint
          }
          pageDots
        }
      }
    } else {
      pageDots
    }
  }

  private var nextPageHint: some View {
    shortcutHint("Tab", title: String(localized: "Next page"))
  }

  private var previousPageHint: some View {
    shortcutHint("⇧Tab", title: String(localized: "Previous page"))
  }

  private func shortcutHint(_ key: String, title: String) -> some View {
    HStack(spacing: 5) {
      Text(verbatim: key)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
      Text(title)
        .font(.caption)
    }
    .foregroundStyle(.secondary)
    .fixedSize()
    .accessibilityElement(children: .combine)
  }

  private var pageDots: some View {
    HStack(spacing: 6) {
      ForEach(0..<total, id: \.self) { index in
        Circle().fill(index == current ? Color.blue : Color.gray.opacity(0.5))
          .frame(width: 8,height: 8)
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
              current = index
            }
          }
      }
    }
  }
}
