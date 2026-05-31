# Interactive Site Build

`docs/site/` contains the JSX source for the interactive documentation. Production pages are built into `build/site/`:

```sh
make site
```

To include the bootable browser image and cache-bust it by content hash:

```sh
make monkey-demo
make site SITE_IMAGE=build/shell_monkey.img
```

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
run.html
```

Boot-path subsections are regular anchors such as `boot.html#s4`.

Production pages load one precompiled `app.js`; they do not use browser-side Babel. The static HTML is pre-rendered so links have real content before JavaScript takes over. The emulator still requires JavaScript.

External browser assets are intentionally not vendored into the repository:

- React and ReactDOM are loaded from exact `18.3.1` UMD URLs on unpkg.
- v86 `libv86.js` and `v86.wasm` are loaded from exact `0.5.359+ge37189a` jsDelivr URLs.
- The v86 BIOS blobs are loaded from `raw.githubusercontent.com/copy/v86/e37189a/bios/` because those files are not exposed by the pinned npm package.
- The generated `shell_monkey.img` URL includes a `?v=<sha256>` query when `SITE_IMAGE` is provided, so deployed pages change the image URL when the image bytes change.

GitHub Pages runs `make monkey-demo` followed by `make site SITE_IMAGE=build/shell_monkey.img` and verifies the generated HTML, `app.js`, and image exist before upload.
