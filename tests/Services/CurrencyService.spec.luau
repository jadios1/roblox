--!strict
local tiniest_for_lune = require("@tiniest/tiniest_for_lune")

local CurrencyService = require("@server/Services/CurrencyService")
local FakeDataStore = require("../helpers/FakeDataStore")

type Tiniest = typeof(tiniest_for_lune.configure({}))

local USER_ID = 123

return function(t: Tiniest)
	local describe = t.describe
	local test = t.test
	local expect = t.expect

	describe("CurrencyService.loadPlayer", function()
		test("gives new players the starting balance", function()
			local service =
				CurrencyService.new({ store = FakeDataStore.new(), startingBalance = 50 })
			service:loadPlayer(USER_ID)
			expect(service:getBalance(USER_ID)).is(50)
		end)

		test("restores a returning player's wallet from the store", function()
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = 777 })
			local service = CurrencyService.new({ store = store })
			service:loadPlayer(USER_ID)
			expect(service:getBalance(USER_ID)).is(777)
		end)

		test("falls back to a fresh wallet on corrupt data", function()
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = -999 } :: any)
			local service = CurrencyService.new({ store = store, startingBalance = 50 })
			service:loadPlayer(USER_ID)
			expect(service:getBalance(USER_ID)).is(50)
		end)

		test("is idempotent while the player stays loaded", function()
			local service =
				CurrencyService.new({ store = FakeDataStore.new(), startingBalance = 50 })
			service:loadPlayer(USER_ID)
			service:deposit(USER_ID, 10)
			service:loadPlayer(USER_ID)
			expect(service:getBalance(USER_ID)).is(60)
		end)
	end)

	describe("CurrencyService.unloadPlayer", function()
		test("persists the wallet and evicts the session", function()
			local store = FakeDataStore.new()
			local service = CurrencyService.new({ store = store, startingBalance = 50 })
			service:loadPlayer(USER_ID)
			service:deposit(USER_ID, 25)
			service:unloadPlayer(USER_ID)

			expect(service:getBalance(USER_ID)).never_exists()
			expect(store.saveCount).is(1)
			local saved = store.peek(`player/{USER_ID}`)
			expect(saved).exists()
			expect((saved :: any).balance).is(75)
		end)

		test("does nothing for players that were never loaded", function()
			local store = FakeDataStore.new()
			local service = CurrencyService.new({ store = store })
			service:unloadPlayer(USER_ID)
			expect(store.saveCount).is(0)
		end)
	end)

	describe("balance commands", function()
		test("deposit and withdraw update the balance", function()
			local service =
				CurrencyService.new({ store = FakeDataStore.new(), startingBalance = 100 })
			service:loadPlayer(USER_ID)
			expect((service:deposit(USER_ID, 40))).is(true)
			expect((service:withdraw(USER_ID, 30))).is(true)
			expect(service:getBalance(USER_ID)).is(110)
		end)

		test("commands fail for unloaded players", function()
			local service = CurrencyService.new({ store = FakeDataStore.new() })
			local ok, err = service:deposit(USER_ID, 40)
			expect(ok).is(false)
			expect(err).is("player is not loaded")
		end)

		test("wallet validation errors pass through", function()
			local service =
				CurrencyService.new({ store = FakeDataStore.new(), startingBalance = 5 })
			service:loadPlayer(USER_ID)
			local ok, err = service:withdraw(USER_ID, 10)
			expect(ok).is(false)
			expect(err).is("insufficient funds")
		end)
	end)
end
