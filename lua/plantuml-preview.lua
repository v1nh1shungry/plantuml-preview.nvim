local M = {}

local global_opts = {}
local augroup = vim.api.nvim_create_augroup('plantuml_preview_auto_update_preview', {})
local md_ns = vim.api.nvim_create_namespace('plantuml_preview_markdown')

local config = {
  markdown = {
    enabled = true,
    hl_group = 'Normal',
  },
  win_opts = {
    split = 'right',
    style = 'minimal',
  },
}

---@param src string
---@param callback fun(string)
---@return vim.SystemObj
local function get_preview(src, callback)
  local url = 'https://www.plantuml.com/plantuml/txt/~h' .. vim.text.hexencode(src)
  return vim.system(
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
  if not config.markdown.enabled then
    return
  end

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
  local jobs = {}
  for id, node in query:iter_captures(root, 0) do
    local capture = query.captures[id]
    if capture == 'code' then
      local start_row, _, end_row, _ = node:range()
      jobs[#jobs + 1] = get_preview(vim.treesitter.get_node_text(node, 0), function(result)
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
  global_opts[vim.api.nvim_get_current_buf()] = jobs
end

local function markdown_clear()
  vim.api.nvim_buf_clear_namespace(0, md_ns, 0, -1)
  for _, j in ipairs(global_opts[vim.api.nvim_get_current_buf()] or {}) do
    if not j:is_closing() then
      j:kill(9)
    end
  end
end

function M.setup(opts)
  config = vim.tbl_extend('force', config, opts)

  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      markdown_render()

      vim.api.nvim_create_autocmd('InsertLeave', {
        buffer = args.buf,
        callback = markdown_render,
        group = augroup,
      })

      vim.api.nvim_create_autocmd('InsertEnter', {
        buffer = args.buf,
        callback = markdown_clear,
        group = augroup,
      })
    end,
    group = augroup,
    pattern = 'markdown',
  })
end

function M.toggle()
  local opts = global_opts[vim.api.nvim_get_current_buf()] or {}

  if vim.bo.filetype == 'markdown' then
    config.markdown.enabled = not config.markdown.enabled
    if not config.markdown.enabled then
      markdown_clear()
    else
      markdown_render()
    end
    vim.notify(
      (config.markdown.enabled and 'Enable ' or 'Disable ') .. 'inline preview',
      vim.log.levels.INFO,
      { title = 'plantuml-preview' }
    )
  elseif vim.fn.expand('%:e') == 'puml' then
    local current_bufnr = vim.api.nvim_get_current_buf()
    local current_winnr = vim.api.nvim_get_current_win()

    local function cancel()
      if opts.job ~= nil and not opts.job:is_closing() then
        opts.job:kill(9)
      end
    end

    local update = function()
      cancel()
      opts.job = get_preview(
        table.concat(vim.api.nvim_buf_get_lines(current_bufnr, 0, -1, false), '\n'),
        function(result)
          if opts.bufnr == nil or not vim.api.nvim_buf_is_valid(opts.bufnr) then
            opts.bufnr = vim.api.nvim_create_buf(false, true)
          end
          if opts.winnr == nil or not vim.api.nvim_win_is_valid(opts.winnr) then
            opts.winnr = vim.api.nvim_open_win(
              opts.bufnr,
              false,
              vim.tbl_extend('force', { win = current_winnr }, config.win_opts)
            )
          end
          vim.api.nvim_buf_set_lines(opts.bufnr, 0, -1, false, vim.split(result, '\n'))
        end
      )
    end

    if opts.winnr ~= nil and vim.api.nvim_win_is_valid(opts.winnr) then
      vim.api.nvim_win_close(opts.winnr, true)
      vim.api.nvim_clear_autocmds { group = augroup }
      cancel()
    else
      update()
      vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
        callback = update,
        group = augroup,
      })
    end

    global_opts[vim.api.nvim_get_current_buf()] = opts
  else
    vim.notify(
      'Current buffer is neither a plantuml file nor a markdown file',
      vim.log.levels.WARN,
      { title = 'plantuml-preview' }
    )
  end
end

return M
