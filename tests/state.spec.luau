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
	local test_state_a: swan.state<string>
	local test_state_b: swan.state<string>
	const test_value_a = "initial value"
	const test_value_b = "new value"

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
		expect(test_state_a.always_force).toBeFalsy()
	end)

	describe("overloads (implicitly computed state)", function()
		it("string concatenation", function()
			const test_state_c = test_state_a .. test_state_b
			expect(test_state_c.value).toBe(test_value_a .. test_value_b)
		end)

		describe("math", function()
			const test_number = 10
			const number_state = state(test_number)

			it("negation", function()
				expect((-number_state)()).toBe(-test_number)
			end)

			it("addition", function()
				expect((number_state + number_state)()).toBe(test_number + test_number)
			end)

			it("subtraction", function()
				expect((number_state - number_state)()).toBe(test_number - test_number)
			end)

			it("multiplication", function()
				expect((number_state * 4)()).toBe(test_number * 4)
			end)

			it("division", function()
				expect((number_state / 4)()).toBe(test_number / 4)
			end)

			it("floor division", function()
				expect((number_state // 3)()).toBe(test_number // 3)
			end)

			it("modulo", function()
				expect((number_state % 3)()).toBe(test_number % 3)
			end)

			it("power", function()
				expect((number_state ^ 3)()).toBe(test_number ^ 3)
			end)
		end)
	end)
end)

return nil
