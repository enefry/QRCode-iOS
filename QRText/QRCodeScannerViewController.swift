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

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    lazy var session: AVCaptureSession = AVCaptureSession() // 输入输出的中间桥梁
    var captureDevices: AVCaptureDevice?

    @IBOutlet var cropMaskView: UIView?
    @IBOutlet var permissionView: UIView?
    @IBOutlet var contentView: UIView?
    @IBOutlet var flashlight: UIButton!
    var previewLayer: AVCaptureVideoPreviewLayer?
    var metadaOutput: AVCaptureMetadataOutput?
    var dataOutput: AVCaptureVideoDataOutput?
    private var rotationCoordinator: AnyObject?
    private var rotationObservation: NSKeyValueObservation?
    private var deviceOrientationObserver: NSObjectProtocol?
    private var lastVideoOrientation: AVCaptureVideoOrientation = .portrait

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
        view.scanLineAutoMirror = scanLineAutoMirror
        view.excludePath = cropMaskView?.frame
        return view
    }()

    deinit {
        if let observer = deviceOrientationObserver {
            NotificationCenter.default.removeObserver(observer)
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
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
    var resultBlock: ((QRCodeScannerViewController, [String]) -> Bool)?

    /**
     * 开始扫描
     */
    func start() {
        let permission = checkPermission()
        if !session.isRunning && permission {
            DispatchQueue.global().async { [self] in
                self.session.startRunning()
            }
            scanWindow.startScanAnimation()
        }
        permissionView?.isHidden = permission
    }

    /**
     * 停止扫描
     */
    func stop() {
        scanWindow.stopScanAnimation()
        if session.isRunning {
            session.stopRunning()
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
    func onScanResult(objects: [AVMetadataMachineReadableCodeObject]) -> Bool {
        if let block = resultBlock {
            return block(self, objects.map({ t in t.stringValue ?? "" }))
        }
        return false
    }

    fileprivate func setupFlashlightButton(_ crop: UIView, _ container: UIView) {
        let frame = crop.bounds
        let width = {
            let fw = (frame.width * 0.4)
            let fh = (frame.height * 0.4)
            var width = fw
            if fw < fh {
                width = fh
            }
            if width > 120 {
                width = 120
            } else if width < 40 {
                width = 40
            }
            return width
        }()
        if flashlight == nil {
            let button = UIButton(type: .custom)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.backgroundColor = UIColor.clear
            let config = UIImage.SymbolConfiguration(pointSize: 36)
            button.setImage(UIImage(systemName: "flashlight.off.fill")?.applyingSymbolConfiguration(config), for: UIControl.State.normal)
            button.setImage(UIImage(systemName: "flashlight.on.fill")?.applyingSymbolConfiguration(config), for: UIControl.State.selected)
            button.isSelected = false
            button.addTarget(self, action: #selector(flashlightStatueChagne), for: UIControl.Event.touchUpInside)
            container.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: crop.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: crop.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: width),
                button.heightAnchor.constraint(equalToConstant: width),
            ])
            flashlight = button
        }
        flashlight.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scanWindow.setNeedsLayout()
        // 获取摄像设备
        // 创建输入流
        if let crop = cropMaskView,
           let container = contentView ?? crop.superview ?? view {
            if let devices = AVCaptureDevice.default(for: AVMediaType.video),
               let input = try? AVCaptureDeviceInput(device: devices) {
                captureDevices = devices
                let output = AVCaptureMetadataOutput()
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                let dataOutput = AVCaptureVideoDataOutput()
                dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
                if session.canSetSessionPreset(.high) {
                    session.sessionPreset = .high
                }
                session.addInput(input)
                session.addOutput(output)
                session.addOutput(dataOutput)

                let availableMetadataObjectTypes = output.availableMetadataObjectTypes
                var filterTypes = [AVMetadataObject.ObjectType.aztec,
                                   AVMetadataObject.ObjectType.code128,
                                   AVMetadataObject.ObjectType.code39,
                                   AVMetadataObject.ObjectType.code39Mod43,
                                   AVMetadataObject.ObjectType.code93,
                                   AVMetadataObject.ObjectType.dataMatrix,
                                   AVMetadataObject.ObjectType.ean13,
                                   AVMetadataObject.ObjectType.ean8,
                                   AVMetadataObject.ObjectType.interleaved2of5,
                                   AVMetadataObject.ObjectType.itf14,
                                   AVMetadataObject.ObjectType.pdf417,
                                   AVMetadataObject.ObjectType.qr].filter({ type in
                    availableMetadataObjectTypes.contains(type)
                })
                if #available(iOS 15.4, *) {
                    filterTypes.append(contentsOf: [AVMetadataObject.ObjectType.codabar,
                                                    AVMetadataObject.ObjectType.gs1DataBar,
                                                    AVMetadataObject.ObjectType.gs1DataBarExpanded,
                                                    AVMetadataObject.ObjectType.gs1DataBarLimited,
                                                    AVMetadataObject.ObjectType.microPDF417,
                                                    AVMetadataObject.ObjectType.microQR].filter({ type in
                            availableMetadataObjectTypes.contains(type)
                        }))
                }
                output.metadataObjectTypes = filterTypes

                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = container.bounds

                container.clipsToBounds = true
                container.layer.insertSublayer(layer, at: 0)
                previewLayer = layer
                metadaOutput = output
                if #available(iOS 17.0, *) {
                    let coordinator = AVCaptureDevice.RotationCoordinator(device: devices, previewLayer: layer)
                    rotationCoordinator = coordinator
                    // AVFoundation delivers these observations on the main queue.
                    rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview,
                                                               options: [.initial, .new]) { [weak self] _, _ in
                        self?.updateScaner()
                    }
                }
                setupFlashlightButton(crop, container)
            }
            updateScaner()
        }
    }

    @IBAction func flashlightStatueChagne() {
        flashlight.isSelected = !flashlight.isSelected
        turnTorchOn(isOn: flashlight.isSelected)
    }

    func turnTorchOn(isOn: Bool) {
        if let captureDevices = captureDevices,
           captureDevices.hasTorch,
           captureDevices.hasFlash {
            do {
                try! captureDevices.lockForConfiguration()
                if isOn {
                    captureDevices.torchMode = .on
                    captureDevices.flashMode = .on
                } else {
                    captureDevices.flashMode = .off
                    captureDevices.torchMode = .off
                }
                captureDevices.unlockForConfiguration()
            } catch {
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 17.0, *) {
            // RotationCoordinator observes camera pose and preview layer geometry.
        } else if deviceOrientationObserver == nil {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            deviceOrientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.updateScaner()
            }
        }
        updateScaner()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if session.isRunning {
            scanWindow.startScanAnimation()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        scanWindow.stopScanAnimation()
        if let observer = deviceOrientationObserver {
            NotificationCenter.default.removeObserver(observer)
            deviceOrientationObserver = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScaner()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateScaner()
        }, completion: { _ in
            self.updateScaner()
        })
    }

    func updateScaner() {
        guard let container = contentView ?? cropMaskView?.superview ?? view,
              let cropMaskView = cropMaskView else { return }

        // Camera pose can change while the app's interface stays portrait.
        // The coordinator also accounts for cameras with a different native
        // sensor orientation and the preview layer's orientation on screen.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = container.bounds
        if let connection = previewLayer?.connection {
            if #available(iOS 17.0, *),
               let coordinator = rotationCoordinator as? AVCaptureDevice.RotationCoordinator {
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            } else if connection.isVideoOrientationSupported {
                switch UIDevice.current.orientation {
                case .portrait: lastVideoOrientation = .portrait
                case .portraitUpsideDown: lastVideoOrientation = .portraitUpsideDown
                // Device and capture orientations use opposite landscape names.
                case .landscapeLeft: lastVideoOrientation = .landscapeRight
                case .landscapeRight: lastVideoOrientation = .landscapeLeft
                default: break // Preserve the last valid pose when flat/unknown.
                }
                connection.videoOrientation = lastVideoOrientation
            }
        }
        CATransaction.commit()

        let crop = cropMaskView.convert(cropMaskView.bounds, to: container)
        if let previewLayer = previewLayer, !container.bounds.isEmpty {
            // Account for orientation and the cropping introduced by aspect fill.
            metadaOutput?.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: crop)
        }
        scanWindow.excludePath = cropMaskView.convert(cropMaskView.bounds, to: scanWindow)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print("扫描到:\(metadataObjects)")
        var results: [AVMetadataMachineReadableCodeObject] = []
        for obj in metadataObjects {
            if let data = obj as? AVMetadataMachineReadableCodeObject,
               let _ = data.stringValue {
                results.append(data)
            }
        }
        if results.count > 0 {
            if onScanResult(objects: results) {
                stop()
            }
        }
    }

    let brightnessThresholdValue = -0.2
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var brightness: Double?
        if let metadata: NSDictionary = (CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) as NSDictionary?),
           let exif = metadata[kCGImagePropertyExifDictionary] as? NSDictionary,
           let brightnessValue = exif[kCGImagePropertyExifBrightnessValue] as? NSNumber {
            brightness = brightnessValue.doubleValue
        }
        if let brightness = brightness {
            flashlight.isHidden = !(flashlight.isSelected || brightness < brightnessThresholdValue)
        }
    }
}
