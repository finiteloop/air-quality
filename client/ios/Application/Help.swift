// Copyright 2020 Bret Taylor

import AQI
import UIKit

class HelpController: UINavigationController {
    init() {
        super.init(rootViewController: HelpControllerContent())
        self.modalPresentationStyle = .formSheet
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class HelpControllerContent: UIViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Air Quality Index", comment: "Title of help overview dialog")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self._onDone))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = UIView(frame: UIScreen.main.bounds)
        self.view.backgroundColor = .systemBackground
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
        let scrollView = UIScrollView(frame: self.view.bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(scrollView)

        let safeArea = self.view.safeAreaLayoutGuide
        let stackView = UIStackView(arrangedSubviews: [
            self._bodyLabel(NSLocalizedString("The Air Quality Index (AQI) tells you how clean or polluted your air is and what associated health effects might be a concern for you. The Environmental Protection Agency (EPA) divides AQI into six categories:", comment: "Describes the AQI table")),
            _aqiTable(),
            self._purpleAirLabel(),
        ])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        let horizontalPadding: CGFloat = 15
        let verticalPadding: CGFloat = 15
        scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: -horizontalPadding)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leftAnchor.constraint(equalTo: safeArea.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: safeArea.rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            stackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -2 * horizontalPadding),
        ])
    }
    
    private func _bodyLabel(_ text: String) -> UILabel {
        let label = UILabel(frame: UIScreen.main.bounds)
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.backgroundColor = .clear
        label.textColor = .label
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func _aqiTable() -> UIView {
        let stackView = UIStackView(arrangedSubviews: [
            self._aqiRow(0, 50, NSLocalizedString("Good", comment: "AQI risk description")),
            self._aqiRow(51, 100, NSLocalizedString("Moderate", comment: "AQI risk description")),
            self._aqiRow(101, 150, NSLocalizedString("Unhealthy for Sensitive Groups", comment: "AQI risk description")),
            self._aqiRow(151, 200, NSLocalizedString("Unhealthy", comment: "AQI risk description")),
            self._aqiRow(201, 300, NSLocalizedString("Very Unhealthy", comment: "AQI risk description")),
            self._aqiRow(301, 500, NSLocalizedString("Hazardous", comment: "AQI risk description")),
        ])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }
    
    private func _aqiRow(_ low: UInt32, _ high: UInt32, _ description: String) -> UIView {
        let range = String(format: "%d - %d", low, high)
        let readingCell = self._aqiCell(range, low)
        readingCell.widthAnchor.constraint(equalToConstant: 100).isActive = true
        let stackView = UIStackView(arrangedSubviews: [
            readingCell,
            self._aqiCell(description, low),
        ])
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }
    
    private func _aqiCell(_ text: String, _ aqi: UInt32) -> UITextView {
        let textView = UITextView(frame: UIScreen.main.bounds)
        textView.isScrollEnabled = false
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = uiColor(AQI.color(aqi: aqi))
        textView.text = text
        textView.textColor = uiColor(AQI.textColor(aqi: aqi))
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    private func _purpleAirLabel() -> UITextView {
        let text = NSLocalizedString("This app displays AQI readings from PurpleAir, a collection of air quality sensors run by enthusiasts and air quality professionals around the world.", comment: "Described the source of AQI data")
        let formatted = NSMutableAttributedString(string: text, attributes: [
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
            NSAttributedString.Key.foregroundColor: UIColor.label,
        ])
        if let range = formatted.string.range(of: "PurpleAir") {
            formatted.addAttribute(NSAttributedString.Key.link, value: "https://www.purpleair.com/", range: NSRange(location: range.lowerBound.utf16Offset(in: formatted.string), length: 9))
        }
        let textView = UITextView(frame: UIScreen.main.bounds)
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.attributedText = formatted
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }
    
    @objc private func _onDone() {
        self.dismiss(animated: true, completion: nil)
    }
}
