# Cloud integration tests (stub — not wired up yet)

Local gates cover everything that doesn't need a real Roblox server. What they
can't cover: DataStore semantics, replication, Player lifecycle, physics —
i.e. the code confined to `src/server/Adapters/` and the composition roots.

The plan for covering that layer is the **Roblox Open Cloud Luau Execution
API** (Beta as of mid-2026), which runs Luau code on a real Roblox place from
CI with no Studio involved:

- Docs: https://create.roblox.com/docs/cloud/reference/features/luau-execution
- Endpoint: `POST /cloud/v2/universes/{universeId}/places/{placeId}/luau-execution-session-tasks`
- Auth: Open Cloud API key with the Luau execution scope
- Constraints (verify current values when wiring up): 5-minute task limit,
  10 concurrent tasks per place, results/logs fetched by polling the task.

## Planned flow

1. `rojo build default.project.json --output build.rbxl`
2. Upload the build to a **dedicated test place** via the Open Cloud place
   publish endpoint (never the production place).
3. Submit a Luau execution task that runs adapter-level integration specs
   (e.g. DataStoreAdapter round-trips against real DataStores) and prints a
   machine-readable result.
4. Poll the task, fetch logs, fail CI on any failed spec.

## Prerequisites before wiring this into CI

- A test universe/place owned by the game's group or account.
- An Open Cloud API key scoped to that universe (place publish + Luau
  execution), stored as the `ROBLOX_API_KEY` GitHub Actions secret.
- A `lune run cloud-test` script implementing the flow above (Lune's
  `@lune/net` covers the HTTP calls).
- Re-verify the API surface against the docs first — it was Beta when this
  stub was written, and shapes/limits may have changed.
