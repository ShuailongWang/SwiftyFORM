// MIT license. Copyright (c) 2016 SwiftyFORM. All rights reserved.
import UIKit

/*
one-finger pan to adjust slider
two-finger pinch to adjust zoom
*/
class PrecisionSlider: UIView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, UIScrollViewDelegate, UIGestureRecognizerDelegate {
	var originalScale: Double = 1
	var originalValue: Double = 0
	
	var model = PrecisionSlider_InnerModel()
	
	typealias ValueDidChange = Void -> Void
	var valueDidChange: ValueDidChange?
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		commonInit()
	}
	
	func commonInit() {
		addSubview(collectionView)
		addSubview(leftCoverView)
		addSubview(rightCoverView)
		addGestureRecognizer(pinchGestureRecognizer)
	}
	
	func updateContentInset() {
		let halfWidth = round(bounds.width/2)
		if model.hasOnePartialItem {
			collectionView.contentInset = UIEdgeInsets(top: 0, left: halfWidth, bottom: 0, right: halfWidth)
			return
		}
		let inset = halfWidth - round(CGFloat(model.lengthOfFullItem) / 2)
		var insetLeft = inset
		var insetRight = inset
		if model.hasPartialItemBefore {
			insetLeft = halfWidth - CGFloat(model.lengthOfFullItem / 2 + model.remainingLengthOfPartialItemBefore)
		}
		if model.hasPartialItemAfter {
			insetRight = halfWidth - CGFloat(model.lengthOfFullItem / 2 + model.remainingLengthOfPartialItemAfter)
		}
		collectionView.contentInset = UIEdgeInsets(top: 0, left: insetLeft, bottom: 0, right: insetRight)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		collectionView.frame = bounds
		
		updateContentInset()
		
		let (leftFrame, rightFrame) = bounds.divide(round(bounds.width/2), fromEdge: .MinXEdge)
		leftCoverView.frame = CGRect(x: leftFrame.origin.x, y: leftFrame.origin.y, width: leftFrame.size.width - 1, height: leftFrame.size.height)
		rightCoverView.frame = rightFrame
	}
	
	lazy var leftCoverView: UIView = {
		let instance = UIView()
		instance.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1)
		instance.userInteractionEnabled = false
		return instance
	}()
	
	lazy var rightCoverView: UIView = {
		let instance = UIView()
		instance.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1)
		instance.userInteractionEnabled = false
		return instance
	}()

	var value: Double {
		get { return valueFromContentOffset() }
		set { setContentOffset(newValue) }
	}
	
	func valueFromContentOffset() -> Double {
		let scale = model.lengthOfFullItem
		if scale < 0.001 {
			return model.fallbackValue
		}
		
		let midX: CGFloat = collectionView.contentOffset.x + collectionView.contentInset.left
		var result = Double(midX) / scale + model.minimumValue
		if result < model.minimumValue {
			result = model.minimumValue
		}
		if result > model.maximumValue {
			result = model.maximumValue
		}
		result /= model.zoomMode.scalar
		return result
	}
	
	func setContentOffset(value: Double) {
		let scale = model.lengthOfFullItem
		if scale < 0.001 {
			return
		}
		
		var clampedValue = value * model.zoomMode.scalar
		if clampedValue < model.minimumValue {
			clampedValue = model.minimumValue
		}
		if clampedValue > model.maximumValue {
			clampedValue = model.maximumValue
		}
		
		let valueAdjusted = clampedValue - model.minimumValue
		let contentInsetLet = Double(collectionView.contentInset.left)
		let offsetX = CGFloat(round((scale * valueAdjusted) - contentInsetLet))
		//print("offsetX: \(offsetX)    [ \(scale) * \(valueAdjusted) - \(contentInsetLet) ]")
		
		let originalValueDidChange = valueDidChange
		valueDidChange = nil
		collectionView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
		valueDidChange = originalValueDidChange
	}
	
	lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
		let instance = UIPinchGestureRecognizer(target: self, action: #selector(PrecisionSlider.handlePinch))
		instance.delegate = self
		return instance
	}()
	
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return false
	}
	
	func handlePinch(gesture: UIPinchGestureRecognizer) {
		if gesture.state == .Began {
			originalScale = model.scale
			originalValue = self.value
		}
		if gesture.state == .Changed {
			var scale = originalScale * Double(gesture.scale)
			if scale < 0.0 {
				// ensure scale never goes below zero
				scale = 0.01
			}
			if scale > model.maximumScale {
				scale = model.maximumScale
			}
			if scale < model.minimumScale {
				scale = model.minimumScale
			}
			if model.scale == scale {
				return // no need to update UI
			}
			model.scale = scale
			//print(String(format: "update scale: %.5f   \(model.zoomMode)", scale))
			reloadSlider()
			
			self.value = originalValue
			
			valueDidChange?()
		}
	}
	
	func reloadSlider() {
		model.updateRange()
		updateContentInset()
		collectionView.reloadData()
		layout.itemSize = computeItemSize()
		layout.invalidateLayout()
	}
	
	func computeItemSize() -> CGSize {
		return CGSize(width: CGFloat(model.lengthOfFullItem), height: PrecisionSlider_InnerModel.height)
	}
	
	lazy var layout: PrecisionSlider_InnerCollectionViewFlowLayout = {
		let instance = PrecisionSlider_InnerCollectionViewFlowLayout()
		instance.scrollDirection = .Horizontal
		instance.minimumInteritemSpacing = 0
		instance.minimumLineSpacing = 0
		instance.sectionInset = UIEdgeInsetsZero
		instance.headerReferenceSize = CGSizeZero
		instance.footerReferenceSize = CGSizeZero
		instance.itemSize = self.computeItemSize()
		instance.model = self.model
		return instance
	}()
	
	lazy var collectionView: UICollectionView = {
		let instance = UICollectionView(frame: CGRectZero, collectionViewLayout: self.layout)
		instance.showsHorizontalScrollIndicator = false
		instance.showsVerticalScrollIndicator = false
		instance.backgroundColor = UIColor.whiteColor()
		instance.bounces = false
		instance.alwaysBounceHorizontal = true
		instance.alwaysBounceVertical = false
		instance.registerClass(PrecisionSlider_InnerCollectionViewSingleCell.self, forCellWithReuseIdentifier: PrecisionSlider_InnerCollectionViewSingleCell.identifier)
		instance.registerClass(PrecisionSlider_InnerCollectionViewFirstCell.self, forCellWithReuseIdentifier: PrecisionSlider_InnerCollectionViewFirstCell.identifier)
		instance.registerClass(PrecisionSlider_InnerCollectionViewLastCell.self, forCellWithReuseIdentifier: PrecisionSlider_InnerCollectionViewLastCell.identifier)
		instance.registerClass(PrecisionSlider_InnerCollectionViewFullCell.self, forCellWithReuseIdentifier: PrecisionSlider_InnerCollectionViewFullCell.identifier)
		instance.contentInset = UIEdgeInsetsZero
		instance.delegate = self
		instance.dataSource = self
		return instance
	}()
	
	func scrollViewDidScroll(scrollView: UIScrollView) {
		valueDidChange?()
	}
	
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		var count = model.numberOfFullItems
		if model.hasOnePartialItem {
			count += 1
		}
		if model.hasPartialItemBefore {
			count += 1
		}
		if model.hasPartialItemAfter {
			count += 1
		}
		//print("number of items: \(count)")
		return count
	}
	
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		if model.hasOnePartialItem {
			let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PrecisionSlider_InnerCollectionViewSingleCell.identifier, forIndexPath: indexPath) as! PrecisionSlider_InnerCollectionViewSingleCell
			return cell
		}
		
		let labelText: String?  = model.labelTextForIndexPath(indexPath)
		let markColor: UIColor? = model.markColorForIndexPath(indexPath)
		
		let count = self.collectionView(collectionView, numberOfItemsInSection: 0)
		let isFirst = indexPath.row == 0
		let isLast = indexPath.row == count - 1
		
		if isFirst && model.hasPartialItemBefore {
			let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PrecisionSlider_InnerCollectionViewFirstCell.identifier, forIndexPath: indexPath) as! PrecisionSlider_InnerCollectionViewFirstCell
			cell.label.text = labelText
			cell.mark.backgroundColor = markColor
			cell.configure(model.lengthOfPartialItemBefore, fullLength: model.lengthOfFullItem)
			return cell
		}
		if isLast && model.hasPartialItemAfter {
			let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PrecisionSlider_InnerCollectionViewLastCell.identifier, forIndexPath: indexPath) as! PrecisionSlider_InnerCollectionViewLastCell
			cell.label.text = labelText
			cell.mark.backgroundColor = markColor
			cell.configure(model.lengthOfPartialItemAfter, fullLength: model.lengthOfFullItem)
			return cell
		}
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PrecisionSlider_InnerCollectionViewFullCell.identifier, forIndexPath: indexPath) as! PrecisionSlider_InnerCollectionViewFullCell
		cell.label.text = labelText
		cell.mark.backgroundColor = markColor
		return cell
	}
	
	func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
		if model.hasOnePartialItem {
			let size = CGSize(
				width: CGFloat(model.lengthOfOnePartialItem),
				height: PrecisionSlider_InnerModel.height
			)
			//print("size for one-partial \(indexPath.row) \(size.width)")
			return size
		}
		var row = indexPath.row
		if model.hasPartialItemBefore {
			if row == 0 {
				let size = CGSize(
					width: CGFloat(model.lengthOfFullItem * 2),
					height: PrecisionSlider_InnerModel.height
				)
				//print("size for partial-before \(indexPath.row) \(size.width)")
				return size
			}
			row -= 1
		}
		if row >= model.numberOfFullItems {
			if model.hasPartialItemAfter {
				let size = CGSize(
					width: CGFloat(model.lengthOfFullItem * 2),
					height: PrecisionSlider_InnerModel.height
				)
				//print("size for partial-after \(indexPath.row) \(size.width)")
				return size
			}
		}
		let size = CGSize(
			width: CGFloat(model.lengthOfFullItem),
			height: PrecisionSlider_InnerModel.height
		)
		//print("size for full \(indexPath.row) \(size.width)")
		return size
	}
}


class PrecisionSlider_InnerCollectionViewFlowLayout: UICollectionViewFlowLayout {
	weak var model: PrecisionSlider_InnerModel?
	
	override func collectionViewContentSize() -> CGSize {
		guard let model = self.model else {
			print("no model")
			return CGSizeZero
		}
		return CGSize(width: CGFloat(model.lengthOfContent), height: PrecisionSlider_InnerModel.height)
	}
}