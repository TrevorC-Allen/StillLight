# Film Presets

StillLight currently ships 27 original film/camera presets. They are inspired by familiar film stocks, classic camera color, compact digital cameras and instant-photo formats, but use original names and local parameters.

| Preset | Intent | Technical Bias |
| --- | --- | --- |
| Human Warm 400 | Pleasing humanistic scenes, cafes and interiors | warm creamy highlights, clean greens, medium vignette |
| Shadow Walk 800 | Moodier street, museum and architecture scenes | stronger edge falloff, deeper blacks, subdued color |
| Soft Muse 400 | Soft portrait look | warm skin, low contrast, lifted shadows, protected highlights |
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

## Frame Output

`BorderStyle.whiteFrame`, `paper` and `instant` all render a bottom frame area with:

- selected camera/model name
- StillLight roll short name
- ISO mark
- optional timestamp

## Current Pipeline Parameters

Each preset controls:

- ISO
- exposure bias
- temperature shift
- tint shift
- contrast
- brightness
- saturation
- tone curve
- grain amount and size
- vignette
- halation
- light leak
- timestamp color
- border style
- localized English / Chinese display text
- camera/model frame label
