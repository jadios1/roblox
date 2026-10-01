# logging

## Files

- `src/shared/Currency/Wallet.luau` - Wallet logic
- `src/server/Services/CurrencyService.luau` - Server business logic
- `src/server/Adapters/DataStoreAdapter.luau` - Roblox adapter
- `src/client/init.client.luau` - Client glue
- `src/server/init.server.luau` - Server composition root
- `src/world/StarterWorld.luau` - World content
- `src/world/StarterPlayer.luau` - Player logic
- `src/world/StarterGear.luau` - Starter asset
- `src/world/StarterGui.luau` - Starter UI

## File structure

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

## Global types

- `WalletData = { balance: number }`
- `Wallet = typeof(setmetatable({} :: { _balance: number }, Wallet))`
- `StoreLike = { load: (key: string) -> LoadResult, save: (key: string, data: unknown) -> SaveResult }`
- `CurrencyService.StoreLike = StoreLike`
- `CurrencyService.LoadResult = { ok: true, data: unknown } | { ok: false, err: string }`
- `CurrencyService.SaveResult = { ok: true } | { ok: false, err: string }`

## Logging

All code uses `debug.traceback()` and `debug.info()` for logging.
