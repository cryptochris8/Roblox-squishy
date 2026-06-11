--!strict
-- StoryPageConfig
-- The 18 hidden pages of The Lost Sparkle storybook, scattered through the
-- lands at story-appropriate spots. Permanent one-time treasures (unlike the
-- daily Sparkle Bits): find a page, see the real watercolor spread, and fill
-- the Storybook shelf. Collect all 18 to re-read the whole tale (+ a bonus).
--
-- `caption` is the book's text for that spread — left empty until Chris pastes
-- the real lines; the viewer shows just the art + page number meanwhile.

export type Page = { id: string, n: number, position: Vector3, caption: string }

local StoryPageConfig = {}

StoryPageConfig.PageCoins = 25
StoryPageConfig.AllBonus = 300

local pages: { Page } = {
	-- Pudding Hills (the story begins)
	{ id = "page_01", n = 1, position = Vector3.new(0, 3, -52), caption = "" },
	{ id = "page_02", n = 2, position = Vector3.new(62, 3, -46), caption = "" },
	{ id = "page_03", n = 3, position = Vector3.new(-80, 3, 36), caption = "" },
	{ id = "page_04", n = 4, position = Vector3.new(-24, 3, -74), caption = "" },
	{ id = "page_05", n = 5, position = Vector3.new(-42, 3, -58), caption = "" },
	{ id = "page_06", n = 6, position = Vector3.new(102, 3, -14), caption = "" },
	-- Goo Coast
	{ id = "page_07", n = 7, position = Vector3.new(600, 4.5, -56), caption = "" },
	{ id = "page_08", n = 8, position = Vector3.new(518, 3, -4), caption = "" },
	{ id = "page_09", n = 9, position = Vector3.new(554, 3, 54), caption = "" },
	{ id = "page_10", n = 10, position = Vector3.new(670, 3, 2), caption = "" },
	{ id = "page_11", n = 11, position = Vector3.new(650, 3, 72), caption = "" },
	{ id = "page_12", n = 12, position = Vector3.new(580, 3, 88), caption = "" },
	-- Moonlit Hollow (the story ends where the Sparkle fell)
	{ id = "page_13", n = 13, position = Vector3.new(1248, 3, -72), caption = "" },
	{ id = "page_14", n = 14, position = Vector3.new(1144, 3, 74), caption = "" },
	{ id = "page_15", n = 15, position = Vector3.new(1138, 3, 14), caption = "" },
	{ id = "page_16", n = 16, position = Vector3.new(1248, 3, 16), caption = "" },
	{ id = "page_17", n = 17, position = Vector3.new(1200, 3, -42), caption = "" },
	{ id = "page_18", n = 18, position = Vector3.new(1272, 3, -20), caption = "" },
}
StoryPageConfig.Pages = pages

function StoryPageConfig.count(): number
	return #pages
end

function StoryPageConfig.get(id: string): Page?
	for _, p in ipairs(pages) do
		if p.id == id then
			return p
		end
	end
	return nil
end

return StoryPageConfig
