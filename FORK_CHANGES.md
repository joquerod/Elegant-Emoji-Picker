# What's different in this fork

A fork of [Finalet/Elegant-Emoji-Picker](https://github.com/Finalet/Elegant-Emoji-Picker),
branched at [`ceff7eb`](https://github.com/Finalet/Elegant-Emoji-Picker/commit/ceff7eb).
All credit for the library — and for the emoji data that makes it work — goes to
[@GrantOgany](https://twitter.com/GrantOgany).

**Everything here is a general fix.** Nothing is specific to the app this fork
was made for, and each change is written to be upstreamable as-is. If none of it
matters to you, use the original.

## Install

```
https://github.com/joquerod/Elegant-Emoji-Picker
```

| Version | Contains |
| ------- | -------- |
| `1.1.0` | everything below |
| `1.0.0` | everything except the opaque background |

Source divergence from upstream: **6 files under `Sources/`, +317 / −43**.

---

## 1. An embeddable SwiftUI view

**The problem.** The only SwiftUI entry point upstream is the `.emojiPicker`
modifier, and it hard-codes `.sheet`:

```swift
content.sheet(isPresented: $isPresented) { ElegantEmojiPickerRepresentable(...) }
```

So a SwiftUI caller cannot present the picker any other way. That rules out a
real iPad popover with an arrow — even though the UIKit `ElegantEmojiPicker`
supports popovers perfectly well via its `sourceView:` initializer. It also
rules out embedding the picker inline in a larger layout.

**The change.** `ElegantEmojiPickerView` renders the picker and nothing else,
leaving presentation entirely to the caller:

```swift
.popover(isPresented: $showingPicker, arrowEdge: .leading) {
    ElegantEmojiPickerView(selectedEmoji: $emoji, isPresented: $showingPicker)
        .frame(width: 460, height: 400)
}
```

It also surfaces two delegate hooks that UIKit callers already had but SwiftUI
callers didn't — supplying your own sections, and overriding search:

```swift
ElegantEmojiPickerView(
    selectedEmoji: $emoji,
    isPresented: $showingPicker,
    configuration: ElegantConfiguration(showRandom: false),
    sectionProvider: { config, localization in
        [myCuratedSection] + ElegantEmojiPicker.getDefaultEmojiSections(
            config: config, localization: localization
        )
    },
    searchProvider: { prompt, sections in
        myOwnSearch(prompt, sections)
    }
)
```

The existing `.emojiPicker` sheet modifier is untouched — this is purely
additive.

## 2. An embedded picker no longer configures a presentation it doesn't own

**The problem.** `ElegantEmojiPicker.init` unconditionally does:

```swift
self.modalPresentationStyle = .formSheet   // or .popover
self.presentationController?.delegate = self
```

That's right when the picker presents itself. But when it is a *child* view
controller — the content of a SwiftUI `.popover` or `.sheet` — its
`presentationController` belongs to the **container**, so the picker reaches
past itself and reconfigures the presentation that is hosting it.

**The change.** A `configuresOwnPresentation` parameter, defaulting to `true`
so existing callers are unaffected. `ElegantEmojiPickerView` passes `false`,
which also skips the light-mode scrim — that tint exists to dim whatever sits
behind a modal, and embedded there's nothing behind it to dim.

Two related details the embedded path needs: the picker can't dismiss itself
(`UIViewController.dismiss` on a child either no-ops or tears down the host's
presentation without telling SwiftUI), so the coordinator returns `false` from
`emojiPickerShouldDismissAfterSelection` and drives the caller's `isPresented`
binding instead.

> This one is correctness by construction rather than a fix for an observed
> crash — the embedded picker did render before the change.

## 3. Multi-word search, and de-duplicated results

**The problem — search.** `getSearchResults` matched the whole prompt as a
single substring against each alias, tag and description:

```swift
$0.description.localizedCaseInsensitiveContains(cleanSearchTerm)
```

So any multi-word query found nothing unless that exact run of characters
appeared in one field. `"red car"` → nothing. `"walk dog"` → nothing.

**The problem — duplicates.** Results were appended per section with no
de-duplication, so an emoji present in two sections came back twice. That's
guaranteed for anyone supplying a curated section alongside the standard
categories: 🧹 lives in both your section and *Objects*.

**The change.** Each word is now matched independently and an emoji must
satisfy all of them, via a new `Emoji.matchesSearchTerm(_:)` that keeps the
existing aliases → tags → description priority. Results are de-duplicated
keyed on **the glyph**, not on `Emoji` equality — `getDefaultEmojiSections`
applies persisted skin tones via `duplicate(_:)`, so two instances of the same
emoji can compare unequal.

```swift
// before → []          after → 🚗 🚙 🏎 …
ElegantEmojiPicker.getSearchResults("red car", fromAvailable: sections)
```

> **Worth knowing if you rely on search:** even fixed, the bundled dataset is
> thin on synonyms — **75% of its ~1,900 emoji have an empty `tags` array**
> (0.36 tags each on average), so search is close to "match the Unicode name".
> `"teeth"` will not find 🪥 (`toothbrush`), `"laundry"` will not find 🧺
> (`basket`). If your users search in everyday language, plan to supply your
> own vocabulary through `searchProvider` / the `searchResultFor` delegate
> method. That layer is domain-specific, so it deliberately lives in the app,
> not here.

## 4. An optional opaque background

**The problem.** The picker is translucent by design — a blur behind the grid,
blur/glass behind the search field and the sections toolbar. On iOS 26 the
backdrop blur is skipped entirely:

```swift
if #unavailable(iOS 26.0) { /* add the blur */ }
```

on the assumption that the system paints a material behind the sheet presenting
it. A picker embedded in a container that paints nothing — a SwiftUI `.popover`
— therefore has **no background at all**, and whatever is behind it shows
straight through.

**The change.** `ElegantConfiguration.backgroundColor`. When set, the picker
paints that color, skips the backdrop blur, and fills its search field and
toolbar with opaque blends of it:

```swift
ElegantConfiguration(backgroundColor: .systemBackground)
```

The toolbar matters specifically because it floats *over* the grid — glass
there shows the emoji scrolling underneath it. The blends are re-resolved in
`traitCollectionDidChange` so a light/dark switch repaints them. Default `nil`
keeps the current translucent appearance.

## 5. Replacements for deprecated APIs

`AppConfiguration.windowFrame` reached the key window through
`UIApplication.windows` — deprecated in iOS 15, and empty in a scene-based app
— then fell back to `UIScreen.main.bounds`, deprecated in iOS 26 and wrong on
iPad, where a window is often a fraction of the screen. Both are now a
connected-scene lookup.

`traitCollectionDidChange` read `UIScreen.main.traitCollection` to choose the
scrim color; it now reads the view controller's own `traitCollection`, which is
what it meant.

---

## Upstreaming

**No upstream PR has been opened yet** — this fork exists first, and the changes
may be offered back later. They were written to be upstreamable regardless: each
is self-contained, none is app-specific, and every new option defaults to the
existing behaviour so nothing breaks for current callers.

If you're reading this because you hit one of these problems, the best outcome
is that it lands upstream and this fork stops being necessary. Feel free to open
an issue or PR upstream pointing at any of it — no permission needed, it's MIT.

## License

MIT, unchanged from upstream. See [LICENSE](LICENSE).
