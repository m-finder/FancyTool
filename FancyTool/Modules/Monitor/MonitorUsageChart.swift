import SwiftUI
import Charts
import SystemInfoKit

struct MonitorUsageChart: View {
  let history: MonitorHistory
  let metric: MonitorHistory.Metric
  let color: Color

  var body: some View {
    let points = history.points(for: metric)
    let singletons = Set(Dictionary(grouping: points, by: \.segment).filter { $0.value.count == 1 }.keys)
    Chart {
      ForEach(points) { point in
        AreaMark(x: .value("Time", point.date), yStart: .value("Baseline", 0),
                 yEnd: .value("Usage", point.value), series: .value("Segment", point.segment))
          .foregroundStyle(color.opacity(0.12))
          .interpolationMethod(.linear)
        LineMark(x: .value("Time", point.date), y: .value("Usage", point.value),
                 series: .value("Segment", point.segment))
          .foregroundStyle(color)
          .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
          .interpolationMethod(.linear)
        if point.id == points.last?.id || singletons.contains(point.segment) {
          PointMark(x: .value("Time", point.date), y: .value("Usage", point.value))
            .foregroundStyle(color)
            .symbolSize(12)
        }
      }
    }
    .chartXScale(domain: history.domain)
    .chartYScale(domain: 0...100)
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
          .foregroundStyle(.secondary.opacity(0.2))
        if let percent = value.as(Int.self), percent != 50 {
          AxisValueLabel(anchor: .leading) { Text("\(percent)%").font(.system(size: 8)).foregroundStyle(Color.primary.opacity(0.75)) }
        }
      }
    }
    .chartLegend(.hidden)
    .overlay {
      if points.isEmpty {
        Text("Waiting for samples…").font(.caption2).foregroundStyle(.primary.opacity(0.75))
      }
    }
  }
}

struct MonitorNetworkChart: View {
  let history: MonitorHistory

  var body: some View {
    let upload = history.points(for: .upload)
    let download = history.points(for: .download)
    let maximum = max(1, (upload + download).map(\.value).max() ?? 0)
    let upper = maximum * 1.15
    Chart {
      trace(upload, name: "Upload", color: .teal, dash: [3, 2])
      trace(download, name: "Download", color: .orange, dash: [])
    }
    .chartXScale(domain: history.domain)
    .chartYScale(domain: 0...upper)
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(position: .trailing, values: [0, upper]) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
          .foregroundStyle(.secondary.opacity(0.2))
        if let rate = value.as(Double.self) {
          AxisValueLabel(anchor: .leading) {
            Text(verbatim: "\(ByteData(byteCount: rate))/s")
              .font(.system(size: 8)).foregroundStyle(Color.primary.opacity(0.75))
          }
        }
      }
    }
    .chartLegend(.hidden)
    .overlay {
      if upload.isEmpty && download.isEmpty {
        Text("Waiting for samples…").font(.system(size: 9)).foregroundStyle(.primary.opacity(0.75))
      }
    }
  }

  @ChartContentBuilder
  private func trace(_ points: [MonitorHistory.Point], name: String, color: Color, dash: [CGFloat]) -> some ChartContent {
    ForEach(points) { point in
      LineMark(x: .value("Time", point.date), y: .value("Bytes per second", point.value),
               series: .value("Series", "\(name)-\(point.segment)"))
        .foregroundStyle(color)
        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: dash))
        .interpolationMethod(.linear)
      if point.id == points.last?.id {
        PointMark(x: .value("Time", point.date), y: .value("Bytes per second", point.value))
          .foregroundStyle(color).symbolSize(10)
      }
    }
  }
}
