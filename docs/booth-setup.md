# Adding a trade booth

Booths are hand-placed. `BoothService` never spawns one — it discovers whatever
the place contains, so adding, moving or deleting a booth is a Studio edit and
never a code change.

Any model works, including something dragged straight out of the toolbox.

## What a booth model needs

| Requirement | What it is |
|---|---|
| Tag `TradeBooth` | CollectionService tag on the **model** |
| Attribute `BoothId` | Unique, stable string on the model, e.g. `booth_7` |
| Part named `Anchor` | The display board. Its **front face (−Z)** carries the storefront GUI, so point it at whoever is meant to read it |
| Part named `SkinMount` | Recoloured by the equipped skin. Pick something prominent — an awning, a sign, a nameplate |
| `ProximityPrompt` named `BoothPrompt` | Anywhere in the model. Hold-to-claim |

Anything missing, or a `BoothId` already used by another booth, and the booth is
skipped with a named warning at boot rather than half-working. Check the output
window after a play test.

## Making a model skinnable

Skins recolour **by part name**, so a toolbox model becomes skinnable just by
renaming a few parts:

- parts named `Canopy` take the skin's canopy colour
- parts named `Trim` take the skin's trim colour
- `SkinMount` always takes the canopy colour

Nothing else is touched, so the rest of the model keeps whatever the artist gave
it. Skins never affect price, tax, slot count, or which listings show — that rule
has a test that fails if it's ever broken.

## Converting a toolbox model into a booth

Select the model in Studio and run this in the command bar. It adds the tag, the
id, and a display board sized to the model, and it warns instead of guessing when
it can't find something.

```lua
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

for _, model in Selection:Get() do
	if not model:IsA("Model") then
		warn(model.Name .. " is not a Model; skipped")
		continue
	end

	-- unique id derived from the model name, deduped against what's placed
	local base = model.Name:lower():gsub("[^%w]+", "_")
	local id, n = base, 1
	local function taken(candidate)
		for _, b in CollectionService:GetTagged("TradeBooth") do
			if b ~= model and b:GetAttribute("BoothId") == candidate then
				return true
			end
		end
		return false
	end
	while taken(id) do
		n += 1
		id = base .. "_" .. n
	end
	model:SetAttribute("BoothId", id)

	local cf, size = model:GetBoundingBox()

	-- display board across the back, facing OUT of the model's front (-Z)
	if model:FindFirstChild("Anchor", true) == nil then
		local board = Instance.new("Part")
		board.Name = "Anchor"
		board.Size = Vector3.new(size.X * 0.9, size.Y * 0.42, 0.4)
		board.CFrame = cf * CFrame.new(0, size.Y * 0.22, size.Z * 0.45)
		board.Color = Color3.fromRGB(26, 29, 38)
		board.Anchored = true
		board.CanCollide = false
		board.Parent = model
	end

	-- nameplate on the front, for the skin colour
	if model:FindFirstChild("SkinMount", true) == nil then
		local plate = Instance.new("Part")
		plate.Name = "SkinMount"
		plate.Size = Vector3.new(size.X * 0.7, 1.1, 0.3)
		plate.CFrame = cf * CFrame.new(0, -size.Y * 0.2, -size.Z * 0.5)
		plate.Color = Color3.fromRGB(90, 100, 120)
		plate.Anchored = true
		plate.CanCollide = false
		plate.Parent = model
	end

	if model:FindFirstChild("BoothPrompt", true) == nil then
		local host = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if host then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BoothPrompt"
			prompt.ObjectText = "Trade Booth"
			prompt.ActionText = "Set up shop"
			prompt.HoldDuration = 1
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = host
		else
			warn(model.Name .. " has no BasePart to host the prompt")
		end
	end

	CollectionService:AddTag(model, "TradeBooth")
	print(("booth ready: %s (BoothId %q)"):format(model.Name, id))
end
```

Check the `Anchor` afterwards — the script points it along the model's own −Z,
which is only right if the model was built facing that way. Rotate it so it faces
the walkway.

## How many booths to place

Set the place's **max players to the number of booths**. Claims are first-come
and released when the owner leaves, so matching the two means a booth is always
free and nobody is ever locked out. Place fewer and some players can never set
up shop.
