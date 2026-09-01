//
//  ElegantEmojiPickerView.swift
//  ElegantEmojiPicker
//
//  An embeddable SwiftUI view for the emoji picker.
//

import SwiftUI
import UIKit

/// A SwiftUI view that renders the emoji picker inline, without presenting
/// itself.
///
/// The existing `.emojiPicker` modifier always presents the picker in a
/// `.sheet`. That leaves SwiftUI callers unable to use any other presentation —
/// notably a real iPad `.popover` with an arrow, which the UIKit
/// `ElegantEmojiPicker` supports but only via its `sourceView:` initializer.
///
/// This view solves that by staying presentation-agnostic: it renders the
/// picker and nothing else, so the caller decides how it appears.
///
/// ```swift
/// .popover(isPresented: $showingPicker, arrowEdge: .leading) {
///     ElegantEmojiPickerView(selectedEmoji: $emoji, isPresented: $showingPicker)
///         .frame(width: 420, height: 520)
/// }
/// ```
///
/// Because the picker is embedded rather than presented, it cannot dismiss
/// itself — `UIViewController.dismiss` would either no-op or tear down the
/// host presentation without telling SwiftUI. This view instead suppresses the
/// picker's self-dismissal and drives the caller's `isPresented` binding after
/// a selection.
@available(iOS 14.0, *)
public struct ElegantEmojiPickerView: UIViewControllerRepresentable {

    @Binding private var selectedEmoji: Emoji?
    @Binding private var isPresented: Bool

    private let configuration: ElegantConfiguration
    private let localization: ElegantLocalization
    private let sectionProvider: SectionProvider?
    private let searchProvider: SearchProvider?

    /// Supplies the sections offered by the picker, replacing the defaults.
    public typealias SectionProvider = (ElegantConfiguration, ElegantLocalization) -> [EmojiSection]

    /// Supplies search results for a prompt, replacing the default algorithm.
    public typealias SearchProvider = (String, [EmojiSection]) -> [Emoji]

    /// Create an embeddable emoji picker.
    /// - Parameters:
    ///   - selectedEmoji: Receives the user's selection. Set to nil when the
    ///     user resets their selection.
    ///   - isPresented: Set to false once a selection is made, so a presenting
    ///     container can dismiss. Pass a constant binding when embedding the
    ///     picker permanently.
    ///   - configuration: Configuration controlling UI and behavior.
    ///   - localization: Texts for all on-screen labels.
    ///   - sectionProvider: Optionally provide your own emoji sections. Mirrors
    ///     the `loadEmojiSections` delegate method.
    ///   - searchProvider: Optionally override the search algorithm. Mirrors
    ///     the `searchResultFor` delegate method. Runs on a background thread.
    public init(
        selectedEmoji: Binding<Emoji?>,
        isPresented: Binding<Bool> = .constant(true),
        configuration: ElegantConfiguration = ElegantConfiguration(),
        localization: ElegantLocalization = ElegantLocalization(),
        sectionProvider: SectionProvider? = nil,
        searchProvider: SearchProvider? = nil
    ) {
        self._selectedEmoji = selectedEmoji
        self._isPresented = isPresented
        self.configuration = configuration
        self.localization = localization
        self.sectionProvider = sectionProvider
        self.searchProvider = searchProvider
    }

    public func makeUIViewController(context: Context) -> ElegantEmojiPicker {
        // The picker asks its delegate for sections inside init, so the
        // coordinator has to be wired up as the delegate here rather than after.
        ElegantEmojiPicker(
            delegate: context.coordinator,
            configuration: configuration,
            localization: localization
        )
    }

    public func updateUIViewController(_ uiViewController: ElegantEmojiPicker, context: Context) {
        context.coordinator.parent = self
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, ElegantEmojiPickerDelegate {
        var parent: ElegantEmojiPickerView

        init(_ parent: ElegantEmojiPickerView) {
            self.parent = parent
        }

        public func emojiPicker(_ picker: ElegantEmojiPicker, didSelectEmoji emoji: Emoji?) {
            parent.selectedEmoji = emoji
            parent.isPresented = false
        }

        // The picker is embedded, not presented — it must not try to dismiss
        // itself. The caller's `isPresented` binding above does that instead.
        public func emojiPickerShouldDismissAfterSelection(_ picker: ElegantEmojiPicker) -> Bool {
            false
        }

        public func emojiPicker(
            _ picker: ElegantEmojiPicker,
            loadEmojiSections withConfiguration: ElegantConfiguration,
            _ withLocalization: ElegantLocalization
        ) -> [EmojiSection] {
            guard let sectionProvider = parent.sectionProvider else {
                return ElegantEmojiPicker.getDefaultEmojiSections(
                    config: withConfiguration,
                    localization: withLocalization
                )
            }
            return sectionProvider(withConfiguration, withLocalization)
        }

        public func emojiPicker(
            _ picker: ElegantEmojiPicker,
            searchResultFor prompt: String,
            fromAvailable: [EmojiSection]
        ) -> [Emoji] {
            guard let searchProvider = parent.searchProvider else {
                return ElegantEmojiPicker.getSearchResults(prompt, fromAvailable: fromAvailable)
            }
            return searchProvider(prompt, fromAvailable)
        }
    }
}
