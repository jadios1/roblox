--!strict
-- Pure wallet logic. No Roblox APIs — this module must stay runnable under Lune.
-- Amounts are integers (no fractional currency).

export type WalletData = {
	balance: number,
}

local Wallet = {}
Wallet.__index = Wallet

export type Wallet = typeof(setmetatable({} :: { _balance: number }, Wallet))

local function validateAmount(amount: number): (boolean, string?)
	if amount ~= amount then
		return false, "amount must not be NaN"
	end
	if amount ~= math.floor(amount) or math.abs(amount) == math.huge then
		return false, "amount must be an integer"
	end
	if amount <= 0 then
		return false, "amount must be positive"
	end
	return true, nil
end

function Wallet.new(initialBalance: number?): Wallet
	local balance = initialBalance or 0
	assert(
		balance == balance and balance >= 0 and balance == math.floor(balance),
		"initial balance must be a non-negative integer"
	)
	return setmetatable({ _balance = balance }, Wallet)
end

function Wallet.balance(self: Wallet): number
	return self._balance
end

function Wallet.deposit(self: Wallet, amount: number): (boolean, string?)
	local ok, err = validateAmount(amount)
	if not ok then
		return false, err
	end
	self._balance += amount
	return true, nil
end

function Wallet.withdraw(self: Wallet, amount: number): (boolean, string?)
	local ok, err = validateAmount(amount)
	if not ok then
		return false, err
	end
	if amount > self._balance then
		return false, "insufficient funds"
	end
	self._balance -= amount
	return true, nil
end

-- New: check if a withdrawal would succeed without mutating
function Wallet.canWithdraw(self: Wallet, amount: number): boolean
	-- amount must be a positive integer; treat invalid as false
	local ok, _ = validateAmount(amount)
	if not ok then
		return false
	end
	return amount <= self._balance
end

-- Return true if the wallet has a zero balance.
function Wallet.isEmpty(self: Wallet): boolean
	return self._balance == 0
end

function Wallet.serialize(self: Wallet): WalletData
	return { balance = self._balance }
end

-- Data from persistence is untrusted: validate the shape before use.
function Wallet.deserialize(data: unknown): (Wallet?, string?)
	if typeof(data) ~= "table" then
		return nil, "wallet data must be a table"
	end
	local balance = (data :: { [string]: unknown }).balance
	if typeof(balance) ~= "number" then
		return nil, "wallet balance must be a number"
	end
	if balance ~= balance or balance < 0 or balance ~= math.floor(balance) then
		return nil, "wallet balance must be a non-negative integer"
	end
	return Wallet.new(balance), nil
end

return Wallet
