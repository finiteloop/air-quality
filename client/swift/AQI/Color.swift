// Copyright 2020 Bret Taylor

import Foundation

/// The color-coding of an air quality reading.
public struct Color {
    public let r: Float
    public let g: Float
    public let b: Float
    
    init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
}


/// Returns the color representing the given AQI reading.
public func color(aqi: UInt32) -> Color {
    let color0 = Color(r: 139, g: 222, b: 92)
    let color50 = Color(r: 255, g: 254, b: 115)
    let color100 = Color(r: 223, g: 138, b: 70)
    let color150 = Color(r: 213, g: 69, b: 51)
    let color200 = Color(r: 127, g: 38, b: 74)
    let color250 = Color(r: 127, g: 38, b: 74)
    let color300 = Color(r: 104, g: 29, b: 39)
    if aqi < 50 {
        return interpolate(low: 0, high: 50, lowColor: color0, highColor: color50, value: aqi)
    } else if aqi < 100 {
        return interpolate(low: 50, high: 100, lowColor: color50, highColor: color100, value: aqi)
    } else if aqi < 150 {
        return interpolate(low: 100, high: 150, lowColor: color100, highColor: color150, value: aqi)
    } else if aqi < 200 {
        return interpolate(low: 150, high: 200, lowColor: color150, highColor: color200, value: aqi)
    } else if aqi < 250 {
        return interpolate(low: 200, high: 250, lowColor: color200, highColor: color250, value: aqi)
    } else if aqi < 300 {
        return interpolate(low: 250, high: 300, lowColor: color250, highColor: color300, value: aqi)
    } else {
        return color300
    }
}


/// Returns the color for text on top of the color representing the given AQI.
public func textColor(aqi: UInt32) -> Color {
    return aqi <= 100 ? Color(r: 0, g: 0, b: 0) : Color(r: 255, g: 255, b: 255)
}

private func interpolate(low: UInt32, high: UInt32, lowColor: Color, highColor: Color, value: UInt32) -> Color {
    let percentage = max(min(Float(value - low) / Float(high - low), 1.0), 0.0)
    return Color(r: lowColor.r + (highColor.r - lowColor.r) * percentage, g: lowColor.g + (highColor.g - lowColor.g) * percentage, b: lowColor.b + (highColor.b - lowColor.b) * percentage)
}
