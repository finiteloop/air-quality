// Copyright 2020 Bret Taylor

import AQI
import Cocoa

class SensorDetailView: NSView {
    var reading: AQI.Reading? {
        didSet {
            if let reading = self.reading {
                self._currentReading.aqi = reading.aqi
                self._aqi10M.aqi = reading.aqi10M
                self._aqi30M.aqi = reading.aqi30M
                self._aqi1H.aqi = reading.aqi1H
                self._aqi6H.aqi = reading.aqi6H
                self._aqi24H.aqi = reading.aqi24H
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                formatter.dateTimeStyle = .named
                self._aqiHeading.stringValue = "Updated " + formatter.localizedString(for: reading.lastUpdated, relativeTo: Date())
            }
        }
    }
    
    private lazy var _aqiHeading: NSTextField = {
        return self._heading(NSLocalizedString("AQI", comment: "Title of air quality index detail"))
    }()
    
    private lazy var _currentReading: CurrentReadingView = {
        return CurrentReadingView();
    }()
    
    private lazy var _aqi10M: HistoricalReadingView = {
        return HistoricalReadingView(timeDescriptor: NSLocalizedString("10m", comment: "Very short abbreviation of 10 minutes"))
    }()
    
    private lazy var _aqi30M: HistoricalReadingView = {
        return HistoricalReadingView(timeDescriptor: NSLocalizedString("30m", comment: "Very short abbreviation of 30 minutes"))
    }()
    
    private lazy var _aqi1H: HistoricalReadingView = {
        return HistoricalReadingView(timeDescriptor: NSLocalizedString("1h", comment: "Very short abbreviation of 1 hour"))
    }()
    
    private lazy var _aqi6H: HistoricalReadingView = {
        return HistoricalReadingView(timeDescriptor: NSLocalizedString("6h", comment: "Very short abbreviation of 6 hours"))
    }()
    
    private lazy var _aqi24H: HistoricalReadingView = {
        return HistoricalReadingView(timeDescriptor: NSLocalizedString("24h", comment: "Very short abbreviation of 24 hours"))
    }()

    init() {
        super.init(frame: .zero)

        let historicalReadings = NSStackView(views: [
            self._aqi10M,
            self._aqi30M,
            self._aqi1H,
            self._aqi6H,
            self._aqi24H,
        ])
        historicalReadings.orientation = .horizontal
        historicalReadings.spacing = 1

        let stack = NSStackView(views: [
            self._aqiHeading,
            self._currentReading,
            self._heading(NSLocalizedString("Air Quality Average", comment: "Title of table of average AQI from last 24 hours")),
            historicalReadings,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 5
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.setCustomSpacing(20, after: self._currentReading)
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leftAnchor.constraint(equalTo: self.leftAnchor),
            stack.rightAnchor.constraint(equalTo: self.rightAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: 15),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    private func _heading(_ title: String) -> NSTextField {
        let field = NSTextField()
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        field.backgroundColor = .clear
        field.textColor = NSColor.labelColor
        field.stringValue = title
        return field
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class CurrentReadingView: NSView {
    let _circleSize: CGFloat = 50

    var aqi: UInt32 = 0 {
        didSet {
            self._reading.stringValue = String(aqi)
            self._circle.setColor(color: AQI.color(aqi: aqi))
            self._reading.textColor = nsColor(AQI.textColor(aqi: aqi)).withAlphaComponent(0.8)
            if aqi <= 50 {
                self._description.stringValue = NSLocalizedString("Good", comment: "AQI risk description")
            } else if aqi <= 100 {
                self._description.stringValue = NSLocalizedString("Moderate", comment: "AQI risk description")
            } else if aqi <= 150 {
                self._description.stringValue = NSLocalizedString("Unhealthy for Sensitive Groups", comment: "AQI risk description")
            } else if aqi <= 200 {
                self._description.stringValue = NSLocalizedString("Unhealthy", comment: "AQI risk description")
            } else if aqi <= 300 {
                self._description.stringValue = NSLocalizedString("Very Unhealthy", comment: "AQI risk description")
            } else {
                self._description.stringValue = NSLocalizedString("Hazardous", comment: "AQI risk description")
            }
        }
    }

    private lazy var _circle: ReadingCircle = {
        let circle = ReadingCircle()
        circle.translatesAutoresizingMaskIntoConstraints = false
        return circle
    }()
    
    private lazy var _reading: NSTextField = {
        let field = NSTextField()
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        field.backgroundColor = .clear
        field.alignment = .center
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private lazy var _description: NSTextField = {
        let field = NSTextField()
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingTail
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        field.backgroundColor = .clear
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    init() {
        super.init(frame: .zero)
        self.addSubview(self._circle)
        self.addSubview(self._reading)
        self.addSubview(self._description)
        
        let spacing: CGFloat = 8
        NSLayoutConstraint.activate([
            self._circle.widthAnchor.constraint(equalToConstant: self._circleSize),
            self._circle.heightAnchor.constraint(equalToConstant: self._circleSize),
            self._circle.topAnchor.constraint(equalTo: self.topAnchor),
            self._circle.leftAnchor.constraint(equalTo: self.leftAnchor),
            self._circle.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
            self._reading.leftAnchor.constraint(equalTo: self._circle.leftAnchor),
            self._reading.widthAnchor.constraint(equalTo: self._circle.widthAnchor),
            self._reading.centerYAnchor.constraint(equalTo: self._circle.centerYAnchor),
            self._description.leftAnchor.constraint(equalTo: self._circle.rightAnchor, constant: spacing),
            self._description.centerYAnchor.constraint(equalTo: self._circle.centerYAnchor),
            self._description.rightAnchor.constraint(lessThanOrEqualTo: self.rightAnchor),
            self._description.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
        ])
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class HistoricalReadingView: NSView {
    var aqi: UInt32 = 0 {
        didSet {
            self._reading.stringValue = String(aqi)
            self.layer?.backgroundColor = nsColor(AQI.color(aqi: aqi)).cgColor
            self._reading.textColor = nsColor(AQI.textColor(aqi: aqi)).withAlphaComponent(0.8)
            self._descriptor.textColor = self._reading.textColor
        }
    }

    private lazy var _descriptor: NSTextField = {
        let field = NSTextField()
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 12)
        field.backgroundColor = .clear
        field.translatesAutoresizingMaskIntoConstraints = false
        field.alignment = .center
        return field
    }()

    private lazy var _reading: NSTextField = {
        let field = NSTextField()
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        field.backgroundColor = .clear
        field.translatesAutoresizingMaskIntoConstraints = false
        field.alignment = .center
        return field
    }()

    init(timeDescriptor: String) {
        super.init(frame: .zero)
        self._descriptor.stringValue = timeDescriptor
        self.addSubview(self._reading)
        self.addSubview(self._descriptor)
        self.wantsLayer = true
        
        let verticalPadding: CGFloat = 8
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: 44),
            self._reading.topAnchor.constraint(equalTo: self.topAnchor, constant: verticalPadding),
            self._reading.leftAnchor.constraint(equalTo: self.leftAnchor),
            self._reading.rightAnchor.constraint(equalTo: self.rightAnchor),
            self._descriptor.topAnchor.constraint(equalTo: self._reading.bottomAnchor, constant: 2),
            self._descriptor.leftAnchor.constraint(equalTo: self.leftAnchor),
            self._descriptor.rightAnchor.constraint(equalTo: self.rightAnchor),
            self._descriptor.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -verticalPadding),
        ])
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
