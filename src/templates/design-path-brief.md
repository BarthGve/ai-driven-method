<!-- driven — read by /dm-design only when this path is chosen. Instructions, not an output structure. -->
# /dm-design — external brief path

**EXTERNAL BRIEF path (Gemini or any other tool)** — you write the brief, the user produces the screens:
1. Write docs/designs/<id>-brief.md (structure: @templates/design-brief.md): every screen with layout, exact fields and actions, the four states, and the design system constraints COPIED IN (tokens, components, do/don't) so the brief is self-contained and pasteable into the external tool. Out-of-scope stated. This file is the deliverable of this step — not a chat message.
2. The user takes the brief to their design tool and brings back the result (exported HTML, screenshot, or description). You then: record/normalize the mockup into docs/designs/<id>.html, and write docs/designs/<id>.md (structure: @templates/design-screen.md) describing the screen and pointing to the HTML.
If the user brought nothing back → end with: "Brief ready in docs/designs/<id>-brief.md — take it to your design tool, then rerun /dm-design <id> with the result." Don't generate in their place, unless they explicitly switch to the Agent path.
