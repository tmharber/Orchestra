# Orchestra — macOS Terminal Orchestrator

## What is this?

A native macOS app for orchestrating multiple terminal instances (Claude Code, Codex, shell sessions, etc.) in a tiling layout. Think tmux meets a purpose-built GUI with drag-to-split pane management.

---

## Terminal Emulation: SwiftTerm

There's really only one serious option here: **SwiftTerm** by Miguel de Icaza.

### Why SwiftTerm

- **Pure Swift, SPM-native.** Add it as a package dependency and go.
- **`LocalProcessTerminalView`** is exactly what we need. It's an AppKit `NSView` subclass that wires a `TerminalView` to a local Unix pseudo-terminal. It spawns the user's default shell (zsh, bash, fish, whatever is configured) and handles all the pty plumbing. This is what gives you the "open a terminal, it looks like iTerm" behaviour.
- **Battle-tested.** Used in production by Secure Shellfish, La Terminal, and CodeEdit. The emulation quality is on par with or better than xterm.js. Full VT100/Xterm, Unicode, emoji, sixel graphics, Kitty image protocol.
- **Actively maintained.** Recent releases include fixes for coding agent compatibility (specifically mentioned), progress notifications (OSC 9;4), and a 69% throughput improvement in processing benchmarks.
- **AppKit-native.** Since our app is macOS-only, we get CoreText rendering, proper font handling, and native input method support for free.

### What alternatives exist (and why we're not using them)

| Option | Why not |
|---|---|
| **Roll our own (Process + pty + NSTextView)** | Enormous effort. Terminal emulation is deceptively complex: escape sequences, scrollback buffers, alternate screens, mouse tracking, colour handling, Unicode grapheme clusters. This is months of work to get right. |
| **Embed a web view with xterm.js** | Works (VS Code does this) but adds Chromium overhead, breaks native feel, and creates an awkward bridge between JS and Swift for our tiling logic. We'd be fighting two layout systems. |
| **libghostty** | Ghostty's core is a Zig library with a C API that could theoretically be embedded. However, it's not packaged or documented for third-party embedding yet. The README mentions this as a future goal but it's not there today. Also introduces a Zig build dependency. |
| **Fork/embed iTerm2** | iTerm2 is GPL-licensed and deeply coupled to its own app architecture. Not designed for embedding. |

### SwiftTerm integration notes

- **Sandboxing must be disabled.** `LocalProcessTerminalView` needs unrestricted filesystem and process access. The app should ship unsigned/notarised without sandbox, or use a hardened runtime with the relevant entitlements.
- **SwiftUI bridging.** SwiftTerm's views are AppKit `NSView` subclasses. We'll wrap them with `NSViewRepresentable` for SwiftUI, but the tiling layout itself may be cleaner in AppKit (see Architecture section).
- **Shell environment.** `LocalProcessTerminalView.startProcess()` launches the user's login shell by default. It inherits `$PATH`, `$SHELL`, and environment variables from the parent process. Claude Code, Codex, etc. will work as long as they're on the user's PATH, same as in iTerm or Terminal.app.
- **Resize handling.** SwiftTerm handles `SIGWINCH` (terminal resize signals) automatically when the view frame changes. This is critical for our drag-to-resize feature.

---

## Architecture

### AppKit vs SwiftUI vs Hybrid

**Recommendation: Hybrid, AppKit-primary for the terminal area.**

The tiling pane system (split views, drag handles, resize logic) is fundamentally about precise frame geometry and hit testing. AppKit gives us direct control over `NSView` frames, `NSSplitView` behaviour, and custom drag handles. SwiftUI's layout system would fight us here because it wants to own sizing through its constraint solver.

The sidebars and toolbar can be SwiftUI. The terminal tiling area should be AppKit, hosted in a SwiftUI window via `NSViewRepresentable` or (simpler) just use an `NSWindow` with AppKit throughout and SwiftUI for the sidebar content views.

**Simplest approach:** Full AppKit app, with SwiftUI used for sidebar content panels via `NSHostingView`.

### Project structure

```
Orchestra/
├── Orchestra.xcodeproj (or Package.swift if SPM-only)
├── Orchestra/
│   ├── AppDelegate.swift              — App lifecycle, menu bar
│   ├── MainWindowController.swift     — Window setup, toolbar
│   │
│   ├── Tiling/
│   │   ├── TileTree.swift             — Binary tree data model
│   │   ├── TileContainerView.swift    — Root NSView, recursive layout
│   │   ├── TileResizeHandle.swift     — Drag handles between panes
│   │   ├── TileSplitMode.swift        — The "add terminal" hover/split UX
│   │   └── TileNode.swift             — Enum: .leaf(terminal) | .split(axis, children, ratio)
│   │
│   ├── Terminal/
│   │   ├── TerminalPaneView.swift     — Wraps LocalProcessTerminalView + chrome (close button, label)
│   │   └── TerminalManager.swift      — Tracks live terminal instances, handles cleanup
│   │
│   ├── Sidebar/
│   │   ├── LeftSidebarView.swift      — (future: task list, agent status)
│   │   └── RightSidebarView.swift     — (future: notes, context)
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── MainMenu.xib (or programmatic)
```

---

## Core Data Model: The Tile Tree

The layout is a **binary tree**. Every node is either:

- **A leaf** — contains a terminal instance
- **A split** — has an axis (horizontal or vertical), two children, and a split ratio (0.0 to 1.0)

```swift
enum SplitAxis {
    case horizontal  // children are left | right
    case vertical    // children are top | bottom
}

// Each node has a unique ID for tracking
indirect enum TileNode {
    case leaf(id: UUID, terminal: TerminalPaneView)
    case split(id: UUID, axis: SplitAxis, first: TileNode, second: TileNode, ratio: CGFloat)
}
```

### Why a binary tree?

This structure naturally enforces your resize constraint. When you drag a boundary between two panes, you're adjusting the `ratio` of their shared parent split node. The boundary spans the full extent of the parent's frame along the split axis, which means both children's corresponding edges are exactly the same length. You can only resize siblings.

If you have:

```
split(vertical)
├── Terminal A (top half)
└── split(horizontal)
    ├── Terminal B (bottom-left)
    └── Terminal C (bottom-right)
```

- The boundary between B and C is the horizontal split's ratio. B's right edge and C's left edge are the same height (the bottom half). Resizable.
- The boundary between A and {B,C} is the vertical split's ratio. A's bottom edge spans the full width, and the {B,C} group's top edge also spans the full width. Resizable.
- But there's no boundary between A and C alone, because they aren't siblings. You can't drag just the top-right corner of C upward. This matches your requirement exactly.

### Layout algorithm

Given a `TileNode` and a `CGRect` (the available frame), layout is recursive:

```
func layout(node: TileNode, frame: CGRect):
    if node is .leaf:
        set terminal view frame = frame
    if node is .split(axis, first, second, ratio):
        (frame1, frame2) = divide frame along axis at ratio
        layout(first, frame1)
        layout(second, frame2)
        position resize handle along the dividing line
```

This is clean, fast, and trivially handles arbitrarily deep nesting.

---

## Feature: Adding a Terminal (Split Mode)

When the user clicks `+` in the toolbar:

1. **Enter split mode.** An overlay appears over the terminal area. The cursor changes (or a visual indicator appears).

2. **Hover detection.** As the user moves their cursor over existing terminal panes, we detect which pane they're hovering over and which edge zone they're near (top/bottom/left/right, roughly the outer 30% of each pane).

3. **Dwell timer (250ms).** After the cursor stays in an edge zone for ~250ms, show a preview: the target pane visually splits with a translucent placeholder showing where the new terminal will go.

4. **Click to confirm.** The user clicks to commit the split. A new `TileNode.split` replaces the leaf node in the tree, with the existing terminal on one side and a new terminal on the other.

5. **Escape/click-outside to cancel.** Returns to normal mode.

### Edge zone logic

For a given pane, divide it into zones:

```
┌──────────────────────┐
│       TOP (30%)       │
├─────┬──────────┬──────┤
│     │          │      │
│ L   │  CENTER  │  R   │
│30%  │  (dead)  │ 30%  │
│     │          │      │
├─────┴──────────┴──────┤
│      BOTTOM (30%)     │
└──────────────────────┘
```

- Hovering LEFT → split horizontal, existing terminal moves right, new one on left
- Hovering RIGHT → split horizontal, existing on left, new on right
- Hovering TOP → split vertical, existing moves down, new on top
- Hovering BOTTOM → split vertical, existing on top, new on bottom
- CENTER → no split (dead zone to prevent accidental splits)

---

## Feature: Resizing Terminals

Resize handles are thin invisible-ish hit areas (6-8pt wide) positioned along every split boundary in the tree.

### How it works

1. **On mouse down over a handle:** identify which split node owns this boundary.
2. **On drag:** update that split node's `ratio` based on mouse position relative to the parent frame.
3. **On mouse up:** commit the new ratio.
4. **Continuously during drag:** re-run the layout algorithm from the affected split node downward.

### Minimum size enforcement

Each pane should have a minimum size (e.g. 200x100pt) to prevent terminals from collapsing to nothing. Clamp the ratio during drag so neither child goes below minimum.

### Why the "matching boundary" constraint works for free

Because we only expose resize handles at split boundaries (i.e. between siblings in the tree), the constraint you described is automatically satisfied. There's no handle to grab between non-sibling panes. The user simply can't attempt an invalid resize.

---

## Feature: Closing a Terminal

When a terminal pane is closed (via a close button, right-click menu, or keyboard shortcut):

1. Find the leaf node in the tree.
2. Find its parent split node.
3. Replace the parent split node with the sibling node (the other child of the split).
4. The sibling expands to fill the parent's entire frame.

### The 3-sibling edge case

Your example: three terminals across the bottom (B-left, B-mid, B-right), close B-mid. This means the tree looks like:

```
split(horizontal)
├── B-left
└── split(horizontal)
    ├── B-mid
    └── B-right
```

Closing B-mid removes the inner split, and B-right expands to fill the right portion. B-left is unaffected. This is the natural tree behaviour.

But what if the tree was built differently (B-mid is the root of a subtree with B-left and B-right as children)? Then closing B-mid isn't possible in that structure because B-mid would be a split node, not a leaf.

**Key insight:** because splits are always binary and we always split an existing leaf, the tree structure ensures that closing a leaf always has exactly one sibling to expand into. The "pick the smallest" heuristic you mentioned would only apply if we had n-ary splits, which we don't need. Binary tree keeps things clean.

---

## Feature: Sidebars

Narrow fixed-width panels on left and right of the terminal area. These are **not** part of the tile tree. They're separate views in the main window layout:

```
┌────┬──────────────────────────┬────┐
│    │                          │    │
│ L  │     Terminal Tiling      │ R  │
│    │         Area             │    │
│    │                          │    │
└────┴──────────────────────────┴────┘
```

Content TBD, but placeholder panels should be there from the start. Collapsible via a toggle button or keyboard shortcut.

---

## Milestones

### M1: Skeleton app with one terminal
- Xcode project with SwiftTerm dependency
- Single window with a `LocalProcessTerminalView` filling the main area
- Verify shell works (zsh loads, commands run, colours render, Claude Code works)
- App menu with Quit, basic window management

### M2: Tile tree and manual splitting
- Implement `TileNode` data model
- Recursive layout engine
- Hardcode a couple of splits to prove the layout works
- Resize handles between split panes

### M3: Interactive split mode (the + button UX)
- Toolbar with + button
- Split mode overlay with edge zone detection
- 250ms dwell timer and preview animation
- Click to commit, escape to cancel

### M4: Closing terminals
- Close button on each pane (appears on hover?)
- Tree pruning on close
- Sibling expansion animation

### M5: Sidebars
- Left and right sidebar shells
- Toggle visibility (keyboard shortcut + button)
- Placeholder content

### M6: Polish
- Keyboard shortcuts (Cmd+D for horizontal split, Cmd+Shift+D for vertical, Cmd+W to close pane, Cmd+T for new terminal)
- Focus management (click a terminal to focus, visual indicator for active pane)
- Minimum pane size enforcement
- Smooth resize animations
- Dark mode support (terminal themes)
- App icon

---

## Open Questions / Future Considerations

- **Terminal tabs within a pane?** Some users might want multiple shell sessions in one pane slot, switchable via tabs. Not in v1.
- **Named terminals / labels?** Useful for tracking which terminal is running Claude Code vs Codex vs a build watcher. Could show a small label bar at the top of each pane.
- **Layout persistence across restarts?** Not in v1. Would need to serialise the tree structure and re-spawn shells.
- **Drag-to-rearrange?** Dragging a terminal pane to swap its position with another. Complex but possible with the tree model.
- **Session restore from tmux/screen?** Connecting to an existing tmux session rather than spawning a new shell.
- **Global keyboard navigation?** Moving focus between panes with Cmd+Option+Arrow or similar.

---

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| SwiftTerm | Latest (SPM) | Terminal emulation via `LocalProcessTerminalView` |

That's it. One dependency. Everything else is AppKit/SwiftUI.

---

## Build & Run Requirements

- macOS 13+ (Ventura) — for modern SwiftUI interop if needed
- Xcode 15+
- **App Sandbox disabled** — required for `LocalProcessTerminalView` to access the filesystem and spawn processes
- Hardened Runtime with relevant entitlements for notarisation (if distributing)