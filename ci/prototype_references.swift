// Renders the approved prototype (design/prototipo.html) in the macOS WebKit, the engine of Safari, where
// the system font is the real SF Pro: one image for each entry of ci/prototype-references.json, the size of
// the CI screenshots, to compare them with. Used only by the manual workflow "Referências do protótipo"
// (.github/workflows/prototype-references.yml); it is not part of the app and needs nothing but macOS.
//
// The page is 402 points wide and as tall as the screen below the top safe area: the image starts there, on
// a black status bar area, as the screenshots are compared. The prototype file is never changed: the copy
// that is loaded is read as UTF-8, gets the iPhone 17 safe areas in place of env() (0 at the top, since the
// image already starts below it, and 34 at the bottom), has no browser margin around the page (as in the
// artifact viewer), hides the prototype's notes and test buttons, and has no animations, so an image never
// catches a movement halfway. The page has no access to the network.
//
// Usage: prototype-references <prototype.html> <references.json> <output folder> [name filter]

import AppKit
import ImageIO
import UniformTypeIdentifiers
import WebKit

/// What is added to the copy of the prototype that is loaded. The prototype is made for the artifact
/// viewer, which shows it without the browser's default margin of 8 around the page: without it here too,
/// the screens start at the edge, with the 16 of their own margins, as on the phone.
private let injectedStyle = """
<style>
html, body { margin: 0 !important; }
.foot, .vn-note, .vn-sheet-toggle, .desk-hint { display: none !important; }
*, *::before, *::after { animation: none !important; transition: none !important; caret-color: transparent !important; }
button:focus-visible, input:focus-visible { outline: none !important; }
::-webkit-scrollbar { display: none !important; width: 0 !important; height: 0 !important; }
</style>
"""

/// One step, as a person would do it: a tap on a button, text typed in a field, a scroll. Returns "ok" or
/// what went wrong. It runs in the page, with the step from the JSON as `step`.
private let stepScript = """
const one = (selector, index) => document.querySelectorAll(selector)[index || 0];
const s = step;
if (s.click) {
  const e = one(s.click, s.index);
  if (!e) return 'not found: ' + s.click + (s.index ? ' [' + s.index + ']' : '');
  if (e.disabled) return 'disabled: ' + s.click;
  e.click();
} else if (s.reveal) {
  const e = one(s.reveal);
  if (!e) return 'not found: ' + s.reveal;
  e.scrollIntoView({ block: 'nearest', inline: 'center' });
} else if (s.focus) {
  const e = one(s.focus);
  if (!e) return 'not found: ' + s.focus;
  e.focus();
} else if (s.type) {
  const e = one(s.type[0]);
  if (!e) return 'not found: ' + s.type[0];
  e.value = s.type[1];
  e.dispatchEvent(new Event('input', { bubbles: true }));
} else if (s.select) {
  const e = one(s.select[0]);
  if (!e) return 'not found: ' + s.select[0];
  e.value = s.select[1];
  e.dispatchEvent(new Event('change', { bubbles: true }));
} else if (s.scroll !== undefined) {
  window.scrollTo(0, s.scroll === 'bottom' ? document.documentElement.scrollHeight : s.scroll);
} else if (s.scrollIn) {
  const e = one(s.scrollIn[0]);
  if (!e) return 'not found: ' + s.scrollIn[0];
  e.scrollTop = s.scrollIn[1] === 'bottom' ? e.scrollHeight : s.scrollIn[1];
} else if (s.wait === undefined) {
  return 'unknown step: ' + JSON.stringify(s);
}
return 'ok';
"""

private struct RenderError: Error, CustomStringConvertible {
    let description: String
}

/// The screen the images stand for, from the JSON.
private struct Screen {
    let width: Double
    let height: Double
    let safeTop: Double
    let safeBottom: Double
    let scale: Double

    init(_ json: [String: Any]) throws {
        func value(_ key: String) throws -> Double {
            guard let number = json[key] as? NSNumber else { throw RenderError(description: "screen.\(key) missing") }
            return number.doubleValue
        }
        width = try value("width")
        height = try value("height")
        safeTop = try value("safeTop")
        safeBottom = try value("safeBottom")
        scale = try value("scale")
    }
}

/// Resumes when a page has finished loading.
@MainActor
private final class LoadWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func wait(for load: () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            load()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

@MainActor
private struct Renderer {
    let page: URL
    let screen: Screen
    let sequences: [String: [[String: Any]]]
    let stepWait: Double
    let finalWait: Double
    let output: URL
    let blockNetwork: WKContentRuleList

    /// The steps with each "do" replaced by the steps of its sequence.
    func expand(_ steps: [[String: Any]]) throws -> [[String: Any]] {
        try steps.flatMap { step -> [[String: Any]] in
            guard let name = step["do"] as? String else { return [step] }
            guard let sequence = sequences[name] else { throw RenderError(description: "unknown sequence \(name)") }
            return try expand(sequence)
        }
    }

    func render(name: String, url fragment: String, steps: [[String: Any]]) async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(blockNetwork)
        configuration.websiteDataStore = .nonPersistent()
        let viewSize = NSSize(width: screen.width, height: screen.height - screen.safeTop)
        let webView = WKWebView(frame: NSRect(origin: .zero, size: viewSize), configuration: configuration)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: viewSize), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        // On screen, so WebKit draws it as it would draw a visible page.
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        let waiter = LoadWaiter()
        webView.navigationDelegate = waiter
        guard let address = URL(string: page.lastPathComponent + fragment, relativeTo: page.deletingLastPathComponent()) else {
            throw RenderError(description: "bad url \(fragment)")
        }
        try await waiter.wait {
            webView.loadFileURL(address.absoluteURL, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        try await Task.sleep(for: .milliseconds(400))

        for step in try expand(steps) {
            let result: Any? = try await withCheckedThrowingContinuation { continuation in
                webView.callAsyncJavaScript(stepScript, arguments: ["step": step], in: nil, in: .page) { result in
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            guard let text = result as? String, text == "ok" else {
                throw RenderError(description: "\(name): \(String(describing: result))")
            }
            let wait = (step["wait"] as? NSNumber)?.doubleValue ?? 0
            try await Task.sleep(for: .milliseconds(Int(wait + stepWait)))
        }
        try await Task.sleep(for: .milliseconds(Int(finalWait)))

        let snapshot = WKSnapshotConfiguration()
        snapshot.rect = webView.bounds
        // Drawn by WebKit at this width, three pixels for each point, not enlarged afterwards.
        snapshot.snapshotWidth = NSNumber(value: screen.width * screen.scale)
        snapshot.afterScreenUpdates = true
        let image: NSImage = try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: snapshot) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? RenderError(description: "\(name): no snapshot"))
                }
            }
        }
        try save(image, as: output.appendingPathComponent(name + ".png"))
    }

    /// The page below the top safe area of a black screen of the size of the screenshots, in sRGB.
    func save(_ image: NSImage, as file: URL) throws {
        let width = Int(screen.width * screen.scale)
        let height = Int(screen.height * screen.scale)
        let pageHeight = Int((screen.height - screen.safeTop) * screen.scale)
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let page = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw RenderError(description: "could not draw \(file.lastPathComponent)") }
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        // Core Graphics counts from the bottom: the page fills everything below the top safe area.
        context.draw(page, in: CGRect(x: 0, y: 0, width: width, height: pageHeight))
        guard
            let result = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw RenderError(description: "could not save \(file.lastPathComponent)") }
        CGImageDestinationAddImage(destination, result, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError(description: "could not save \(file.lastPathComponent)") }
        print("\(file.lastPathComponent): page \(page.width)×\(page.height) px")
    }
}

@MainActor
private func run(arguments: [String]) async -> Int32 {
    guard arguments.count >= 4 else {
        print("Usage: prototype-references <prototype.html> <references.json> <output folder> [name filter]")
        return 2
    }
    do {
        let prototype = URL(fileURLWithPath: arguments[1])
        let output = URL(fileURLWithPath: arguments[3], isDirectory: true)
        let filter = arguments.count > 4 ? arguments[4] : nil
        guard let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: arguments[2]))) as? [String: Any],
              let screenJSON = json["screen"] as? [String: Any],
              let references = json["references"] as? [[String: Any]]
        else { throw RenderError(description: "references.json is not as expected") }
        let screen = try Screen(screenJSON)

        // The copy that is loaded: the iPhone 17 safe areas in place of env(), and the style above.
        var html = try String(contentsOf: prototype, encoding: .utf8)
        let insets = [
            ("env(safe-area-inset-top, 0px)", "0px"),
            ("env(safe-area-inset-bottom, 0px)", "\(Int(screen.safeBottom))px"),
            ("env(safe-area-inset-left, 0px)", "0px"),
            ("env(safe-area-inset-right, 0px)", "0px"),
        ]
        for (inset, value) in insets {
            html = html.replacingOccurrences(of: inset, with: value)
        }
        if html.contains("env(") {
            throw RenderError(description: "the prototype uses an env() value this renderer does not set")
        }
        guard let styleEnd = html.range(of: "</style>") else { throw RenderError(description: "no <style> in the prototype") }
        html.replaceSubrange(styleEnd, with: "</style>\n" + injectedStyle)
        // The prototype does not name its encoding (it is served as UTF-8); a file without it would be read
        // as Latin-1, which breaks its text and its script.
        if !html.lowercased().contains("<meta charset") {
            html = "<meta charset=\"utf-8\">\n" + html
        }
        // Nor does it start with a doctype: the artifact viewer shows it in standards mode, and without one
        // WebKit would lay it out in quirks mode (lines with only small inline text come out shorter).
        if !html.lowercased().hasPrefix("<!doctype") {
            html = "<!DOCTYPE html>\n" + html
        }

        let work = output.appendingPathComponent(".pagina", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let page = work.appendingPathComponent("prototipo.html")
        try html.write(to: page, atomically: true, encoding: .utf8)

        let rules = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
        let blockNetwork: WKContentRuleList = try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "sem-rede", encodedContentRuleList: rules) { list, error in
                if let list {
                    continuation.resume(returning: list)
                } else {
                    continuation.resume(throwing: error ?? RenderError(description: "could not block the network"))
                }
            }
        }

        let renderer = Renderer(
            page: page,
            screen: screen,
            sequences: json["sequences"] as? [String: [[String: Any]]] ?? [:],
            stepWait: (json["stepWait"] as? NSNumber)?.doubleValue ?? 300,
            finalWait: (json["finalWait"] as? NSNumber)?.doubleValue ?? 500,
            output: output,
            blockNetwork: blockNetwork
        )
        var failures: [String] = []
        for reference in references {
            guard let name = reference["name"] as? String else { throw RenderError(description: "a reference has no name") }
            if let filter, !name.contains(filter) { continue }
            do {
                try await renderer.render(
                    name: name,
                    url: reference["url"] as? String ?? "",
                    steps: reference["steps"] as? [[String: Any]] ?? []
                )
            } catch {
                print("::error::\(name): \(error)")
                failures.append(name)
            }
        }
        try? FileManager.default.removeItem(at: work)
        if !failures.isEmpty {
            print("Failed: \(failures.joined(separator: ", "))")
            return 1
        }
        return 0
    } catch {
        print("::error::\(error)")
        return 1
    }
}

@main
enum PrototypeReferences {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let arguments = CommandLine.arguments
        Task { @MainActor in
            exit(await run(arguments: arguments))
        }
        app.run()
    }
}
