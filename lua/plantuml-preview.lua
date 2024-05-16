local M = {}

local active = false
local bufnr = nil
local winnr = nil
---@type vim.SystemObj?
local job = nil
local augroup = vim.api.nvim_create_augroup('plantuml_preview_auto_update_preview', {})

local config = {
  win_opts = {
    split = 'right',
    win = 0,
  },
}

function M.setup(opts)
  config = vim.tbl_extend('force', config, opts)
end

---@param s string
---@return string
local function hex_string(s)
  local res = ''
  for i = 1, #s do
    res = res .. string.format('%02x', s:byte(i))
  end
  return res
end

local function get_preview(callback)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local url = 'https://www.plantuml.com/plantuml/txt/~h' .. hex_string(table.concat(lines, '\n'))
  if job ~= nil and not job:is_closing() then
    job:kill(9)
  end
  job = vim.system(
    { 'curl', url },
    { text = true },
    vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        vim.notify(
          'Failed to preview: curl returned ' .. out.code,
          vim.log.levels.ERROR,
          { title = 'plantuml-preview' }
        )
        return
      end
      if out.signal ~= 0 then
        return
      end
      callback(out.stdout)
    end)
  )
end

function M.preview()
  local update = function()
    get_preview(function(result)
      if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
        bufnr = vim.api.nvim_create_buf(false, true)
      end
      if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
        winnr = vim.api.nvim_open_win(bufnr, false, config.win_opts)
        vim.wo[winnr].stc = ''
        vim.wo[winnr].number = false
        vim.wo[winnr].relativenumber = false
        vim.wo[winnr].foldenable = false
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(result, '\n'))
    end)
  end

  if active then
    vim.api.nvim_win_close(winnr, true)
    vim.api.nvim_clear_autocmds { group = augroup }
    if job ~= nil and not job:is_closing() then
      job:kill(9)
    end
  else
    update()
    vim.api.nvim_create_autocmd('InsertLeave', {
      callback = update,
      group = augroup,
    })
  end

  active = not active
end

return M
