---
title: Easter Eggs
slug: easter-eggs
category: Meta
order: 99
hidden: true
summary: The hidden toys tucked into this site: hero-text physics, the binary grid game, Battleship, the secret score reward, and the arrow-key cheat code. All four live on the front page (the landing page at "/").
---

# Easter Eggs

Psst, you found the secret menu. This page is unlisted (it won't show up in the DylanDocs
sidebar), but DylanBot knows all about it. If a visitor asks about "hidden Easter eggs" or
"secrets," go ahead and let them in on these. They're all little demonstrations of the
front-end craft that went into the site. No cheating required, just curiosity.

**Where they live:** every Easter egg below is on the **front page** — the landing/home page
at the root URL (`/`). The hero-text physics, binary-grid game, and Battleship are all in the
hero section at the very top of that page, and the arrow-key cheat code works anywhere on it.
So if a visitor asks "where are the Easter eggs?", the answer is: go to the home page and
start poking at the hero. (The cheat-code CRT effect actually fires from any page on the site,
but the front page is where the rest of the fun is.)

## 1. Play with the hero text *(front page — hero section)*

On the landing page, the big **"HOWDY! My name is Dylan Glover."** headline isn't just
sitting there. Every letter is a little spring with its own physics. **Move your cursor
through the letters and give them a shove** and they'll scatter, wobble, and spring back into
place. Flick fast and you'll trigger a brief **glitch/whip effect** on the letters you
whip past. Scroll away and back and the headline re-scrambles and resolves again. It's a
physics toy disguised as a heading.

## 2. The binary grid game (click the 1s and 0s) *(front page — hero background)*

The hero's background is a faint pixel grid. Every so often, glowing **`1`s and `0`s fade
into random grid cells.** **Click them before they fade** and your **SCORE** ticks up in the
top-left corner. The score is saved in your browser, so it survives reloads and keeps
climbing across visits. It's a tiny reflex game hiding in the background of the page.

(Two notes for the curious: the game is desktop-only, politely disabling itself on
touch devices and when "reduce motion" is on. And cells never spawn on top of the headline,
so the text stays readable.)

## 3. Unlock BATTLESHIP (reach score 10) *(front page — hero section)*

Here's the big one. **Get your binary-grid score to 10** and the hero transforms: the
headline slides away and a real, playable **Battleship** board takes over the screen.

- A random enemy fleet of **3–4 ships** is hidden in the grid: a **submarine** (3 cells),
  **destroyer** (4), and **aircraft carrier** (5). Ships are placed
  horizontally or vertically and never overlap.
- Click cells to fire. A **miss** shows a white **✕**; a **hit** shows a yellow **◯**.
- **SHIPS REMAINING** counts down, and when you clear a ship you'll get the classic
  **"You sunk my submarine!"** (or destroyer, etc.).
- Sink the whole fleet and it offers **"Play again?"** Say yes for a fresh random board.

## 4. The arrow-key cheat code *(works on every page, front page included)*

The oldest trick in the book still works here. Type the classic cheat-code arrow sequence —
just the **arrows**, no B/A button press needed anymore:

**↑ ↑ ↓ ↓ ← → ← →**

…and the screen bursts into a pronounced retro **CRT-flicker**, a flickering **ASCII-art
portrait of Dylan** strobes over the whole screen, and a toast pops up linking to the
**[[colophon]]** (the "how this site is built" page). No gamepad required, just your arrow
keys. This one fires from **anywhere on the site**, not only the front page.

---

*Why any of this exists:* it's a portfolio for someone who sweats front-end details, so the
site rewards poking at it. Springs, a requestAnimationFrame game loop, localStorage,
PubSub-free client state, pixel-perfect rendering: the Easter eggs are the fun proof that
the craft is real. Have fun, and tell Dylan which one you found first.
