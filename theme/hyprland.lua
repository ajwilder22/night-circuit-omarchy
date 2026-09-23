local teal = "rgba(50d8c5ee)"
local violet = "rgba(a58bffee)"
local inactive = "rgba(334a5cbb)"
local active = { colors = { teal, violet }, angle = 35 }

hl.config({
  general = {
    border_size = 2,
    gaps_in = 10,
    gaps_out = 17,
    col = { active_border = active, inactive_border = inactive },
  },
  group = {
    col = { border_active = active, border_inactive = inactive },
  },
  decoration = {
    rounding = 18,
    rounding_power = 2,
    shadow = {
      enabled = true,
      range = 18,
      render_power = 3,
      color = "rgba(50d8c530)",
      color_inactive = "rgba(05091366)",
    },
  },
})
