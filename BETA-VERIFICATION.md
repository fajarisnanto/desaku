# Desaku v0.5.0-beta.1 verification

Validated on Windows 11, Godot 4.7.2, AMD Radeon RX 6900 XT, and local Ollama Qwen3:8b on 2026-10-30.

- Isolated regressions: navigation, resident social behavior, settings/profile UI, office building/recruitment/persistence, news parsing — PASS.
- Mock HTTP integration: ten requests covered authenticated dialogue and structured plans, 401, malformed/empty output, timeout, rejected redirect, validation, persistence, and key handling — PASS.
- Live Qwen: each of four departments started a role-relevant office project — PASS.
- Live Qwen autonomy: after workspace preparation Operation recruited Nia (Logistics coordinator); Nia then independently chose a recruitment plan, which was applied and counted as her planning turn — PASS.
- Live news retrieval: all four configured public feeds returned 42 dated entries in this run — PASS. Qwen generated an API-backed, attributed headline discussion — PASS.
- Exported Windows build: settings, all four office panels, news panel and village rendered; 30-second session soak, saved office/team/construction/profile reload — PASS.
- Two isolated launches of the exported build: PASS. No `ERROR` entries in either Godot log.
- Graphics device: AMD Radeon RX 6900 XT (OpenGL Compatibility).
- Character art: five transparent role cutouts adapted closely from the user's provided lineup; included and rendered in game.
- Qwen endpoint default now uses `127.0.0.1:11434`.

Tests used disposable app-data directories; existing user world and credentials were not used as test output. UI test screenshots include a clearly labeled news fixture. Feed counts and generated dialogue vary over time.

Known limits: validation covers one Windows PC and a 30-second rendered soak, not long-duration play or other hardware/providers. News context contains headline metadata only; Qwen can still be mistaken. Characters use mesh-based puppet gait and horizontal mirroring rather than full multi-direction sprite cycles. Office furniture and bounded teams use a fixed catalog. See README for scope and operation.
