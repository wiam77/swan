--!strict

const swan = require("../Packages/swan")
const swan_types = require("../Packages/swan/swan_types")
const create = swan.create
const values = swan.values

const inventory: swan.proxy_state<{ string }> = swan.proxy { "sword", "apple", "shield", "bow", "arrow" }
const inventory_proxy = inventory.value
const inventory_real = swan.utils.get_real(inventory_proxy)

return function(target: Frame): () -> ()
	const inventory_ui = swan.create "Frame" {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = target,

		create "UIGridLayout" {
			CellSize = UDim2.fromScale(0.5, 0.2),
			FillDirectionMaxCells = 1,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},

		values(inventory, function(index: swan_types.state<number>, item: string)
			return create "TextLabel" {
				Name = index :: any,
				Font = Enum.Font.Ubuntu,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				Text = "[" .. index :: any .. "] " .. item,
				TextColor3 = Color3.new(0.9, 0.9, 0.9),
				BackgroundColor3 = Color3.new(0.2, 0.2, 0.2),
				BorderSizePixel = 0,
			}
		end),
	}

	const shuffle_thread = task.spawn(function()
		while true do
			task.wait(math.random(1, 2))

			const item_count = #inventory_real
			const item1_index = math.random(1, item_count)
			local item2_index = item1_index
			while item2_index == item1_index do
				item2_index = math.random(1, item_count)
			end

			const item1 = inventory_real[item1_index]
			inventory_proxy[item1_index] = inventory_real[item2_index]
			inventory_proxy[item2_index] = item1
		end
	end)

	return function()
		inventory_ui:Destroy()
		task.cancel(shuffle_thread)
	end
end
