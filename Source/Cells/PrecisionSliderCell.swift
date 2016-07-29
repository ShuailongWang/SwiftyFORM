// MIT license. Copyright (c) 2016 SwiftyFORM. All rights reserved.
import UIKit

public class PrecisionSliderCellModel {
	var title: String?
	var decimalPlaces: UInt = 3
	var value: Int = 0
	var minimumValue: Int = 0
	var maximumValue: Int = 1000
	
	var valueDidChange: Int -> Void = { (value: Int) in
		SwiftyFormLog("value \(value)")
	}
	
	var actualValue: Double {
		let decimalScale: Double = pow(Double(10), Double(decimalPlaces))
		return Double(value) / decimalScale
	}
}

public struct PrecisionSliderCellFormatter {
	public static func format(value value: Int, decimalPlaces: UInt) -> String {
		let decimalScale: Int = Int(pow(Double(10), Double(decimalPlaces)))
		let integerValue = abs(value / decimalScale)
		let sign: String = value < 0 ? "-" : ""
		
		let fractionString: String
		if decimalPlaces > 0 {
			let fractionValue = abs(value % decimalScale)
			let fmt = ".%0\(decimalPlaces)i"
			fractionString = String(format: fmt, fractionValue)
		} else {
			fractionString = ""
		}
		
		return "\(sign)\(integerValue)\(fractionString)"
	}
}


public class PrecisionSliderCell: UITableViewCell, CellHeightProvider, SelectRowDelegate {
	weak var expandedCell: PrecisionSliderCellExpanded?
	public let model: PrecisionSliderCellModel

	public init(model: PrecisionSliderCellModel) {
		self.model = model
		super.init(style: .Value1, reuseIdentifier: nil)
		selectionStyle = .None
		clipsToBounds = true
		textLabel?.text = model.title
		reloadValueLabel()
	}
	
	public required init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public func form_cellHeight(indexPath: NSIndexPath, tableView: UITableView) -> CGFloat {
		return 60
	}
	
	public func form_didSelectRow(indexPath: NSIndexPath, tableView: UITableView) {
		guard let tableView = tableView as? FormTableView else {
			return
		}
		guard let expandedCell = expandedCell else {
			return
		}
		tableView.expandCollapse(expandedCell: expandedCell, indexPath: indexPath)
	}
	
	func reloadValueLabel() {
		detailTextLabel?.text = PrecisionSliderCellFormatter.format(value: model.value, decimalPlaces: model.decimalPlaces)
	}
	
	func sliderDidChange(newValueOrNil: Double?) {
		var newValueOrZero: Int = 0
		
		if let newValue = newValueOrNil {
			let decimalScale: Double = pow(Double(10), Double(model.decimalPlaces))
			newValueOrZero = Int(round(newValue * decimalScale))
		}
		
		if model.value == newValueOrZero {
			return
		}
		model.value = newValueOrZero
		model.valueDidChange(newValueOrZero)
		reloadValueLabel()
	}
}

extension PrecisionSliderCellModel {
	struct Constants {
		static let initialInset: CGFloat = 30.0
		static let maxZoomedOut_Inset: CGFloat = 100.0
		static let maxZoomedIn_DistanceBetweenMarks: Double = 60
	}
	
	func sliderViewModel(sliderWidth sliderWidth: CGFloat) -> PrecisionSlider_InnerModel {
		let decimalScale: Double = pow(Double(10), Double(decimalPlaces))
		let minimumValue = Double(self.minimumValue) / decimalScale
		let maximumValue = Double(self.maximumValue) / decimalScale
		
		let instance = PrecisionSlider_InnerModel()
		instance.originalMinimumValue = minimumValue
		instance.originalMaximumValue = maximumValue
		
		let rangeLength = maximumValue - minimumValue
		
		let initialSliderWidth = Double(sliderWidth - Constants.initialInset)
		if initialSliderWidth > 10 && rangeLength > 0.001 {
			instance.scale = initialSliderWidth / rangeLength
		} else {
			instance.scale = 10
		}

		let maxZoomOutSliderWidth = Double(sliderWidth - Constants.maxZoomedOut_Inset)
		if maxZoomOutSliderWidth > 10 && rangeLength > 0.001 {
			instance.minimumScale = maxZoomOutSliderWidth / rangeLength
		} else {
			instance.minimumScale = 10
		}

		instance.maximumScale = Constants.maxZoomedIn_DistanceBetweenMarks * decimalScale
		
		// Prevent negative scale-range
		if instance.minimumScale > instance.maximumScale {
			//print("preventing negative scale-range: from \(instance.minimumScale) to \(instance.maximumScale)")
			instance.maximumScale = instance.minimumScale
			instance.scale = instance.minimumScale
		}
		return instance
	}
}

public class PrecisionSliderCellExpanded: UITableViewCell, CellHeightProvider {
	weak var collapsedCell: PrecisionSliderCell?

	public func form_cellHeight(indexPath: NSIndexPath, tableView: UITableView) -> CGFloat {
		return PrecisionSlider_InnerModel.height
	}
	
	func sliderDidChange() {
		collapsedCell?.sliderDidChange(slider.value)
	}
	
	lazy var slider: PrecisionSlider = {
		let instance = PrecisionSlider()
		instance.valueDidChange = nil
		return instance
	}()
	
	public init() {
		super.init(style: .Default, reuseIdentifier: nil)
		addSubview(slider)
	}
	
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public override func layoutSubviews() {
		super.layoutSubviews()
		slider.frame = bounds
		
		let tinyDelay = dispatch_time(DISPATCH_TIME_NOW, Int64(0.001 * Float(NSEC_PER_SEC)))
		dispatch_after(tinyDelay, dispatch_get_main_queue()) {
			self.assignInitialValue()
		}
	}
	
	func assignInitialValue() {
		if slider.valueDidChange != nil {
			return
		}
		guard let model = collapsedCell?.model else {
			return
		}
		
		let sliderViewModel = model.sliderViewModel(sliderWidth: slider.bounds.width)
		slider.model = sliderViewModel
		slider.layout.model = sliderViewModel
		slider.reloadSlider()

		let decimalScale: Double = pow(Double(10), Double(model.decimalPlaces))
		let scaledValue = Double(model.value) / decimalScale

		/*
		First we scroll to the right offset
		Next establish two way binding
		*/
		slider.value = scaledValue

		slider.valueDidChange = { [weak self] in
			self?.sliderDidChange()
		}
	}
	
	func setValueWithoutSync(value: Int) {
		guard let model = collapsedCell?.model else {
			return
		}
		SwiftyFormLog("set value \(value)")
		
		let decimalScale: Double = pow(Double(10), Double(model.decimalPlaces))
		let scaledValue = Double(value) / decimalScale
		slider.value = scaledValue
	}
}