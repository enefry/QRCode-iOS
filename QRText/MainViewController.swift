//
//  ViewController.swift
//  QRText
//
//  Created by 陈任伟 on 2022/9/14.
//

import Combine
import CoreImage
import Photos
import PhotosUI
import SafariServices
import UIKit

class MainViewController: QRCodeScannerViewController, PHPickerViewControllerDelegate {
    @IBOutlet var textView: UITextView!
    @IBOutlet var openButton: UIButton!
    @IBOutlet var exportButton: UIButton!
    @IBOutlet var historyButton: UIButton!
    @IBOutlet var importButton: UIButton!

    @IBOutlet var hudPanel: UIView!
    @IBOutlet var loading: UIActivityIndicatorView!

    @Published var text: String = ""
    var events: [AnyCancellable] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        start()
        resultBlock = { vc, texts in
            if let vc = vc as? MainViewController,
               texts.count > 0 {
                print("扫描到:\(texts)")
                vc.text = texts.joined(separator: "\n\n")
            }
            return false
        }
        $text.removeDuplicates().sink { [weak self] text in
            if let self = self {
                self.exportButton.isEnabled = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count > 0
                self.openButton.isEnabled = text.hasPrefix("http://") || text.hasPrefix("https://")
                self.textView.text = text
                self.appendHistory(text: text)
            }
        }.store(in: &events)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stop()
    }

    func appendHistory(text: String) {
        if text.count > 0 {
            var history = UserDefaults.standard.stringArray(forKey: HistoryKey) ?? []
            history.insert(text, at: 0)
            if history.count > 30 {
                history.removeLast()
            }
            UserDefaults.standard.set(history, forKey: HistoryKey)
            UserDefaults.standard.synchronize()
        }
    }

    @IBAction func onActionExport(_ sender: UIButton) {
        if text.lengthOfBytes(using: String.Encoding.utf8) > 0 {
            let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = sender
                popover.permittedArrowDirections = UIPopoverArrowDirection.any
            }
            present(activity, animated: true)
        }
    }

    @IBAction func onActionOpenHistory(_ sender: UIButton) {
        // TODO:
        if let vc = storyboard?.instantiateViewController(withIdentifier: "HistoryViewController") {
            present(vc, animated: true)
        }
    }

    @IBAction func onActionOpenInSafari(_ sender: UIButton) {
        if let url = URL(string: text) {
            let vc = SFSafariViewController(url: url)
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    @IBAction func onActionImport(_ sender: UIButton) {
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
            self.text = String(qrCodeResults.joined(separator: "\n=============\n"))
        }
        picker.dismiss(animated: true)
    }

    func showLoading() {
        view.bringSubviewToFront(hudPanel)
        hudPanel?.alpha = 0
        hudPanel?.isHidden = false
        loading?.startAnimating()
        UIView.animate(withDuration: 0.25) {
            self.hudPanel?.alpha = 1
        }
    }

    @objc func hideLoading() {
        if let hudPanel = hudPanel {
            UIView.animate(withDuration: 0.25) {
                hudPanel.alpha = 0
            } completion: { _ in
                self.loading?.stopAnimating()
                hudPanel.isHidden = true
                self.view.sendSubviewToBack(hudPanel)
            }
        }
    }
}
