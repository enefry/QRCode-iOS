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
            setNeedsLayout()
            setNeedsDisplay()
            restartScanAnimationIfNeed()
        }
    }

    func startScanAnimation() {
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
        let moveHeight = (excludePath?.size ?? size).height - size.height
        let destPoint = CGPoint(x: point.x, y: point.y + moveHeight)
        line?.frame = CGRect(x: point.x, y: point.y, width: size.width, height: size.height)
        let autoMirror = scanLineAutoMirror
        let scanLineView = line
        UIView.animateKeyframes(withDuration: moveHeight / 50, delay: 0, options: UIView.KeyframeAnimationOptions(rawValue: UIView.KeyframeAnimationOptions.repeat.rawValue | UIView.AnimationOptions.curveEaseInOut.rawValue)) {
            if autoMirror {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.01) {
                    scanLineView?.transform = CGAffineTransformMakeScale(1.0, 1.0)
                }
            }
            UIView.addKeyframe(withRelativeStartTime: 0.01, relativeDuration: 0.5) {
                scanLineView?.frame = CGRect(x: destPoint.x, y: destPoint.y, width: size.width, height: size.height)
            }

            if autoMirror {
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.01) {
                    scanLineView?.transform = CGAffineTransformMakeScale(1.0, -1.0)
                }
            }
            UIView.addKeyframe(withRelativeStartTime: 0.51, relativeDuration: 0.49) {
                scanLineView?.frame = CGRect(x: point.x, y: point.y, width: size.width, height: size.height)
            }
        } completion: { _ in
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
            startScanAnimation()
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
