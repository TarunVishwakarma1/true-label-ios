import SwiftUI

struct NotFoundScreen: View {
    let barcode: String
    var inSheet: Bool = false
    var onSubmitted: () -> Void

    @State private var contributing = false
    @State private var inviting = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: TL.R.xl, style: .continuous)
                    .fill(TL.warn.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(TL.warn)

                    .symbolEffect(.bounce, value: inviting)
            }
            .appear(0)

            Text("Not in the catalogue yet")
                .font(.displayM)
                .appear(1)
            Text("You can be the first. Point the camera at the pack — front, ingredients, nutrition — and it's read live on your phone.")
                .font(.subheadline)
                .foregroundStyle(TL.fg2)
                .multilineTextAlignment(.center)
                .appear(2)
            Text(barcode)
                .font(.caption.monospaced())
                .foregroundStyle(TL.fg3)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(TL.surface).overlay(Capsule().stroke(TL.line)))
                .appear(3)

            Spacer()
            Button {
                contributing = true
            } label: {
                Label("Add it from the label", systemImage: "camera.fill")
            }
            .buttonStyle(.primary)
            .appear(4)
        }
        .padding(28)
        .toolbar { if inSheet { CloseButton() } }
        .task {

            try? await Task.sleep(for: .milliseconds(900))
            inviting = true
        }
        .fullScreenCover(isPresented: $contributing) {
            ContributeFlow(barcode: barcode) { submitted in
                contributing = false
                if submitted { onSubmitted() }
            }
        }
    }
}
