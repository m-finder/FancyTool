//
//  SettingsView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct SettingsView: View {

  private enum Section: String, CaseIterable, Identifiable {
    case universal
    case hidder
    case texter
    case paster
    case rounder
    case monitor
    case shotter
    case runner

    var id: Self { self }

    var title: LocalizedStringKey {
      switch self {
      case .universal: "Universal"
      case .hidder: "Hidder"
      case .texter: "Texter"
      case .paster: "Paster"
      case .rounder: "Rounder"
      case .monitor: "Monitor"
      case .shotter: "Shotter"
      case .runner: "Runner"
      }
    }

    var symbol: String {
      switch self {
      case .universal: "gearshape"
      case .hidder: "menubar.rectangle"
      case .texter: "text.cursor"
      case .paster: "doc.on.clipboard"
      case .rounder: "rectangle.roundedtop"
      case .monitor: "chart.line.uptrend.xyaxis"
      case .shotter: "pencil.and.outline"
      case .runner: "square.grid.2x2"
      }
    }
  }

  @State private var selection: Section? = .universal

  var body: some View {
    HStack(spacing: 0) {
      List(Section.allCases, selection: $selection) { section in
        Label(section.title, systemImage: section.symbol)
          .tag(section)
      }
      .listStyle(.sidebar)
      .frame(width: 184)

      Divider()

      detail
    }
    .frame(minWidth: 600, minHeight: 380)
  }

  @ViewBuilder
  private var detail: some View {
    switch selection ?? .universal {
    case .universal:
      SettingsDetailView {
        MainSettingView()
      }
    case .hidder:
      SettingsDetailView {
        HidderSettingView()
      }
    case .texter:
      SettingsDetailView {
        TexterSettingView()
      }
    case .paster:
      SettingsDetailView {
        PasterSettingView()
      }
    case .rounder:
      SettingsDetailView {
        RounderSettingView()
      }
    case .monitor:
      SettingsDetailView {
        MonitorSettingView()
      }
    case .shotter:
      SettingsDetailView {
        ShotterSettingView()
      }
    case .runner:
      SettingsDetailView {
        RunnerSettingView()
      }
    }
  }
}

private struct SettingsDetailView<Content: View>: View {

  @ViewBuilder let content: Content

  var body: some View {
    VStack(spacing: 0) {
      content
        .frame(maxWidth: 420, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 22)

      Spacer(minLength: 0)

      Divider()

      HStack {
        Spacer()
        CopyrightView()
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 1)
    }
  }
}


struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
