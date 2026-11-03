//
//  File.swift
//  QRText
//
//  Created by 陈任伟 on 2022/9/14.
//

import Foundation
import UIKit
class QRScanWindowView: UIView {
    private var _animating = false

    var showCorner: Bool = true
    var cornerColor: UIColor = UIColor.green {
        didSet {
            var alpha: CGFloat = 0

            if cornerColor.getRed(nil, green: nil, blue: nil, alpha: &alpha) {
                showCorner = alpha > 0.001
            }
        }
    }

    var scanLine: UIImage?
    var scanLineAutoMirror: Bool = true
    var line: UIView?
    var excludePath: CGRect? {
        didSet {
            guard excludePath != oldValue else { return }
            setNeedsLayout()
            setNeedsDisplay()
            restartScanAnimationIfNeed()
        }
    }

    func startScanAnimation() {
        guard !_animating else { return }
        stopScanAnimation()
        _animating = true
        var size = excludePath?.size ?? bounds.size
        let point = excludePath?.origin ?? CGPoint.zero
        line?.removeFromSuperview()
        if let scanLine = scanLine {
            let iv = UIImageView(image: scanLine)
            addSubview(iv)
            line = iv
            size.height = scanLine.size.height
        } else {
            size.height = 2
            let iv = UIView(frame: CGRect(origin: point, size: size))
            iv.backgroundColor = UIColor.green
            addSubview(iv)
            line = iv
        }
        let moveHeight = (excludePath?.height ?? bounds.height) - size.height
        line?.frame = CGRect(origin: point, size: size)

        guard let scanLineView = line, moveHeight > 0 else { return }

        let duration = CFTimeInterval(moveHeight / 150)
        // A keyed layer animation has its own timing, independent of UIKit's
        // layout/rotation animation context, and cannot accumulate on restart.
        let movement = CABasicAnimation(keyPath: "transform.translation.y")
        movement.fromValue = 0
        movement.toValue = moveHeight
        movement.duration = duration
        movement.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        movement.autoreverses = true
        movement.repeatCount = .infinity
        scanLineView.layer.add(movement, forKey: "scanMovement")

        // 镜像动画：与位置动画周期同步（完整往返 = duration * 2）
        if scanLineAutoMirror {
            let mirrorAnim = CAKeyframeAnimation(keyPath: "transform.scale.y")
            mirrorAnim.values = [1, 1, -1, -1]
            mirrorAnim.keyTimes = [0, 0.5, 0.5, 1]
            mirrorAnim.duration = duration * 2
            mirrorAnim.repeatCount = .infinity
            mirrorAnim.calculationMode = .discrete
            scanLineView.layer.add(mirrorAnim, forKey: "mirror")
        }
    }

    func stopScanAnimation() {
        if _animating {
            line?.layer.removeAllAnimations()
        }
        _animating = false
    }

    func restartScanAnimationIfNeed() {
        if _animating {
            stopScanAnimation()
            startScanAnimation()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if excludePath == nil {
            restartScanAnimationIfNeed()
        }
    }

    override func draw(_ rect: CGRect) {
        if let ctx = UIGraphicsGetCurrentContext(),
           let excludePath = excludePath {
            ctx.saveGState()
            let full = UIBezierPath(rect: rect)
            full.append(UIBezierPath(rect: excludePath))
            full.usesEvenOddFillRule = true
            full.addClip()
            full.fill(with: CGBlendMode.normal, alpha: 0.6)
            // 四个角
            if showCorner {
                let corner = UIBezierPath()
                let r = excludePath
                let lineLength: CGFloat = 20
                corner.lineWidth = 4
                corner.move(to: CGPoint(x: r.origin.x, y: r.origin.y + lineLength))
                corner.addLine(to: CGPoint(x: r.origin.x, y: r.origin.y))
                corner.addLine(to: CGPoint(x: r.origin.x + lineLength, y: r.origin.y))
                corner.move(to: CGPoint(x: r.origin.x + r.size.width, y: r.origin.y + lineLength))
                corner.addLine(to: CGPoint(x: r.origin.x + r.size.width, y: r.origin.y))
                corner.addLine(to: CGPoint(x: r.origin.x + r.size.width - lineLength, y: r.origin.y))
                corner.move(to: CGPoint(x: r.origin.x, y: r.origin.y + r.size.height - lineLength))
                corner.addLine(to: CGPoint(x: r.origin.x, y: r.origin.y + r.size.height))
                corner.addLine(to: CGPoint(x: r.origin.x + lineLength, y: r.origin.y + r.size.height))
                corner.move(to: CGPoint(x: r.origin.x + r.size.width, y: r.origin.y + r.size.height - lineLength))
                corner.addLine(to: CGPoint(x: r.origin.x + r.size.width, y: r.origin.y + r.size.height))
                corner.addLine(to: CGPoint(x: r.origin.x + r.size.width - lineLength, y: r.origin.y + r.size.height))

                cornerColor.setStroke()
                corner.stroke(with: CGBlendMode.normal, alpha: 1.0)
            }
            ctx.restoreGState()
        }
    }
}
