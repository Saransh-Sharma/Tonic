//
//  RecommendationDetailView.swift
//  Tonic
//
//  Detail view for scan recommendations with selectable paths
//

import SwiftUI

// MARK: - Path Detail Model

struct PathDetail: Identifiable, Hashable, Sendable {
    let id = UUID()
    let path: String
    let size: Int64?
    let isDirectory: Bool
    var isExpanded: Bool = false
    var children: [PathDetail]? = nil
    var isLoadingChildren: Bool = false

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    var parentDirectory: String {
        (path as NSString).deletingLastPathComponent
    }

    var formattedSize: String {
        guard let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var displayPath: String {
        if path.hasPrefix(NSHomeDirectory()) {
            return "~" + path.dropFirst(NSHomeDirectory().count)
        }
        return path
    }
}

// MARK: - Recommendation Detail View

struct RecommendationDetailView: View {
    let recommendation: ScanRecommendation
    @Binding var isPresented: Bool
    @State private var pathDetails: [PathDetail] = []
    @State private var selectedItems: Set<String> = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var sizeIndex: [String: Int64] = [:]

    @Environment(\.dismiss) private var dismiss

    private var filteredItems: [PathDetail] {
        if searchText.isEmpty {
            return pathDetails
        }
        return pathDetails.filter { detail in
            detail.fileName.localizedCaseInsensitiveContains(searchText) ||
            detail.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalSelectedSize: Int64 {
        selectedItems.reduce(0) { total, path in
            total + (sizeIndex[path] ?? 0)
        }
    }

    private var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()

            if isLoading {
                loadingView
            } else if filteredItems.isEmpty {
                emptyState
            } else {
                itemsList
            }

            Divider()
            footer
        }
        .frame(width: 650, height: 500)
        .onAppear {
            loadPathDetails()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: recommendation.icon)
                .font(.system(size: 28))
                .foregroundColor(recommendation.color)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.headline)

                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if recommendation.safeToFix {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.caption2)
                    Text("Safe to remove")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(TonicColors.success.opacity(0.15))
                .foregroundColor(TonicColors.success)
                .cornerRadius(6)
            }

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search files and folders...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            Spacer()

            Text("\(selectedItems.count) selected · \(formattedSelectedSize)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading file details...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No results found")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filteredItems) { detail in
                    PathDetailRow(
                        detail: detail,
                        selectedItems: $selectedItems,
                        isTopLevel: true,
                        toggleExpansion: toggleExpansion
                    )

                    if detail.id != filteredItems.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(selectedItems.count == filteredItems.count ? "Deselect All" : "Select All") {
                if selectedItems.count == filteredItems.count {
                    selectedItems.removeAll()
                } else {
                    selectedItems = Set(filteredItems.map { $0.path })
                }
            }
            .buttonStyle(.bordered)
            .disabled(filteredItems.isEmpty)

            Spacer()

            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)

            Button("Apply Selection") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedItems.isEmpty)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func loadPathDetails() {
        isLoading = true

        Task {
            var details: [PathDetail] = []
            var sizes: [String: Int64] = [:]

            for path in recommendation.affectedPaths {
                let detail = await createPathDetail(from: path)
                details.append(detail)
                if let size = detail.size {
                    sizes[detail.path] = size
                }
            }

            details.sort { ($0.size ?? 0) > ($1.size ?? 0) }

            await MainActor.run {
                pathDetails = details
                sizeIndex = sizes
                isLoading = false
            }
        }
    }

    private func createPathDetail(from path: String) async -> PathDetail {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isDirectory = values?.isDirectory ?? false
        let size = isDirectory ? nil : Int64(values?.fileSize ?? 0)

        return PathDetail(
            path: path,
            size: size,
            isDirectory: isDirectory,
            isExpanded: false,
            children: nil,
            isLoadingChildren: false
        )
    }

    private func toggleExpansion(_ detail: PathDetail) {
        guard let index = pathDetails.firstIndex(where: { $0.id == detail.id }) else { return }

        if pathDetails[index].isExpanded {
            pathDetails[index].isExpanded = false
            return
        }

        if pathDetails[index].children != nil {
            pathDetails[index].isExpanded = true
            return
        }

        pathDetails[index].isLoadingChildren = true

        Task {
            let children = await loadChildren(for: detail.path)
            await MainActor.run {
                pathDetails[index].children = children
                pathDetails[index].isLoadingChildren = false
                pathDetails[index].isExpanded = true

                for child in children {
                    if let size = child.size {
                        sizeIndex[child.path] = size
                    }
                }
            }
        }
    }

    private func loadChildren(for path: String) async -> [PathDetail] {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let limited = contents.prefix(100)
        return limited.map { childURL in
            let values = try? childURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDirectory = values?.isDirectory ?? false
            let size = isDirectory ? nil : Int64(values?.fileSize ?? 0)
            return PathDetail(
                path: childURL.path,
                size: size,
                isDirectory: isDirectory,
                isExpanded: false,
                children: nil,
                isLoadingChildren: false
            )
        }
    }
}

// MARK: - Path Detail Row

struct PathDetailRow: View {
    let detail: PathDetail
    @Binding var selectedItems: Set<String>
    let isTopLevel: Bool
    let toggleExpansion: (PathDetail) -> Void

    private var isSelected: Bool {
        selectedItems.contains(detail.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    toggleSelection()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? TonicColors.accent : .secondary)
                }
                .buttonStyle(.plain)

                if detail.isDirectory {
                    if detail.isLoadingChildren {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Button {
                            toggleExpansion(detail)
                        } label: {
                            Image(systemName: detail.isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Spacer()
                        .frame(width: 16)
                }

                Image(systemName: detail.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(detail.isDirectory ? .blue : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.fileName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(detail.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !isTopLevel {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(detail.parentDirectory)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Button {
                    showInFinder()
                } label: {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )

            if detail.isExpanded, let children = detail.children, !children.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(children) { child in
                        PathDetailRow(
                            detail: child,
                            selectedItems: $selectedItems,
                            isTopLevel: false,
                            toggleExpansion: toggleExpansion
                        )
                    }
                }
                .padding(.leading, 24)
            }
        }
    }

    private func toggleSelection() {
        if selectedItems.contains(detail.path) {
            selectedItems.remove(detail.path)
        } else {
            selectedItems.insert(detail.path)
        }
    }

    private func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: detail.path)])
    }
}
