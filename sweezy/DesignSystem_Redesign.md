# Sweezy Design System — Redesign Specification
**Apple × OpenAI × Monobank aesthetic with Ukrainian soul 🇺🇦**

---

## 🎨 Design Philosophy

### Core Principles
- **Clarity**: Generous white space, clear hierarchy, intuitive navigation
- **Depth**: Layered surfaces with real translucency, cinematic lighting
- **Motion**: Natural spring animations, subtle parallax, smooth transitions
- **Warmth**: Ukrainian blue and gold as emotional anchors
- **Humanity**: Friendly microinteractions, empathetic empty states

### Brand DNA
- **Primary**: Ukrainian Blue `#005BBB` — trust, stability, digital sky
- **Accent**: Gold `#FFD500` — warmth, optimism, achievement
- **Gradient**: Blue→Gold represents journey from arrival to thriving

---

## 🌈 Color System

### Light Mode
```swift
// Primary Palette
primary         #005BBB    // Ukrainian Blue
accent          #FFD500    // Gold
surface         #F9F9FB    // Almost white with hint of blue
card            rgba(255,255,255,0.65)  // Frosted glass
shadow          rgba(0,0,0,0.08)        // Soft drop shadow
divider         rgba(0,0,0,0.06)

// Text Hierarchy
textPrimary     #0C0C15    // Near black
textSecondary   rgba(12,12,21,0.6)
textTertiary    rgba(12,12,21,0.4)
textOnPrimary   #FFFFFF

// Semantic
success         #34C759    // iOS green
warning         #FF9500    // iOS orange
error           #FF3B30    // iOS red
info            #007AFF    // iOS blue

// Gradients
gradientPrimary    linear(#005BBB → #FFD500)
gradientSoft       linear(#E0E9FF → #FFF5DA)
gradientHero       linear(#005BBB 0%, #0066CC 50%, #FFD500 100%)
```

### Dark Mode
```swift
// Primary Palette
background      #0C0C15    // Deep blue-black
surface         rgba(255,255,255,0.06)
card            rgba(255,255,255,0.08)
shadow          rgba(0,0,0,0.4)
divider         rgba(255,255,255,0.08)

// Text Hierarchy
textPrimary     rgba(255,255,255,0.92)
textSecondary   rgba(255,255,255,0.6)
textTertiary    rgba(255,255,255,0.4)

// Adapted Gradients
gradientPrimary    linear(#0066CC → #FFB800)  // Slightly desaturated
gradientHero       linear(#004499 0%, #005BBB 50%, #CC9900 100%)
```

---

## 📐 Typography System

### Font Stack
- **Display**: SF Pro Display (iOS system)
- **Text**: SF Pro Text (iOS system)
- **Mono**: SF Mono (for code/numbers)

### Scale
```swift
largeTitle      34pt  Bold      // Hero headlines
title1          28pt  Bold      // Section titles
title2          22pt  Semibold  // Card headers
headline        20pt  Semibold  // Subsection headers
body            17pt  Regular   // Body text
callout         16pt  Regular   // Secondary body
subheadline     15pt  Medium    // Captions with hierarchy
footnote        13pt  Regular   // Fine print
caption1        12pt  Medium    // Labels, metadata
caption2        11pt  Regular   // Smallest UI text
```

### Vertical Rhythm
- Base unit: 8pt
- Line heights: 1.2 (tight), 1.4 (normal), 1.6 (relaxed)
- Paragraph spacing: 16pt

---

## 🧱 Spacing System

```swift
xxxs    2pt
xxs     4pt
xs      8pt
sm      12pt
md      16pt
lg      24pt
xl      32pt
xxl     48pt
xxxl    64pt
```

### Layout Margins
- Screen edge: 16pt (iPhone), 20pt (iPad)
- Card padding: 16–20pt
- Section spacing: 24–32pt

---

## 🎭 Elevation & Shadows

```swift
// Elevation Levels
level0   none                           // Flat on surface
level1   y:2  blur:8  opacity:0.06      // Subtle lift
level2   y:4  blur:16 opacity:0.08      // Cards
level3   y:8  blur:24 opacity:0.12      // Modals
level4   y:12 blur:32 opacity:0.16      // Floating CTAs

// Special Shadows
glow     blur:20 opacity:0.3 color:accent  // Accent elements
colored  blur:16 opacity:0.2 color:primary // Branded elements
```

---

## 🔲 Border Radius

```swift
xs      6pt     // Chips, tags
sm      8pt     // Small buttons
md      12pt    // Input fields, small cards
lg      16pt    // Standard cards
xl      20pt    // Hero cards
xxl     24pt    // Large feature cards
pill    999pt   // Fully rounded buttons
continuous      // Use .continuous style for smooth corners
```

---

## 🎬 Motion & Animation

### Spring Presets
```swift
quick       response:0.25  damping:0.8  blend:0.2
smooth      response:0.35  damping:0.8  blend:0.3
soft        response:0.5   damping:0.85 blend:0.3
bounce      response:0.4   damping:0.6  blend:0.3
```

### Durations
- Micro: 150ms (hover, focus)
- Quick: 250ms (button press, chip selection)
- Smooth: 350ms (card transitions, sheet present)
- Slow: 500ms (screen transitions, hero animations)

### Easing
- Default: `.easeInOut`
- Enter: `.easeOut`
- Exit: `.easeIn`
- Natural: `.spring(...)` — prefer this

---

## 🧩 Component Specifications

### PrimaryButton
**Visual**: Pill-shaped, gradient fill, soft shadow, 44pt min height  
**States**: Default → Pressed (scale 0.96) → Loading (spinner) → Disabled (opacity 0.5)  
**Haptics**: Light impact on press  
**Animation**: Spring (0.35s, 0.8 damping)

### GlassCard
**Material**: `.ultraThinMaterial` with 75% opacity  
**Border**: 1pt gradient stroke (white 40% → white 10%)  
**Shadow**: Level 2  
**Corner**: 16pt continuous  
**Hover**: Subtle parallax shift (2pt)

### SectionHeader
**Typography**: Headline (20pt Semibold)  
**Accent**: 3pt × 20pt accent bar below (optional)  
**Spacing**: 24pt top, 12pt bottom

### EmptyState
**Icon**: 56pt SF Symbol with gradient fill  
**Title**: Title2 (22pt Semibold)  
**Subtitle**: Body (17pt Regular, secondary color)  
**CTA**: Optional PrimaryButton below  
**Spacing**: 24pt between elements

### LoadingState
**Skeleton**: Soft gradient (#F0F0F2 → #FAFAFA → #F0F0F2)  
**Animation**: 1.5s linear loop, shimmer sweep  
**Corner**: Match content (12–16pt)

### LockOverlay
**Background**: `.ultraThinMaterial` blur  
**Icon**: 40pt lock.fill with soft glow  
**Text**: Subheadline (15pt Medium)  
**Card**: Small centered glass card with level 3 shadow

---

## 📱 Screen-Specific Guidelines

### HomeView
- **Hero**: 200pt tall, animated gradient background, parallax on scroll
- **Quick Actions**: 2×2 grid, 180pt tall tiles, unique gradient per tile
- **Stats**: 3-column horizontal, compact glass cards
- **News**: Horizontal scroll, 280×200 cards with image overlay
- **Spacing**: 24pt between major sections

### GuidesView
- **Hero Header**: Glass card with icon, title, count
- **Search Bar**: Frosted glass with gradient stroke, 48pt height
- **Category Chips**: Pill-shaped, active state with colored background
- **Cards**: Glass with gradient left accent bar (3pt)

### RegistrationView
- **Layout**: Full-screen centered form, max 400pt width
- **Header**: 160pt gradient hero with large icon
- **Fields**: 52pt height, 12pt radius, focus state with accent border
- **CTA**: Gradient pill button, 56pt height
- **Success**: Confetti + glow particle overlay

### TabBar
- **Material**: Frosted glass (`.thinMaterial`)
- **Icons**: 24pt SF Symbols, filled when active
- **Indicator**: 3pt accent line above active tab
- **Height**: 49pt (iOS standard)

---

## 🌓 Dark Mode Adaptation

### Principles
- Maintain hierarchy with subtle contrast
- Use softer gradients (desaturate 15%)
- Increase glow on accent elements
- Reduce shadow opacity by 50%

### Key Adjustments
```swift
// Surface elevation in dark
background → #0C0C15
card → rgba(255,255,255,0.08)
elevated → rgba(255,255,255,0.12)

// Text inversion
primary → rgba(255,255,255,0.92)
secondary → rgba(255,255,255,0.6)

// Gradients soften
Blue #005BBB → #0066CC
Gold #FFD500 → #FFB800
```

---

## 🎯 Iconography

### SF Symbols Usage
- **Weights**: Use Medium (default) or Semibold for headers
- **Sizes**: 20pt (inline), 24pt (cards), 28pt (features), 40pt+ (heroes)
- **Rendering**: Prefer `.automatic` or `.hierarchical` for depth

### Custom Icons
- If needed, match SF Symbol weight and optical size
- Export at 1x/2x/3x with consistent stroke width
- Use monochrome or gradient fill

---

## ✅ Implementation Checklist

### Phase 1: Foundation
- [ ] Update `Theme.swift` with new color tokens
- [ ] Add typography presets
- [ ] Define shadow and animation presets
- [ ] Update `ThemeManager` for light/dark switching

### Phase 2: Core Components
- [ ] Redesign `PrimaryButton`
- [ ] Update `GlassCard` with new material + gradient stroke
- [ ] Refresh `SectionHeader` with accent bar
- [ ] Improve `EmptyStateView`, `LoadingStateView`
- [ ] Update `LockOverlayView` with frosted effect

### Phase 3: Feature Screens
- [ ] Redesign `HomeView` hero and sections
- [ ] Update `GuidesView` with new cards
- [ ] Refresh `RegistrationView` layout
- [ ] Apply new TabBar appearance
- [ ] Update `OnboardingView` with cinematic hero

### Phase 4: Polish
- [ ] Add micro-animations (spring, parallax, glow)
- [ ] Test dark mode across all screens
- [ ] Verify accessibility (contrast, dynamic type)
- [ ] Create `ThemePreviewView` for design QA

---

## 🧪 Testing & QA

### Visual QA
- Light/Dark mode parity
- All font sizes scale with Dynamic Type
- Touch targets ≥ 44×44pt
- Color contrast ≥ 4.5:1 (text), ≥ 3:1 (UI elements)

### Motion QA
- Reduce Motion respects system setting
- Animations feel natural (not too fast/slow)
- No janky parallax or scroll stuttering

### Device Coverage
- iPhone SE (compact)
- iPhone 14 Pro (standard)
- iPhone 14 Pro Max (large)
- iPad (responsive layout)

---

**Version**: 2.0 — Apple × OpenAI × Monobank redesign  
**Date**: 2025  
**Status**: Ready for implementation 🚀

