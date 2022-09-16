//
//  HistoryViewController.swift
//  QRText
//
//  Created by 陈任伟 on 2022/9/16.
//

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
        cell.textLabel?.text = history[indexPath.row]
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
