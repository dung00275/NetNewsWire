//
//  AddFeedViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import Account
import RSCore
import RSTree
import RSParser

class AddFeedViewController: UITableViewController, AddContainerViewControllerChild {
	
	@IBOutlet weak var urlTextField: UITextField!
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var folderPickerView: UIPickerView!
	@IBOutlet weak var folderLabel: UILabel!
	
	private var pickerData: AddFeedFolderPickerData!
	
	private var userCancelled = false

	weak var delegate: AddContainerViewControllerChildDelegate?
	var initialFeed: String?
	var initialFeedName: String?

	override func viewDidLoad() {
		
        super.viewDidLoad()
		
		urlTextField.autocorrectionType = .no
		urlTextField.autocapitalizationType = .none
		urlTextField.text = initialFeed
		
		if initialFeed != nil {
			delegate?.readyToAdd(state: true)
		}
		
		nameTextField.text = initialFeedName
		
		pickerData = AddFeedFolderPickerData()
		folderPickerView.dataSource = self
		folderPickerView.delegate = self
		folderPickerView.showsSelectionIndicator = true
		folderLabel.text = pickerData.containerNames[0]

		// I couldn't figure out the gap at the top of the UITableView, so I took a hammer to it.
		tableView.contentInset = UIEdgeInsets(top: -28, left: 0, bottom: 0, right: 0)
		
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: urlTextField)

	}
	
	func cancel() {
		userCancelled = true
		delegate?.processingDidCancel()
	}
	
	func add() {

		let urlString = urlTextField.text ?? ""
		let normalizedURLString = (urlString as NSString).rs_normalizedURL()
		
		guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString) else {
			delegate?.processingDidCancel()
			return
		}
		
		let container = pickerData.containers[folderPickerView.selectedRow(inComponent: 0)]
		
		var account: Account?
		var folder: Folder?
		if let containerAccount = container as? Account {
			account = containerAccount
		}
		if let containerFolder = container as? Folder, let containerAccount = containerFolder.account {
			account = containerAccount
			folder = containerFolder
		}
		
		if account!.hasFeed(withURL: url.absoluteString) {
			showAlreadySubscribedError()
 			return
		}
		
		let title = nameTextField.text
		
		delegate?.processingDidBegin()

		account!.createFeed(with: nil, url: url.absoluteString) { [weak self] result in
			
			switch result {
			case .success(let createFeedResult):
				switch createFeedResult {
				case .created(let feed):
					self?.processFeed(feed, account: account!, folder: folder, url: url, title: title)
				case .multipleChoice(let feedChoices):
					print()
					self?.delegate?.processingDidCancel()
				case .alreadySubscribed:
					self?.showAlreadySubscribedError()
					self?.delegate?.processingDidCancel()
				case .notFound:
					self?.showNoFeedsErrorMessage()
					self?.delegate?.processingDidCancel()
				}
			case .failure(let error):
				self?.presentError(error)
				self?.delegate?.processingDidCancel()
			}
			
		}

	}
	
	@objc func textDidChange(_ note: Notification) {
		delegate?.readyToAdd(state: urlTextField.text?.rs_stringMayBeURL() ?? false)
	}
	
}

extension AddFeedViewController: UIPickerViewDataSource, UIPickerViewDelegate {
	
	func numberOfComponents(in pickerView: UIPickerView) ->Int {
		return 1
	}
	
	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return pickerData.containerNames.count
	}
	
	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return pickerData.containerNames[row]
	}
	
	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		folderLabel.text = pickerData.containerNames[row]
	}
	
}

private extension AddFeedViewController {
	
	private func showAlreadySubscribedError() {
		let title = NSLocalizedString("Already subscribed", comment: "Feed finder")
		let message = NSLocalizedString("Can’t add this feed because you’ve already subscribed to it.", comment: "Feed finder")
		presentError(title: title, message: message)
	}
	
	private func showNoFeedsErrorMessage() {
		let title = NSLocalizedString("Feed not found", comment: "Feed finder")
		let message = NSLocalizedString("Can’t add a feed because no feed was found.", comment: "Feed finder")
		presentError(title: title, message: message)
	}
	
	private func showInitialDownloadError(_ error: Error) {
		let title = NSLocalizedString("Download Error", comment: "Feed finder")
		let formatString = NSLocalizedString("Can’t add this feed because of a download error: “%@”", comment: "Feed finder")
		let message = NSString.localizedStringWithFormat(formatString as NSString, error.localizedDescription)
		presentError(title: title, message: message as String)
	}
	
	func processFeed(_ feed: Feed, account: Account, folder: Folder?, url: URL, title: String?) {
		
		if let title = title {
			account.renameFeed(feed, to: title) { [weak self] result in
				switch result {
				case .success:
					break
				case .failure(let error):
					self?.presentError(error)
				}
			}
		}
		
		// TODO: make this async and add to above code
		account.addFeed(feed, to: folder)
		
		// Move this into the mess above
		NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
		
		delegate?.processingDidEnd()
		
	}
	
}
