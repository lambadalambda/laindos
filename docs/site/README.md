# Interactive Site Build

`docs/site/` contains the JSX source for the interactive documentation. Production pages are built into `build/site/`:

```sh
make site
```

By default, `make site` rebuilds `build/shell_monkey.img`, copies it into `build/site/`, and cache-busts the browser image URL by content hash. To build the docs without a browser image, use an explicit empty image value:

```sh
make site SITE_IMAGE=
```

To use a custom prebuilt image, pass it explicitly with `SITE_IMAGE=path/to/image.img`.

The build emits real static HTML pages for the top-level routes:

```text
index.html
boot.html
dosapi.html
tests.html
filesystem.html
memory.html
programs.html
shell.html
mouse.html
emulators.html
glossary.html
run.html
```

Boot-path subsections are regular anchors such as `boot.html#s4`.

Production pages load one precompiled `app.js`; they do not use browser-side Babel. The static HTML is pre-rendered so links have real content before JavaScript takes over. Glossary popups are CSS hover/focus affordances in the static HTML. The emulator still requires JavaScript.

The shared sidebar includes a prominent `View Actual Source` link to `https://github.com/lambadalambda/laindos` so readers can always find the repository from any generated page.

External browser assets are intentionally not vendored into the repository:

- React and ReactDOM are loaded from exact `18.3.1` UMD URLs on unpkg.
- v86 `libv86.js` and `v86.wasm` are loaded from exact `0.5.359+ge37189a` jsDelivr URLs.
- The v86 BIOS blobs are loaded from `raw.githubusercontent.com/copy/v86/e37189a/bios/` because those files are not exposed by the pinned npm package.
- The generated `shell_monkey.img` URL includes a `?v=<sha256>` query when the site build has an image, so deployed pages change the image URL when the image bytes change.

GitHub Pages runs `make site` and verifies the generated HTML, `app.js`, and image exist before upload.
