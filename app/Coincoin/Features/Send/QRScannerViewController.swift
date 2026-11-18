//
//  QRScannerViewController.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import AVFoundation
import UIKit
import Vision
import VisionKit

final class QRScannerViewController: UIViewController, DataScannerViewControllerDelegate {

    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    private let onScan: (String) -> Bool
    private let scanner = DataScannerViewController(
        recognizedDataTypes: [.barcode(symbologies: [.qr])],
        qualityLevel: .balanced,
        recognizesMultipleItems: false,
        isHighlightingEnabled: true)
    private let messageLabel = UILabel()

    static func sheet(onScan: @escaping (String) -> Bool) -> UIViewController {
        let navigation = UINavigationController(rootViewController: QRScannerViewController(onScan: onScan))
        navigation.sheetPresentationController?.detents = [.large()]
        return navigation
    }

    init(onScan: @escaping (String) -> Bool) {
        self.onScan = onScan
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Escanear QR code")
        view.backgroundColor = .black
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
        scanner.delegate = self

        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = String(localized: "Aponte para o QR code do endereço Coincoin.")
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            messageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await startScanning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stopScanning()
    }

    private func startScanning() async {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard DataScannerViewController.isAvailable else {
            showCameraUnavailable()
            return
        }
        try? scanner.startScanning()
    }

    private func showCameraUnavailable() {
        messageLabel.text = String(localized: "Sem acesso à câmera. Permita em Ajustes para escanear.")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: String(localized: "Ajustes"),
            primaryAction: UIAction { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
    }

    // MARK: - DataScannerViewControllerDelegate

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        for case .barcode(let barcode) in addedItems {
            guard let text = barcode.payloadStringValue else { continue }
            if onScan(text) {
                dataScanner.stopScanning()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss(animated: true)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            messageLabel.text = String(localized: "Este QR code não é um endereço Coincoin.")
        }
    }
}
