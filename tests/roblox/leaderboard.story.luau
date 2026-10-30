--!strict

const swan = require("../Packages/swan")
const map = swan.map
const create = swan.create

const names = { "john", "mark", "anne", "julius", "david" }

return function(target: Frame): () -> ()
	const leaderboard = swan.create "Frame" {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = target,

		create "UIGridLayout" {
			CellSize = UDim2.fromScale(0.2, 0.2),
			FillDirectionMaxCells = 1,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},

		map(swan.proxy(names), function(i: number, name: string)
			return swan.create "TextLabel" {
				Text = `{i}. {name}`,
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundColor3 = Color3.new(),
				BorderSizePixel = 0,
			}
		end),
	}

	return function()
		leaderboard:Destroy()
	end
end
