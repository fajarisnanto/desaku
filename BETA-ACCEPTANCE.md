# Beta acceptance criteria

A beta release requires evidence for all of these gates:

- Automated navigation, social, profile/UI, office persistence and news parser tests pass in isolated app data.
- Mock HTTP tests cover dialogue and structured planning success/failure, including timeouts and malformed output.
- Live Qwen completes a useful office project, recruits a specialist after prerequisites, and the specialist takes a planning turn.
- All news feeds are fetched through the game's HTTP client; story dates, source links, offline behavior and disabled behavior are verified.
- Windows exported build opens all panels, has no layout-blocking errors, survives restart with office state and profiles, and produces no script errors in a bounded soak test.
- Runtime state and credentials stay out of source/release packages. Source and Windows archives have matching published checksums.

Scope: autonomous village conversations, four bounded office simulations and small teams, and sourced headline discussion. Arbitrary code generation, external tool execution, unrestricted construction and full multi-direction animated character sprites are not beta requirements.

Current status: beta gates passed on the tested Windows PC; user authorized launches and live validation. See BETA-VERIFICATION.md for results and limitations.
