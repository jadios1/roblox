# Current Task

**Selected Chaos Idea**: Player Balance Warping (Idea 2)

## Description
When a player deposits currency, a random small percentage is "lost to the void" or "found by a stranger" instead of going to them.

## Implementation Plan
1. Add `ChaosEffect` interface to `src/shared/Currency/ChaosEffect.luau` (pure, testable)
2. Implement `WalletWarp` chaos effect in `src/shared/Currency/WalletWarp.luau`
3. Wire chaos effect into `CurrencyService:deposit()` in `src/server/Services/CurrencyService.luau`
4. Add unit tests in `tests/Currency/WalletWarp.spec.luau`
5. Update `.agent/STATE.md` with implementation progress

## Architecture Rules
- Chaos logic in `src/shared/` (pure Luau, no Roblox globals)
- No fake APIs - use actual Roblox DataStore via adapter
- Server-side orchestration testable under Lune
- No changes to adapters or composition root

## Status
In Progress
