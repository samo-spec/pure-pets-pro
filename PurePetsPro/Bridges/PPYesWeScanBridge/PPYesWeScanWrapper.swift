import UIKit
import YesWeScan

@objc public protocol PPYesWeScanWrapperDelegate: AnyObject {
    func yesWeScanWrapper(_ wrapper: PPYesWeScanWrapper, didCaptureImage image: UIImage, forTag tag: Int)
}

@objc public final class PPYesWeScanWrapper: NSObject, ScannerViewControllerDelegate {
    
    @objc public weak var delegate: PPYesWeScanWrapperDelegate?
    private var tag: Int = 0
    
    @objc public func presentScanner(from viewController: UIViewController, withTag tag: Int) {
        self.tag = tag
        let scanner = ScannerViewController()
        scanner.delegate = self
        scanner.scanningQuality = .medium
        
        let nav = UINavigationController(rootViewController: scanner)
        nav.modalPresentationStyle = .fullScreen
        
        // Add close button
        let closeItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        scanner.navigationItem.leftBarButtonItem = closeItem
        
        viewController.present(nav, animated: true, completion: nil)
    }
    
    @objc private func cancelTapped() {
        if let delegateVC = delegate as? UIViewController {
            delegateVC.dismiss(animated: true, completion: nil)
        }
    }
    
    public func scanner(_ scanner: ScannerViewController, didCaptureImage image: UIImage) {
        if let delegateVC = delegate as? UIViewController {
            delegateVC.dismiss(animated: true, completion: nil)
        }
        self.delegate?.yesWeScanWrapper(self, didCaptureImage: image, forTag: self.tag)
    }
}
