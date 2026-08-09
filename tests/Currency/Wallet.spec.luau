--!strict
local tiniest_for_lune = require("@tiniest/tiniest_for_lune")

local Wallet = require("@shared/Currency").Wallet

type Tiniest = typeof(tiniest_for_lune.configure({}))

return function(t: Tiniest)
	local describe = t.describe
	local test = t.test
	local expect = t.expect

	describe("Wallet.new", function()
		test("starts at zero by default", function()
			expect(Wallet.new():balance()).is(0)
		end)

		test("accepts an initial balance", function()
			expect(Wallet.new(250):balance()).is(250)
		end)

		test("rejects a negative initial balance", function()
			expect(function()
				Wallet.new(-1)
			end).fails()
		end)
	end)

	describe("Wallet:deposit", function()
		test("adds to the balance", function()
			local wallet = Wallet.new(10)
			local ok = wallet:deposit(5)
			expect(ok).is(true)
			expect(wallet:balance()).is(15)
		end)

		test("rejects zero and negative amounts", function()
			local wallet = Wallet.new(10)
			expect((wallet:deposit(0))).is(false)
			expect((wallet:deposit(-5))).is(false)
			expect(wallet:balance()).is(10)
		end)

		test("rejects non-integer amounts", function()
			local wallet = Wallet.new(10)
			expect((wallet:deposit(1.5))).is(false)
			expect(wallet:balance()).is(10)
		end)

		test("rejects NaN and infinity", function()
			local wallet = Wallet.new(10)
			expect((wallet:deposit(0 / 0))).is(false)
			expect((wallet:deposit(math.huge))).is(false)
			expect(wallet:balance()).is(10)
		end)
	end)

	describe("Wallet:withdraw", function()
		test("subtracts from the balance", function()
			local wallet = Wallet.new(10)
			local ok = wallet:withdraw(4)
			expect(ok).is(true)
			expect(wallet:balance()).is(6)
		end)

		test("rejects overdrafts and reports why", function()
			local wallet = Wallet.new(3)
			local ok, err = wallet:withdraw(4)
			expect(ok).is(false)
			expect(err).is("insufficient funds")
			expect(wallet:balance()).is(3)
		end)

		test("allows withdrawing the full balance", function()
			local wallet = Wallet.new(7)
			expect((wallet:withdraw(7))).is(true)
			expect(wallet:balance()).is(0)
		end)
	end)

	describe("serialization round trip", function()
		test("serialize -> deserialize preserves balance", function()
			local wallet = Wallet.new(42)
			local restored = Wallet.deserialize(wallet:serialize())
			expect(restored).exists()
			expect((restored :: any):balance()).is(42)
		end)

		test("deserialize rejects malformed data", function()
			for _, bad in
				{ 5 :: any, "money", { balance = "lots" }, { balance = -1 }, { balance = 0.5 } }
			do
				local restored, err = Wallet.deserialize(bad)
				expect(restored).never_exists()
				expect(err).exists()
			end
		end)
	end)
end
