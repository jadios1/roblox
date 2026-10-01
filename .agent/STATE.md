# State of Implementation

## Core Components

- **Wallet.luau** - Pure Luau currency logic with validation
- **CurrencyService.luau** - Server-side orchestration with retry mechanism
- **DataStoreAdapter.luau** - Roblox adapter for DataStoreService
- **init.server.luau** - Server composition root with client glue
- **init.client.luau** - Client glue for balance retrieval
- **StarterWorld.luau** - World content with Starter characters and assets
- **StarterPlayer.luau** - Starter player logic
- **StarterGear.luau** - Starter asset logic
- **StarterGui.luau** - Starter UI

## Project Structure

```
src/
├── shared/
│   └── Currency/
│       └── Wallet.luau
├── server/
│   ├── Services/
│   │   └── CurrencyService.luau
│   ├── Adapters/
│   │   └── DataStoreAdapter.luau
│   └── init.server.luau
└── client/
    └── init.client.luau
```

## Game Concept

Simple character progression game with a currency system. Players earn money through earning points, which are converted to currency. The game features:
1. Starter characters with a default balance
2. Earnable points for leveling up
3. Currency accumulation over time
4. Player balance management with withdrawal capabilities

## Implemented Features

### 1. Wallet.luau - Currency Logic
- `Wallet.new()` - Initialize wallet with balance
- `Wallet.balance()` - Get current balance
- `Wallet.deposit()` - Add currency
- `Wallet.withdraw()` - Subtract currency
- `Wallet.canWithdraw()` - Check if withdrawal is possible
- `Wallet.serialize()` - Serialize wallet data
- `Wallet.deserialize()` - Deserialize wallet data

### 2. CurrencyService.luau - Server Business Logic
- `CurrencyService.new()` - Initialize service with store and config
- `CurrencyService.loadWithRetry()` - Load wallet with retry mechanism
- `CurrencyService.saveWithRetry()` - Save wallet with retry
- `CurrencyService.loadPlayer()` - Load player wallet
- `CurrencyService.unloadPlayer()` - Unload player wallet
- `CurrencyService.unloadAll()` - Flush all sessions
- `CurrencyService.getBalance()` - Get current balance
- `CurrencyService.deposit()` - Deposit currency
- `CurrencyService.withdraw()` - Withdraw currency

### 3. DataStoreAdapter.luau - Roblox Adapter
- `DataStoreAdapter.new()` - Wrap DataStoreService
- `DataStoreAdapter.load()` - Load wallet with retry
- `DataStoreAdapter.save()` - Save wallet with retry

## Dependencies

- `require("../../shared/Currency")` - Import Wallet module
- `require("../../shared/Currency")` - Import Wallet module (for CurrencyService)
- `require("../../shared/Currency")` - Import Wallet module (for DataStoreAdapter)

## Quality Gates

- `config parity` - All duplicated facts have been set
- `format` - Styling is compliant
- `lint` - No undefined globals, no suspicious code
- `types` - No strict Luau type errors
- `unit tests` - No unit tests (client is not unit tested)
- `build` - Build succeeded

## TODOs

1. Implement session locking for multiplayer support
2. Add balance ceiling for withdrawal (2^53)
3. Implement persistence with session locking
4. Add player creation system (StarterPack)
5. Add leveling system (progression)
6. Add more actions to earn points
7. Add game mechanics (stats, achievements, etc.)

## Testing

- All tests are in `tests/Currency/`
- Tests are deterministic and do not depend on real time
- Tests use fakes for service construction
- Client is not unit tested (only renders results)

## File Structure

```
src/
├── shared/
│   └── Currency/
│       └── Wallet.luau
├── server/
│   ├── Services/
│   │   └── CurrencyService.luau
│   ├── Adapters/
│   │   └── DataStoreAdapter.luau
│   └── init.server.luau
└── client/
    └── init.client.luau
```

## Global Types

- `WalletData = { balance: number }`
- `Wallet = typeof(setmetatable({} :: { _balance: number }, Wallet))`
- `StoreLike = { load: (key: string) -> LoadResult, save: (key: string, data: unknown) -> SaveResult }`
- `CurrencyService.StoreLike = StoreLike`
- `CurrencyService.LoadResult = { ok: true, data: unknown } | { ok: false, err: string }`
- `CurrencyService.SaveResult = { ok: true } | { ok: false, err: string }`
