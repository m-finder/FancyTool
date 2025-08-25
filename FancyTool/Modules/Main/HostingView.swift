//
//  MainStatusItem.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class HostingView {
  
  init(view: some View, button: NSStatusBarButton) {
    
    let hostingView = NSHostingView(
      rootView: RunnerMainView(height: 22)
        .frame(minWidth: 40, maxWidth: .infinity)
        .fixedSize().aspectRatio(
          contentMode: .fit
        )
    )
    
    button.addSubview(hostingView)
    
    // 将宿主视图四边锚定到按钮边界，也就是将视图展开
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      hostingView.topAnchor.constraint(equalTo: button.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
      hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor)
    ])
  }
}
