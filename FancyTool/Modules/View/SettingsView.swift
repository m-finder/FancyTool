//
//  SettingsView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
  case universal
  case hidder
  case texter
  case paster
  case rounder
  case monitor
  case duo
  case shotter
  case runner

  var id: Self { self }

  static var visibleCases: [Self] {
    allCases.filter { $0 != .hidder || Hidder.isSupported }
  }

  var title: LocalizedStringKey {
    switch self {
    case .universal: "Universal"
    case .hidder: "Hidder"
    case .texter: "Texter"
    case .paster: "Paster"
    case .rounder: "Rounder"
    case .monitor: "Monitor"
    case .duo: "Duo"
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
    case .duo: "circle.grid.2x2"
    case .shotter: "pencil.and.outline"
    case .runner: "square.grid.2x2"
    }
  }
}

@MainActor
final class SettingsNavigation: ObservableObject {
  static let shared = SettingsNavigation()
  @Published var selection: SettingsSection? = .universal
  private init() {}
}

struct SettingsView: View {
  @ObservedObject private var navigation = SettingsNavigation.shared

  var body: some View {
    HStack(spacing: 0) {
      List(SettingsSection.visibleCases, selection: $navigation.selection) { section in
        Label(section.title, systemImage: section.symbol)
          .fontWeight(navigation.selection == section ? .semibold : .regular)
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
    switch navigation.selection ?? .universal {
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
    case .duo:
      SettingsDetailView {
        DuoSettingView()
      }
    case .runner:
      SettingsDetailView(expandsContent: true) {
        RunnerSettingView()
      }
    }
  }
}

private struct SettingsDetailView<Content: View>: View {

  var expandsContent = false
  @ViewBuilder let content: Content

  var body: some View {
    VStack(spacing: 0) {
      content
        .frame(maxWidth: expandsContent ? .infinity : 420, alignment: .leading)
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
