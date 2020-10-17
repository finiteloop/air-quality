// Copyright 2020 Bret Taylor

import AQI
import UIKit

class SensorDetailView: UIView {
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
                self._aqiHeading.text = "Updated " + formatter.localizedString(for: reading.lastUpdated, relativeTo: Date())
            }
        }
    }
    
    private lazy var _aqiHeading: UILabel = {
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

        let historicalReadings = UIStackView(arrangedSubviews: [
            self._aqi10M,
            self._aqi30M,
            self._aqi1H,
            self._aqi6H,
            self._aqi24H,
        ])
        historicalReadings.axis = .horizontal
        historicalReadings.spacing = 1

        let stack = UIStackView(arrangedSubviews: [
            self._aqiHeading,
            self._currentReading,
            self._heading(NSLocalizedString("Air Quality Average", comment: "Title of table of average AQI from last 24 hours")),
            historicalReadings,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 5
        stack.axis = .vertical
        stack.setCustomSpacing(20, after: self._currentReading)
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leftAnchor.constraint(equalTo: self.leftAnchor),
            stack.rightAnchor.constraint(equalTo: self.rightAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    private func _heading(_ title: String) -> UILabel {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.text = title
        label.backgroundColor = .clear
        label.textColor = UIColor.label.withAlphaComponent(0.5)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class CurrentReadingView: UIView {
    let _circleSize: CGFloat = 50

    var aqi: UInt32 = 0 {
        didSet {
            self._reading.text = String(aqi)
            self._reading.backgroundColor = uiColor(AQI.color(aqi: aqi))
            self._reading.textColor = uiColor(AQI.textColor(aqi: aqi)).withAlphaComponent(0.8)
            if aqi <= 50 {
                self._description.text = NSLocalizedString("Good", comment: "AQI risk description")
            } else if aqi <= 100 {
                self._description.text = NSLocalizedString("Moderate", comment: "AQI risk description")
            } else if aqi <= 150 {
                self._description.text = NSLocalizedString("Unhealthy for Sensitive Groups", comment: "AQI risk description")
            } else if aqi <= 200 {
                self._description.text = NSLocalizedString("Unhealthy", comment: "AQI risk description")
            } else if aqi <= 300 {
                self._description.text = NSLocalizedString("Very Unhealthy", comment: "AQI risk description")
            } else {
                self._description.text = NSLocalizedString("Hazardous", comment: "AQI risk description")
            }
        }
    }
    
    private lazy var _reading: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.clipsToBounds = true
        label.layer.cornerRadius = self._circleSize / 2
        return label
    }()
    
    private lazy var _description: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.backgroundColor = .clear
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init() {
        super.init(frame: .zero)
        self.addSubview(self._reading)
        self.addSubview(self._description)
        
        let spacing: CGFloat = 8
        NSLayoutConstraint.activate([
            self._reading.widthAnchor.constraint(equalToConstant: self._circleSize),
            self._reading.heightAnchor.constraint(equalToConstant: self._circleSize),
            self._reading.topAnchor.constraint(equalTo: self.topAnchor),
            self._reading.leftAnchor.constraint(equalTo: self.leftAnchor),
            self._reading.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
            self._description.leftAnchor.constraint(equalTo: self._reading.rightAnchor, constant: spacing),
            self._description.centerYAnchor.constraint(equalTo: self._reading.centerYAnchor),
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

private class HistoricalReadingView: UIView {
    var aqi: UInt32 = 0 {
        didSet {
            self._reading.text = String(aqi)
            self.backgroundColor = uiColor(AQI.color(aqi: aqi))
            self._reading.textColor = uiColor(AQI.textColor(aqi: aqi)).withAlphaComponent(0.8)
            self._descriptor.textColor = self._reading.textColor
        }
    }

    private lazy var _descriptor: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 12)
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var _reading: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(timeDescriptor: String) {
        super.init(frame: .zero)
        self._descriptor.text = timeDescriptor
        self.addSubview(self._reading)
        self.addSubview(self._descriptor)
        
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
