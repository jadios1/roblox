# Territory Ball — high-level delivery plan

## Goal

Build a small two-sided physics game that teaches Roblox development through
thin, testable slices. Two competitors push or kick a physical ball toward the
other competitor's territory. A human can play against another human or a
simple server-controlled bot.

This plan is removed when the game has reached the first complete playable
version. Each detailed slice plan is removed as soon as that slice ships.

## First playable rules

- The arena has Player 1 territory, a neutral zone, and Player 2 territory.
- The ball and both competitors reset to fixed positions at the start of a
  round.
- Contact between a competitor and the ball produces a controlled physics kick
  with a short per-competitor cooldown.
- When the ball enters a competitor's territory, the opponent starts capturing
  it. The opponent scores if the ball remains there for two seconds.
- Moving the ball to another zone resets the capture timer.
- After a point, play pauses, positions reset, and a short countdown starts the
  next round.
- The first competitor to five points wins the match.
- One human can play against a bot; two humans can play each other.

The capture duration, kick strength, cooldown, arena size, and winning score are
tuning values. Keep them easy to change while the game feel is being explored.

## Authority and trust boundaries

- The server owns player slots, match state, capture time, scores, resets, and
  the decision that a point was scored.
- Clients render state and use normal Roblox character controls. A client never
  reports that it scored or directly chooses a ball velocity.
- The server remains the authority for gameplay decisions involving the ball.
  The exact contact and networking model will be chosen in a future slice.
- Match score is session state, not persistent currency. Currency rewards can
  be integrated after the match loop is reliable.

## Architecture

- Static arena content is a Rojo-managed subtree under
  `Workspace.TerritoryBall`, leaving unrelated place content unmanaged.
- Pure shared modules own zone classification, match transitions, kick
  calculations, and bot decisions. Every shared module has mirrored Lune specs.
- Ball contact and kick behavior will be designed as a separate tested slice.
- Server services orchestrate rounds and effects through minimal injected
  interfaces. Every service is constructed with fakes in its specs.
- Roblox adapters translate the service interfaces into engine calls and contain
  no game policy.
- Composition roots only create adapters, create services, and connect events.
- Client code is limited to presentation, input glue, and remote calls.

## Delivery slices

1. **Two-player setup and shooting** — Add player assignment, resets, and the
   stronger action-button shot. Validate first
   with two Studio clients.
2. **Territory scoring and rounds** — Add pure zone rules, capture timing,
   server-authoritative scoring, round states, resets, and match completion.
3. **HUD and feedback** — Show scores, capture progress, countdowns, point
   results, and the match winner. Add restrained sound and visual feedback.
4. **Bot opponent** — Fill an empty slot with a simple bot that moves behind
   the ball and attacks toward the opposing territory. Add reaction delay and
   aim error only after its deterministic decisions are tested.
5. **Playtest and tuning** — Exercise solo, two-client, device, and adverse
   network modes; tune the arena and kick feel; resolve discovered edge cases.
6. **Optional progression** — Award persistent currency for completed matches
   only after the match result is trustworthy and abuse cases are defined.

## Testing strategy

- Put deterministic rules in pure modules and cover boundaries, transitions,
  cooldowns, timer resets, double-score prevention, and bot choices under Lune.
- For every new behavioral test, deliberately break the behavior once and
  confirm the test fails before restoring it.
- Run targeted unit tests during a slice and `lune run check` before completing
  every slice.
- Use Studio Test for solo client/server inspection and Server & Clients for
  real two-player replication and lifecycle checks.
- Keep Roblox-only behavior behind the smallest possible adapter surface. The
  planned cloud harness remains the eventual home for engine integration tests.

## First playable definition of done

- A human can complete a full first-to-five match against either another human
  or the bot.
- The server makes every scoring and round-transition decision.
- The arena, score, timer, and reset behavior are understandable without the
  Output window.
- Existing content in a non-empty place remains intact when Rojo connects.
- All repository quality gates pass.

## Deliberately deferred

- Matchmaking, parties, public servers, and spectating.
- Sophisticated navigation or obstacle-aware AI.
- Client prediction and advanced network-ownership tuning.
- Persistent rankings, rewards, shops, and anti-cheat beyond authoritative game
  decisions.
- Art production, animation polish, and monetization.
