//
//  ViewController.swift
//  QRText
//
//  Created by 陈任伟 on 2022/9/14.
//

import CoreImage
import Photos
import PhotosUI
import SafariServices
import UIKit

class ViewController: QRCodeScannerViewController, PHPickerViewControllerDelegate {
    @IBOutlet var textView: UITextView?
    @IBOutlet var openButton: UIButton?

    @IBOutlet var hudPanel: UIView?
    @IBOutlet var loading: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        start()
        resultBlock = { vc, text in
            if let vc = vc as? ViewController {
                vc.updateText(text: text)
            }
            return false
        }
    }

    func updateText(text: String) {
        textView?.text = text
        openButton?.isEnabled = text.starts(with: "https://") || text.starts(with: "http://")
    }

    @IBAction func onActionCopy() {
        UIPasteboard.general.string = textView?.text
    }

    @IBAction func onActionOpen() {
        if let text = textView?.text,
           let url = URL(string: text) {
            let vc = SFSafariViewController(url: url)
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    @IBAction func onActionSelectFrom() {
        var configure = PHPickerConfiguration(photoLibrary: .shared())
        configure.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configure)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        var qrCodeResults: [String] = []
        showLoading()
        Task {
            let option = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            for item in results {
                if item.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    let qrcode = await withCheckedContinuation({ continuation in
                        item.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                            var qrcodes: [String] = []
                            if let image = image as? UIImage,
                               let ciImg = CIImage(image: image),
                               let detector: CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: option)
                            {
                                let features: [CIFeature] = detector.features(in: ciImg)
                                for feature in features {
                                    if let qrcode = feature as? CIQRCodeFeature,
                                       let message = qrcode.messageString {
                                        qrcodes.append(message)
                                    }
                                }
                            }
                            continuation.resume(returning: String(qrcodes.joined(separator: "\n\n")))
                        }
                    })
                    qrCodeResults.append(qrcode)
                }
                hideLoading()
            }
            self.updateText(text: String(qrCodeResults.joined(separator: "\n=============\n")))
        }
        picker.dismiss(animated: true)
    }

    func showLoading() {
        hudPanel?.alpha = 0
        hudPanel?.isHidden = false
        loading?.startAnimating()
        UIView.animate(withDuration: 0.25) {
            self.hudPanel?.alpha = 1
        }
    }

    @objc func hideLoading() {
        UIView.animate(withDuration: 0.25) {
            self.hudPanel?.alpha = 0
        } completion: { _ in
            self.loading?.stopAnimating()
            self.hudPanel?.isHidden = true
        }
    }
}
