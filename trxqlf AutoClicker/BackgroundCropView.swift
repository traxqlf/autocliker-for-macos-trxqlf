import SwiftUI
import AppKit

/// Recadrage du fond : l'image remplit un cadre au ratio de la fenêtre,
/// l'utilisateur la déplace et zoome, puis on découpe exactement ce cadre.
struct BackgroundCropView: View {
    let image: NSImage
    var onValidate: (NSImage) -> Void
    var onCancel: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    private let cropSize = CGSize(width: 340, height: 379) // ratio 520 × 580

    var body: some View {
        VStack(spacing: 16) {
            Text("Recadre l'image de fond")
                .font(.headline)

            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cropSize.width, height: cropSize.height)
                .scaleEffect(zoom)
                .offset(offset)
                .frame(width: cropSize.width, height: cropSize.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = clamped(CGSize(width: dragStart.width + value.translation.width,
                                                    height: dragStart.height + value.translation.height))
                        }
                        .onEnded { _ in dragStart = offset }
                )

            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $zoom, in: 1...4)
                Image(systemName: "plus.magnifyingglass")
            }

            HStack {
                Button("Annuler", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Utiliser cette image") {
                    if let cropped = croppedImage() { onValidate(cropped) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onChange(of: zoom) { _ in offset = clamped(offset) }
    }

    private var cgImage: CGImage? {
        image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private func clamped(_ proposed: CGSize) -> CGSize {
        guard let cg = cgImage else { return .zero }
        let scale = max(cropSize.width / CGFloat(cg.width), cropSize.height / CGFloat(cg.height)) * zoom
        let maxX = max(0, (CGFloat(cg.width) * scale - cropSize.width) / 2)
        let maxY = max(0, (CGFloat(cg.height) * scale - cropSize.height) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    private func croppedImage() -> NSImage? {
        guard let cg = cgImage else { return nil }
        let scale = max(cropSize.width / CGFloat(cg.width), cropSize.height / CGFloat(cg.height)) * zoom
        let visibleWidth = cropSize.width / scale
        let visibleHeight = cropSize.height / scale
        let x = min(max(CGFloat(cg.width) / 2 - offset.width / scale - visibleWidth / 2, 0),
                    CGFloat(cg.width) - visibleWidth)
        let y = min(max(CGFloat(cg.height) / 2 - offset.height / scale - visibleHeight / 2, 0),
                    CGFloat(cg.height) - visibleHeight)

        let rect = CGRect(x: x, y: y, width: visibleWidth, height: visibleHeight).integral
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
    }
}
