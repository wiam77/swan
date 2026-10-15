--!strict

const swan = require("../Packages/swan")

return function(target: Frame): () -> ()
	const target_size = swan.state(UDim2.fromScale(0.2, 0.2))
	const target_color = swan.state(Color3.new())

	const main = swan.create "Frame" {
		AnchorPoint = Vector2.one * 0.5,
		Position = swan.tween(
			TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, true),
			UDim2.fromScale(0.8, 0.8),
			UDim2.fromScale(0.2, 0.2)
		),
		Rotation = swan.tween(TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), 180, 0),
		Size = swan.tween(TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), target_size),
		BackgroundColor3 = swan.tween(TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), target_color),
		BorderSizePixel = 0,
		Parent = target,
	}

	const thread = task.spawn(function()
		while true do
			task.wait(1)

			const current_size = target_size.value
			const current_width = current_size.X.Scale
			const current_height = current_size.Y.Scale
			target_size(
				UDim2.new(
					math.clamp(current_width + math.random(-1, 1) / 10, 0.1, 1),
					nil,
					math.clamp(current_height + math.random(-1, 1) / 10, 0.1, 1),
					nil
				)
			)

			const current_color = target_color.value
			target_color(
				current_color:Lerp(
					Color3.new(math.random(), math.random(), math.random()),
					math.abs(math.sin(os.clock()))
				)
			)
		end
	end)

	return function()
		main:Destroy()
		coroutine.close(thread)
	end
end
