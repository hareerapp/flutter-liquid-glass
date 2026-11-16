import CoreText
import Flutter
import UIKit

final class LiquidGlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "liquid_design/tab_bar"

  private weak var registrar: FlutterPluginRegistrar?
  private let messenger: FlutterBinaryMessenger

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    messenger = registrar.messenger()
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    LiquidGlassTabBarPlatformView(
      frame: frame,
      channelName: "\(Self.viewType)_\(viewId)",
      args: args as? [String: Any] ?? [:],
      messenger: messenger,
      parent: registrar?.viewController
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class LiquidGlassTabBarPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let channel: FlutterMethodChannel
  private var host: AnyObject?

  init(
    frame: CGRect,
    channelName: String,
    args: [String: Any],
    messenger: FlutterBinaryMessenger,
    parent: UIViewController?
  ) {
    container = UIView(frame: frame)
    channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    super.init()
    container.backgroundColor = .clear
    container.isOpaque = false
    container.clipsToBounds = false

    #if compiler(>=6.2)
      guard #available(iOS 26.0, *) else { return }
      let host = LiquidGlassTabBarHostView(params: args) { [weak channel] index in
        channel?.invokeMethod("onTabSelected", arguments: index)
      }
      host.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(host)
      let overflow = CGFloat((args["overflow"] as? NSNumber)?.doubleValue ?? 0)
      NSLayoutConstraint.activate([
        host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        host.topAnchor.constraint(equalTo: container.topAnchor, constant: overflow),
        host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
      host.attach(to: parent)
      self.host = host

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self, let host = self.host as? LiquidGlassTabBarHostView else {
          return result(nil)
        }
        switch call.method {
        case "select":
          host.select((call.arguments as? NSNumber)?.intValue ?? 0)
        case "badges":
          host.setBadges(call.arguments as? [Any] ?? [])
        case "style":
          host.setStyle(call.arguments as? [String: Any] ?? [:])
        case "hidden":
          let alpha: CGFloat = (call.arguments as? Bool) == true ? 0 : 1
          if self.container.alpha != alpha {
            UIView.animate(withDuration: alpha == 0 ? 0.15 : 0.25) {
              self.container.alpha = alpha
            }
          }
        default:
          return result(FlutterMethodNotImplemented)
        }
        result(nil)
      }
    #endif
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { container }
}

#if compiler(>=6.2)
  @available(iOS 26.0, *)
  final class LiquidGlassTabBarHostView: UIView, UITabBarControllerDelegate {
    private let controller = UITabBarController()
    private let onSelected: (Int) -> Void
    private var params: [String: Any]
    private var identifiers: [String] = []
    private var programmatic = false

    init(params: [String: Any], onSelected: @escaping (Int) -> Void) {
      self.onSelected = onSelected
      self.params = params.filter { $0.key != "tabs" }
      super.init(frame: .zero)
      backgroundColor = .clear
      isOpaque = false
      clipsToBounds = false
      configure(tabs: params["tabs"] as? [[String: Any]] ?? [])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
      if controller.parent != nil {
        controller.willMove(toParent: nil)
        controller.removeFromParent()
      }
    }

    func attach(to parent: UIViewController?) {
      guard let parent, controller.parent !== parent else { return }
      parent.addChild(controller)
      controller.didMove(toParent: parent)
      applyStyle()
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window != nil { applyStyle() }
    }

    private var direction: UISemanticContentAttribute {
      (params["rtl"] as? Bool) == true ? .forceRightToLeft : .forceLeftToRight
    }

    private func configure(tabs: [[String: Any]]) {
      let scale = CGFloat((params["iconScale"] as? NSNumber)?.doubleValue ?? UIScreen.main.scale)
      let view = controller.view!
      view.backgroundColor = .clear
      view.isOpaque = false
      view.clipsToBounds = false

      controller.tabs = tabs.enumerated().map { index, tab in
        let identifier = "tab-\(index)"
        let item = UITab(
          title: tab["label"] as? String ?? "",
          image: Self.image(tab["icon"], scale: scale),
          identifier: identifier
        ) { _ in
          let content = UIViewController()
          content.view.backgroundColor = .clear
          return content
        }
        if item.responds(to: NSSelectorFromString("setSelectedImage:")),
          let selected = Self.image(tab["selectedIcon"], scale: scale)
        {
          item.setValue(selected, forKey: "selectedImage")
        }
        item.badgeValue = tab["badge"] as? String
        return item
      }
      identifiers = controller.tabs.map { $0.identifier }
      controller.mode = .tabBar
      controller.delegate = self
      select((params["selectedIndex"] as? NSNumber)?.intValue ?? 0)

      let tabBar = controller.tabBar
      tabBar.clipsToBounds = false
      for target in [tabBar, view, self] as [UIView] {
        target.semanticContentAttribute = direction
      }
      applyStyle()

      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
      NSLayoutConstraint.activate([
        view.leadingAnchor.constraint(equalTo: leadingAnchor),
        view.trailingAnchor.constraint(equalTo: trailingAnchor),
        view.topAnchor.constraint(equalTo: topAnchor),
        view.bottomAnchor.constraint(equalTo: bottomAnchor),
      ])
    }

    private func applyStyle() {
      let style: UIUserInterfaceStyle = (params["dark"] as? Bool) == true ? .dark : .light
      controller.overrideUserInterfaceStyle = style
      overrideUserInterfaceStyle = style

      let selected = LiquidGlassTabBarStyle.color(params["selectedColor"])
      let unselected = LiquidGlassTabBarStyle.color(params["unselectedColor"])
      let badge = LiquidGlassTabBarStyle.color(params["badgeColor"])
      let size = CGFloat((params["fontSize"] as? NSNumber)?.doubleValue ?? 10)
      let font =
        LiquidGlassTabBarStyle.font(asset: params["fontAsset"] as? String, size: size)
        ?? UIFont.systemFont(ofSize: size, weight: .semibold)

      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      for layout in [
        appearance.stackedLayoutAppearance,
        appearance.inlineLayoutAppearance,
        appearance.compactInlineLayoutAppearance,
      ] {
        layout.normal.titleTextAttributes[.font] = font
        layout.selected.titleTextAttributes[.font] = font
        if let selected {
          layout.selected.iconColor = selected
          layout.selected.titleTextAttributes[.foregroundColor] = selected
        }
        if let unselected {
          layout.normal.iconColor = unselected
          layout.normal.titleTextAttributes[.foregroundColor] = unselected
        }
        if let badge {
          layout.normal.badgeBackgroundColor = badge
          layout.selected.badgeBackgroundColor = badge
        }
      }
      let tabBar = controller.tabBar
      tabBar.standardAppearance = appearance
      tabBar.scrollEdgeAppearance = appearance
      if let selected {
        tabBar.tintColor = selected
        controller.view.tintColor = selected
      }
      if let unselected { tabBar.unselectedItemTintColor = unselected }
    }

    func setStyle(_ style: [String: Any]) {
      params.merge(style) { _, new in new }
      applyStyle()
    }

    func select(_ index: Int) {
      guard index >= 0, index < identifiers.count,
        controller.selectedTab?.identifier != identifiers[index],
        let tab = controller.tab(forIdentifier: identifiers[index])
      else { return }
      programmatic = true
      controller.selectedTab = tab
      programmatic = false
    }

    func setBadges(_ badges: [Any]) {
      for (index, tab) in controller.tabs.enumerated() where index < badges.count {
        let value = badges[index] as? String
        if tab.badgeValue != value { tab.badgeValue = value }
      }
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
      if !programmatic, tab.identifier == tabBarController.selectedTab?.identifier,
        let index = identifiers.firstIndex(of: tab.identifier)
      {
        onSelected(index)
      }
      return true
    }

    func tabBarController(
      _ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?
    ) {
      guard !programmatic, let index = identifiers.firstIndex(of: selectedTab.identifier) else {
        return
      }
      onSelected(index)
    }

    private static func image(_ raw: Any?, scale: CGFloat) -> UIImage? {
      guard let data = (raw as? FlutterStandardTypedData)?.data,
        let image = UIImage(data: data, scale: scale)
      else { return nil }
      return image.withRenderingMode(.alwaysTemplate)
    }
  }
#endif

@MainActor
enum LiquidGlassTabBarStyle {
  private static var fonts: [String: String] = [:]

  static func color(_ value: Any?) -> UIColor? {
    guard let argb = (value as? NSNumber)?.uint32Value else { return nil }
    return UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }

  static func font(asset: String?, size: CGFloat) -> UIFont? {
    guard let asset, let name = postScriptName(asset: asset) else { return nil }
    return UIFont(name: name, size: size)
  }

  private static func postScriptName(asset: String) -> String? {
    if let cached = fonts[asset] { return cached }
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil),
      let provider = CGDataProvider(url: URL(fileURLWithPath: path) as CFURL),
      let font = CGFont(provider),
      let name = font.postScriptName as String?
    else { return nil }
    CTFontManagerRegisterGraphicsFont(font, nil)
    fonts[asset] = name
    return name
  }
}
