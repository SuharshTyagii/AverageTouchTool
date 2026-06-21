# AverageTouchTool — website

Static landing page. No build step, no dependencies — plain HTML/CSS/JS.

## Files
- `index.html` — the page
- `styles.css` — design system + layout
- `app.js` — the interactive detection pad, copy button, scroll reveals
- `assets/favicon.svg` — icon
- `assets/averagetouchtool-demo.mp4` — **drop the rendered demo here** (see `/video`)
- `assets/demo-poster.png` — optional video poster frame

## Run locally
Just open `index.html`, or serve the folder:

```bash
cd web
python3 -m http.server 8080
# visit http://localhost:8080
```

## Deploy
Copy the `web/` folder to your server's web root (it's fully static). On
`suharshh.com` that's whatever path you want, e.g. `/averagetouchtool/`.

## To update before launch
- Replace the GitHub URL `SuharshTyagii/AverageTouchTool` if the repo name differs.
- Render the promo video into `assets/averagetouchtool-demo.mp4`.
- Optionally export a poster frame to `assets/demo-poster.png`.
