# Film Presets

StillLight ships 27 original film/camera presets. They are inspired by familiar
film stocks, classic camera color, compact digital cameras and instant-photo
formats, but use original names and local rendering parameters.

The current product direction is Dazz-like, scene-first and sample-led: the
picker should feel like opening a drawer of physical rolls, and each roll should
be understood through a real shooting mood before the user reads any parameter.

## Flagship Rolls

| Preset | Portfolio Intent | Rendering Bias | Real Sample Direction |
| --- | --- | --- | --- |
| Humanist Color 400 | Humanistic cafes, markets and quiet street life | honeyed highlights, clean greens, forgiving midtones, light grain | cafe tables, warm interiors, market corners, daylight street scenes |
| Underpass 800 | Night street, subway, gallery and vignette-heavy atmosphere | tunnel-like edge falloff, deeper blacks, subdued color, focused center glow | museum corridors, night streets, concrete stairs, backlit architecture |
| Atelier Skin 400 | Soft portrait and window-light scenes | creamy skin, low contrast, very light grain, lifted shadows, protected highlights | close portraits, window light, editorial interiors, soft daylight skin |

These three rolls are the primary acceptance set for the current build. They
should be tested with real iPhone photos, not only generated thumbnails or UI
mock images.

## Complete Preset List

| Preset | Intent | Technical Bias |
| --- | --- | --- |
| Humanist Color 400 | Humanistic cafes, markets and daily street scenes | honeyed highlights, clean greens, light grain, light vignette |
| Underpass 800 | Night street, subway, gallery and vignette-heavy scenes | strong edge falloff, deep blacks, subdued color, no leak |
| Atelier Skin 400 | Soft portrait look | creamy skin, low contrast, very light grain, lifted shadows, protected highlights |
| Sunlit Gold 200 | Warm daylight and travel | warm temperature, soft S curve, low grain |
| Porcelain Negative 400 | Skin-friendly portraits | cool whites, soft reds, open shadows, gentle saturation |
| Silver HP5 | Monochrome documentary | zero saturation, stronger contrast, larger grain |
| Green Street 400 | Cool city street scenes | cyan-green bias, stronger contrast, medium grain |
| Cinema Tungsten 800T | Night and neon | cool shadows, high ISO grain, red-orange halation |
| Pocket Flash 400 | Disposable-camera snapshots | high contrast, high saturation, edge leak |
| Pocket CCD 2003 | Early digital compact camera | cool whites, direct contrast, low grain |
| SX Square 640 | Square instant output | low contrast, square-friendly look, instant border |
| H Natural Color 100 | HNCS-like medium-format color | neutral temperature, clean saturation, white frame |
| M Rangefinder Color | restrained rangefinder street color | gentle warmth, lower saturation, white frame |
| T Compact Gold | premium compact travel color | warm highlights, punchy midtones, white frame |
| GR Street Snap | high-contrast street snapshot | cooler shadows, direct contrast |
| Classic Chrome X | muted editorial digital-film look | restrained saturation, cyan shadows |
| Medium 500C | square medium-format portrait/still life | soft contrast, paper border |
| Holga 120 Dream | toy-camera softness | heavy vignette, leak, paper border |
| LC-A Vivid | punchy compact color | strong saturation, vignette |
| Wide Instant 800 | wide instant-photo look | warm low contrast, instant border |
| Faded SX 160 | faded instant look | low contrast, faded warmth, instant border |
| Half Frame Diary | daily half-frame notebook feel | low ISO, white frame |
| Ektar Vivid 100 | saturated daylight color | high saturation, crisp contrast |
| Tri-X Street | classic black-and-white street | strong contrast, larger grain |
| Blue CCD Night 200 | cool early-2000s digital | blue bias, clipped highlights |
| Superia Green | family snapshot color | green shadows, gentle warmth |
| Noir Cine 1600 | cinematic night monochrome | high contrast, coarse silver grain, glowing signs |

## Categories

- Featured: the main humanistic, vignette-heavy and portrait use cases.
- Portrait: skin-safe rolls with softer contrast and controlled highlights.
- Color Negative: forgiving daily rolls for travel, family and street scenes.
- Classic Camera: camera-model color behavior with frame labels.
- Instant: instant borders, lower contrast and warmer paper feel.
- Black & White: documentary tone with visible monochrome grain.
- Digital: CCD and early compact-camera looks.
- Experimental: stronger stylization such as tungsten bloom and toy-camera leak.

## Physical Film Objects

The picker is a Dazz-like object drawer instead of a plain filter list. Each
preset maps to a recognizable physical object:

- 135 color-negative paper boxes
- black-and-white film canisters
- instant film packs
- 120 / experimental paper sleeves
- disposable cameras
- half-frame diary tickets
- classic camera / CCD / medium-format camera bodies

Each preset has a separate `FilmCoverStyle` and `FilmCoverComposition` in the
roll picker. The visual profile controls:

- palette and short cover code
- center glow color and position
- paper, canister, pack, sleeve or camera-body material
- 3x3 photographic contact-sheet sample crops
- distinct package/front-cover compositions
- deterministic paper texture, package speckles and worn edges
- contact shadows and drawer depth
- layered lens reflections for camera objects

The miniature samples map roll ids and categories to nine photographic moods:
cafe table, shadow atrium, window portrait, street market, medium-format still
life, tungsten night, CCD flash table, instant desk and monochrome night. The
drawer uses a center-snapping carousel so the focused roll settles into the
middle of the shelf with light selection haptics.

## Rendering Parameters

Each preset defines both product metadata and pipeline controls:

- ISO, display name, localized name, short name and camera/model label.
- Scene tags and localized description for the picker and recommender.
- Exposure bias, temperature shift, tint shift, contrast, brightness and
  saturation.
- Tone curve and highlight/shadow behavior.
- Grain amount, grain size, vignette, halation and light leak.
- Timestamp color and border style.
- StillLight JPEG metadata written during export.

## Pipeline Focus

The current output is not a single LUT. Each preset drives a modular image
pipeline:

- 3200px high-quality processing path.
- Exposure, white balance, tint, contrast and saturation.
- Tone curve and highlight/shadow adjustment.
- `Film Rendering Profile` for local micro-contrast, midtone softness, highlight
  recovery and skin-protected finishing.
- `Tone Separation` through film-specific shadow/midtone/highlight response and
  color matrix behavior.
- Highlight-masked warm halation.
- Soft radial lens falloff.
- Stable seeded light leak.
- Luminance-aware grain and finishing texture.
- Textured paper borders, imperfect timestamp and camera/model labels.

## Frame Output

`BorderStyle.whiteFrame`, `paper` and `instant` all render a bottom frame area
with:

- selected camera / model name
- StillLight roll short name
- ISO mark
- optional timestamp

The frame should support the camera-object story: a result should feel like a
developed StillLight roll, not an anonymous exported filter.

## QA Acceptance

MVP acceptance for presets:

- All 27 presets appear in the picker with the expected category and localized
  text.
- The three flagship rolls are first-class in the featured/portrait flow and are
  validated against real sample photos.
- Switching rolls changes image rendering, frame label and roll metadata.
- Physical film objects are visually distinct at drawer scale and do not depend
  on external sample image downloads.
- White-frame, paper and instant styles render readable camera/model labels.
- Import Lab and camera capture produce consistent output for the same image,
  roll, aspect ratio and intensity.

Next-step acceptance:

- Add a real sample pack for each flagship roll: 8-12 iPhone photos covering the
  sample directions above.
- Compare current procedural rendering with future 3D LUT / `CIColorCube`
  versions under the same samples.
- Define pass/fail notes for skin tone, highlight recovery, shadow detail,
  vignette strength and grain visibility.
- Promote any new roll only after it has physical object art, localized text,
  sample direction and pipeline parameter review.
