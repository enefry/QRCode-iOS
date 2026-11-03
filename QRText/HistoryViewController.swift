//
//  HistoryViewController.swift
//  QRText
//
//  Created by 陈任伟 on 2022/9/16.
//

import CoreImage
import UIKit

let HistoryKey = "history"

class HistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!
    @IBOutlet var textView: UITextView!
    var history: [String] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("History", comment: "")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        history = UserDefaults.standard.stringArray(forKey: HistoryKey) ?? []
        if history.count > 0 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark.circle"), style: .plain, target: self, action: #selector(onActionClear))
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let text = history[indexPath.row]
        cell.textLabel?.text = text
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "qrcode"), for: .normal)
        button.accessibilityLabel = NSLocalizedString("ShowQRCode", comment: "")
        button.accessibilityValue = text
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.addAction(UIAction { [weak self] _ in
            self?.showQRCode(for: text)
        }, for: .touchUpInside)
        cell.accessoryView = button
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        history.remove(at: indexPath.row)
        UserDefaults.standard.set(history, forKey: HistoryKey)
        tableView.reloadData()
    }

    @IBAction func onActionClear(_ sender: AnyObject) {
        let alert = UIAlertController(title: NSLocalizedString("ClearAllHistory", comment: "Clean All History"), message: NSLocalizedString("ClearCannotResue", comment: "Cannot resume after cleaning"), preferredStyle: UIAlertController.Style.alert)

        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Sure", comment: ""), style: .destructive, handler: { [weak self] _ in
            self?.history = []
            UserDefaults.standard.set([], forKey: HistoryKey)
            self?.tableView.reloadData()
        }))
        present(alert, animated: true)
    }

    @IBAction func onActionDone(_ sender: AnyObject) {
        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        textView?.text = history[indexPath.row]
    }

    private func showQRCode(for text: String) {
        guard let image = HistoryQRCodeGenerator.makeImage(for: text) else {
            let alert = UIAlertController(title: NSLocalizedString("QRCodeUnavailable", comment: ""),
                                          message: NSLocalizedString("QRCodeTooLong", comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Sure", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }
        navigationController?.pushViewController(HistoryQRCodeViewController(text: text, image: image), animated: true)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let text = history[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath)
        return UIContextMenuConfiguration(previewProvider: { [weak self] in
            if let self = self, let tv = self.storyboard?.instantiateViewController(withIdentifier: "TextViewController") {
                let width = self.view.bounds.size.width * 0.6
                var height = self.view.bounds.size.height * 0.8
                tv.view.subviews.forEach({ v in
                    if let textView = v as? UITextView {
                        textView.text = text
                        let warnHeight = textView.sizeThatFits(CGSize(width: width - 16, height: height - 16)).height + 16
                        if warnHeight < height {
                            height = warnHeight
                        }
                    }
                })
                tv.preferredContentSize = CGSize(width: width, height: height)
                return tv
            }
            return nil
        }, actionProvider: { defaultMenu in
            var menus = defaultMenu
            menus.append(contentsOf: [
                UIAction(title: NSLocalizedString("ShowQRCode", comment: ""), image: UIImage(systemName: "qrcode"), handler: { [weak self] _ in
                    self?.showQRCode(for: text)
                }),
                UIAction(title: "复制", handler: { _ in
                    UIPasteboard.general.string = text
                }),
                UIAction(title: NSLocalizedString("Share", comment: ""), image: UIImage(systemName: "square.and.arrow.up"), handler: { [weak self] _ in
                    let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                    if let popover = activity.popoverPresentationController {
                        popover.sourceView = cell
                        popover.permittedArrowDirections = UIPopoverArrowDirection.any
                    }
                    self?.present(activity, animated: true)
                }),
            ])
            return UIMenu(children: menus)
        })
    }
}

private final class HistoryQRCodeViewController: UIViewController {
    private let image: CGImage
    private let text: String

    init(text: String, image: CGImage) {
        self.text = text
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("ShowQRCode", comment: "")
        // Keep the code black on white even in dark mode.
        view.backgroundColor = .white
        let imageView = UIImageView(image: UIImage(cgImage: image))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.minificationFilter = .nearest
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = NSLocalizedString("ShowQRCode", comment: "")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Copy", comment: ""), style: .plain,
            target: self, action: #selector(copyOriginalText))

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .black
        textView.backgroundColor = .white
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byCharWrapping
        scrollView.addSubview(textView)

        let safeArea = view.safeAreaLayoutGuide
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            imageView.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            imageView.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: frame.widthAnchor, constant: -32),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: frame.heightAnchor, multiplier: 0.65),
            textView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
        ])
        let preferredWidth = imageView.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -32)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true
    }

    @objc private func copyOriginalText() {
        UIPasteboard.general.string = text
        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Copied", comment: ""))
    }
}

// Uses only Core Image so the generated payload can also be round-trip checked.
enum HistoryQRCodeGenerator {
    static func makeImage(for text: String) -> CGImage? {
        guard !text.isEmpty,
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let code = filter.outputImage else { return nil }
        // QR codes need a quiet zone of at least four modules on every side.
        let extent = code.extent.insetBy(dx: -4, dy: -4)
        let background = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: extent)
        let padded = code.composited(over: background).cropped(to: extent)
        let scaled = padded.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
