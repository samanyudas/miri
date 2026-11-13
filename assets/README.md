# Branding assets

These files contain Miri's blue and violet window mark.

| Asset | Use |
| --- | --- |
| [AppIcon.icon](AppIcon.icon) | App icon of the released Miri, in blue, as an Icon Composer file with Light and Dark artwork. |
| [AppIcon-Developer.icon](AppIcon-Developer.icon) | App icon of Miri Developer, in yellow, with the same layers and appearances. |
| [icon.svg](icon.svg) | Full-color logo with a white rounded tile and a 1024 by 1024 view box, for documents such as the README. |
| [menubar-icon.svg](menubar-icon.svg) | Running state with a filled front window, sized at 18 by 18 points. |
| [menubar-icon-stopped.svg](menubar-icon-stopped.svg) | Stopped state with an outlined front window, sized at 18 by 18 points. |

## App icons

Each `.icon` file has three layers: the front window, the short rear window, and the tall rear window.
Each layer has a Light SVG and a Dark SVG in the file's `Assets` folder.
The background fill is a white gradient in Light and a graphite gradient in Dark.
macOS draws the rounded tile, its edge, and its shadow, so the layer SVGs contain only the windows.
macOS also makes the tinted and clear icon styles from the same layers.

Open a `.icon` file in Icon Composer, which ships inside Xcode, to see or change it.
Icon Composer can render each appearance, and so can its command-line tool, for example:

```sh
"$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool" assets/AppIcon.icon \
    --export-image --output-file dark.png --platform macOS --rendition Dark --width 512 --height 512 --scale 1
```

`scripts/build-app.sh` compiles `AppIcon-Developer.icon` with `actool` into the bundle's `Assets.car` and an `.icns` fallback.
Miri Developer is yellow so that it never passes for the released Miri.
In the Developer icon, the tall rear window is lighter and the short one more solid, because pale yellow windows blend together on the white tile.

## Menu bar icons

The menu bar SVGs use black shapes on a transparent background.
The native app must load the menu bar images as template images so macOS can apply the correct appearance.
`scripts/build-app.sh` copies the menu bar SVGs into the bundle, which the app loads as template images.

## Colors

The updated Paper UI uses `#4F6BF5` for the primary accent and `#3048C8` for darker links and labels.
Warning and error colors retain their existing meanings.
The Paper screens have not yet been exported into this repository.
