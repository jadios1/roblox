--!strict
local tiniest_for_lune = require("@tiniest/tiniest_for_lune")

local CurrencyService = require("@server/Services/CurrencyService")
local FakeDataStore = require("../helpers/FakeDataStore")

type Tiniest = typeof(tiniest_for_lune.configure({}))

local USER_ID = 123
local OTHER_USER_ID = 456

-- Collects the messages a service reports instead of printing them, so the
-- "we recovered, but noisily" paths can be asserted on.
local function newLog()
	local messages: { string } = {}
	return messages, function(message: string)
		table.insert(messages, message)
	end
end

-- Records retry delays without spending any real time.
local function newWait()
	local delays: { number } = {}
	return delays, function(seconds: number)
		table.insert(delays, seconds)
	end
end

local function contains(messages: { string }, needle: string): boolean
	for _, message in messages do
		if string.find(message, needle, 1, true) then
			return true
		end
	end
	return false
end

return function(t: Tiniest)
	local describe = t.describe
	local test = t.test
	local expect = t.expect

	describe("CurrencyService.new", function()
		test("rejects a misconfigured starting balance at construction", function()
			-- Contract: configuration errors crash at startup, not at player join.
			local ok = pcall(function()
				return CurrencyService.new({ store = FakeDataStore.new(), startingBalance = -1 })
			end)
			expect(ok).is(false)

			local okFractional = pcall(function()
				return CurrencyService.new({ store = FakeDataStore.new(), startingBalance = 0.5 })
			end)
			expect(okFractional).is(false)
		end)

		test("rejects a non-positive retry count", function()
			local ok = pcall(function()
				return CurrencyService.new({ store = FakeDataStore.new(), maxAttempts = 0 })
			end)
			expect(ok).is(false)
		end)
	end)

	describe("CurrencyService.loadPlayer", function()
		test("gives new players the starting balance", function()
			local service =
				CurrencyService.new({ store = FakeDataStore.new(), startingBalance = 50 })
			expect((service:loadPlayer(USER_ID))).is(true)
			expect(service:getBalance(USER_ID)).is(50)
		end)

		test("restores a returning player's wallet from the store", function()
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = 777 })
			local service = CurrencyService.new({ store = store })
			service:loadPlayer(USER_ID)
			expect(service:getBalance(USER_ID)).is(777)
		end)

		test("is idempotent while the player stays loaded", function()
			local service =
				CurrencyService.new({ store = FakeDataStore.new(), startingBalance = 50 })
			service:loadPlayer(USER_ID)
			service:deposit(USER_ID, 10)
			service:loadPlayer(USER_ID)
			expect(service:getBalance(USER_ID)).is(60)
		end)

		test("retries a failing load and succeeds within the attempt budget", function()
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = 42 })
			store.failLoads = 2
			local delays, wait = newWait()
			local service = CurrencyService.new({
				store = store,
				maxAttempts = 3,
				retryDelay = 2,
				wait = wait,
			})

			expect((service:loadPlayer(USER_ID))).is(true)
			expect(service:getBalance(USER_ID)).is(42)
			expect(store.loadCount).is(3)
			expect(#delays).is(2)
			expect(delays[1]).is(2)
		end)

		test("gives no wallet when the store stays unavailable", function()
			-- The important part: a failed read must NOT invent a wallet, because
			-- unloading would then write it over the player's real balance.
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = 500 })
			store.failLoads = 3
			local _, wait = newWait()
			local service = CurrencyService.new({ store = store, maxAttempts = 3, wait = wait })

			local ok, err = service:loadPlayer(USER_ID)
			expect(ok).is(false)
			expect(err).is("store unavailable")
			expect(service:getBalance(USER_ID)).never_exists()

			service:unloadPlayer(USER_ID)
			expect((store.peek(`player/{USER_ID}`) :: any).balance).is(500)
		end)
	end)

	describe("corrupt stored data", function()
		test("quarantines the original payload and reports why", function()
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = -999 })
			local messages, log = newLog()
			local service = CurrencyService.new({ store = store, startingBalance = 50, log = log })

			service:loadPlayer(USER_ID)

			expect(service:getBalance(USER_ID)).is(50)
			expect(contains(messages, "quarantining")).is(true)
			local parked = store.peek(`player/{USER_ID}/corrupt`)
			expect(parked).exists()
			expect((parked :: any).balance).is(-999)
		end)

		test("persists the replacement wallet once the original is parked", function()
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = -999 })
			local service = CurrencyService.new({ store = store, startingBalance = 50 })

			service:loadPlayer(USER_ID)
			service:deposit(USER_ID, 5)
			expect((service:unloadPlayer(USER_ID))).is(true)
			expect((store.peek(`player/{USER_ID}`) :: any).balance).is(55)
		end)

		test("refuses to overwrite unreadable data it could not quarantine", function()
			-- The data-loss case from the review: without this guard, a fresh
			-- wallet gets written over a record support might have recovered.
			--
			-- failSaves is set to exactly the quarantine's attempt budget, so the
			-- quarantine fails but the later write WOULD succeed. That is what
			-- makes this test able to fail: with the guard removed, the save goes
			-- through and the original payload is gone.
			local store = FakeDataStore.new()
			store.seed(`player/{USER_ID}`, { balance = "not a number" })
			local messages, log = newLog()
			local _, wait = newWait()
			local service = CurrencyService.new({
				store = store,
				startingBalance = 50,
				maxAttempts = 2,
				wait = wait,
				log = log,
			})

			store.failSaves = 2
			service:loadPlayer(USER_ID)
			expect(service:getBalance(USER_ID)).is(50)
			expect(store.failSaves).is(0) -- quarantine exhausted the budget

			service:deposit(USER_ID, 5)
			local ok, err = service:unloadPlayer(USER_ID)

			expect(ok).is(false)
			expect(err).exists()
			expect(contains(messages, "will not be persisted")).is(true)
			-- Nothing was written anywhere, and the original survives intact.
			expect(store.saveCount).is(0)
			expect((store.peek(`player/{USER_ID}`) :: any).balance).is("not a number")
		end)
	end)

	describe("CurrencyService.unloadPlayer", function()
		test("persists the wallet and evicts the session", function()
			local store = FakeDataStore.new()
			local service = CurrencyService.new({ store = store, startingBalance = 50 })
			service:loadPlayer(USER_ID)
			service:deposit(USER_ID, 25)
			expect((service:unloadPlayer(USER_ID))).is(true)

			expect(service:getBalance(USER_ID)).never_exists()
			expect(store.saveCount).is(1)
			local saved = store.peek(`player/{USER_ID}`)
			expect(saved).exists()
			expect((saved :: any).balance).is(75)
		end)

		test("does nothing for players that were never loaded", function()
			local store = FakeDataStore.new()
			local service = CurrencyService.new({ store = store })
			expect((service:unloadPlayer(USER_ID))).is(true)
			expect(store.saveCount).is(0)
		end)

		test("retries a failing save and succeeds within the attempt budget", function()
			local store = FakeDataStore.new()
			local delays, wait = newWait()
			local service = CurrencyService.new({
				store = store,
				startingBalance = 10,
				maxAttempts = 3,
				retryDelay = 5,
				wait = wait,
			})
			service:loadPlayer(USER_ID)

			store.failSaves = 2
			expect((service:unloadPlayer(USER_ID))).is(true)
			expect(#delays).is(2)
			expect(delays[1]).is(5)
			expect((store.peek(`player/{USER_ID}`) :: any).balance).is(10)
		end)

		test("reports a failed save and still evicts the session", function()
			local store = FakeDataStore.new()
			store.failSaves = 99
			local messages, log = newLog()
			local _, wait = newWait()
			local service = CurrencyService.new({
				store = store,
				maxAttempts = 2,
				wait = wait,
				log = log,
			})
			service:loadPlayer(USER_ID)

			local ok, err = service:unloadPlayer(USER_ID)
			expect(ok).is(false)
			expect(err).is("store unavailable")
			expect(service:getBalance(USER_ID)).never_exists()
			expect(contains(messages, "failed to persist")).is(true)
		end)
	end)

	describe("CurrencyService.unloadAll", function()
		test("flushes every live session", function()
			-- Stands in for BindToClose: without it a shutdown drops these writes.
			local store = FakeDataStore.new()
			local service = CurrencyService.new({ store = store, startingBalance = 10 })
			service:loadPlayer(USER_ID)
			service:loadPlayer(OTHER_USER_ID)
			service:deposit(USER_ID, 5)
			service:deposit(OTHER_USER_ID, 7)

			expect((service:unloadAll())).is(true)
			expect(store.saveCount).is(2)
			expect((store.peek(`player/{USER_ID}`) :: any).balance).is(15)
			expect((store.peek(`player/{OTHER_USER_ID}`) :: any).balance).is(17)
			expect(service:getBalance(USER_ID)).never_exists()
		end)

		test("keeps flushing after one player fails and reports the failure", function()
			local store = FakeDataStore.new()
			local _, wait = newWait()
			local service = CurrencyService.new({
				store = store,
				startingBalance = 10,
				maxAttempts = 1,
				wait = wait,
			})
			service:loadPlayer(USER_ID)
			service:loadPlayer(OTHER_USER_ID)

			-- USER_ID sorts first, so fail exactly that one save.
			store.failSaves = 1
			local ok, err = service:unloadAll()

			expect(ok).is(false)
			expect(err).is("store unavailable")
			expect(store.peek(`player/{USER_ID}`)).never_exists()
			expect((store.peek(`player/{OTHER_USER_ID}`) :: any).balance).is(10)
		end)

		test("is a no-op with no sessions", function()
			local store = FakeDataStore.new()
			local service = CurrencyService.new({ store = store })
			expect((service:unloadAll())).is(true)
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
