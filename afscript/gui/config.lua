-- GUI config

local config = {
    colors = {
        main = {
            bg = colors.lightBlue,
            fg = colors.white
        },
        button = {
            bg = colors.white,
            fg = colors.black,
            bg_press = colors.lightGray,
            fg_press = colors.gray,
            bg_disabled = colors.lightGray,
        },
        input = {
            bg = colors.white,
            fg = colors.black
        },
        label = {
            bg = colors.white,
            fg = colors.black,
            notice = colors.orange,
        },
        bar = {
            bg = colors.white,
            fg_low = colors.green,
            fg_med = colors.orange,
            fg_high = colors.red,
            label = colors.orange
        },
    },
    sizes = {
        button = {
            width = 19,
            height = 3
        }
    }
}

return config