//
//  QRCodeScannerViewController.swift
//  QRText
//
//  Created by 陈任伟 on 2022/9/14.
//

import AVFoundation
import Foundation
import UIKit

func generateRandmoColor() -> UIColor {
    let hue: CGFloat = CGFloat(Double(arc4random() % 256) / 256.0) //  0.0 to 1.0
    let saturation: CGFloat = CGFloat(Double(arc4random() % 128) / 256.0 + 0.5) //  0.5 to 1.0, away from white
    let brightness: CGFloat = CGFloat(Double(arc4random() % 128) / 256.0 + 0.5) //  0.5 to 1.0, away from black
    return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
}

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    lazy var session: AVCaptureSession = AVCaptureSession() // 输入输出的中间桥梁

    @IBOutlet var cropMaskView: UIView?
    @IBOutlet var contentView: UIView?
    var previewLayer: CALayer?
    var metadaOutput: AVCaptureMetadataOutput?

    lazy var scanWindow: QRScanWindowView = {
        let container = contentView ?? self.view!
        let view = QRScanWindowView(frame: container.bounds)
        view.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(view, at: 0)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view.backgroundColor = UIColor.clear
        view.cornerColor = cornerColor ?? UIColor.clear
        view.scanLine = scanLine
        view.excludePath = cropMaskView?.frame
        return view
    }()

    deinit {
    }

    func setCornerColor(cornerColor: UIColor) {
        self.cornerColor = cornerColor
        if isViewLoaded {
            scanWindow.cornerColor = cornerColor
        }
    }

    func setScanLine(scanLine: UIImage?) {
        self.scanLine = scanLine
        if isViewLoaded {
            scanWindow.scanLine = scanLine
        }
    }

    func setScanLineAutoMirror(scanLineAutoMirror: Bool) {
        self.scanLineAutoMirror = scanLineAutoMirror
        if isViewLoaded {
            scanWindow.scanLineAutoMirror = scanLineAutoMirror
        }
    }

    func newScanLine() -> UIImage? {
        let color = generateRandmoColor()
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 320, height: 2), false, 0)
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.setFillColor(color.cgColor)
            ctx.fill([CGRect(x: 0, y: 0, width: 320, height: 2)])
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    /**
     * 边角颜色
     */
    @IBInspectable var cornerColor: UIColor?

    /**
     * 扫描线图片, 仅在显示前设置才能生效
     */
    @IBInspectable var scanLine: UIImage?

    /**
     * 扫描线自动镜像
     */
    @IBInspectable var scanLineAutoMirror: Bool = true

    /**
     * 扫描回调
     */
    var resultBlock: ((QRCodeScannerViewController, String) -> Bool)?

    /**
     * 开始扫描
     */
    func start() {
        if !session.isRunning && checkPermission() {
            DispatchQueue.global().async { [self] in
                self.session.startRunning()
            }
            scanWindow.startScanAnimation()
        }
    }

    /**
     * 停止扫描
     */
    func stop() {
        if session.isRunning {
            session.stopRunning()
            scanWindow.stopScanAnimation()
        }
    }

    func checkPermission() -> Bool {
        let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if authStatus == AVAuthorizationStatus.restricted || authStatus == AVAuthorizationStatus.denied {
            return false
        } else {
            return true
        }
    }

    /**
     * 扫描结果
     * @param object 扫描输出
     * @return 是否停止 YES 停止, NO 继续
     */
    func onScanResult(object: AVMetadataMachineReadableCodeObject) -> Bool {
        if let block = resultBlock, let text = object.stringValue {
            return block(self, text)
        }
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scanWindow.setNeedsLayout()
        // 获取摄像设备
        // 创建输入流
        if let devices = AVCaptureDevice.default(for: AVMediaType.video),
           let input = try? AVCaptureDeviceInput(device: devices) {
            let output = AVCaptureMetadataOutput()
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            let crop = cropMaskView!
            let container = contentView ?? crop.superview ?? view!

            output.rectOfInterest = getScanCrop(rect: crop.frame, readerViewBounds: container.frame)
            session.canSetSessionPreset(AVCaptureSession.Preset.high)
            session.addInput(input)
            session.addOutput(output)
            output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr, AVMetadataObject.ObjectType.codabar, AVMetadataObject.ObjectType.code128]
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = container.bounds
            container.layer.insertSublayer(layer, at: 0)
            previewLayer = layer
            metadaOutput = output
        }
    }

    // MARK: - 获取扫描区域的比例关系

    func getScanCrop(rect: CGRect, readerViewBounds: CGRect) -> CGRect {
        let x, y, width, height: CGFloat
        y = CGRectGetMinX(rect) / CGRectGetWidth(readerViewBounds)
        x = CGRectGetMinY(rect) / CGRectGetHeight(readerViewBounds)
        height = CGRectGetWidth(rect) / CGRectGetWidth(readerViewBounds)
        width = CGRectGetHeight(rect) / CGRectGetHeight(readerViewBounds)
        return CGRectMake(x, y, width, height)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if session.isRunning {
            scanWindow.startScanAnimation()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let container = (contentView ?? cropMaskView?.superview ?? view) {
            previewLayer?.frame = container.bounds
            let crop = cropMaskView!.frame
            let scanCrop = getScanCrop(rect: crop, readerViewBounds: container.frame)
            metadaOutput?.rectOfInterest = scanCrop
            scanWindow.excludePath = crop
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let data = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           onScanResult(object: data) {
            stop()
        }
    }
}
