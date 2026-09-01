//
//  AboutDisclosure.swift
//  Chisme
//
//  A reusable "About" disclosure triangle that reveals a short description
//  of what a tab does. Clicking the triangle/label expands or collapses it.
//

import SwiftUI

struct AboutDisclosure: View {
    let title: String
    let description: String
    @State private var isExpanded: Bool = false

    init(title: String = "About", description: String) {
        self.title = title
        self.description = description
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(description)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.horizontal, 2)
        } label: {
            Label(title, systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
                .contentShape(Rectangle())
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    AboutDisclosure(description: "This is an example description explaining what a tab does.")
        .padding()
        .frame(width: 480)
}
