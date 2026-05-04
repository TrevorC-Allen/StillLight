# Film Presets

StillLight currently ships 27 original film/camera presets. They are inspired by familiar film stocks, classic camera color, compact digital cameras and instant-photo formats, but use original names and local parameters.

| Preset | Intent | Technical Bias |
| --- | --- | --- |
| Human Warm 400 | Pleasing humanistic scenes, cafes and interiors | creamy warm whites, protected highlight shoulder, light grain, medium vignette |
| Shadow Walk 800 | Moodier street, museum and architecture scenes | stronger edge falloff, deeper blacks, subdued color, restrained leak |
| Soft Muse 400 | Soft portrait look | warm skin, low contrast, very light grain, lifted shadows, protected highlights |
| Sunlit Gold 200 | Warm daylight and travel | warm temperature, soft S curve, low grain |
| Soft Portrait 400 | Skin-friendly portraits | lifted shadows, low contrast, gentle saturation |
| Silver HP5 | Monochrome documentary | zero saturation, stronger contrast, larger grain |
| Green Street 400 | Cool city street scenes | cyan-green bias, stronger contrast, medium grain |
| Tungsten 800 | Night and neon | cool base, high ISO grain, warm halation |
| Pocket Flash | Disposable-camera snapshots | high contrast, high saturation, edge leak |
| CCD 2003 | Early digital compact camera | cool whites, direct contrast, low grain |
| Instant Square | Instant-photo output | low contrast, square-friendly look, instant border |
| HNCS Natural | HNCS-inspired medium-format color | neutral temperature, clean saturation, white frame |
| M Rangefinder Color | restrained rangefinder street color | gentle warmth, lower saturation, white frame |
| T Compact Gold | premium compact travel color | warm highlights, punchy midtones, white frame |
| GR Street Snap | high-contrast street snapshot | cooler shadows, direct contrast |
| Classic Chrome X | muted editorial digital-film look | restrained saturation, cyan shadows |
| Medium 500C | square medium-format portrait/still life | soft contrast, paper border |
| Holga 120 Dream | toy-camera softness | heavy vignette, leak, paper border |
| LC-A Vivid | punchy compact color | strong saturation, vignette |
| Instant Wide | wide instant-photo look | warm low contrast, instant border |
| SX Fade | faded instant look | low contrast, faded warmth, instant border |
| Half Frame Diary | daily half-frame notebook feel | low ISO, white frame |
| Ektar Vivid 100 | saturated daylight color | high saturation, crisp contrast |
| Tri-X Street | classic black-and-white street | strong contrast, larger grain |
| Cyber CCD Blue | cool early-2000s digital | blue bias, clipped highlights |
| Superia Green | family snapshot color | green shadows, gentle warmth |
| Noir Soft | soft night monochrome | low saturation, lifted shadows |

## Categories

- Featured: scene-first rolls for the main humanistic use cases
- Portrait: soft skin-first portrait rolls
- Color Negative: forgiving everyday film rolls
- Classic Camera: camera-model color behavior and frame labels
- Instant: instant-photo borders and softer contrast
- Black & White: monochrome grain and documentary tone
- Digital: CCD / early compact-camera looks
- Experimental: stronger stylization such as tungsten bloom and toy-camera leak

## Physical Film Objects

The picker is a Dazz-like object drawer instead of a plain filter list. Each preset maps to a recognizable physical object:

- 135 color-negative paper boxes
- black-and-white film canisters
- instant film packs
- 120 / experimental paper sleeves
- disposable cameras
- half-frame diary tickets
- classic camera / CCD / medium-format camera bodies

Each preset has a separate `FilmCoverStyle` in the roll picker. The cover style controls:

- palette
- center glow color and position
- paper, canister, pack, sleeve or camera-body material
- per-roll miniature sample scene
- deterministic paper texture and worn edges
- contact shadows and drawer depth
- layered lens reflections
- short cover code

The sample scenes map each roll id / category to visual moods such as cafe tables, low-key street atriums, soft portraits, neon nights, CCD campus scenes, instant tabletops, beaches, flowers and half-frame diaries. This keeps the library visually scannable and mood-led without shipping heavy external sample-image assets.

## Current Pipeline Focus

The current output is not a single LUT. Each preset drives a modular image pipeline:

- 3200px high-quality processing path
- exposure, white balance, tint, contrast and saturation
- tone curve
- highlight / shadow adjustment
- film rendering profiles for local micro-contrast, midtone softness, highlight recovery and skin protection
- film-specific color response matrix
- highlight-masked warm halation
- soft radial lens falloff
- stable seeded light leak
- skin-protected finishing texture and luminance-aware grain
- textured paper borders, imperfect timestamp, camera/model labels

## Frame Output

`BorderStyle.whiteFrame`, `paper` and `instant` all render a bottom frame area with:

- selected camera / model name
- StillLight roll short name
- ISO mark
- optional timestamp
