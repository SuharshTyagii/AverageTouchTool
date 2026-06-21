# AverageTouchTool — promo video (Remotion)

A ~31-second promo built with [Remotion](https://www.remotion.dev). It reuses
the site's "trackpad telemetry on graph paper" identity: animated gestures on a
trackpad with live readouts, the action library, feature highlights, screenshot
windows, and an outro.

## Setup

```bash
cd video
npm install
```

## Preview (Remotion Studio)

```bash
npm run dev
```

Opens the studio at http://localhost:3000 — scrub the `Promo` composition.

## Render the video

```bash
npm run render        # -> out/averagetouchtool-demo.mp4  (1920x1080, 30fps)
npm run still         # -> out/demo-poster.png            (poster frame)
```

Then copy the outputs into the website:

```bash
cp out/averagetouchtool-demo.mp4 ../web/assets/
cp out/demo-poster.png ../web/assets/      # optional
```

## Add real screenshots (the "live" footage)

The `Screens` scene renders styled placeholder windows by default so it builds
with zero assets. To use real screenshots, drop PNGs in `public/screens/` and
set their filenames in `src/scenes/Screens.tsx`. See `public/screens/README.md`.

## Structure

- `src/Root.tsx` — registers the `Promo` composition (930 frames @ 30fps)
- `src/Promo.tsx` — the scene timeline (`<Series>`)
- `src/scenes/` — Title, GestureDemo, Actions, Features, Screens, Outro
- `src/components/` — `Pad` (animated trackpad), `Readout`, `GraphPaper`
- `src/theme.ts` — colors + fonts (shared identity)

## Note on versions

All `remotion` / `@remotion/*` packages must share one version. If `npm install`
reports a mismatch, run `npm run upgrade` to align them.
