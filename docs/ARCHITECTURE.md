# Architecture

A native macOS menubar app (no Dock icon) that adds Vimium-style keyboard navigation to any app via the Accessibility API and a global event tap.

```mermaid
flowchart TD
    Main[main.swift / AppDelegate] --> Engine[VimiumEngine<br/>mode state machine]
    Main --> Status[StatusItemController]
    Main --> Win[MainWindowController]
    Main --> Perm[Permissions<br/>Accessibility · Input Monitoring]

    Tap[EventTap<br/>global key events] --> Engine
    Focus[FocusWatcher<br/>frontmost app + text focus] --> Engine
    Excl[AppExclusions] --> Engine
    Engine --> Map[KeyMapper]
    Map --> Act[Actions<br/>scroll · back/forward · click]
    Engine --> Hint[HintEngine]
    Hint --> Collect["AX/ElementCollector<br/>AXSupport"]
    Hint --> Overlay[HintOverlay<br/>label badges]
    Engine --> HUD[HUD]

    Collect -->|AXUIElement tree| Apps[(Frontmost app)]
    Act -->|synthetic events| Apps
    Overlay -.drawn over.-> Apps
```

| Module | Role |
|---|---|
| `EventTap` | Intercepts and swallows/passes keystrokes |
| `FocusWatcher` | Switches to insert mode when a text field has focus |
| `AX/` | Walks the accessibility tree to find clickable elements |
| `Hints/` | Generates labels and renders overlay |
