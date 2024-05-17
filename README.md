<h1 align="center">plantuml-preview.nvim</h1>

![Real-time preview](https://github.com/v1nh1shungry/plantuml-preview.nvim/assets/98312435/8ccba7c2-90ac-4d7c-8434-04b44abb2960)

![Inline preview](https://github.com/v1nh1shungry/plantuml-preview.nvim/assets/98312435/f7d9ca0e-4676-4d88-8ac2-128ccbb7de65)

## 🎉 Features

* Real-time preview `plantuml` right in neovim
* Inline preview in markdown code block

**NOTE: The function relies on [the PlantUML Web Server](https://www.plantuml.com/plantuml/uml/SyfFKj2rKt3CoKnELR1Io4ZDoSa70000)'s
service, so you have to be connected. Thus, it may be unsafe.**

## 📦 Installation

**Require Neovim >= 0.11**

💤 [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'v1nh1shungry/plantuml-preview.nvim',
    keys = { { '<Leader>up', function() require('plantuml-preview').toggle() end }, desc = 'Preview plantuml' },
    opts = {},
}
```

## ⚙️ Configuration

**Make sure you have called `require('plantuml-preview').setup()` before you use the plugin!**

```lua
-- default configuration
{
    markdown = {
        enabled = true, -- whether to enable inline preview
        hl_group = 'Normal', -- highlight group for the preview
    },
    win_opts = { -- config which will be passed to `vim.api.nvim_open_win`
        split = 'right',
        win = 0,
        style = 'minimal',
    },
}
```

## 🚀 Usage

* `toggle()`: toggle the preview
