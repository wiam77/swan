local binary_ops = {}

function binary_ops.concat(a, b)
	return a..b
end

function binary_ops.add(a, b)
	return a + b
end

function binary_ops.sub(a, b)
	return a - b
end

function binary_ops.mul(a, b)
	return a * b
end

function binary_ops.div(a, b)
	return a / b
end

function binary_ops.idiv(a, b)
	return a // b
end

function binary_ops.mod(a, b)
	return a % b
end

function binary_ops.pow(a, b)
	return a ^ b
end

return binary_ops