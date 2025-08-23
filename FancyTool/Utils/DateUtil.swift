//
//  ColorModel.swift
//  M-Tools
//
//  Created by 吴雲放 on 2023/9/23.
//

import SwiftUI
import Foundation

class DateUtil {
  
  static let shared = DateUtil()
  private init() {}
  
  // 日期格式化器
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale.current
    return formatter
  }()
  
  // 计算相对时间字符串
  func relativeTime(from date: Date) -> String {
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.second, .minute, .hour, .day], from: date, to: now)
    
    // 超过2天显示具体日期
    if let day = components.day, day >= 2 {
      return dateFormatter.string(from: date)
    }
 
    // 2天内显示相对时间
    if let day = components.day, day > 0 {
      return String.localizedStringWithFormat(NSLocalizedString("%d days ago", comment: ""), day)
    } else if let hour = components.hour, hour > 0 {
      return String.localizedStringWithFormat(NSLocalizedString("%d hours ago", comment: ""), hour)
    } else if let minute = components.minute, minute > 0 {
      return String.localizedStringWithFormat(NSLocalizedString("%d minutes ago", comment: ""), minute)
    } else if let second = components.second, second > 0 {
      return second < 5 ? NSLocalizedString("Just now", comment: "") :
      String.localizedStringWithFormat(NSLocalizedString("%d seconds ago", comment: ""), second)
    } else {
      return NSLocalizedString("Just now", comment: "")
    }
  }
  
}
