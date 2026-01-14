# 🎨 Sweezy Visual Redesign — GoIT × Ukrainian Identity

## Design Philosophy

**Inspiration:** GoIT.global bold, modern, interactive web design  
**Brand DNA:** Ukrainian Blue (#005BBB) × Gold (#FFD500)  
**Aesthetic:** Apple elegance + OpenAI futurism + Monobank energy + Swiss precision + Ukrainian soul

---

## 🌈 Visual Language

### Core Principles
1. **Bold & Confident**: Large hero sections, full-width gradients, cinematic visuals
2. **Interactive & Alive**: Parallax scrolling, hover states, micro-animations, dynamic shapes
3. **Clean Structure**: Grid-based layouts, generous whitespace, modular sections
4. **Emotional Connection**: Warm Ukrainian identity woven throughout with subtle graphic details
5. **Premium Feel**: Glassmorphism with real depth, soft shadows, smooth transitions

---

## 🎨 Color System

### Brand Colors
```swift
primary: #005BBB     // Ukrainian Blue
accent: #FFD500      // Gold
```

### Light Mode
```swift
background: #FAFAFA  // Soft white
surface: #F9F9FB     // Off-white panels
card: rgba(255,255,255,0.85) // Glass cards
text: #333333        // Near-black
textSecondary: #666666
textTertiary: #999999
```

### Dark Mode
```swift
background: #0C0C15  // Deep navy-black
surface: rgba(255,255,255,0.06)
card: rgba(255,255,255,0.08)
elevated: rgba(255,255,255,0.12)
text: #E5E5E5
textSecondary: rgba(255,255,255,0.6)
```

### Gradients
```swift
gradientBrand: linear(#005BBB → #FFD500)
gradientHero: linear(#005BBB → #0066CC → #FFD500) // 3-stop
gradientSoft: linear(#E0E9FF → #FFF5DA) // Subtle backgrounds
gradientDarkAdaptive: linear(#0066CC → #FFB800) // Desaturated for dark
```

### Semantic Colors
- **Success**: #34C759
- **Warning**: #FF9500
- **Error**: #FF3B30
- **Info**: #007AFF

---

## 📝 Typography System

### Typefaces
- **Primary**: SF Pro Display (iOS system)
- **Fallback**: Inter / Helvetica Neue

### Scale
```swift
megaTitle:   48pt, Bold      // Hero headlines
largeTitle:  34pt, Bold      // Section headers
title1:      28pt, Bold      // Subsection titles
title2:      22pt, Semibold  // Card titles
headline:    20pt, Semibold  // List headers
body:        17pt, Regular   // Primary text
callout:     16pt, Regular   // Secondary text
subheadline: 15pt, Medium    // Labels
footnote:    13pt, Regular   // Captions
caption:     12pt, Medium    // Tiny details
```

### Hierarchy Rules
- **Hero text**: MegaTitle, maximum 2 lines, bold, white on gradient
- **Section headers**: LargeTitle or Title1, with optional accent underline
- **Body text**: 17pt with 1.4 line height for readability
- **Small text**: Never below 12pt for accessibility

---

## 📐 Spacing & Grid

### Grid System
- **Base unit**: 8px (used for vertical rhythm)
- **Horizontal margins**: 16px mobile, 24px tablet, 32px desktop
- **Section spacing**: 48-64px between major sections

### Spacing Scale
```swift
xxxs: 2px   // Tight elements
xxs:  4px   // Icon-text gaps
xs:   8px   // Compact spacing
sm:   12px  // Default gaps
md:   16px  // Cards, margins
lg:   24px  // Section internals
xl:   32px  // Between sections
xxl:  48px  // Major dividers
xxxl: 64px  // Hero padding
```

---

## 🔲 Corner Radius

```swift
xs:   6px   // Tiny chips
sm:   8px   // Buttons
md:   12px  // Small cards
lg:   16px  // Default cards
xl:   20px  // Large panels
xxl:  24px  // Hero sections
pill: 999px // Fully rounded
```

**Design Rule**: Larger surfaces = larger radius (visual harmony)

---

## 🌑 Shadows & Depth

### Shadow Levels
```swift
level0: none              // Flat on surface
level1: rgba(0,0,0,0.06), 8px blur, 0/2    // Subtle lift
level2: rgba(0,0,0,0.08), 16px blur, 0/4   // Cards
level3: rgba(0,0,0,0.12), 24px blur, 0/8   // Modals
level4: rgba(0,0,0,0.16), 32px blur, 0/12  // Floating CTAs
```

### Special Effects
- **Glow**: Colored shadow for brand elements (blue/gold)
- **Inner shadow**: For pressed/inset states
- **Gradient shadow**: Matching brand gradient on CTAs

**Dark Mode**: Reduce shadow opacity by 50%, add subtle glow to elevate surfaces

---

## ✨ Motion & Animation

### Spring Presets
```swift
quick:  response 0.25s, damping 0.8  // Buttons, taps
smooth: response 0.35s, damping 0.8  // Transitions, slides
soft:   response 0.5s,  damping 0.85 // Gentle reveals
bounce: response 0.4s,  damping 0.6  // Playful emphasis
```

### Animation Principles
1. **Responsive feedback**: Every tap gets immediate visual response (scale 0.96)
2. **Parallax**: Hero backgrounds move 30% slower than foreground
3. **Staggered reveals**: List items appear with 50ms delay cascade
4. **Gradient motion**: Animated gradient shifts on hero (subtle 10s loop)
5. **Reduce motion**: Respect accessibility preference, fallback to fade

### Key Interactions
- **Button press**: Scale 0.96 + glow increase
- **Card hover**: Lift 2px + border glow
- **Tab switch**: Slide + fade, 350ms
- **Modal present**: Scale from 0.9 + fade, 400ms
- **Hero parallax**: ScrollView offset * 0.3

---

## 🧩 Component Library

### 1. Hero Section
**Purpose**: Cinematic entry point, emotional connection  
**Anatomy**:
- Full-width gradient background (#005BBB → #FFD500)
- Animated particles or wave shapes (subtle motion)
- Large headline (48pt, bold, white, 2 lines max)
- Subtitle (17pt, white opacity 0.9)
- Primary CTA button (gradient fill, pill shape, white text)
- Parallax scroll effect

**Use in**: Home, Onboarding, Welcome screens

---

### 2. Glass Card
**Purpose**: Content container with depth  
**Anatomy**:
- Background: `.ultraThinMaterial` with 75% opacity
- Border: White gradient stroke (0.4 → 0.1 opacity)
- Corner radius: 16px
- Shadow: level2
- Inner highlight: White 10% opacity, top edge
- Padding: 16-24px

**Variants**:
- **Standard**: White material
- **Colored**: Tinted blue/gold (10% opacity)
- **Elevated**: level3 shadow for focus

**Use in**: Guides, Checklists, Templates, Calculator results

---

### 3. Primary Button
**Purpose**: Main call-to-action  
**Anatomy**:
- Background: Brand gradient (#005BBB → #FFD500)
- Text: White, 17pt, Semibold
- Padding: 16px vertical, 32px horizontal
- Corner radius: pill (999px)
- Shadow: Colored gradient shadow (20% opacity)
- Press state: Scale 0.96, glow increase

**Variants**:
- **Primary**: Full gradient
- **Secondary**: Outline with gradient stroke, transparent fill
- **Tertiary**: Text only, gradient text color
- **Loading**: Shows spinner, disabled state

**Use in**: Registration, Onboarding, Form submissions

---

### 4. Section Header
**Purpose**: Visual hierarchy marker  
**Anatomy**:
- Title: 28pt or 34pt, Bold
- Optional subtitle: 15pt, Medium, secondary color
- Accent underline: 3px height, 40px width, gradient, left-aligned
- Bottom spacing: 16-24px

**Use in**: All list screens (Guides, Checklists, Home sections)

---

### 5. Interactive Card (List Item)
**Purpose**: Tappable content preview  
**Anatomy**:
- Glass card base
- Icon (SF Symbol): 24pt, brand gradient fill
- Title: 17pt, Semibold
- Subtitle: 15pt, Regular, secondary
- Chevron: 14pt, tertiary (right edge)
- Tap state: Scale 0.98, border glow

**Hover effect** (if supported):
- Lift 2px
- Border increases to 1.5px with glow
- Slight shadow increase

**Use in**: Guides list, Templates list, Checklists list

---

### 6. Tab Bar
**Purpose**: Primary navigation  
**Anatomy**:
- Background: Frosted glass (`.ultraThinMaterial`)
- Height: 80px (safe area included)
- Active indicator: 3px height gradient line, 40px width, centered under icon
- Icons: 28pt SF Symbols
- Label: 11pt, Medium
- Inactive color: Tertiary
- Active color: Gradient (blue/gold)

**Animation**: Indicator slides smoothly (350ms spring) between tabs

**Use in**: MainTabView

---

### 7. Parallax Hero
**Purpose**: Immersive entry experience  
**Anatomy**:
- Background: Animated gradient or subtle particle field
- ScrollView offset tracking: `GeometryReader` at top
- Foreground content moves at 1.0x speed
- Background moves at 0.3x speed (parallax)
- Text scales down and fades as user scrolls
- Min height: 200px, Max height: 400px

**Use in**: Home, Onboarding, Guide Detail hero

---

### 8. Lock Overlay
**Purpose**: Content gating for unregistered users  
**Anatomy**:
- Blurred content beneath (4px blur)
- Centered glass card
- Lock icon: 24pt, glowing blue
- Message: 15pt, Medium, centered
- Background: `.ultraThinMaterial`, 90% opacity
- CTA: "Register to unlock" (optional)

**Use in**: Guides, Templates, Checklists (when locked)

---

### 9. Empty State
**Purpose**: Friendly null state  
**Anatomy**:
- Icon: 56pt SF Symbol, gradient fill
- Title: 22pt, Semibold
- Subtitle: 17pt, Regular, secondary, centered, max 280px width
- Optional CTA button (secondary style)
- Vertical spacing: 24px between elements

**Use in**: Empty search results, no appointments, no templates

---

### 10. Shimmer Skeleton
**Purpose**: Loading placeholder  
**Anatomy**:
- Rectangle shapes matching content layout
- Gradient overlay: White 0% → 30% → 0%
- Animation: Translate gradient from left to right, 1.5s linear infinite
- Corner radius: Matches actual content (12-16px)
- Background: Card color

**Use in**: List loading, detail loading

---

## 📱 Screen-by-Screen Design

### 🏠 Home Screen
**Hero Section** (400px height):
- Full-width gradient background (Blue → Gold)
- Floating particle animation (optional)
- Dynamic greeting: "Добрий ранок, [Name]" / "Good morning"
- Time-based icon (sun/moon)
- Parallax scroll effect

**Quick Actions** (Below hero):
- 4 tiles, 2x2 grid
- Glass cards with icons and labels
- Tap → Scale + haptic feedback
- Icons: Guides, Checklists, Calculator, Map

**Statistics Cards**:
- Horizontal scroll row
- Glass cards with numbers/icons
- "12 Guides read", "3 Checklists active", etc.

**News Section**:
- Title: "Що нового?" / "What's new?"
- Horizontal scroll of news cards
- Each card: Image/gradient, title, date
- Tap → open article/guide

**Telegram CTA**:
- Full-width glass card
- Icon + "Join our community"
- Tap → open Telegram deep link

---

### 📖 Guides Screen
**Header**:
- Section title: "Довідники" / "Guides" (34pt, bold)
- Accent underline (gradient, 3px)
- Search bar: Glass style, icon + placeholder

**Search Bar**:
- Frosted glass background
- Magnifying glass icon (left)
- Placeholder: "Search guides..."
- Active state: Border glow (brand gradient)

**Category Filter** (Horizontal scroll):
- Pill-shaped chips
- Inactive: Glass background, secondary text
- Active: Gradient fill, white text
- Tap animation: Scale + spring

**Guides List**:
- Vertical stack of interactive cards
- Each card:
  - Icon (category-specific, gradient)
  - Title (17pt, Semibold)
  - Subtitle (15pt, secondary)
  - Priority badge (if high)
  - Chevron (right)
- Staggered reveal animation on load

**Empty State**:
- Centered icon + text
- "No guides found"
- Optional "Browse all" button

---

### 📋 Checklists Screen
**Layout**: Similar to Guides  
**Unique Elements**:
- Progress ring on each card (showing completion %)
- Checkmark icon for completed items
- Badge showing "3/10 tasks" on card

---

### 📄 Templates Screen
**Layout**: Similar to Guides  
**Unique Elements**:
- "Generate" button on each card (secondary style)
- Document preview icon
- Category badge (Employment, Legal, etc.)

---

### 📍 Map Screen
**Top**: Full-screen map (MapKit)  
**Bottom Sheet**:
- Draggable glass panel (frosted)
- Handle indicator at top (pill shape)
- List of places below
- Each place card: Icon, name, address, distance
- Tap place → Center map + show details

---

### 🧮 Calculator Screen
**Form Section**:
- Glass card container
- Input fields: Glass style with gradient focus border
- Labels: 15pt, Medium, secondary
- Segmented pickers: Gradient active state

**Results Section**:
- Glass cards for each benefit
- Icon (category-specific)
- Title + amount (bold, large)
- "Eligible" badge (green) or "Not eligible" (gray)
- Tap → Expand details

---

### ⚙️ Settings Screen
**Profile Section** (if registered):
- Glass card
- Avatar (gradient circle with initials)
- Name + email
- "Edit" button (tertiary)

**Options List**:
- Glass cards grouped by category
- Each row: Icon (left), Label, Value/Chevron (right)
- Theme picker: Visual thumbnails (Light/Dark/System)
- Language picker: Flag icons

**Actions**:
- "Privacy Policy" (row)
- "Logout" (row, red text)

---

### 🎓 Onboarding
**Full-screen pages** (3 pages):
- Each page: Gradient hero background (different tints)
- Large illustration/icon (top center)
- Headline (48pt, bold, white)
- Body text (17pt, white opacity 0.9)
- Progress dots (bottom)
- "Next" button (white gradient)
- "Skip" (top right, text button)

**Page transitions**: Horizontal slide + fade

---

### 🔐 Registration Screen
**Layout**:
- Full-screen gradient background (Blue → Gold)
- Glass card container (centered, max-width 400px)
- Logo/icon at top
- "Create Your Account" headline
- Input fields (Name, Email, Password):
  - Glass background
  - Gradient border on focus
  - Error state: Red border + message below
- Primary button: "Register" (white text, gradient)
- Loading state: Spinner replaces text
- Success: Confetti animation

---

## 🌓 Dark Mode Strategy

### Automatic Adaptation
- All colors use `UIColor { traitCollection in ... }` for dynamic switching
- Gradients desaturate slightly in dark mode
- Shadows reduce opacity by 50%
- Glass material remains consistent (system provides dark variant)

### Key Adjustments
- Background: #FAFAFA → #0C0C15
- Text: #333333 → #E5E5E5
- Cards: White glass → White 8% opacity glass
- Primary gradient: #005BBB→#FFD500 → #0066CC→#FFB800 (desaturated)
- Glow effects become more prominent for elevation

---

## 🇺🇦 Ukrainian Identity Integration

### Visual Elements
1. **Color DNA**: Blue + Gold as primary brand gradient throughout
2. **Flag motif**: Subtle horizontal bands in hero gradients (blue upper, gold lower)
3. **Geometric patterns**: Optional Ukrainian folk-inspired abstract shapes in backgrounds (very subtle, 5% opacity)
4. **Language-first**: Ukrainian as default, prominent in UI
5. **Community emphasis**: Telegram CTA, shared resources, mutual support tone

### Emotional Tone
- **Warm**: Welcoming, supportive language
- **Empowering**: "You've got this" confidence
- **Community-driven**: "We're here together"
- **Practical**: Clear, actionable information

---

## 📐 Layout Principles

### Grid System
- **Mobile**: 16px margins, full-width cards
- **Tablet**: 24px margins, 2-column grids where appropriate
- **Content max-width**: 800px for readability (centered)

### Vertical Rhythm
- Use 8px base unit for all vertical spacing
- Section spacing: 48px minimum
- Card internal padding: 16-24px
- List item spacing: 8-12px

### Scroll Behavior
- **Hero parallax**: Background moves at 0.3x speed
- **Nav bar**: Becomes opaque glass on scroll
- **Pull-to-refresh**: Custom blue-gold activity indicator
- **Scroll-to-top**: Tap status bar or floating button

---

## 🎭 Interaction States

### Buttons
- **Default**: Gradient fill, white text, shadow
- **Hover** (iPad): Lift 2px, glow increase
- **Press**: Scale 0.96, haptic medium
- **Disabled**: 40% opacity, no interaction
- **Loading**: Spinner, disabled state

### Cards
- **Default**: Glass, level2 shadow
- **Tap**: Scale 0.98, border glow
- **Selected**: Border becomes solid gradient (2px)
- **Locked**: Blur + overlay with lock icon

### Inputs
- **Default**: Glass background, gray border
- **Focus**: Gradient border (animated)
- **Error**: Red border, shake animation, error text below
- **Success**: Green checkmark icon (right side)

---

## 🚀 Implementation Checklist

### Phase 1: Foundation
- [x] Update `Theme.swift` with all new tokens
- [x] Create base component library (Button, Card, Header)
- [ ] Implement animation presets
- [ ] Set up dark mode adaptive colors

### Phase 2: Core Components
- [ ] Rebuild `PrimaryButton` with all variants
- [ ] Rebuild `GlassCard` with proper depth
- [ ] Create `HeroView` with parallax
- [ ] Create `SectionHeader` with accent line
- [ ] Create `InteractiveCard` for lists
- [ ] Create `TabBarView` with animated indicator

### Phase 3: Screens
- [ ] Redesign `HomeView` (hero + sections)
- [ ] Redesign `GuidesView` (search + filters + cards)
- [ ] Redesign `ChecklistsView`
- [ ] Redesign `TemplatesView`
- [ ] Redesign `MapView` (bottom sheet)
- [ ] Redesign `CalculatorView` (form + results)
- [ ] Redesign `SettingsView`
- [ ] Redesign `OnboardingView` (hero pages)
- [ ] Redesign `RegistrationView` (full-screen form)

### Phase 4: Polish
- [ ] Add all micro-animations
- [ ] Implement parallax scrolling
- [ ] Add staggered list reveals
- [ ] Test all dark mode transitions
- [ ] Add haptic feedback throughout
- [ ] Optimize performance (60fps target)
- [ ] Add accessibility labels
- [ ] Test with VoiceOver

### Phase 5: QA
- [ ] Test on iPhone SE (small screen)
- [ ] Test on iPhone Pro Max (large screen)
- [ ] Test on iPad (different layouts)
- [ ] Test all localizations (UA/RU/EN/DE)
- [ ] Test with Dynamic Type (accessibility)
- [ ] Test with Reduce Motion enabled
- [ ] Performance profiling
- [ ] Final design review

---

## 🎯 Success Criteria

**Visual Impact**: User opens app and says "Wow, this is beautiful"  
**Brand Recognition**: Blue + Gold immediately signals Ukrainian identity  
**Usability**: Every interaction feels smooth, predictable, delightful  
**Performance**: 60fps scrolling, instant feedback, <200ms transitions  
**Accessibility**: Full VoiceOver support, Dynamic Type, high contrast  
**Consistency**: Every screen follows the same design language  

---

**Design Lead**: AI Product Designer  
**Version**: 2.0 — GoIT-Inspired Redesign  
**Date**: November 2025  
**Status**: Ready for Implementation 🚀

