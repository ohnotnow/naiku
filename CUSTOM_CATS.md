# Making a custom cat

Naiku does not depend on the bundled cat being orange. You can replace it with your own cat, another small creature, or an entirely imaginary desktop companion. The app only cares that the replacement image follows the same sprite-atlas layout.

## Ask an image-capable coding assistant

The easiest route is to give an assistant a description or reference image and ask it to generate and assemble the animation rows. This prompt is designed for Codex, but the geometry and art direction apply to other image-capable tools too:

```text
Create a custom animated cat for this Naiku repository.

Use the $hatch-pet workflow if it is available, and use image generation for
the artwork. My cat should look like: [describe colours, markings, shape and
personality]. Use [path to a reference image] as the identity reference if I
provide one.

Follow Naiku's existing sprite contract exactly:
- final file: Naiku/Resources/NaikuSpritesheet.png
- transparent RGBA PNG, exactly 1536 x 1872 pixels
- 8 columns by 9 rows; every cell is 192 x 208 pixels
- preserve the row order and frame counts in NaikuAnimations.json
- unused cells must be fully transparent

Create one canonical image of the character first. Use it as a reference for
every animation row so the face, markings, proportions, palette and outline
stay consistent. Generate rows separately, then assemble them deterministically;
do not ask an image model to draw the complete atlas in one attempt.

Keep the design simple enough to read at roughly 72 pixels high. Use a compact
silhouette, clear poses, flat shading and no scenery, text, grid lines, floor
shadows, motion trails or detached effects. Keep every pose inside its own cell.

Show me a contact sheet and animation previews before replacing the bundled
asset. After I approve it, install the PNG, leave NaikuAnimations.json unchanged,
run the tests, build the app and tell me where the built app is. Do not commit.
```

If your assistant does not have a pet-specific workflow, it can still follow the same process: make a single reference design, generate each row using that design as an input, remove the background, cut out the frames, and place them on the fixed transparent canvas.

## Atlas layout

The atlas is `1536×1872`: eight columns by nine rows of `192×208` cells. Rows are counted from the top, and every animation begins in column 0.

| Row | Animation | Frames | Purpose |
| ---: | --- | ---: | --- |
| 0 | `idle` | 6 | Breathing and blinking |
| 1 | `running-right` | 8 | Walking or running to the right |
| 2 | `running-left` | 8 | Walking or running to the left |
| 3 | `waving` | 4 | Signals that click-to-chat is ready |
| 4 | `jumping` | 5 | Anticipation, lift, peak, descent and landing |
| 5 | `failed` | 8 | Reserved reaction animation |
| 6 | `waiting` | 6 | Resting and longer naps |
| 7 | `running` | 6 | Front-facing or vertical movement |
| 8 | `review` | 6 | Reserved focused/thinking animation |

Clear every unused cell after a row's final frame. The exact frame timings live in [`NaikuAnimations.json`](Naiku/Resources/NaikuAnimations.json); you do not need to change that file when keeping these frame counts.

`failed` and `review` are included for compatibility and possible future behaviour. The current desktop cat does not select them, but completing them keeps the atlas ready for later features.

## What makes the animation work

- Keep the character's face, markings, proportions and colours consistent in every row.
- Preview at about 72 pixels high. Fine fur detail and tiny accessories that look good in the source image may disappear in the app.
- Keep a little transparent padding around each pose. Nothing should touch or cross a cell boundary.
- Make the first `idle` frame a good still image because Reduce Motion may leave Naiku on it.
- Make the first and last poses of a loop flow into one another without an obvious jump.
- Mirror `running-right` to make `running-left` only when the design is genuinely symmetrical. Redraw it if the cat has one-sided markings or accessories.
- Show movement through the pose rather than speed lines, dust, floor shadows or effects floating beside the character.
- If an image generator cannot produce transparency directly, use a flat background colour that does not occur anywhere in the character, then remove it completely before assembly.

Generating one row at a time is much more reliable than requesting a finished sprite sheet. If one row drifts away from the reference or contains a bad pose, regenerate that row rather than starting the whole cat again.

## Install and check the cat

Replace:

```text
Naiku/Resources/NaikuSpritesheet.png
```

Check the dimensions and alpha channel:

```sh
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  Naiku/Resources/NaikuSpritesheet.png
```

The result should report `1536`, `1872`, and `hasAlpha: yes`.

Run the tests and build into the repository's `build` directory:

```sh
xcodebuild \
  -project Naiku.xcodeproj \
  -scheme Naiku \
  -destination 'platform=macOS' \
  test \
  CODE_SIGNING_ALLOWED=NO

xcodebuild \
  -project Naiku.xcodeproj \
  -scheme Naiku \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  build

open build/Build/Products/Debug/Naiku.app
```

Watch Naiku idle, stroll in both directions, jump and settle down. Move the pointer onto a stationary Naiku and wait for the wave to check that row too.

Only commit artwork that you created or have permission to redistribute. A reference photo, generated image service, or borrowed character may have terms that are different from Naiku's MIT Licence.
