--!strict

const swan = require("../Packages/swan")
const create = swan.create
const keys = swan.keys

const names = { "john", "mark", "anne", "julius", "david" }
const players: swan.proxy_state<{ string }> = swan.proxy {}
const players_proxy = players()
const players_real = swan.utils.get_real(players_proxy)

const full = UDim2.fromScale(1, 1)

return function(target: Frame): () -> ()
	const playerlist = swan.create "ScrollingFrame" {
		Size = full,
		CanvasSize = full,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = target,

		create "UIGridLayout" {
			CellSize = UDim2.fromScale(0.5, 0.2),
			FillDirectionMaxCells = 1,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},

		keys(players, function(name: swan.state<string>)
			return create "TextLabel" {
				Name = name.value,
				Font = Enum.Font.Ubuntu,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				Text = name,
				TextColor3 = Color3.new(0.9, 0.9, 0.9),
				BackgroundColor3 = Color3.new(0.2, 0.2, 0.2),
				BorderSizePixel = 0,
			}
		end),
	}

	const thread = task.spawn(function()
		while true do
			task.wait(1)

			if math.random() > 0.45 then
				const name_count = #names
				if name_count == 0 then
					continue
				end

				const index = math.random(1, name_count)
				const name = names[index]
				players_proxy[#players_real + 1] = name
				names[index] = nil
				continue
			end

			const name_count = #players_real
			if name_count == 0 then
				continue
			end

			const index = math.random(1, name_count)
			const name = players_real[index]
			players_proxy[index] = nil
			table.insert(names, name)
		end
	end)

	return function()
		playerlist:Destroy()
		task.cancel(thread)
	end
end
