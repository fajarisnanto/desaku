# Desaku

**Fountain Commons — Living Offices + World News (v0.5.0 beta 1)**

[Download the Windows beta](https://github.com/fajarisnanto/desaku/releases/tag/v0.5.0-beta.1) · [All releases](https://github.com/fajarisnanto/desaku/releases)

![Desaku village](preview.png)

![Resident AI settings](settings-preview.png)

A Windows 11 village showcase built with Godot 4.7.2. Four AI residents wander, greet nearby neighbors, pause for small talk, and then resume their walks. You are the Governor.

## Run

Download the Windows ZIP from Releases, extract it, and open `AI Village.exe`. Godot and Python are not needed to play. The 64-bit executable contains its game data and is unsigned. Offline conversation works immediately, without an account or connection.

## Controls

- **N / News desk**: inspect recent IT headlines, dates, source links and feed status; enable/disable news or refresh.
- **O / Offices**: view a department interior, team, construction and decision journal. Building nameplates also open their office.
- **S / AI settings**: configure Creative, Research, Operation and Maintenance separately.
- **G / Speak as Governor**: choose a recipient, type your own message, and send it. Enter also sends.
- **C**: large character portrait gallery.
- **L**: show/hide the recent conversation panel.
- **Space**: pause/resume the village.
- **F11**: fullscreen/windowed.
- **Tab**: navigation routes.
- **Esc**: close an open panel; otherwise quit.

The Governor remains at the Townhall approach and never wanders or generates speech. There is no Governor AI profile. The settings and human-message panels pause village simulation while open. There are no player movement controls in this stage.

## Configure each AI resident

1. Open **AI settings** and select a resident.
2. Choose **Offline small talk** or **Chat-completions API**.
3. For API mode, enter the **full endpoint URL**, **model ID**, and an API key if required. Different residents can use different endpoints, models and personalities. Set the per-resident **Timeout** (5–180 seconds) for slower local models. **Thinking: Off** sends `reasoning_effort: "none"`; leave Provider default for other endpoints unless they support this field.
4. Edit the personality. It is included in API requests; offline dialogue uses built-in role-specific lines.
5. Use **Test this connection**. The result explicitly says API, Offline or Fallback. A test uses the currently displayed fields, even before saving.
6. Choose **Save this resident**. Repeat for the other residents. Unsaved changes remain as drafts during this app session; each resident has a separate Save action.

The **Join nearby conversations** checkbox controls spontaneous conversations for that resident. Direct messages from the human Governor still receive a reply when spontaneous conversations are disabled.

### Local model server

For an already running Ollama server, the endpoint is:

`http://127.0.0.1:11434/v1/chat/completions`

Enter a model actually installed on your server. Local Ollama normally does not require a key. Other local servers implementing the same chat-completions JSON format can use their own full URL. This project does not install or download models.

### Fast Qwen preset

Install Ollama separately, then run `ollama pull qwen3:8b`. Close Desaku and run `presets/Import-QwenProfiles.ps1` in PowerShell to apply the bundled four-resident preset. It backs up existing settings before replacing these four profiles. Open Desaku again afterward. No model weights or credentials are included in the release.

The preset uses `http://127.0.0.1:11434/v1/chat/completions`, Qwen 8B, Thinking Off, a 45-second timeout, and nearby conversations enabled. Using the explicit loopback address avoided a roughly 30-second localhost connection delay observed on the test PC.

| Resident | Role and traits |
| --- | --- |
| Creative | Imaginative, empathetic artist; design, storytelling, festivals |
| Research | Curious, careful scholar; evidence, discovery, clear explanations |
| Operation | Calm, organized coordinator; priorities, supplies, teamwork |
| Maintenance | Practical, observant mechanic; prevention, upkeep, safe troubleshooting |

The Governor stays human-controlled. Personalities match the speaker's language, including Indonesian and English. These are dialogue traits, not actual tools or work-execution capabilities.

On the tested RX 6900 XT, Ollama reported 100% GPU allocation for Qwen 8B. Warm role tests took approximately 0.6–0.9 seconds; initial loading took around 10 seconds in a separate test. Timing varies with hardware, prompt length, and load. Settings are reloaded when opening the menu, while existing unsaved drafts are retained.

### Hosted model API

Use your provider's full HTTPS chat-completions URL and model ID. Only non-streaming `messages` / `choices[0].message.content` chat-completions responses are supported. This is a direct API client, not an MCP client; MCP stdio, MCP tool discovery, Responses API and Anthropic-native Messages API are not implemented. An adapter may expose one of those systems through the supported chat-completions format.

The request includes `model`, `stream:false`, `max_tokens:96` for dialogue (420 for office JSON plans), and system/user messages. Some providers require different request fields; use a compatible endpoint or adapter. Dialogue has no tool execution. The office planner can choose only the bounded in-game build/recruit/wait actions; no external actions are available.

### Keys and saved settings

Typed keys are masked and held in memory only until the game closes. To avoid retyping, set the named environment variable before launching the game (for example `VILLAGE_CREATIVE_API_KEY`). Each resident can use a different variable. A nonempty typed key takes precedence over its environment variable.

Settings save to Godot's local app-data directory, normally `%APPDATA%\Godot\app_userdata\AI Village — Fountain Commons\residents.json`. That JSON stores endpoint, model, environment-variable name, personality and social preference, never the typed key. Active runtime settings stay on each PC. The optional key-free preset in `presets/qwen-residents.json` provides the four role personalities for setup or restoration.

Saving API mode enables automatic model calls during conversations. Requests send the configured personality and recent encounter dialogue, including human messages when applicable, to your chosen endpoint. Hosted providers may charge. The game uses at most one in-flight request, at least six seconds between starts, a configurable per-resident timeout (12 seconds by default), and a 64 KiB response limit. Requests do not follow redirects. HTTPS is required except for HTTP on localhost or 127.0.0.1.

## Social behavior

Neighbors within 145 scene pixels stop, face each other, and exchange up to three short lines. An unobstructed walkable line between them is required, so they cannot talk across the fountain. Encounters have a 55-second pair cooldown and a 16-second resident cooldown. One conversation happens at a time so bubbles remain readable.

Opening greetings and subsequent turns use each speaker's configured provider, with scripted fallback on connection problems or request pacing. The village greeting clock uses Jakarta time (UTC+7). The transcript marks **Offline**, **API**, **Fallback** or **Human**; fallback errors are shown without raw server response bodies.

When an AI meets the Governor, it greets you and waits briefly, then leaves; the game never invents your reply. **Speak as Governor** lets you address any resident directly, regardless of distance, and starts a short directed exchange. These messages are exactly your typed words, followed by the selected resident's response. No speech audio is included.

## Autonomous offices

Each of the four AI leads starts with an empty office and 100 materials. With a configured API provider, the team evaluates its workspace and chooses one simulated action: build a furnishing, recruit a specialist, or wait. A new planning request is attempted roughly every 12 seconds, rotating through eligible departments and respecting the shared AI connection. Offline residents do not generate office plans.

Press **O**, click **Offices**, or click a department nameplate to enter the office view. The village walk simulation pauses while viewing offices; office construction and decisions continue. The office autonomy toggle pauses all department development. Settings panels and the global Space pause also pause office ticks. Work proceeds only while the application is running; it does not progress in the background after quitting.

AI teams choose from a furnishing catalog and 12 floor positions. Creative has an easel, Research a discovery station, Operation a planning board, and Maintenance a repair station; all can choose tables, archives, plants, lighting, rest areas and tea stations. Furniture raises office comfort, work capacity, knowledge or community scores. This stage models these benefits as simulation scores, not actual real-world productivity.

Construction takes about 22 seconds before team bonuses. Materials regenerate at 0.16 per simulation second, capped at 140 per office. Teams may recruit up to three named specialists after completing two furnishings and providing a free teammate desk. Recruitment costs 20 materials and takes 16 seconds. Recruits rotate through AI planning turns with their own name and specialty, share the department model and budget, and speed construction by 30% per teammate. They appear inside the office using tinted department character art; they are not additional independently wandering village sprites yet.

Decisions and reasons appear in the journal. Plans cannot execute code, access files or networks on their own, purchase resources, or create external accounts. The engine validates catalog items, positions, budget, specialties and team capacity before changing the simulation. Invalid responses spend nothing; the team retries later. Governor remains human-controlled and cannot be recruited.

Office state is stored separately from AI profiles in `user://offices.json`, including completed furnishings, teammates and in-progress construction. It autosaves every ten active seconds, on decisions/completion, and on normal exit. An unreadable save is preserved and disables office saving/autonomy for that session. The first-stage interiors are procedural isometric cutaways; freeform asset generation, arbitrary buildings, village-wide construction and external worker tools are not included.

**Beta validation:** isolated navigation, conversation, settings, office persistence and news-parser regressions pass. Mock HTTP tests cover dialogue and structured plans. Live Qwen built first projects for all four departments, recruited a specialist, and applied that specialist's own team decision. The exported Windows build passed rendered panel checks, a 30-second soak, and a separate restart with saved furniture, recruitment, construction and profile checks.

## IT news conversations

The shared news desk retrieves public feed metadata from The Hacker News, Microsoft Research, Google AI, and CISA's Known Exploited Vulnerabilities catalog. Feed requests run at startup and every 30 minutes while the app is open. Manual refresh is limited to once per minute. Each request has an 18-second timeout and 3 MB response limit. No API key is needed, and no village conversations are sent to news publishers.

Only dated entries from the last 14 days are eligible. Residents may discuss news on alternating spontaneous encounters. Messages from the Governor containing words such as news, berita, CVE, hacking, AI, security or cyber can select relevant headlines. Creative favors AI/design, Maintenance and Operation favor security/CVEs, and Research can discuss either. A chosen story remains attached to the encounter, and generated news dialogue is marked `API / News` with its source reference.

Press **N** to see each headline's publisher, date, retrieval time and original link. The **Read original source** button opens the browser only when clicked. News may be disabled in this panel. Settings and bounded headline metadata are stored in `user://village_news.json`; old or undated entries are excluded. Failed refreshes keep eligible dated cache entries and show an unavailable status. When no recent evidence exists, residents are instructed to acknowledge that instead of inventing breaking news.

Only headline metadata is passed to Qwen, not full articles. It is instructed to attribute reports, separate opinion, and avoid inventing exploit details, CVSS values, affected versions or fixes. CISA dates are explicitly marked **added to KEV**, not CVE disclosure dates. These are selected international feeds, not complete global coverage; verify important details at the original source. Model adherence is not guaranteed.

The game's HTTP client successfully fetched all four live sources (42 eligible entries in the beta validation run), and Qwen generated an attributed news reply. Parser regression, panel rendering and fallback/disable checks pass. News content changes over time.

## Open and rebuild

Import `project.godot` into Godot **4.7.2 standard edition**, then press F5. This uses GDScript and OpenGL Compatibility, not .NET. Install matching Windows export templates and run `build.ps1`, or export using the included Windows Desktop preset.

Important files:

- `scripts/office_world.gd`, `office_ui.gd`, `office_room.gd`: autonomous plans, construction, recruitment, persistence and office views.
- `scripts/ai_service.gd`: profile persistence, HTTP transport, validation and fallback.
- `scripts/social.gd`: proximity, conversation turns, cooldowns and human messages.
- `scripts/settings_ui.gd`: per-resident menu and human chat box.
- `scripts/village.gd`: navigation, simulation, scenery and tests.
- `scripts/resident.gd`, `resident_walk.gdshader`: character art, animation and speech bubbles.
- `assets/`: village background and five transparent character images.
- `reference/`, `ART_DIRECTION.txt`, `CHARACTER_ART.txt`: supplied reference and image-generation provenance.
- `preview.png`, `settings-preview.png`: actual rendered game and menu.
- `tests/`: reproducible UI and API integration tests.
- `VERIFICATION.txt`: validation results and limits.

## Verification commands

Run from the project directory, with Godot on PATH:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --self-test
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --social-test
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_ui.gd
python tests/run_api_tests.py
```

The last command uses a disposable local mock server and Python's standard library. It does not contact a real provider or use your API keys. Live local Ollama inference, office recruitment and team decisions, four public news sources and attributed news dialogue were tested. Hosted providers have not been tested. Run `python tests/run_regressions.py` for isolated regressions, `python tests/run_live_beta.py` for opt-in live Ollama/feed checks, and `python tests/run_export_smoke.py build/Desaku-Beta.exe build/beta-captures` for the exported UI/restart smoke test. Live checks require qwen3:8b installed locally and network access for feeds.

## Current scope

The village is a painted scene with animated fountain effects and character sprites. The four departments have office cutaway views and a bounded construction/team simulation; the pub and Townhall have no interiors. Navigation avoids scenery; residents can pass through one another outside conversations. Characters use a subtle mesh-based puppet gait and horizontal mirroring, not a complete multi-direction sprite walk cycle. Their artwork closely adapts your supplied lineup; pets, robots and nameplates from that reference are omitted.


Protocol references: [Ollama chat-completions compatibility](https://docs.ollama.com/api/openai-compatibility) and [Godot HTTPRequest documentation](https://docs.godotengine.org/en/stable/classes/class_httprequest.html).

### Beta limitations

This beta is ready for user testing, not a finished release. Office furniture uses procedural cutaways; recruits reuse tinted role art and remain inside offices. The simulation has a fixed furnishing catalog, bounded teams and simple wellbeing scores. A model may propose an invalid action; it is rejected and retried later. News is headline-only evidence and model replies can still be mistaken. Dialogue can fall back while the shared AI connection is busy. Validation covered this Windows PC and a short soak, not extended multi-hour play or other hardware.
