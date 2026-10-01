--!strict
local tiniest_for_lune = require("@tiniest/tiniest_for_lune")

local WanderPoint = require("@shared/Wander/WanderPoint")

type Tiniest = typeof(tiniest_for_lune.configure({}))

local describe = t.describe
local test = t.test
local expect = t.expect

describe("WanderPoint.new", function()
	test("creates a WanderPoint with a location", function()
		local wp = WanderPoint.new("ball")
		expect(wp.location).is("ball")
	end)

	test("rejects a nil location", function()
		local ok = pcall(function()
			WanderPoint.new(nil)
		end)
		expect(ok).is(false)
	end)
end)

describe("WanderPoint.type", function()
	test("WanderPoint is a table", function()
		local wp = WanderPoint.new("ball")
		expect(type(wp)).is("table")
	end)
end)
