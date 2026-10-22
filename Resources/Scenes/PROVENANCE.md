# Listening-room assets

Created with the built-in `image_gen` tool. Visual reference: a user-supplied listening-room reference video, sampled at 13.934 seconds (night) and 0 seconds (day). Video frames are reference evidence only, not playback textures. The shipped scenes contain no desktop UI or original album covers. Live album art, label, platter motion, spindle, tonearm and metadata are native layers.

## listening-room-night.png

Generated source: `exec-aa206f1c-e4be-42b8-8782-8ff89ecfb60f.png` under the session's Codex generated-images folder. Input: video frame 8.

Exact prompt:

Edit target: the supplied frame from a user-provided reference video. Create a production-quality, photorealistic still background for an interactive macOS listening-room wallpaper. Preserve the exact camera perspective, warm wooden tabletop, cream plaster wall, brass-framed wall painting, right-side glowing ribbed amber glass lamp, album stand on the left, and walnut-and-ivory turntable body in the center. Preserve object positions and scale closely; output landscape at the same aspect ratio as the reference (about 1.54:1), high resolution. REMOVE ALL macOS UI including menu bar, Dock, cursor, app windows, and every icon; replace those areas naturally with the room. Replace the large upright Drake album artwork in the left wooden stand with a clean completely blank warm ivory square record sleeve, same exact four corners and perspective. Replace the album covers on the right-side small stack with tasteful abstract plain printed papers with no readable words or faces. The black vinyl record on the platter should remain black concentric grooves but its center label must be plain dark burnt orange, no printed art. REMOVE the tonearm and cartridge entirely, retaining only the round tonearm pivot at the rear right of the turntable: an interactive tonearm will be composited later. Keep the platter circular in its physical plane (an ellipse in the image) and the turntable surface pristine. No added text, words, logos, UI, borders, watermark, decorative graphics, or extra objects. Warm realistic evening light, photographic materials, detailed wood and metal, soft natural shadows. This is a room asset, not a UI mockup.

## listening-room-day.png

Generated source: `exec-02ef1cbd-2c30-41a2-bc35-02ca3079b12c.png`. Input: the generated night asset.

Exact prompt:

Edit ONLY the lighting and time of day of this exact listening-room background asset. Keep the exact pixel composition, camera, frame size/aspect ratio, perspective and location of every single object. Change the warm nighttime amber lighting into natural late-afternoon daylight: cream wall lit by soft warm sunlight from a window on the left, with broad believable diagonal Venetian-blind shadows across the plaster wall and tabletop. Turn off the bulb in the ribbed glass lamp on the right: lamp stays in the exact same place and the glass remains amber, but the bulb does not glow. Preserve the ivory blank upright sleeve, stand, turntable body, black record with plain burnt orange label, tonearm pivot with no arm, metal platter, painting, right paper stack. Do not add any tonearm or artwork or text or GUI. The sleeve corners and platter geometry must be identical to the input, because live artwork and a rotating disc will be composited into these exact locations by software. Photorealistic daylight materials and shadows. No macOS UI, menu bar, Dock, cursor, words, logos, border or watermark.

## listening-room-cutout.png

Generated source: `exec-2289b3d9-dd9f-4fd8-a557-e7d75e5cb550.png`. Input: the generated day asset. Generated with transparent background enabled. The resulting cutout moved/enlarged the objects, so its sleeve/platter landmarks are explicitly separate in `RoomGeometry.cutout`; it is not silently registered against the day/night plate. At load time, the native compositor insets the alpha matte by 3 pixels to suppress edge fringes; the source asset remains unchanged.

Exact prompt:

Background-extraction asset for a software compositor. Edit this exact 1557x1010 listening-room image. KEEP ONLY the large blank ivory record sleeve and its wooden display stand on the LEFT, and the entire walnut/ivory turntable body, platter, black record, and tonearm pivot in the CENTER. Remove the entire wall, tabletop, wall picture, lamp, paper stack on the right, and all other background pixels, replacing them with genuine transparent alpha. Do not add any tonearm. IMPORTANT: preserve the exact original canvas size, camera perspective, pixel positions and scale of the sleeve and turntable. Do not center, crop, enlarge, rotate, or rearrange the retained objects. Retain fine anti-aliased object edges and subtle contact shadows where possible, but no rectangular patch of table/wall. We will put live cover art over the sleeve and a live rotating disc over the record at their exact original coordinates. High-quality photorealistic cutout, no text or UI.
