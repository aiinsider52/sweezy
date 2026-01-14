# Design Redesign — GoIT × Apple × OpenAI

## Visual Principles
- Clean, human, tech-futuristic aesthetic
- Wide whitespace, modular sections, soft color accents
- Natural motion: subtle fades, springs, parallax

## Colors
- Background (light): #FAF9F6 (Ivory), #F5F5F3 (Stone)
- Accents: Turquoise #00C8A0, Warm Green #A4E6C3, Soft Yellow #FFE066
- Text (light): Graphite #212121; (dark): white/gray80
- Gradients: Turquoise → Warm Green for primary CTAs; Soft BG gradient for hero

## Typography
- Headlines: 34–40 pt bold (SF Pro Display)
- Subhead: 22–26 pt semibold
- Body: 17 pt regular, line height 1.5
- Caption: 13 pt medium

## Layout & Spacing
- Grid: 12/16/24/32 pt rhythm; 48–64 pt between sections
- Cards: radius 16, shadow blur 8, light borders
- Hero: left text + CTA; right illustration/image; parallax on scroll

## Components
- PrimaryButton: pill, gradient (turquoise→green), soft glow, spring press
- Glass/Card: pastel or frosted background, 16 corner, md shadow
- TabBar: frosted base, animated indicator glow under active icon
- HeroView: gradient background, floating particles (light), large headline
- ChipView: capsule with #E0E0E0 border; selected: accent fill
- TextField: minimalist, rounded, pastel border; focus glow
- SectionHeader: bold + accent underline
- Empty/Loading: animated gradient pulse (no spinner)

## Motion
- Buttons: scale 0.96, quick spring
- Cards: lift 2–4 pt on hover/press
- Transitions: fade + slight slide (0.35s)
- Sheets: blur fade-in
- Reduce Motion: fall back to fades

## Dark Mode
- Background: #0C0C15
- Cards: rgba(255,255,255,0.05)
- Text: white/gray80
- Accents: keep luminous turquoise/yellow

## Implementation Map
- Theme.swift: GoIT tokens, gradients, inputs, chip borders
- Components: PrimaryButton, GlassCard, ChipView, AccentTextField, SectionHeader, Loading/Empty
- Screens: apply styles to Home, Guides, Templates, Checklists, Calculator, Map, Onboarding, Registration
- ThemePreviewView: showcase all tokens and components

## Accessibility
- High contrast, minimum 12pt text
- VoiceOver labels and hints
- Dynamic Type support in all text

---

Status: Implemented tokens, PrimaryButton, ChipView, AccentTextField, Loading pulse, previews.
Next: Apply to all screens and tab bar glow polish.
