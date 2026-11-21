# DESIGN.md: DOS Rescue Dark Modern Stardew-Craft Retro Pixel Art Edition

## Design Read
Reading this as: Interactive DOS/CMD learning game for SMK PPLG students in a **Dark Modern Stardew-Craft Retro Pixel Art** UI language (carved beveled indigo-slate frames with golden-brass corner rivets, smoked slate-indigo HUD bar, deep CRT monitor wells, physical 3px 3D arcade buttons), dial **ENERGY 2 / RHYTHM 2 / MOTION 2**.

## Dials & Craftsmanship Rules
- **ENERGY 2 (Cozy Dark Pixel Craft):** Hand-crafted 9-slice RPG window frames (`#262B44` well, `#3A4466` / `#607294` / `#181B2B` carved bevels, `#141020` `2px` notched outline, warm brass-gold corner rivets `#FEAE34` / `#FEE761`) floating above a calm low-contrast lab circuit/floor tile (`#181425`). Zero generic web-app rounded pills, zero neon glow blur, zero decorative capsule badges.
- **RHYTHM 2 (One-Layer Navigation, Steady Scroll Areas):** Login centers 1 carved RPG card with manual `Absen` numeric input + 2 quick buttons (`[PERINGKAT]`, `[MATERI]`); Main Hub shows 1 dark header bar, 1 gold-rimmed rank strip, and 5 stage cards highlighting the next recommended stage in gold; Minigames lock heavy workspace panels (`URUTAN FLOWCHART` and `SIMULASI MONITOR DOS` in Stage 2) inside internal `ScrollContainer` regions so adding blocks never shifts page height; Final Report presents dense tabular score/log recaps.
- **MOTION 2 (Tactile Micro-Juice):** Physical `3px` downward depression on 3D button press, crisp `offset_transform_scale` settle pop, short horizontal shake on validation or wrong answer, and staggered star-burst chime on stage completion. Zero idle pulse/float loops (R-19).

## Color Palette (2 Core + 1 Single Accent + Neutrals, WCAG AA Verified)
- **Core #1 (Deep Pixel Indigo & Carved Slate-Blue):**
  - Canvas Backdrop: `#181425` with subtle `64x64` lab circuit tile (`#211D35` / `#120F1D`).
  - Top HUD Header Bar (`panel_header.png`): `#1F233A` with brass corner pins and `#FEAE34` lower gold rail.
  - RPG Card Frame (`panel_rpg.png`): `#262B44` interior surrounded by carved `#3A4466` / `#607294` bevels and brass corner rivets (`#FEAE34` / `#FEE761`).
  - Command Keycap Chip (`btn_chip_normal.png`): `#3A4466` (`#FFF5E4` cream text, 8.84:1; hover `#46527A`).
- **Core #2 (Royal Pixel Blue & Deep CRT Ink):**
  - DOS Monitor & Text Inputs (`panel_monitor.png`, `input_box.png`): Deep CRT `#12171D` inside metallic slate bevels (`#3A4466` / `#5A6988`).
  - Secondary Interactive Button & Selected Chip: Royal Blue `#2B59C3` (`#FFFFFF` text, 6.33:1; hover `#3366D9`, 5.19:1; pressed `#1F449C`, 8.88:1).
- **Single Deliberate Accent (Arcade Honey Gold CTA & Highlights):**
  - Gold CTA (`btn_gold_*.png`): Normal `#FEAE34` (9.71:1 with `#181425`), Hover `#FEE761` (14.43:1), Pressed `#E48E24` (7.03:1).
  - Double-ring Focus Halo (`btn_focus.png`): Outer `#141020` halo + inner `#FEE761` ring.
- **Text Neutrals & Semantic Status (Always paired with `[OK]` / `[ERR]` / `[ALLOW]` / `[DENY]` / `[INFO]`):**
  - Primary Cream `#FFF5E4` (12.86:1 - 16.67:1), Secondary Silver `#C0CBDC` (8.48:1 - 11.00:1), Headings `#FEE761` (11.13:1 - 14.42:1).
  - Success `[OK]` Green `#63C74D`, Error `[ERR]` Coral `#FF8599`, Info `[INFO]` Sky `#87E0FF`.

## Typography & Pixel Rendering (R-06)
- `rendering/textures/canvas_textures/default_texture_filter=0` ensures all carved bevels, `16x16` icons (`32x32` at 2x), and `bg_tile.png` stay crisp with zero blur.
- `pixel_display.fnt` for headings, stage labels, scores, and short CTAs; sans-serif for mission wording and manual input; Monospace inside CRT monitors.

## Written Purpose Decisions (R-31 & Purpose-Gate)
- **Why dark `#262B44` / `#181425` palette with Stardew carved bevels and brass corner rivets? (R-07, R-21):** Combines low-glare classroom legibility around authentic `#12171D` DOS CRT monitors with tactile golden-rivet RPG craftsmanship.
- **Why fixed-height internal `ScrollContainer` on Flowchart sequence in MG2? (R-03, R-12):** Prevents card expansion from pushing the command block bank downward while tapping, keeping mobile and desktop input anchored in place.
- **Why manual `Nomor Absen` input & single-flight `BATCH_SYNC`? (R-08, C-4):** Direct numeric entry avoids stepper repetition while queued batch sync eliminates overlapping requests and status flashes.
