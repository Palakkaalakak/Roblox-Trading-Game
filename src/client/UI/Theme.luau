--!strict
-- Theme: palette, fonts, shared metrics. Pet-Sim-adjacent: chunky rounded
-- panels, bold headers, rarity-colored accents.

local Theme = {
	Font = Enum.Font.GothamBold,
	FontLight = Enum.Font.Gotham,

	Bg = Color3.fromRGB(32, 34, 42),
	BgLight = Color3.fromRGB(44, 47, 58),
	Panel = Color3.fromRGB(38, 41, 51),
	Stroke = Color3.fromRGB(70, 74, 90),
	TextPrimary = Color3.fromRGB(240, 242, 248),
	TextDim = Color3.fromRGB(160, 165, 180),

	Accent = Color3.fromRGB(88, 166, 255),
	Good = Color3.fromRGB(87, 217, 130),
	Bad = Color3.fromRGB(240, 95, 95),
	Warn = Color3.fromRGB(250, 190, 80),
	Gem = Color3.fromRGB(120, 220, 232),

	Rarity = {
		Common = Color3.fromRGB(154, 160, 166),
		Rare = Color3.fromRGB(79, 195, 247),
		Legendary = Color3.fromRGB(255, 183, 77),
		Mythical = Color3.fromRGB(186, 104, 200),
		Godly = Color3.fromRGB(255, 95, 130), -- rose-red
		Celestial = Color3.fromRGB(120, 245, 235), -- aqua glow
	} :: { [string]: Color3 },

	Corner = UDim.new(0, 10),
	CornerSmall = UDim.new(0, 6),

	-- UI chrome icons (Simulator Icon Pack decals)
	Icons = {
		Gem = "rbxassetid://17368064384",
		Trade = "rbxassetid://15403064919",
		Inventory = "rbxassetid://15402958715",
		Accept = "rbxassetid://17368190066",
		Deny = "rbxassetid://17368208554",
		Player = "rbxassetid://92109681457452",
		Star = "rbxassetid://17368097932",
	},
}

return Theme
