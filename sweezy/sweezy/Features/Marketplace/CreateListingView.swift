import PhotosUI
import SwiftUI
import UIKit

struct CreateListingView: View {
    var listingType: ListingType = .service
    var onCreated: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title = ""
    @State private var description = ""
    @State private var category: ServiceCategory = .other
    @State private var itemCategory: ItemCategory = .other
    @State private var canton = APIClient.subdivisionCode
    @State private var priceInfo = ""
    @State private var priceText = ""
    @State private var isFreeItem = false
    @State private var condition: ItemCondition = .used
    @State private var negotiable = false
    @State private var contactType: ContactType = .telegram
    @State private var contactValue = ""
    @State private var authorName = ""

    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showMyListings = false
    @State private var showCantonPicker = false
    @State private var errorMessage: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [SelectedListingImage] = []

    @State private var suggestedCategory: ServiceCategory?
    @State private var categorySuggestionVisible = false

    @FocusState private var focusedField: FormField?

    private let maxImages = 6

    private enum FormField: Hashable {
        case title, description, price, contact, author
    }

    private var isValid: Bool {
        let base = !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        description.trimmingCharacters(in: .whitespaces).count >= 20 &&
        !contactValue.trimmingCharacters(in: .whitespaces).isEmpty &&
        !authorName.trimmingCharacters(in: .whitespaces).isEmpty
        guard listingType == .item else { return base }
        return base && (isFreeItem || parsedPrice != nil)
    }

    private var parsedPrice: Int? {
        guard let value = Int(priceText.trimmingCharacters(in: .whitespaces)), value >= 0 else { return nil }
        return value
    }

    private var currencyCode: String { APIClient.countryCode == "CH" ? "CHF" : "EUR" }
    private var country: ResidenceCountry { ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland }

    private var hasAbout: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && description.trimmingCharacters(in: .whitespaces).count >= 20
    }
    private var hasPrice: Bool { listingType == .service || isFreeItem || parsedPrice != nil }
    private var hasContact: Bool {
        !contactValue.trimmingCharacters(in: .whitespaces).isEmpty && !authorName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var hasCategory: Bool { listingType == .item ? itemCategory != .other : category != .other }

    /// Required steps only; photos and category stay optional.
    private var progress: (done: Int, total: Int) {
        let steps = [hasAbout, hasPrice, hasContact]
        return (steps.filter { $0 }.count, steps.count)
    }

    private var missingHint: String {
        var missing: [String] = []
        if title.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("marketplace.field.title".localized) }
        if description.trimmingCharacters(in: .whitespaces).count < 20 { missing.append("marketplace.field.description".localized) }
        if !hasPrice { missing.append("marketplace.field.price".localized) }
        if contactValue.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("marketplace.field.contact".localized) }
        if authorName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("marketplace.field.author".localized) }
        return "marketplace.create.missing".localized(with: missing.joined(separator: ", ").lowercased())
    }

    private var previewPrice: String {
        if listingType == .item {
            if isFreeItem { return "marketplace.free".localized }
            if let parsedPrice { return "\(currencyCode) \(parsedPrice)" }
            return "\(currencyCode) —"
        }
        let trimmed = priceInfo.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "marketplace.create.price_on_request".localized : trimmed
    }

    private var previewCategory: (title: String, icon: String) {
        listingType == .item ? (itemCategory.displayName, itemCategory.icon) : (category.displayName, category.icon)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                JourneyVisual.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header
                        previewCard
                        stepCard(1, title: "marketplace.field.photos".localized, icon: "photo.on.rectangle.angled", done: !selectedImages.isEmpty, optional: true) {
                            photosContent
                        }
                        stepCard(2, title: "marketplace.step.about".localized, icon: "text.alignleft", done: hasAbout) {
                            titleField
                            descriptionField
                        }
                        stepCard(3, title: "marketplace.field.category".localized, icon: "tag.fill", done: hasCategory) {
                            categoryGrid
                        }
                        stepCard(4, title: "marketplace.field.price".localized, icon: "banknote.fill", done: hasPrice && (listingType == .item || !priceInfo.isEmpty), optional: listingType == .service) {
                            if listingType == .item { itemPriceContent } else { servicePriceField }
                        }
                        stepCard(5, title: country.subdivisionTitle, icon: "mappin.and.ellipse", done: true) {
                            cantonButton
                        }
                        stepCard(6, title: "marketplace.field.contact".localized, icon: "bubble.left.fill", done: hasContact) {
                            contactContent
                            authorField
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 132)
                }
                .scrollDismissesKeyboard(.interactively)

                publishBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSuccess) { successSheet }
            .sheet(isPresented: $showMyListings) { MyListingsView() }
            .sheet(isPresented: $showCantonPicker) {
                CantonPickerSheet(selectedCanton: $canton, country: country)
            }
            .onChange(of: selectedPhotoItems.map(\.itemIdentifier)) { _, _ in
                Task { await appendSelectedPhotos(from: selectedPhotoItems) }
            }
            .alert("marketplace.error_title".localized, isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("common.ok".localized) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Header & preview

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.card, in: Circle())
                    .overlay(Circle().stroke(JourneyVisual.softBorder))
            }
            .accessibilityLabel("common.cancel".localized)

            VStack(alignment: .leading, spacing: 1) {
                Text(listingType == .item ? "marketplace.create_item_title".localized : "marketplace.create_title".localized)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("marketplace.create.progress".localized(with: progress.done, progress.total))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)
            }

            Spacer(minLength: 8)

            Button { showMyListings = true } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.card, in: Circle())
                    .overlay(Circle().stroke(JourneyVisual.softBorder))
            }
            .accessibilityLabel("marketplace.my_listings".localized)
        }
        .padding(.top, 8)
    }

    /// How the listing will look in the feed, updated while the form is filled.
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("marketplace.create.preview".localized.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.2)
                    .foregroundColor(JourneyVisual.accentText)
                Spacer()
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(JourneyVisual.softSurface)
                        Capsule().fill(JourneyVisual.lime)
                            .frame(width: proxy.size.width * CGFloat(progress.done) / CGFloat(max(progress.total, 1)))
                    }
                }
                .frame(width: 84, height: 6)
                .animation(.easeOut(duration: 0.25), value: progress.done)
            }

            HStack(spacing: 14) {
                ZStack {
                    if let first = selectedImages.first {
                        Image(uiImage: first.image).resizable().scaledToFill()
                    } else {
                        JourneyVisual.softSurface
                        Image(systemName: previewCategory.icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(JourneyVisual.accentStrong)
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Label(previewCategory.title, systemImage: previewCategory.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(JourneyVisual.accentText)
                        .lineLimit(1)
                    Text(title.isEmpty ? "marketplace.create.preview_title".localized : title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(title.isEmpty ? JourneyVisual.secondaryText : JourneyVisual.primaryText)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(previewPrice)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(JourneyVisual.lime, in: Capsule())
                        Label(canton == "all" ? country.flag : canton, systemImage: "mappin")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JourneyVisual.lime.opacity(0.55), lineWidth: 1.5))
        .animation(.easeOut(duration: 0.2), value: title)
        .animation(.easeOut(duration: 0.2), value: selectedImages.count)
    }

    // MARK: - Steps

    private func stepCard<Content: View>(
        _ number: Int, title: String, icon: String, done: Bool, optional: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(done ? JourneyVisual.lime : JourneyVisual.softSurface)
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .black)).foregroundColor(.black)
                    } else {
                        Text("\(number)").font(.system(size: 13, weight: .black)).foregroundColor(JourneyVisual.primaryText)
                    }
                }
                .frame(width: 28, height: 28)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: done)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                if optional {
                    Text("marketplace.optional".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(JourneyVisual.softSurface, in: Capsule())
                }
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            content()
        }
        .padding(16)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }

    // MARK: - Photos

    private var photosContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedImages.isEmpty {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: maxImages, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 54, height: 54)
                            .background(JourneyVisual.lime, in: Circle())
                        Text("marketplace.photos_placeholder".localized(with: maxImages))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(JourneyVisual.primaryText)
                        Text("marketplace.photos_hint".localized)
                            .font(.caption)
                            .foregroundColor(JourneyVisual.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 12)
                    .background(JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(JourneyVisual.accentStrong.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedImages.enumerated()), id: \.element.id) { index, image in
                            photoThumbnail(image, isCover: index == 0)
                        }
                        if selectedImages.count < maxImages {
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: maxImages - selectedImages.count,
                                matching: .images
                            ) {
                                VStack(spacing: 6) {
                                    Image(systemName: "plus").font(.system(size: 20, weight: .bold))
                                    Text("\(selectedImages.count)/\(maxImages)").font(.caption.weight(.bold))
                                }
                                .foregroundColor(JourneyVisual.accentText)
                                .frame(width: 104, height: 104)
                                .background(JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(JourneyVisual.accentStrong.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private func photoThumbnail(_ image: SelectedListingImage, isCover: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image.image)
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if isCover {
                        Text("marketplace.photo_cover".localized)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .frame(height: 18)
                            .background(JourneyVisual.lime, in: Capsule())
                            .padding(6)
                    }
                }

            Button {
                removeSelectedImage(image)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white, Color.black.opacity(0.55))
                    .padding(5)
            }
            .accessibilityLabel("marketplace.photo_remove".localized)
        }
    }

    // MARK: - About

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldCaption("marketplace.field.title".localized, counter: "\(title.count)/100", warn: title.count > 90)
            TextField("marketplace.field.title_placeholder".localized, text: $title)
                .focused($focusedField, equals: .title)
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(fieldBackground)
                .overlay(fieldBorder(.title))
                .onChange(of: title) { _, newValue in
                    if newValue.count > 100 { title = String(newValue.prefix(100)) }
                    updateCategorySuggestion(for: newValue)
                }
            if let suggested = suggestedCategory, categorySuggestionVisible, suggested != category {
                suggestedCategoryBadge(suggested)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: categorySuggestionVisible)
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldCaption("marketplace.field.description".localized, counter: "\(description.count)/1000", warn: description.count > 950)
            TextEditor(text: $description)
                .focused($focusedField, equals: .description)
                .font(.body)
                .frame(minHeight: 110, maxHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(fieldBackground)
                .overlay(fieldBorder(.description))
                .onChange(of: description) { _, newValue in
                    if newValue.count > 1000 { description = String(newValue.prefix(1000)) }
                }
            if description.count < 20 && !description.isEmpty {
                Label("marketplace.field.description_min".localized, systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.warning)
            }
        }
    }

    // MARK: - Category

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            if listingType == .item {
                ForEach(ItemCategory.allCases) { cat in
                    categoryChip(title: cat.displayName, icon: cat.icon, selected: itemCategory == cat, suggested: false) {
                        itemCategory = cat
                        if cat == .free { isFreeItem = true }
                    }
                }
            } else {
                ForEach(ServiceCategory.allCases) { cat in
                    categoryChip(
                        title: cat.displayName, icon: cat.icon, selected: category == cat,
                        suggested: suggestedCategory == cat && categorySuggestionVisible && category != cat
                    ) {
                        category = cat
                        if suggestedCategory == cat { categorySuggestionVisible = false }
                    }
                }
            }
        }
    }

    private func categoryChip(title: String, icon: String, selected: Bool, suggested: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if suggested {
                    Image(systemName: "sparkle").font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(selected ? .black : JourneyVisual.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(selected ? JourneyVisual.lime : JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(suggested ? JourneyVisual.accentStrong.opacity(0.6) : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Price

    private var itemPriceContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                segment("marketplace.create.sell".localized, icon: "banknote", selected: !isFreeItem) { isFreeItem = false }
                segment("marketplace.field.give_away".localized, icon: "gift.fill", selected: isFreeItem) { isFreeItem = true }
            }

            if !isFreeItem {
                HStack(spacing: 10) {
                    Text(currencyCode)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(JourneyVisual.accentText)
                    TextField("marketplace.field.item_price_placeholder".localized, text: $priceText)
                        .focused($focusedField, equals: .price)
                        .font(.system(size: 22, weight: .bold))
                        .keyboardType(.numberPad)
                        .onChange(of: priceText) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            if digits != newValue { priceText = digits }
                            if digits.count > 7 { priceText = String(digits.prefix(7)) }
                        }
                }
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(fieldBackground)
                .overlay(fieldBorder(.price))

                Toggle(isOn: $negotiable) {
                    Text("marketplace.field.negotiable".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(JourneyVisual.primaryText)
                }
                .tint(JourneyVisual.accentStrong)
            }

            fieldCaption("marketplace.field.condition".localized)
            HStack(spacing: 8) {
                ForEach(ItemCondition.allCases) { cond in
                    segment(cond.displayName, icon: nil, selected: condition == cond) { condition = cond }
                }
            }
        }
    }

    private var servicePriceField: some View {
        HStack(spacing: 10) {
            Text(currencyCode)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(JourneyVisual.accentText)
            TextField("marketplace.field.price_placeholder".localized, text: $priceInfo)
                .focused($focusedField, equals: .price)
                .font(.body.weight(.medium))
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(fieldBackground)
        .overlay(fieldBorder(.price))
    }

    // MARK: - Location

    private var cantonButton: some View {
        Button {
            showCantonPicker = true
        } label: {
            HStack(spacing: 12) {
                Text(canton == "all" ? country.flag : canton)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(JourneyVisual.lime, in: Circle())
                Text(CountryCatalog.subdivisionName(country: country, code: canton))
                    .font(.body.weight(.semibold))
                    .foregroundColor(JourneyVisual.primaryText)
                Spacer()
                Text("common.change".localized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(JourneyVisual.accentText)
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .background(fieldBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contact

    private var contactContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(ContactType.allCases) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { contactType = type }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: type.icon).font(.system(size: 15, weight: .semibold))
                            Text(type.displayName)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundColor(contactType == type ? .black : JourneyVisual.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(contactType == type ? JourneyVisual.lime : JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
                    .accessibilityAddTraits(contactType == type ? .isSelected : [])
                }
            }

            HStack(spacing: 10) {
                Image(systemName: contactType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(JourneyVisual.accentStrong)
                    .frame(width: 20)
                TextField(contactType.placeholder, text: $contactValue)
                    .focused($focusedField, equals: .contact)
                    .font(.body.weight(.medium))
                    .keyboardType(contactType == .email ? .emailAddress : contactType == .telegram ? .default : .phonePad)
                    .textContentType(contactType == .email ? .emailAddress : contactType == .phone ? .telephoneNumber : nil)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(fieldBackground)
            .overlay(fieldBorder(.contact))
        }
    }

    private var authorField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldCaption("marketplace.field.author".localized)
            HStack(spacing: 10) {
                Text(authorName.isEmpty ? "?" : String(authorName.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                    .background(JourneyVisual.lime, in: Circle())
                TextField("marketplace.field.author_placeholder".localized, text: $authorName)
                    .focused($focusedField, equals: .author)
                    .font(.body.weight(.medium))
                    .textContentType(.name)
            }
            .padding(.horizontal, 10)
            .frame(height: 50)
            .background(fieldBackground)
            .overlay(fieldBorder(.author))
        }
    }

    // MARK: - Publish

    private var publishBar: some View {
        VStack(spacing: 8) {
            if !isValid {
                Text(missingHint)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .transition(.opacity)
            }
            Button {
                focusedField = nil
                Task { await submit() }
            } label: {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView().tint(.black)
                        Text(selectedImages.isEmpty ? "marketplace.submit".localized : "marketplace.photos_uploading".localized)
                    } else {
                        Text("marketplace.submit".localized)
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.headline)
                .foregroundColor(isValid ? .black : JourneyVisual.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isValid ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
                .shadow(color: isValid ? JourneyVisual.lime.opacity(0.35) : .clear, radius: 14, y: 6)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
            .disabled(!isValid || isSubmitting)
            .accessibilityIdentifier("marketplace.create.submit")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            JourneyVisual.pageBackground
                .opacity(0.96)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.06), radius: 10, y: -4)
        )
        .animation(.easeOut(duration: 0.2), value: isValid)
    }

    // MARK: - Success Sheet

    private var successSheet: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.black)
                .frame(width: 88, height: 88)
                .background(JourneyVisual.lime, in: Circle())
                .shadow(color: JourneyVisual.lime.opacity(0.45), radius: 20, y: 8)
            Text("marketplace.success_title".localized)
                .font(.title2.bold())
                .foregroundColor(JourneyVisual.primaryText)
            Text("marketplace.success_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(JourneyVisual.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                showSuccess = false
                dismiss()
            } label: {
                Text("common.ok".localized)
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(JourneyVisual.lime, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(JourneyVisual.pageBackground)
        .presentationDetents([.medium])
    }

    // MARK: - Shared Components

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035))
    }

    private func fieldBorder(_ field: FormField) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(focusedField == field ? JourneyVisual.accentStrong : Color.clear, lineWidth: 1.5)
            .animation(.easeOut(duration: 0.15), value: focusedField)
    }

    private func fieldCaption(_ text: String, counter: String? = nil, warn: Bool = false) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(JourneyVisual.secondaryText)
            Spacer()
            if let counter {
                Text(counter)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(warn ? Theme.Colors.error : JourneyVisual.secondaryText)
            }
        }
    }

    private func segment(_ title: String, icon: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundColor(selected ? .black : JourneyVisual.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(selected ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func suggestedCategoryBadge(_ cat: ServiceCategory) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                category = cat
                categorySuggestionVisible = false
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkle").font(.system(size: 9, weight: .bold))
                Text("marketplace.create.suggested".localized(with: cat.displayName))
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(JourneyVisual.lime.opacity(0.35), in: Capsule())
            .foregroundColor(JourneyVisual.primaryText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Auto-Suggest Category

    private func updateCategorySuggestion(for text: String) {
        guard listingType == .service else { return }
        let lower = text.lowercased()
        guard lower.count >= 3 else {
            withAnimation { categorySuggestionVisible = false }
            return
        }

        let mapping: [(keywords: [String], category: ServiceCategory)] = [
            (["переклад", "translat", "übersetzu", "dolmetsch", "перевод", "interpret"], .translation),
            (["документ", "document", "dokument", "довідк", "справк", "паспорт", "дозвіл", "permit", "bewillig"], .documents),
            (["репетит", "tutor", "nachhilfe", "урок", "lesson", "навчан", "math", "english", "deutsch", "мов"], .tutoring),
            (["програм", "develop", "web", "сайт", "app", "software", "it ", "комп'ютер", "computer", "код"], .it),
            (["макіяж", "makeup", "beauty", "nail", "нігт", "волосс", "hair", "стриж", "brows", "lash"], .beauty),
            (["прибир", "clean", "reinig", "пральн", "миття", "wash", "hauswart"], .cleaning),
            (["бухгалт", "account", "buchhalt", "steuer", "податк", "tax", "фінанс", "financ"], .accounting),
            (["юрист", "legal", "lawyer", "advokat", "rechts", "закон", "право", "law"], .legal),
            (["дит", "child", "baby", "nanny", "няня", "kinder", "betreuung", "догляд"], .childcare),
            (["переїзд", "moving", "umzug", "transport", "вантаж", "delivery", "lieferung"], .moving),
            (["ремонт", "repair", "reparatur", "сантехн", "plumb", "electric", "handwerk", "fix"], .repair),
        ]

        for entry in mapping {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                let newSuggested = entry.category
                if suggestedCategory != newSuggested || !categorySuggestionVisible {
                    suggestedCategory = newSuggested
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        categorySuggestionVisible = true
                    }
                }
                return
            }
        }

        withAnimation { categorySuggestionVisible = false }
    }

    // MARK: - Submit

    private func submit() async {
        guard isValid else { return }
        isSubmitting = true

        let payload = ServiceListingCreate(
            listingType: listingType,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            category: listingType == .item ? itemCategory.rawValue : category.rawValue,
            canton: canton,
            priceInfo: listingType == .service && !priceInfo.isEmpty ? priceInfo : nil,
            priceChf: listingType == .item && !isFreeItem ? parsedPrice : nil,
            priceMinor: listingType == .item && !isFreeItem ? parsedPrice.map { $0 * 100 } : nil,
            isFree: listingType == .item && isFreeItem,
            condition: listingType == .item ? condition : nil,
            negotiable: listingType == .item && !isFreeItem && negotiable,
            contactType: contactType,
            contactValue: contactValue.trimmingCharacters(in: .whitespaces),
            authorName: authorName.trimmingCharacters(in: .whitespaces),
            imageURLs: []
        )

        do {
            var payloadWithImages = payload
            payloadWithImages.imageURLs = try await uploadSelectedImages()
            _ = try await APIClient.createListing(payloadWithImages)
            EventBus.shared.emit(GamEvent(
                type: .marketplaceContribution,
                metadata: [
                    "entityId": payload.title,
                    "title": "Service listing submitted"
                ]
            ))
            onCreated?()
            showSuccess = true
        } catch {
            if (error as NSError).code == 401 {
                errorMessage = "auth.session_expired".localized
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isSubmitting = false
    }

    private func appendSelectedPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        let remainingSlots = maxImages - selectedImages.count
        guard remainingSlots > 0 else {
            selectedPhotoItems = []
            return
        }

        var appended: [SelectedListingImage] = []
        for item in items.prefix(remainingSlots) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let prepared = prepareSelectedImage(from: data) else { continue }
            appended.append(prepared)
        }

        if !appended.isEmpty {
            selectedImages.append(contentsOf: appended)
        }
        selectedPhotoItems = []
    }

    private func prepareSelectedImage(from data: Data) -> SelectedListingImage? {
        guard let original = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1800
        let largestSide = max(original.size.width, original.size.height)
        let scale = largestSide > maxDimension ? maxDimension / largestSide : 1
        let targetSize = CGSize(
            width: max(1, original.size.width * scale),
            height: max(1, original.size.height * scale)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpegData = rendered.jpegData(compressionQuality: 0.82) else { return nil }
        return SelectedListingImage(
            image: rendered,
            data: jpegData,
            filename: "listing-\(UUID().uuidString).jpg"
        )
    }

    private func removeSelectedImage(_ image: SelectedListingImage) {
        selectedImages.removeAll { $0.id == image.id }
    }

    private func uploadSelectedImages() async throws -> [String] {
        guard !selectedImages.isEmpty else { return [] }
        var urls: [String] = []
        for image in selectedImages {
            let uploadedURL = try await APIClient.uploadMarketplaceImage(data: image.data, filename: image.filename)
            urls.append(uploadedURL)
        }
        return urls
    }
}

// MARK: - Canton Picker Sheet

private struct CantonPickerSheet: View {
    @Binding var selectedCanton: String
    let country: ResidenceCountry
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [AdministrativeArea] {
        let areas = CountryCatalog.subdivisions(for: country)
        if searchText.isEmpty { return areas }
        let lower = searchText.lowercased()
        return areas.filter {
            $0.code.lowercased().contains(lower) || $0.name.lowercased().contains(lower)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.market.rawValue, blurRadius: 8, darkness: 0.76)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { canton in
                            cantonRow(canton)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .searchable(text: $searchText, prompt: "marketplace.canton.search".localized)
            .navigationTitle(country.subdivisionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
            }
        }
        .journeyScreen(.market, darkness: 0.76)
        .presentationDetents([.large])
    }

    private func cantonRow(_ canton: AdministrativeArea) -> some View {
        let isSelected = selectedCanton == canton.code
        return Button {
            selectedCanton = canton.code
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(country.flag)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected
                                  ? Theme.Colors.primary.opacity(0.15)
                                  : Theme.Colors.adaptiveCard)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(canton.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    if canton.code != "all" {
                        Text(canton.code)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(JourneyVisual.accentStrong)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? Theme.Colors.primary.opacity(0.08)
                          : Theme.Colors.adaptiveCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.Colors.primary.opacity(0.3) : Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SelectedListingImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
    let filename: String
}
