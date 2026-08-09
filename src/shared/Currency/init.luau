--!strict
-- Public surface of the Currency feature. `@self/X` requires a child of this
-- module — identical semantics in the Roblox engine and Lune.

local Wallet = require("@self/Wallet")

export type Wallet = Wallet.Wallet
export type WalletData = Wallet.WalletData

return {
	Wallet = Wallet,
}
