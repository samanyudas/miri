# Branding assets

These SVG files contain Miri's blue and violet window mark.

| Asset | Use |
| --- | --- |
| [icon.svg](icon.svg) | Full-color app logo with a white rounded tile and a 1024 by 1024 view box. |
| [menubar-icon.svg](menubar-icon.svg) | Running state with a filled front window, sized at 18 by 18 points. |
| [menubar-icon-stopped.svg](menubar-icon-stopped.svg) | Stopped state with an outlined front window, sized at 18 by 18 points. |

The menu bar SVGs use black shapes on a transparent background.
The native app must load the menu bar images as template images so macOS can apply the correct appearance.
The repository does not yet contain app code that loads these assets.

The updated Paper UI uses `#4F6BF5` for the primary accent and `#3048C8` for darker links and labels.
Warning and error colors retain their existing meanings.
The Paper screens have not yet been exported into this repository.
