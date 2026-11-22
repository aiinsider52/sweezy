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
    /// No default: a preselected "Other" sent most listings into a category nobody browses.
    @State private var category: ServiceCategory?
    @State private var itemCategory: ItemCategory?
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

    private var isItem: Bool { listingType == .item }

    private var isValid: Bool { requiredSteps.allSatisfy { $0 } }

    private var parsedPrice: Int? {
        guard let value = Int(priceText.trimmingCharacters(in: .whitespaces)), value >= 0 else { return nil }
        return value
    }

    private var currencyCode: String { APIClient.countryCode == "CH" ? "CHF" : "EUR" }
    private var country: ResidenceCountry { ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland }

    private var hasTitle: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var hasDescription: Bool { description.trimmingCharacters(in: .whitespaces).count >= 20 }
    private var hasAbout: Bool { hasTitle && hasDescription }
    private var hasPrice: Bool { !isItem || isFreeItem || parsedPrice != nil }
    private var hasContact: Bool {
        !contactValue.trimmingCharacters(in: .whitespaces).isEmpty && !authorName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var hasCategory: Bool { isItem ? itemCategory != nil : category != nil }

    /// Steps that gate publishing; a service price stays optional, so it is not one of them.
    private var requiredSteps: [Bool] {
        isItem ? [hasAbout, hasCategory, hasPrice, hasContact] : [hasAbout, hasCategory, hasContact]
    }

    private var stepsLeft: Int { requiredSteps.filter { !$0 }.count }

    private var missingHint: String {
        var missing: [String] = []
        if !hasTitle { missing.append("marketplace.field.title".localized) }
        if !hasDescription { missing.append(descriptionLabel) }
        if !hasCategory { missing.append("marketplace.field.category".localized) }
        if !hasPrice { missing.append("marketplace.field.price".localized) }
        if contactValue.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("marketplace.field.contact".localized) }
        if authorName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("marketplace.field.author".localized) }
        return "marketplace.create.missing".localized(with: missing.joined(separator: ", ").lowercased())
    }

    private var descriptionLabel: String {
        (isItem ? "marketplace.field.item_description" : "marketplace.field.description").localized
    }

    private var previewPrice: String {
        if isItem {
            if isFreeItem { return "marketplace.free".localized }
            if let parsedPrice { return "\(currencyCode) \(parsedPrice)" }
            return "marketplace.create.price_needed".localized
        }
        let trimmed = priceInfo.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "marketplace.create.price_on_request".localized : trimmed
    }

    private var previewCategory: (title: String, icon: String, swatch: JourneyCategorySwatch)? {
        if isItem { return itemCategory.map { ($0.displayName, $0.icon, $0.swatch) } }
        return category.map { ($0.displayName, $0.icon, $0.swatch) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                JourneyVisual.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        previewCard
                        section("marketplace.field.photos".localized, done: !selectedImages.isEmpty, optional: true, boxed: false) {
                            photosContent
                        }
                        section((isItem ? "marketplace.step.about_item" : "marketplace.step.about").localized, done: hasAbout) {
                            aboutContent
                        }
                        section("marketplace.field.category".localized, done: hasCategory, boxed: false) {
                            categoryChips
                        }
                        section("marketplace.field.price".localized, done: isItem ? hasPrice : !priceInfo.isEmpty, optional: !isItem) {
                            if isItem { itemPriceContent } else { servicePriceField }
                        }
                        section("marketplace.create.where_contact".localized, done: hasContact) {
                            contactContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 128)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                circleButton("xmark", label: "common.cancel".localized) { dismiss() }
                Spacer(minLength: 8)
                Text((isItem ? "marketplace.create_item_title" : "marketplace.create_title").localized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                circleButton("list.bullet", label: "marketplace.my_listings".localized) { showMyListings = true }
            }

            HStack(spacing: 4) {
                ForEach(Array(requiredSteps.enumerated()), id: \.offset) { _, done in
                    Capsule()
                        .fill(done ? JourneyVisual.lime : JourneyVisual.primaryText.opacity(0.1))
                        .frame(height: 4)
                }
            }
            .animation(.easeOut(duration: 0.25), value: requiredSteps)

            Text(isValid ? "marketplace.create.ready".localized : "marketplace.create.steps_left".localized(with: stepsLeft))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isValid ? JourneyVisual.accentText : JourneyVisual.secondaryText)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: stepsLeft)
        }
        .padding(.top, 6)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .frame(width: 38, height: 38)
                .background(Theme.Colors.card, in: Circle())
                .overlay(Circle().stroke(JourneyVisual.softBorder))
        }
        .accessibilityLabel(label)
    }

    /// How the listing will look in the feed, updated while the form is filled.
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("marketplace.create.preview".localized)
            HStack(spacing: 12) {
                previewThumb
                VStack(alignment: .leading, spacing: 5) {
                    Text(previewCategory?.title ?? "marketplace.create.pick_category".localized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(previewCategory?.swatch.ink ?? JourneyVisual.secondaryText)
                        .lineLimit(1)
                    Text(title.isEmpty ? "marketplace.create.preview_title".localized : title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(title.isEmpty ? JourneyVisual.secondaryText : JourneyVisual.primaryText)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(previewPrice)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(hasPrice ? .black : JourneyVisual.secondaryText)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(hasPrice ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
                        Label(canton == "all" ? country.flag : canton, systemImage: "mappin")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 12, y: 4)
        }
        .animation(.easeOut(duration: 0.2), value: title)
        .animation(.easeOut(duration: 0.2), value: selectedImages.count)
    }

    @ViewBuilder
    private var previewThumb: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack {
            if let first = selectedImages.first {
                Image(uiImage: first.image).resizable().scaledToFill()
            } else if let cat = previewCategory {
                cat.swatch.fill
                Image(systemName: cat.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(cat.swatch.ink)
            } else {
                JourneyVisual.softSurface
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText.opacity(0.6))
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(shape)
    }

    // MARK: - Sections

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundColor(JourneyVisual.secondaryText)
    }

    private func section<Content: View>(
        _ title: String, done: Bool, optional: Bool = false, boxed: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                sectionLabel(title)
                if optional {
                    Text("· " + "marketplace.optional".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText.opacity(0.8))
                }
                Spacer(minLength: 0)
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.black, JourneyVisual.lime)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: done)
            .padding(.horizontal, 4)

            if boxed {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder))
            } else {
                content()
            }
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(JourneyVisual.softBorder).frame(height: 1).padding(.leading, 14)
    }

    // MARK: - Photos

    private var addPhotoTile: some View {
        VStack(spacing: 4) {
            Image(systemName: "camera.fill").font(.system(size: 18, weight: .semibold))
            Text(selectedImages.isEmpty ? "marketplace.create.add_photo".localized : "\(selectedImages.count)/\(maxImages)")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(JourneyVisual.accentText)
        .frame(width: 76, height: 76)
        .background(JourneyVisual.lime.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(JourneyVisual.accentStrong.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        )
    }

    private var photosContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if selectedImages.count < maxImages {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: maxImages - selectedImages.count,
                        matching: .images
                    ) {
                        addPhotoTile
                    }
                    .buttonStyle(.plain)
                }
                if selectedImages.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("marketplace.photos_placeholder".localized(with: maxImages))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(JourneyVisual.primaryText)
                        Text("marketplace.photos_hint".localized)
                            .font(.system(size: 12))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 250, alignment: .leading)
                    .padding(.leading, 4)
                }
                ForEach(Array(selectedImages.enumerated()), id: \.element.id) { index, image in
                    photoThumbnail(image, isCover: index == 0)
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

    private func photoThumbnail(_ image: SelectedListingImage, isCover: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image.image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if isCover {
                        Text("marketplace.photo_cover".localized)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(JourneyVisual.lime, in: Capsule())
                            .padding(5)
                    }
                }

            Button {
                removeSelectedImage(image)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white, Color.black.opacity(0.55))
                    .padding(3)
            }
            .accessibilityLabel("marketplace.photo_remove".localized)
        }
    }

    // MARK: - About

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TextField((isItem ? "marketplace.field.item_title_placeholder" : "marketplace.field.title_placeholder").localized, text: $title)
                    .focused($focusedField, equals: .title)
                    .font(.system(size: 16, weight: .semibold))
                    .onChange(of: title) { _, newValue in
                        if newValue.count > 100 { title = String(newValue.prefix(100)) }
                        updateCategorySuggestion(for: newValue)
                    }
                if title.count > 80 {
                    Text("\(title.count)/100")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(title.count > 95 ? Theme.Colors.error : JourneyVisual.secondaryText)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            rowDivider

            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text((isItem ? "marketplace.field.item_description_placeholder" : "marketplace.field.description_placeholder").localized)
                        .font(.system(size: 15))
                        .foregroundColor(JourneyVisual.secondaryText.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $description)
                    .focused($focusedField, equals: .description)
                    .font(.system(size: 15))
                    .frame(minHeight: 96, maxHeight: 170)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .onChange(of: description) { _, newValue in
                        if newValue.count > 1000 { description = String(newValue.prefix(1000)) }
                    }
            }

            if !description.isEmpty {
                HStack {
                    if !hasDescription {
                        Label("marketplace.field.description_min".localized, systemImage: "exclamationmark.circle")
                            .foregroundColor(Theme.Colors.warning)
                    }
                    Spacer()
                    Text("\(description.count)/1000")
                        .foregroundColor(description.count > 950 ? Theme.Colors.error : JourneyVisual.secondaryText)
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Category

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let suggested = suggestedCategory, categorySuggestionVisible, suggested != category {
                suggestedCategoryBadge(suggested)
                    .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
            }
            FlowLayout(spacing: 8) {
                if isItem {
                    ForEach(ItemCategory.allCases) { cat in
                        categoryChip(title: cat.displayName, icon: cat.icon, swatch: cat.swatch, selected: itemCategory == cat, suggested: false) {
                            itemCategory = cat
                            if cat == .free { isFreeItem = true }
                        }
                    }
                } else {
                    ForEach(ServiceCategory.allCases) { cat in
                        categoryChip(
                            title: cat.displayName, icon: cat.icon, swatch: cat.swatch, selected: category == cat,
                            suggested: suggestedCategory == cat && categorySuggestionVisible && category != cat
                        ) {
                            category = cat
                            if suggestedCategory == cat { categorySuggestionVisible = false }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: categorySuggestionVisible)
    }

    private func categoryChip(
        title: String, icon: String, swatch: JourneyCategorySwatch, selected: Bool, suggested: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(selected ? .black : swatch.ink)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(selected ? .black : JourneyVisual.primaryText)
                    .lineLimit(1)
            }
            .padding(.leading, 11)
            .padding(.trailing, 13)
            .frame(height: 36)
            .background(selected ? JourneyVisual.lime : Theme.Colors.card, in: Capsule())
            .overlay(
                Capsule().stroke(
                    suggested ? JourneyVisual.accentStrong.opacity(0.7) : (selected ? Color.clear : JourneyVisual.softBorder),
                    style: StrokeStyle(lineWidth: suggested ? 1.5 : 1, dash: suggested ? [4, 3] : [])
                )
            )
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Price

    private var itemPriceContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            segmentTrack {
                segment("marketplace.create.sell".localized, icon: "banknote", selected: !isFreeItem) { isFreeItem = false }
                segment("marketplace.field.give_away".localized, icon: "gift.fill", selected: isFreeItem) { isFreeItem = true }
            }
            .padding(10)

            if !isFreeItem {
                rowDivider
                HStack(spacing: 10) {
                    Text(currencyCode)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(JourneyVisual.accentText)
                    TextField("marketplace.field.item_price_placeholder".localized, text: $priceText)
                        .focused($focusedField, equals: .price)
                        .font(.system(size: 20, weight: .bold))
                        .keyboardType(.numberPad)
                        .onChange(of: priceText) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            if digits != newValue { priceText = digits }
                            if digits.count > 7 { priceText = String(digits.prefix(7)) }
                        }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { negotiable.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: negotiable ? "checkmark" : "arrow.left.arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("marketplace.price.negotiable".localized)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(negotiable ? .black : JourneyVisual.primaryText)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(negotiable ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
                        .overlay(Capsule().stroke(negotiable ? Color.clear : JourneyVisual.softBorder))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95, hapticStyle: .light))
                    .accessibilityLabel("marketplace.field.negotiable".localized)
                    .accessibilityAddTraits(negotiable ? .isSelected : [])
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
            }

            rowDivider
            HStack(spacing: 10) {
                Text("marketplace.field.condition".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)
                segmentTrack {
                    ForEach(ItemCondition.allCases) { cond in
                        segment(cond.displayName, icon: nil, selected: condition == cond) { condition = cond }
                    }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
        }
    }

    private var servicePriceField: some View {
        HStack(spacing: 10) {
            Image(systemName: "banknote")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(JourneyVisual.accentStrong)
                .frame(width: 20)
            TextField("marketplace.field.price_placeholder".localized, text: $priceInfo)
                .focused($focusedField, equals: .price)
                .font(.system(size: 16, weight: .medium))
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }

    // MARK: - Location & contact

    private var contactContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showCantonPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.accentStrong)
                        .frame(width: 20)
                    Text(CountryCatalog.subdivisionName(country: country, code: canton))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                    Spacer()
                    Text(country.subdivisionTitle)
                        .font(.system(size: 13))
                        .foregroundColor(JourneyVisual.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            rowDivider

            segmentTrack {
                ForEach(ContactType.allCases) { type in
                    segment(type.displayName, icon: type.icon, selected: contactType == type) { contactType = type }
                }
            }
            .padding(10)

            HStack(spacing: 10) {
                Image(systemName: contactType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(JourneyVisual.accentStrong)
                    .frame(width: 20)
                TextField(contactType.placeholder, text: $contactValue)
                    .focused($focusedField, equals: .contact)
                    .font(.system(size: 16, weight: .medium))
                    .keyboardType(contactType == .email ? .emailAddress : contactType == .telegram ? .default : .phonePad)
                    .textContentType(contactType == .email ? .emailAddress : contactType == .phone ? .telephoneNumber : nil)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            rowDivider

            HStack(spacing: 10) {
                Text(authorName.isEmpty ? "?" : String(authorName.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(JourneyVisual.lime, in: Circle())
                TextField("marketplace.field.author_placeholder".localized, text: $authorName)
                    .focused($focusedField, equals: .author)
                    .font(.system(size: 16, weight: .medium))
                    .textContentType(.name)
            }
            .padding(.horizontal, 13)
            .frame(height: 50)
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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isValid ? .black : JourneyVisual.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isValid ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
                .shadow(color: isValid ? JourneyVisual.lime.opacity(0.35) : .clear, radius: 14, y: 6)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
            .disabled(!isValid || isSubmitting)
            .accessibilityIdentifier("marketplace.create.submit")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            VStack(spacing: 0) {
                LinearGradient(colors: [JourneyVisual.pageBackground.opacity(0), JourneyVisual.pageBackground], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
                    .offset(y: -24)
                    .padding(.bottom, -24)
                JourneyVisual.pageBackground
            }
            .ignoresSafeArea(edges: .bottom)
        }
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

    /// Pill segments on a soft track, iOS segmented-control style.
    private func segmentTrack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 2) { content() }
            .padding(3)
            .background(JourneyVisual.softSurface, in: Capsule())
    }

    private func segment(_ title: String, icon: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundColor(selected ? .black : JourneyVisual.primaryText)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(selected ? JourneyVisual.lime : Color.clear, in: Capsule())
            .contentShape(Capsule())
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
            category: (isItem ? itemCategory?.rawValue : category?.rawValue) ?? ServiceCategory.other.rawValue,
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
