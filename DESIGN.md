# DESIGN.md: DOS Rescue Retro Pixel Art 128-bit Edition

## Design Read
Reading this as: Interactive DOS/CMD learning game for SMK PPLG students, in a **Retro Pixel Art 128-bit (Endesga-32 inspired)** classic RPG/arcade UI language, dial **ENERGY 2 / RHYTHM 2 / MOTION 2**.

## Dials & Craftsmanship Rules
- **ENERGY 2 (Balanced Retro-Crisp):** Hand-crafted 128-bit pixel frames with notched corners, crisp 2px outlines, corner rivets, and physical 3D button lips inspired by *Eastward*, *Sea of Stars*, *Celeste*, and *Mega Man Battle Network*. No generic web-app rounded pills, no neon blur glows, no decorative capsule badges.
- **RHYTHM 2 (Consistent RPG Window Shell, Varied Task Composition):** Single-layer navigation with zero duplicated buttons. Login centers 1 focused RPG card with 2 quick buttons beneath; Main Hub combines 1 compact top bar, 1 gold-framed personal rank strip, and a 5-stage map where the active next stage stands out in gold; Minigames dedicate >= 80% of screen height to the monitor puzzle and command block deck beneath 1 slim HUD row; Final Report presents dense tabular score and log recaps.
- **MOTION 2 (Purposeful Tactile Micro-Juice):** Physical 3px button depression on press, brief `offset_transform_scale` settle pop on tap, short damped horizontal shake on wrong answer or form error, and star-burst chime on stage completion. Zero endless idle pulses or floating loops (R-19).

## Color Palette (2 Core + 1 Single Accent + Neutrals, WCAG AA Verified)
- **Core #1 (Deep Pixel Indigo & Slate-Blue):**
  - Canvas Background: `#181425` (with low-contrast `64x64` tiled lab circuit pattern `bg_tile.png` using `#1E1A30` / `#13101F`).
  - RPG 9-Slice Window Panel: `#262B44`, 2px outer outline `#181425`, inner top/left bevel `#5A6988`, inner bottom/right shadow `#1A1C2C`.
  - Tactile Command Keycap Chip: `#3A4466` (`#FFF5E4` text, 8.84:1).
- **Core #2 (Royal Pixel Blue & Deep CRT Ink):**
  - DOS Simulation Monitor Interior: `#12171D` inside metallic slate pixel monitor bezel (`#3A4466` / `#5A6988`).
  - Secondary Tactile Button / Selected Chip: `#2B59C3` (`#FFFFFF` text, 6.33:1; hover `#3366D9`, 5.19:1; pressed `#1F449C`, 8.88:1).
- **Single Deliberate Accent (Arcade Gold CTA & Active Stage Highlight):**
  - Normal `#FEAE34` (9.71:1 with `#181425`), Hover `#FEE761` (14.43:1 with `#181425`), Pressed `#E48E24` (7.03:1 with `#181425`).
  - Reserved strictly for the primary CTA on each screen (`MULAI MAIN`, next active stage `MAIN`, `CEK JAWABAN` / `LANJUT >`, `UNDUH CSV`), the personal rank frame (`panel_gold.png`), and keyboard focus brackets (`btn_focus.png`).
- **Text Neutrals:**
  - Primary Text (Warm Pixel Cream): `#FFF5E4` (16.67:1 on `#181425`, 12.86:1 on `#262B44`, 16.67:1 on `#12171D`).
  - Secondary Text (Cool Pixel Silver): `#C0CBDC` (11.00:1 on `#181425`, 8.48:1 on `#262B44`, 10.99:1 on `#12171D`).
- **Semantic Status Only (Always paired with text tags `[OK]` / `[ERR]` / `[ALLOW]` / `[DENY]` / `[INFO]`):**
  - Success Green: `#63C74D` on `#12171D` (8.41:1) and `#142B1D` (7.04:1).
  - Error Coral: `#FF8599` on `#12171D` (7.78:1) and `#3B1522` (6.89:1).
  - Warning / Highlight Gold: `#FEE761` on `#12171D` (14.42:1) and `#262B44` (11.13:1).

## Typography & Pixel Rendering (R-06)
- **Crisp Nearest Filtering:** `rendering/textures/canvas_textures/default_texture_filter=0` ensures all 9-slice frames, `16x16` icons (displayed at exact 2x = `32x32`), and `bg_tile.png` stay razor sharp with zero bilinear blur.
- **Pixel Display Font (`res://assets/pixel_ui/pixel_display.fnt`):** Custom pixel-by-pixel bitmap font reserved strictly for game title, headings, stage titles, score numbers, and short button CTAs to establish classic 128-bit RPG identity.
- **Readable UI Body Font:** Clean sans-serif default for mission instructions, form prompts, and Buku Saku explanations so long text stays comfortable to read on `390x844` mobile screens without eye strain.
- **Monospace Code Font:** Reserved strictly for real DOS/CMD command prompts, directory trees, file names, and terminal simulation outputs inside `panel_monitor.png`.

## Navigation Architecture: 3 Classic Screens, 1 Layer, Zero Duplication (R-24, R-26)
1. **Screen 1 (Title & Login, `login_screen`):** Centered `DOS RESCUE` pixel header, optional saved-session resume strip, 1 compact login card (`Nama Lengkap`, `[PPLG A]` / `[PPLG B]`, `Absen` stepper, 1 gold `[MULAI MAIN]` button), and exactly 2 quick buttons below (`[PERINGKAT]`, `[MATERI]`).
2. **Screen 2 (Stage Map, `main_hub`):** 1 single top bar (`[< KELUAR]` + identity on left; `[PERINGKAT]`, `[MATERI]`, `[RAPOR]`, `[SFX]` on right), 1 gold-framed personal info strip (`Kamu rank X dari Y Peserta`, `Rata-rata`, `Progres X/5`), and 5 large stage cards (`STAGE 1` to `STAGE 5`) with 3-star ratings and clear action buttons (`[MAIN]` in gold for next stage, `[ULANG]` for finished stages).
3. **Screen 3 (Minigame, `BaseMinigame` + `mg1`..`mg5`):** 1 slim top HUD row (`[< MENU]`, `STAGE X (1/4)`, `SKOR`, `[? MATERI]`, `[SFX]`), middle mission + pixel monitor + command chip deck (>= 80% viewport area), and bottom row with max 2 buttons (`[ULANG]` and gold `[CEK JAWABAN]` -> `[LANJUT >]`).
4. **Simple 1-Click / `ESC` Overlays:** `leaderboard_modal` (with `LOADING`, `EMPTY`, `ERROR`, `NO_URL` states + personal rank + 3 scope filters) and `buku_saku_modal` (6 audited tabs in pixel monitors), plus `final_report` (1 slim top bar `[< MENU]` + `[SISWA BARU]`, score recap, `[KIRIM SHEETS]` + `[UNDUH CSV]`, detailed attempt logs).

## Written Purpose Decisions (R-31 & Purpose-Gate)
- **Why `bg_tile.png` retro circuit tile pattern? (R-07):** Low-contrast pixel tile pattern (`#181425` / `#1E1A30`) establishes the retro computer lab world plane behind floating RPG window panels without competing with foreground readability.
- **Why custom `16x16` pixel icons at 2x (`32x32`)? (R-04):** Every icon maps directly to its concrete game function (trophy for leaderboard, book for handbook, terminal for syntax debugger, folder for directory maze, lock for wildcard filter, play for flowchart/start, report for CSV/script output, sound for audio toggle, star for stage mastery). No generic AI sparkles or Lucide strokes.
- **Why physical 3D button lips and notched pixel borders? (R-11, R-12):** Replaces flat rounded web boxes with tactile hardware/arcade depth; depth shadow sits only on clickable buttons and recessed monitor wells to separate interactive controls from static panels.
- **Why single Arcade Gold accent `#FEAE34` / `#FEE761`? (R-01, R-29):** Directs students immediately to the next primary action on every screen while keeping cool slate-blue and royal blue calm for secondary tools.
- **Why dark `#181425` / `#12171D` theme? (R-21):** Authentic DOS/CRT terminal subject matter combined with 128-bit indie pixel RPG framing gives high legibility in classroom lighting and avoids harsh white glare during prolonged lab practice.
- **Why varied card hierarchy on Stage Map? (R-14):** The next recommended stage receives the gold frame and gold CTA so students know their next step in under 2 seconds, while finished stages show earned pixel stars and a calmer blue `[ULANG]` button.
