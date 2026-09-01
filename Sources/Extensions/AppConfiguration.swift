//
//  File.swift
//  
//
//  Created by Grant Oganyan on 3/19/23.
//

import Foundation
import UIKit

class AppConfiguration {
    
    static var deviceType: UIUserInterfaceIdiom { return UIDevice.current.userInterfaceIdiom }
        
    static var isIPad: Bool { return deviceType == .pad }
    static var isIPhone: Bool { return deviceType == .phone }
    static var isMacCatalyst: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }
    
    static var windowFrame: CGRect { return UIApplication.shared.keyWindow?.frame ?? .zero }

}

extension UIApplication {

    /// The key window, found through the connected-scene graph.
    ///
    /// `UIApplication.windows` was deprecated in iOS 15 and returns nothing
    /// useful in a scene-based app; `UIScreen.main` was deprecated in iOS 26
    /// and is wrong on iPad, where a window can be a fraction of the screen.
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
    }

}
