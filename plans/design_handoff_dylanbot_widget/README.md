# Handoff: DylanBot Chat Widget

## Overview
A corner chat widget ("DylanBot") for a personal portfolio site, styled to match the site's pixel/retro-terminal aesthetic. Collapses to a slim header bar with an unread-message badge; expands upward into a full chat panel while the header stays anchored in place.

## About the Design Files
The bundled file (`DylanBot Widget.dc.html`) is a **design reference built in HTML**, not production code to copy verbatim. It shows exact layout, styling, and interaction behavior. Recreate this UI in the target codebase's existing environment (React, Vue, plain JS, etc.) using its established component patterns, state management, and build tooling. If the portfolio has no framework yet, plain HTML/CSS/JS matching this structure is fine.

## Fidelity
**High-fidelity.** Colors, typography, spacing, and interaction behavior below are final — implement pixel-for-pixel.

## Screens / Views

### 1. Collapsed state
- **Purpose**: Persistent, unobtrusive entry point sitting in the bottom-right corner of every page.
- **Layout**: Fixed position, `bottom: 24px; right: 24px;`. Width `302px`. Single row (flex, `align-items:center`, `gap:10px`, `padding:11px 12px`).
- **Components**:
  - Container: `background:#0d1119`, `border:2px solid #e8b923` (all 4 sides when collapsed).
  - Title text "DYLANBOT": color `#e8b923`, font `Press Start 2P`, `font-size:11px`, `letter-spacing:1px`, flex:1 (fills remaining space, pushes badge/arrow right).
  - Status dot: `7px × 7px` square, `background:#4ade80`, blinking animation (opacity 1↔0.3, 2s loop, infinite).
  - Unread badge (only rendered when collapsed AND unread count > 0): square, `min-width:18px; height:18px`, `background:#f2c14e`, `border:2px solid #0d1119`, text color `#14181f`, `font-size:9px`, centered, padding `0 3px`.
  - Toggle button: `24px × 24px` square, `background:#0d1119`, `border:2px solid #e8b923`, `color:#e8b923`, `font-size:10px`, contains an up-triangle glyph `▲` (U+25B2). Hover: `background:#1a1f2b`.

### 2. Expanded state
- **Purpose**: Full chat interface — greeting, quick-reply suggestions, free-text input, footer links.
- **Layout**: Same fixed bottom-right anchor and same `302px` width. Header row stays visually identical (same horizontal position) but its bottom border disappears (`border-bottom:none`) since a panel now sits directly beneath it. Toggle glyph flips to a down-triangle `▼` (U+25BC). Because the container is anchored via `bottom:24px` (not `top`), the added panel height pushes the container's top edge upward — the header visually "rises" while staying pinned to the same corner.
- **Panel** (below header): `border:2px solid #e8b923; border-top:none`, fixed `height:400px`, flex column with three stacked sections:
  1. **Message scroll area**: `flex:1; overflow-y:auto; padding:14px`, flex column, `gap:10px`.
     - Bot messages: left-aligned (`align-self:flex-start`), `background:#0d1119`, `border:2px solid #3a3320`, text `#f2f0e8`.
     - User messages: right-aligned (`align-self:flex-end`), `background:#f2c14e`, `border:2px solid #f2c14e`, text `#14181f`.
     - All message bubbles: `max-width:82%`, `font-size:9px`, `line-height:1.8`, `padding:8px 10px`.
     - Suggestion buttons (shown until the user sends a first message): full-width, stacked, `gap:8px`, each `background:#0d1119`, `border:2px solid #e8b923`, `color:#e8b923`, `font-size:9px`, `padding:10px 8px`, left-aligned text. Hover: `background:#1a1f2b`. Copy: "Show me Dylan's skills", "Show me Dylan's projects", "How do I get the resume?".
  2. **Input row**: `border-top:2px solid #e8b923`, flex row, `gap:8px`, `padding:10px`.
     - Text input: flex:1, `background:#05070a`, `border:2px solid #3a3320`, text `#f2f0e8`, placeholder "Ask DylanBot...", `font-size:9px`, `padding:8px`.
     - Send button: `background:#f2c14e`, `border:2px solid #0d1119`, text `#14181f`, label "SEND", `padding:0 12px`. Hover: `background:#e8b923`.
  3. **Footer links row**: `border-top:2px solid #2a2618`, flex row `justify-content:space-between`, `padding:10px 12px`, `font-size:8px`. Left group: "FULL CHAT" · "DOCS" (underlined links, color `#e8b923`, separated by `·` in `#5b6270`). Right: "LEAVE MSG" (underlined, color `#5b6270`).

## Interactions & Behavior
- **Toggle**: clicking the arrow button flips `expanded` boolean. Opening the widget also resets `unread` to 0 (badge disappears).
- **Sending a message** (via Send button or Enter key in the input): appends a user bubble, then a canned bot reply bubble; clears the input; hides the suggestion buttons permanently once the first message is sent.
- **Suggestion click**: same as sending that suggestion's label as a message.
- **Bot reply logic** (placeholder/demo — replace with real logic or an LLM call in production): keyword-matches "skill" / "project" / "resume" in the outgoing text to pick a canned response; otherwise a generic acknowledgment.
- No animation/transition was specified for the expand/collapse height change itself in this reference — add a smooth height/opacity transition (e.g. `transition: height 200ms ease` or a mount/unmount fade) when implementing, since the reference toggles instantly.
- Status dot blink: `2s` infinite, opacity `1 → 0.3 → 1`.

## State Management
- `expanded: boolean` (default `false` for the collapsed-on-load state agreed in this handoff; source file currently defaults `unread: 2` to demo the badge).
- `unread: number` — increments when new bot messages arrive while collapsed (not implemented in the reference; wire this up to real message events), resets to 0 on expand.
- `inputValue: string`.
- `showSuggestions: boolean` — true until first message sent.
- `messages: Array<{ from: 'user' | 'bot', text: string }>`.

## Design Tokens
- **Colors**:
  - Background (widget/panel): `#0d1119`
  - Input field background: `#05070a`
  - Border yellow (primary accent): `#e8b923`
  - Filled yellow (badge, send button, user bubble): `#f2c14e`
  - Muted border (message bubble, input border): `#3a3320`
  - Divider (footer): `#2a2618`
  - Text — warm white: `#f2f0e8`
  - Text — dark (on yellow): `#14181f`
  - Text — muted gray: `#5b6270`
  - Status green: `#4ade80`
- **Typography**: `Press Start 2P` (Google Font) throughout. Sizes used: `11px` (title), `10px` (toggle glyph), `9px` (body/buttons/messages/input), `8px` (footer links). `letter-spacing:1px` on the title only.
- **Borders**: `2px solid` throughout, no border-radius anywhere (hard, pixel-square corners).
- **Spacing**: header padding `11px 12px`; panel content padding `14px`; input row padding `10px`; footer padding `10px 12px`; gaps of `8–10px` between stacked elements.
- **Widget width**: `302px` fixed, both states.
- **Expanded panel height**: `400px` fixed.

## Assets
No image assets — the only "icon" is a 💬 emoji, which was removed per latest revision (header now has no icon, just title/status dot/badge/arrow). No external icons/images to source.

## Files
- `DylanBot Widget.dc.html` — the full design reference (structure + inline styles + interaction logic) for both collapsed and expanded states, plus a dark grid backdrop used only to preview the widget in context (not part of the widget itself — the widget is a `position: fixed` overlay meant to sit on top of the real site).
