# swan
`swan` is a simple state management library for Luau.

# Installation
## Pesde
```console
# pesde add wiam/swan && pesde install
```

## Wally
Add the following to your `wally.toml`, in the `[dependencies]` section:
```toml
swan = "wiam77/swan@<version>"
```

Then run:
```console
# wally install
```

## npm
`swan` provides typings for TypeScript.
```console
# npm install @rbxts/swan
```

# Documentation
You can read `swan`'s documentation [here](https://wiam.codeberg.page/swan).

# Demo
```luau
local bullets = state(100)
local main_frame = create("Frame", {
	BackgroundColor3 = Color3.new(),
	Size = UDim2.fromScale(1, 1),
	Children = {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(100, 100)
		}),
		bullets_label = create("TextLabel", {
			Text = "Bullets: "..bullets :: string -- implicit derived
		}),
		shoot_button = create("TextButton", {
			Text = "Shoot",
			MouseButton1Down = function()
				bullets(bullets.value - 1)
			end
		})
	}
})
```
