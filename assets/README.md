# Branding assets

These SVG files contain Miri's blue and violet window mark.

| Asset | Use |
| --- | --- |
| [icon.svg](icon.svg) | Full-color app logo with a white rounded tile and a 1024 by 1024 view box. |
| [menubar-icon.svg](menubar-icon.svg) | Running state with a filled front window, sized at 18 by 18 points. |
| [menubar-icon-stopped.svg](menubar-icon-stopped.svg) | Stopped state with an outlined front window, sized at 18 by 18 points. |

The menu bar SVGs use black shapes on a transparent background.
The native app must load the menu bar images as template images so macOS can apply the correct appearance.
`scripts/build-app.sh` builds the app icon from `icon.svg` and copies the menu bar SVGs into the bundle, which the app loads as template images.
Miri Developer swaps the blue and violet colors of `icon.svg` for yellow when `scripts/build-app.sh` builds its icon, so it never passes for the released Miri.
The same build changes the opacity of the two rear windows, because pale yellow windows blend together on the white tile.
The released Miri uses `icon.svg` unchanged.

The updated Paper UI uses `#4F6BF5` for the primary accent and `#3048C8` for darker links and labels.
Warning and error colors retain their existing meanings.
The Paper screens have not yet been exported into this repository.
