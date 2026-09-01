//
//  UIColor+Extensions.swift
//  Demo
//
//  Created by Grant Oganyan on 3/10/23.
//

import Foundation
import UIKit

extension UIColor {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red, green, blue, alpha)
    }
    
    func lerp (second: UIColor, percentage: CGFloat) -> UIColor {
        return UIColor(red: (1-percentage)*self.components.red + percentage*second.components.red, green: (1-percentage)*self.components.green + percentage*second.components.green, blue: (1-percentage)*self.components.blue + percentage*second.components.blue, alpha: (1-percentage)*self.components.alpha + percentage*second.components.alpha)
    }

    /// A fully opaque variant of this colour nudged toward the foreground, for
    /// surfaces that must read as raised without being see-through.
    ///
    /// Both colours are resolved against `traits` first: `components` reads
    /// through `getRed`, which returns garbage for an unresolved dynamic
    /// colour, so blending `.label` directly would break in dark mode.
    func raised (by amount: CGFloat, for traits: UITraitCollection) -> UIColor {
        let base = resolvedColor(with: traits)
        let foreground = UIColor.label.resolvedColor(with: traits)
        return base.lerp(second: foreground, percentage: amount).withAlphaComponent(1)
    }
}
