--!strict

const lest = require("@lest")
const describe, it, expect = lest.describe, lest.it, lest.expect
const beforeEach = lest.beforeEach

const swan = require("../src")
const state = swan.state

describe("state (constructor)", function()
	it("returns a state", function()
		expect(state()).toBeTruthy()
	end)

	it("accepts an initial value", function()
		expect(state("initial value")).toBeTruthy()
	end)
end)

describe("state (object)", function()
	local test_state_a: swan.state
	local test_state_b: swan.state
	const test_value_a = "initial value"
	const test_value_b = "new value"
	const test_value_c = test_value_a .. test_value_b

	beforeEach(function()
		test_state_a = state(test_value_a)
		test_state_b = state(test_value_b)
	end)

	it("has a getter (state())", function()
		expect(test_state_a()).toBe(test_value_a)
	end)

	it("has .value", function()
		expect(test_state_a.value).toBe(test_value_a)
	end)

	it("has a setter (state(v))", function()
		test_state_a(test_value_b)

		expect(test_state_a()).toBe(test_value_b)
		expect(test_state_a.value).toBe(test_value_b)
	end)

	it("is always forceable", function()
		expect(test_state_a.always_force).toBe(false)
	end)

	it("overloads (implicitly derived state)", function()
		describe("string", function()
			it("concatenation", function()
				const test_state_c = test_state_a .. test_state_b
				expect(test_state_c.value).toBe(test_value_c)
			end)
		end)

		describe("math", function()
			it("addition", function() end)
		end)
	end)
end)

return nil
