// page_mouse.jsx - PS/2 mouse input and INT 33h behavior.

const MOUSE_FLOW = [
  ["Install", "The kernel hooks INT 33h for DOS mouse calls and INT 74h for IRQ12 PS/2 packets."],
  ["Initialize", "Boot code enables the auxiliary PS/2 device, resets defaults with F6, starts streaming with F4, and unmasks IRQ12."],
  ["Decode", "Three-byte PS/2 packets update raw motion counters, scaled screen position, button state, and edge counts."],
  ["Serve", "INT 33h calls poll pending PS/2 bytes first, then return position, motion, press/release, range, or ratio state."],
  ["Notify", "If AX=000Ch registered a callback mask, movement and button edges call the game with DOS mouse registers."],
];

const MOUSE_CALLS = [
  ["AX=0000h", "Reset", "AX=FFFFh, BX=2; resets position, ranges, buttons, counters, callback, ratio."],
  ["AX=0001h", "Show cursor", "Increments the visibility counter only; LainDOS does not draw a software cursor."],
  ["AX=0002h", "Hide cursor", "Decrements the visibility counter only."],
  ["AX=0003h", "Get position", "Returns BX=buttons, CX=x, DX=y."],
  ["AX=0004h", "Set position", "Takes CX=x, DX=y; clamps to the active range."],
  ["AX=0005h", "Press data", "BX selects left/right; returns AX=buttons, BX=count, CX:DX=last press, then clears count."],
  ["AX=0006h", "Release data", "Same shape as press data, but for release edges."],
  ["AX=0007h", "Set X range", "Takes CX/DX in either order, stores min/max, clamps current x."],
  ["AX=0008h", "Set Y range", "Takes CX/DX in either order, stores min/max, clamps current y."],
  ["AX=000Bh", "Get motion", "Returns raw CX/DX mickey counters and clears them."],
  ["AX=000Ch", "Set callback", "Takes CX=event mask and ES:DX=far callback."],
  ["AX=000Fh", "Set ratio", "Takes CX/DX mickey-to-pixel ratio; zero becomes one, values cap at 2048."],
];

const MOUSE_UNSUPPORTED = [
  "Unsupported INT 33h functions fall through as no-ops. There is no cursor bitmap drawing, cursor shape API, save/restore driver state, sensitivity query, light pen emulation, wheel data, or version string service.",
  "Show/hide only update the visibility counter because current target games draw their own cursors or just need mouse state.",
  "Button support is left and right only. The reset return advertises two buttons, matching the code path and tests.",
  "The implementation is not a TSR mouse driver; it is part of the kernel and is cleared on reset or process termination where needed.",
];

const MOUSE_TARGETS = [
  ["Monkey Island", "Initializes INT 33h and polls press data plus raw motion during startup/gameplay."],
  ["Monkey Island 2", "Save/load automation depends on reliable QEMU mouse movement and position clamping."],
  ["Stunt Island", "Needed AX=0006h release-query data before buttons on the competition prompt activated."],
  ["Ascendancy", "Uses callbacks and mickey/pixel ratio; AX=000Ch plus AX=000Fh made the 86Box play-screen mouse usable."],
];

const MOUSE_TESTS = [
  ["Basic API", "scripts/test_mouse.py", "Boots MOUSE.EXE and verifies reset, set/get position, ranges, button data, and motion counters."],
  ["Callback edges", "scripts/test_mousecb.py", "Injects QEMU monitor mouse_move and button events, then verifies callback and press/release data."],
  ["Ratio and clamps", "scripts/test_mouseratio.py", "Exercises AX=000Fh scaling, edge clamping, and raw motion delivery."],
  ["Hardware probe", "tests/programs/mousehw.asm", "Optional program bundled by scripts/build_monkey.py for HMP-injected hardware motion checks."],
  ["Setter preservation", "scripts/test_regpres.py", "Covers AX preservation for mouse setter calls that invoke clamp helpers."],
  ["Workflow notes", "docs/emulator_workflows.md", "Explains QEMU, VNC, 86Box, and real-DOS comparison setup."],
  ["Debug history", "docs/debug_log.md", "Records the Stunt release-query and Ascendancy callback/ratio investigations."],
];

const MOUSE_EMULATORS = [
  ["v86", "Click the browser screen to capture input. It is convenient for demos, but browser pointer capture can hide whether the guest or host owns the mouse."],
  ["QEMU -nographic", "Good for tests. Use monitor commands such as `mouse_move 40 0`, `mouse_button 1`, and `mouse_button 0` because there is no visible pointer."],
  ["QEMU display/VNC", "Use a normal display or VNC when validating actual game UI hit targets; keep serial logging enabled for INT 33h traces."],
  ["86Box", "Use for period-style mouse behavior and for games where QEMU display or CPU behavior is suspect. Ascendancy mouse work was confirmed here."],
  ["Real DOS in QEMU", "When comparing against DOS, load MOUSE.COM before launching a mouse-dependent game."],
];

const MOUSE_SECTIONS = [
  {
    id: "dispatch",
    title: "INT 33h dispatch",
    summary: "Every mouse call polls hardware before serving state.",
    body: [
      "The INT 33h handler keeps a narrow implemented surface. It logs optional traces, polls any queued PS/2 bytes, then dispatches known AX values. Unknown functions return with a plain `iret` instead of pretending to implement a broad mouse-driver API.",
      "Reset returns the installed-driver signature in AX and the two-button count in BX. It also resets ranges, position, motion counters, press/release counters, callback state, and the mickey/pixel ratio.",
    ],
    file: "src/kernel/mouse.inc",
    code: [
      [1, "int33_handler:"],
      [19, "    pusha"],
      [20, "    call mouse_poll_ps2"],
      [23, "    cmp ax, 0x0000"],
      [29, "    cmp ax, 0x0003"],
      [33, "    cmp ax, 0x0005"],
      [35, "    cmp ax, 0x0006"],
      [37, "    cmp ax, 0x0007"],
      [41, "    cmp ax, 0x000B"],
      [43, "    cmp ax, 0x000C"],
      [45, "    cmp ax, 0x000F"],
      [47, "    iret"],
      [48, ".reset:"],
      [53, "    mov word [cs:mouse_x], 320"],
      [54, "    mov word [cs:mouse_y], 100"],
      [64, "    mov word [cs:mouse_callback_mask], 0"],
      [68, "    mov word [cs:mouse_ratio_x], 8"],
      [74, "    mov ax, 0xFFFF"],
      [75, "    mov bx, 2"],
      [76, "    iret"],
    ],
    hi: [1, 20, 23, 47, 48, 64, 68, 74, 75],
    tests: ["scripts/test_mouse.py", "scripts/test_regpres.py"],
  },
  {
    id: "position",
    title: "Position, ranges, and ratio",
    summary: "Coordinates are scaled and clamped inside the active range.",
    body: [
      "Position calls use the conventional BX/CX/DX register shape. `AX=0004h` stores CX/DX, clears scaling remainders, then clamps. Range calls accept either order for CX/DX and immediately clamp the current coordinate.",
      "`AX=000Fh` changes the mickey/pixel ratio. LainDOS scales signed PS/2 deltas with `delta * 8 / ratio` and keeps signed remainders so slow movement still accumulates correctly.",
    ],
    file: "src/kernel/mouse.inc",
    code: [
      [83, ".get_pos:"],
      [84, "    mov bx, [cs:mouse_buttons]"],
      [85, "    mov cx, [cs:mouse_x]"],
      [86, "    mov dx, [cs:mouse_y]"],
      [88, ".set_pos:"],
      [89, "    mov [cs:mouse_x], cx"],
      [94, "    call mouse_clamp_position"],
      [97, ".set_x_range:"],
      [98, "    cmp cx, dx"],
      [100, "    xchg cx, dx"],
      [102, "    mov [cs:mouse_min_x], cx"],
      [108, ".set_y_range:"],
      [113, "    mov [cs:mouse_min_y], cx"],
      [185, ".set_ratio:"],
      [190, "    cmp cx, 2048"],
      [202, "    mov [cs:mouse_ratio_x], cx"],
      [204, "    mov word [cs:mouse_scale_rem_x], 0"],
      [237, "mouse_clamp_position:"],
      [239, "    cmp ax, [cs:mouse_min_x]"],
      [243, "    cmp ax, [cs:mouse_max_x]"],
      [257, "    mov [cs:mouse_y], ax"],
    ],
    hi: [83, 88, 94, 97, 108, 185, 202, 237],
    tests: ["scripts/test_mouse.py", "scripts/test_mouseratio.py", "scripts/test_regpres.py"],
  },
  {
    id: "buttons",
    title: "Press, release, and raw motion queries",
    summary: "Edge queries latch data until the game consumes it.",
    body: [
      "Press and release calls take BX=0 for left or BX=1 for right. They return current button bits in AX, the latched edge count in BX, the last edge position in CX/DX, then clear that count.",
      "Raw motion uses AX=000Bh. It returns accumulated signed mickeys in CX/DX and clears the motion counters, independent of the scaled/clamped screen position used by AX=0003h.",
    ],
    file: "src/kernel/mouse.inc",
    code: [
      [119, ".get_button_press:"],
      [130, ".get_left_press:"],
      [132, "    mov bx, [cs:mouse_press_count_l]"],
      [133, "    mov cx, [cs:mouse_press_x_l]"],
      [135, "    mov word [cs:mouse_press_count_l], 0"],
      [146, ".get_button_release:"],
      [157, ".get_left_release:"],
      [159, "    mov bx, [cs:mouse_release_count_l]"],
      [160, "    mov cx, [cs:mouse_release_x_l]"],
      [162, "    mov word [cs:mouse_release_count_l], 0"],
      [173, ".get_motion:"],
      [174, "    mov cx, [cs:mouse_motion_x]"],
      [175, "    mov dx, [cs:mouse_motion_y]"],
      [176, "    mov word [cs:mouse_motion_x], 0"],
      [177, "    mov word [cs:mouse_motion_y], 0"],
    ],
    hi: [119, 130, 135, 146, 157, 162, 173, 176, 177],
    tests: ["scripts/test_mouse.py", "scripts/test_mousecb.py"],
  },
  {
    id: "ps2",
    title: "PS/2 packet path",
    summary: "QEMU/86Box mouse input arrives as standard three-byte PS/2 packets.",
    body: [
      "At boot the kernel enables the auxiliary device, sends mouse defaults and streaming commands, writes the controller command byte, unmasks IRQ12, and records whether PS/2 setup succeeded. The INT 33h path also polls the controller so tests can observe movement without waiting for an interrupt window.",
      "The packet decoder rejects unsynchronized first bytes, sign-extends deltas, ignores overflowed axes, negates Y to match screen coordinates, adds raw motion counters, and applies scaled movement to the clamped cursor position.",
    ],
    file: "src/kernel/mouse.inc",
    code: [
      [328, "mouse_init_ps2:"],
      [334, "    mov al, 0xA8"],
      [337, "    mov al, 0xF6"],
      [341, "    mov al, 0xF4"],
      [347, "    mov al, 0x60"],
      [351, "    mov al, 0x47"],
      [359, "    mov byte [cs:mouse_ps2_enabled], 1"],
      [452, "mouse_poll_ps2:"],
      [457, "    in al, 0x64"],
      [460, "    test al, 0x20"],
      [462, "    in al, 0x60"],
      [463, "    call mouse_ps2_byte"],
      [468, "mouse_ps2_byte:"],
      [477, "    test al, 0x08"],
      [494, "    test byte [cs:mouse_packet0], 0x40"],
      [498, "    test byte [cs:mouse_packet0], 0x10"],
      [508, "    call mouse_scale_x"],
      [509, "    call mouse_apply_delta_x"],
      [523, "    neg ax"],
      [527, "    call mouse_apply_delta_y"],
    ],
    hi: [328, 334, 337, 341, 351, 452, 463, 468, 477, 508, 523, 527],
    tests: ["scripts/test_mousecb.py", "scripts/test_mouseratio.py", "tests/programs/mousehw.asm"],
  },
  {
    id: "callbacks",
    title: "Edges and callbacks",
    summary: "Movement and button edges can call back into a game.",
    body: [
      "Once a full packet has updated movement and button state, LainDOS sets event-mask bits for motion, left press/release, and right press/release. It records edge positions and updates current button bits before considering a callback.",
      "Callback invocation is guarded against recursive mouse callbacks. The game receives AX=matched mask, BX=buttons, CX/DX=position, and SI/DI=movement deltas, then returns with RETF. INT 21h calls made from the callback are rejected so DOS file I/O state is not re-entered.",
    ],
    file: "src/kernel/mouse.inc",
    code: [
      [530, "    mov bx, [cs:mouse_buttons]"],
      [531, "    mov ax, [cs:mouse_new_buttons]"],
      [536, "    or word [cs:mouse_event_mask], 0x0004"],
      [537, "    inc word [cs:mouse_release_count_l]"],
      [546, "    or word [cs:mouse_event_mask], 0x0002"],
      [547, "    inc word [cs:mouse_press_count_l]"],
      [557, "    or word [cs:mouse_event_mask], 0x0010"],
      [567, "    or word [cs:mouse_event_mask], 0x0008"],
      [574, "    mov [cs:mouse_buttons], ax"],
      [575, "    call mouse_invoke_callback"],
      [579, "mouse_invoke_callback:"],
      [581, "    test ax, [cs:mouse_callback_mask]"],
      [591, "    and ax, [cs:mouse_callback_mask]"],
      [592, "    mov bx, [cs:mouse_buttons]"],
      [595, "    mov si, [cs:mouse_event_dx]"],
      [597, "    call far [cs:mouse_callback_off]"],
      [611, "irq12_handler:"],
      [621, "    in al, 0x60"],
      [622, "    call mouse_ps2_byte"],
      [625, "    out 0xA0, al"],
      [626, "    out 0x20, al"],
    ],
    hi: [536, 546, 557, 567, 575, 579, 581, 591, 597, 611, 622, 625, 626],
    tests: ["scripts/test_mousecb.py", "scripts/test_mouseratio.py", "scripts/test_mouseindos.py"],
  },
];

function MouseDocsPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Mouse track
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Mouse
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 800, margin: 0 }}>
            How LainDOS turns emulator PS/2 packets into DOS mouse-driver state: INT 33h calls,
            button edges, callbacks, mickey scaling, emulator capture, and the game-specific behavior
            this small driver is meant to cover.
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={mouseCard(T)}>
              <h2 style={mouseH2(T)}>From packet to callback</h2>
              <p style={mouseP(T)}>
                LainDOS does not load a TSR mouse driver. The kernel owns the INT 33h vector and the IRQ12
                packet path directly, which keeps the implementation small and lets games see a mouse driver
                before any shell command or AUTOEXEC helper is involved.
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {MOUSE_FLOW.map((row, i) => <MouseFlow key={row[0]} row={row} index={i} />)}
              </div>
            </section>

            {MOUSE_SECTIONS.map(section => <MouseSection key={section.id} section={section} />)}

            <section id="unsupported" style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
              <h2 style={mouseH2(T)}>Implemented narrowly on purpose</h2>
              <p style={mouseP(T)}>
                The mouse surface grows only when a target program or regression proves it needs more.
                Current support is enough for the known game paths without claiming complete Microsoft Mouse
                driver compatibility.
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {MOUSE_UNSUPPORTED.map(item => <MouseUnsupported key={item} text={item} />)}
              </div>
            </section>
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={mousePanel(T)}>
              <h3 style={mouseKicker(T)}>INT 33h surface</h3>
              <div style={{ display: "grid", gap: 7 }}>
                {MOUSE_CALLS.map(row => <MouseCall key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...mousePanel(T), marginTop: 14 }}>
              <h3 style={mouseKicker(T)}>Target programs</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {MOUSE_TARGETS.map(row => <MouseTarget key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...mousePanel(T), marginTop: 14 }}>
              <h3 style={mouseKicker(T)}>Manual emulator notes</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {MOUSE_EMULATORS.map(row => <MouseTarget key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...mousePanel(T), marginTop: 14 }}>
              <h3 style={mouseKicker(T)}>Regression map</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {MOUSE_TESTS.map(row => <MouseTest key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...mousePanel(T), marginTop: 14 }}>
              <h3 style={mouseKicker(T)}>Related tracks</h3>
              <button onClick={() => go("dosapi")} style={{ ...mouseButton(T.amber), marginBottom: 8 }}>INT 21h / DOS API</button>
              <button onClick={() => go("tests")} style={{ ...mouseButton(T.blue), marginBottom: 8 }}>Test ladder</button>
              <button onClick={() => go("run")} style={mouseButton(T.pink)}>Try the emulator</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function MouseFlow({ row, index }) {
  const T = window.T;
  return (
    <div style={{ display: "grid", gridTemplateColumns: "42px 116px 1fr", gap: 12, alignItems: "baseline",
      border: `1px solid ${T.line}`, borderRadius: 10, background: "#fffdf6", padding: "10px 12px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.faint }}>{String(index + 1).padStart(2, "0")}</code>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.amber, textTransform: "uppercase" }}>{row[0]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.5 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function MouseSection({ section }) {
  const T = window.T;
  return (
    <section id={section.id} style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap", marginBottom: 8 }}>
        <h2 style={{ ...mouseH2(T), margin: 0 }}>{section.title}</h2>
        <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber }}>{section.summary}</code>
      </div>
      {section.body.map((p, i) => <p key={i} style={mouseP(T)}><window.InlineText text={p} /></p>)}
      <div style={{ display: "grid", gap: 14, marginTop: 16, alignItems: "start" }}>
        <window.CodeBlock file={section.file} code={section.code} hi={section.hi} />
        <div style={mousePanel(T)}>
          <h3 style={mouseKicker(T)}>Tests that pin this</h3>
          <div style={{ display: "grid", gap: 7 }}>
            {section.tests.map(test => <MouseTestLink key={test} path={test} />)}
          </div>
        </div>
      </div>
    </section>
  );
}

function MouseCall({ row }) {
  const T = window.T;
  return (
    <div style={{ borderTop: `1px solid ${T.line}`, padding: "9px 0" }}>
      <div style={{ display: "flex", gap: 8, alignItems: "baseline", flexWrap: "wrap" }}>
        <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber }}>{row[0]}</code>
        <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10.5, color: T.faint, textTransform: "uppercase" }}>{row[1]}</span>
      </div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.3, color: T.dim, lineHeight: 1.45, marginTop: 3 }}><window.InlineText text={row[2]} /></div>
    </div>
  );
}

function MouseTarget({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber, textTransform: "uppercase" }}>{row[0]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function MouseTest({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber, textTransform: "uppercase" }}>{row[0]}</div>
      <MouseTestLink path={row[1]} />
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[2]} /></div>
    </div>
  );
}

function MouseTestLink({ path }) {
  const T = window.T;
  return (
    <a href={`https://github.com/lambadalambda/laindos/blob/main/${path}`} target="_blank" rel="noreferrer"
      style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue, textDecoration: "none" }}>
      {path}
    </a>
  );
}

function MouseUnsupported({ text }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 9, background: "#fffdf6", padding: "11px 13px",
      fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.55 }}>
      <window.InlineText text={text} />
    </div>
  );
}

function mouseCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function mousePanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function mouseH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function mouseP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, maxWidth: 760, margin: "0 0 12px" };
}
function mouseKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function mouseButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { MouseDocsPage });
