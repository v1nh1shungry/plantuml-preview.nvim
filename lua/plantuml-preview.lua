local M = {}

local bufnr = nil
local winnr = nil
---@type vim.SystemObj?
local job = nil
local augroup = vim.api.nvim_create_augroup('plantuml_preview_auto_update_preview', {})
local md_ns = vim.api.nvim_create_namespace('plantuml_preview_markdown')

local config = {
  markdown = {
    enabled = true,
    hl_group = 'Normal',
  },
  win_opts = {
    split = 'right',
    win = 0,
  },
}

---@param s string
---@return string
local function hex_string(s)
  local res = ''
  for i = 1, #s do
    res = res .. string.format('%02x', s:byte(i))
  end
  return res
end

---@param src string
---@param callback fun(string)
local function get_preview(src, callback)
  local url = 'https://www.plantuml.com/plantuml/txt/~h' .. hex_string(src)
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

local function markdown_render()
  local parser = vim.treesitter.get_parser(0, 'markdown')
  local root = parser:parse()[1]:root()
  local query = vim.treesitter.query.parse(
    'markdown',
    [[
(
  (fenced_code_block
    (info_string
      (language) @lang)
    (code_fence_content) @code)
  (#eq? @lang "puml"))
  ]]
  )
  for id, node in query:iter_captures(root, 0) do
    local capture = query.captures[id]
    if capture == 'code' then
      local start_row, _, end_row, _ = node:range()
      get_preview(vim.treesitter.get_node_text(node, 0), function(result)
        local virt_text = {}
        for _, l in ipairs(vim.split(result, '\n')) do
          virt_text[#virt_text + 1] = { { l, config.markdown.hl_group } }
        end
        for i = start_row, end_row do
          vim.api.nvim_buf_set_extmark(0, md_ns, i, 0, {
            virt_text = virt_text[i - start_row + 1],
            virt_text_pos = 'overlay',
          })
        end
        vim.api.nvim_buf_set_extmark(0, md_ns, end_row, 0, {
          virt_lines = vim.list_slice(virt_text, end_row - start_row + 2),
        })
      end)
    end
  end
end

function M.setup(opts)
  config = vim.tbl_extend('force', config, opts)

  if config.markdown.enabled then
    vim.api.nvim_create_autocmd('FileType', {
      callback = function(args)
        markdown_render()

        vim.api.nvim_create_autocmd('InsertLeave', {
          buffer = args.buf,
          callback = markdown_render,
        })

        vim.api.nvim_create_autocmd('InsertEnter', {
          buffer = args.buf,
          callback = function()
            vim.api.nvim_buf_clear_namespace(0, md_ns, 0, -1)
          end,
        })
      end,
      pattern = 'markdown',
    })
  end
end

function M.toggle()
  local function cancel()
    if job ~= nil and not job:is_closing() then
      job:kill(9)
    end
  end

  local update = function()
    cancel()
    get_preview(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'), function(result)
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

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
    vim.api.nvim_clear_autocmds { group = augroup }
    cancel()
  else
    update()
    vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
      callback = update,
      group = augroup,
    })
  end
end

return M
