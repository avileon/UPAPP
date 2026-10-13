# Night Glow — the UP look

Approved mockup: the "UP — עיצוב לילי זוהר" Design canvas (5 screens: Go Live, room, match, chat, profile).

## Colour (lib/core/theme/palette.dart)

| Role (field) | Dark | Meaning |
|---|---|---|
| background | `#09080F` | the room at night |
| surface / surfaceHigh | `#14121D` / `#1C1A28` | cards, bubbles, the nav glass |
| amber → **pink** | `#FF4F7B` on `#1A0710` | the human moment: UP, match, primary action |
| cyan → **mint** | `#4DF2B0` on `#062419` | the signal: Live, room, verification |
| muted / dim | `#A7A3B8` / `#7D7891` | secondary text |

The field names stay `amber`/`cyan` — they name the role, not the hue.

## Type (assets/fonts, OFL)

* **Rubik** 500–900 — display, headlines, wordmark.
* **IBM Plex Sans Hebrew** 400–700 — body and labels.

## Signature moves

* Ambient pools of light (accent + violet) behind every screen — `UpScaffold`.
* Floating glass nav pill with blur — `UpNavBar`.
* Go Live is a breathing pink orb; Live turns it into a mint ring — `home_tab.dart`.
* Primary buttons and the UP circle glow in their own colour; nothing else has shadows.
* Selected intent tiles are filled pink.
* Match: the two faces overlap with a glowing "UP" seal between them.
