//
//  ImageLightboxView.swift
//  truelable
//
//  Full-screen viewer for a product's photo(s). The API only ever returns
//  one image today, but this takes an array and pages with a native
//  TabView — so a second/third photo (ingredients, nutrition) slots in
//  later without touching this file. No custom drag-to-dismiss: layering
//  our own DragGesture over TabView's own paging gesture is exactly the
//  swipe-conflict bug already fixed once in VerifyView. Tap the image or
//  the close button instead.
//

import SwiftUI

struct ImageLightboxView: View {
    let urls: [URL]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(urls: [URL], startIndex: Int = 0) {
        self.urls = urls
        self.startIndex = startIndex
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { i, url in
                    CachedAsyncImage(url: url) { image in
                        if let image {
                            image.resizable()
                                .scaledToFit()
                                .padding(24)
                                .contentShape(Rectangle())
                                .onTapGesture { dismiss() }
                        } else {
                            ProgressView().tint(TL.fg2)
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TL.fg)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .statusBarHidden()
    }
}

#Preview {
    ImageLightboxView(urls: [URL(string: "https://images.openfoodfacts.org/images/products/611/124/210/0992/front_fr.172.400.jpg")!])
}
