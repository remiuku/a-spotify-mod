import SwiftUI
import UIKit 

class EeveeSettingsViewController: SPTPageViewController {
    let settingsView: AnyView
    private var hasShownSpecialLicense = false
    private var settingsHost: UIViewController?
    
    init(_ frame: CGRect, settingsView: AnyView, navigationTitle: String) {
        self.settingsView = settingsView
        super.init(nibName: nil, bundle: nil)
        
        title = navigationTitle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let hostingController = UIHostingController(rootView: settingsView.modifier(ASMWhimsyRefresh()))
        settingsHost = hostingController
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        
        view.addSubview(hostingController.view)
        addChild(hostingController)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Become first responder so we can receive motion events
        becomeFirstResponder()
        updateBottomClearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBottomClearance()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateBottomClearance()
    }

    private func updateBottomClearance() {
        guard let settingsHost, let window = view.window, !view.bounds.isEmpty else { return }
        var overlap: CGFloat = 0

        // Presented settings sheets already have their own viewport; the bars
        // behind the sheet must not reserve space inside it.
        var ancestor: UIViewController? = self
        var isPresented = false
        while let controller = ancestor {
            if controller.presentingViewController != nil { isPresented = true; break }
            ancestor = controller.parent
        }

        if !isPresented {
            func visit(_ candidate: UIView) {
                guard !candidate.isHidden, candidate.alpha > 0.01,
                      candidate !== settingsHost.view else { return }
                let name = NSStringFromClass(type(of: candidate))
                let owner = (candidate.next as? UIViewController).map { NSStringFromClass(type(of: $0)) } ?? ""
                let isBar = candidate is UITabBar
                    || name == "_TtC23NavigationUI_TabBarImpl10TabBarView"
                    || name.contains("NowPlaying_BarPageImpl")
                    || owner.contains("NowPlayingBarContainerViewController")
                    || owner.contains("NowPlayingBarViewController")
                if isBar {
                    let frame = candidate.convert(candidate.bounds, to: view)
                    if frame.intersects(view.bounds), frame.height > 0,
                       frame.height < view.bounds.height * 0.4,
                       frame.minY > view.bounds.midY {
                        overlap = max(overlap, view.bounds.maxY - frame.minY)
                    }
                }
                for child in candidate.subviews { visit(child) }
            }
            visit(window)
        }

        // Use the parent's safe area, not the child's expanded one, so repeated
        // layout passes cannot alternate between adding and removing clearance.
        let bottom = overlap > 0 ? max(0, overlap + 12 - view.safeAreaInsets.bottom) : 0
        if abs(settingsHost.additionalSafeAreaInsets.bottom - bottom) > 0.5 {
            var insets = settingsHost.additionalSafeAreaInsets
            insets.bottom = bottom
            settingsHost.additionalSafeAreaInsets = insets
        }
    }
    
    override var canBecomeFirstResponder: Bool { true }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake, !hasShownSpecialLicense else { return }
        hasShownSpecialLicense = true
        
        let alert = UIAlertController(
            title: "Special License Detected",
            message: "Subscribed to Elsa by Hysan since 2026.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Prayers for Hysan 🙏", style: .default))
        WindowHelper.shared.present(alert)
    }
    
    @objc func openRepositoryUrl(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://github.com/jaydenjcpy/EeveeSpotifyReincarnated")!)
    }
}
