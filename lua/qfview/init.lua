local M = {}

-- Change diagnostic symbols in the sign column (gutter)
-- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#change-diagnostic-symbols-in-the-sign-column-gutter
local signs = {
  E = 'DiagnosticSignError',
  W = 'DiagnosticSignWarn',
  I = 'DiagnosticSignInfo',
  N = 'DiagnosticSignHint',
}

local function get_common_prefix(matrix, shortest)
  local prefix = {}
  local idx = 1
  while true do
    local c = matrix[1][idx]
    if c == nil then
      break
    end
    for i = 2, #matrix do
      if matrix[i][idx] ~= c then
        return prefix
      end
    end
    table.insert(prefix, c)
    idx = idx + 1
    if idx > shortest then
      break
    end
  end
  return prefix
end

function M.qftextfunc(info)
  local qflist = nil
  if info.quickfix == 1 then
    qflist = vim.fn.getqflist({ id = info.id, items = true, qfbufnr = true })
  else
    qflist = vim.fn.getloclist(info.winid, { id = info.id, items = true, qfbufnr = true })
  end
  local items = qflist.items
  -- There are :colder :cnewer commands which reuse the same qf buffer
  -- We need to remove all related signs before adding new ones
  vim.fn.sign_unplace('qfviewSignGroup', { buffer = qflist.qfbufnr })
  -- Collect the information of each item
  local types = {}
  local paths = {}
  local linenrs = {}
  local texts = {}
  -- We always update the whole qf list
  for idx = 1, #items do
    local type = items[idx].type
    table.insert(types, type)
    local bufname = vim.api.nvim_buf_get_name(items[idx].bufnr)
    table.insert(paths, vim.fs.normalize(bufname))
    local linenr = nil
    if items[idx].lnum == items[idx].end_lnum then
      linenr = string.format(
        '%d:%d-%d',
        items[idx].lnum,
        items[idx].col,
        items[idx].end_col
      )
    else
      linenr = string.format(
        '%d-%d:%d%d',
        items[idx].lnum,
        items[idx].end_lnum,
        items[idx].col,
        items[idx].end_col
      )
    end
    table.insert(linenrs, linenr)
    table.insert(texts, items[idx].text)
  end

  local path_matrix = vim.tbl_map(function(path)
    return vim.split(path, '/')
  end, paths)

  local min_size = vim.fn.min(vim.tbl_map(function(path)
    return #path
  end, path_matrix))

  local common_prefix = get_common_prefix(path_matrix, min_size)
  local stripped_paths = nil

  -- The first common_prefix is always "/", which acctually is not common
  if vim.tbl_count(common_prefix) > 1 then
    local prefix_str = table.concat(common_prefix, '/')
    stripped_paths = vim.tbl_map(function(path)
      -- Don't forget to add 1 for the trailing slash
      return string.sub(
        path,
        vim.fn.strdisplaywidth(prefix_str) + 2,
        #path
      )
    end, paths)
  else
    -- No common prefix, use the shorten paths to minimize the display width
    stripped_paths = vim.tbl_map(function(path)
      return vim.fn.pathshorten(path, 1)
    end, paths)
  end

  local path_maxw = vim.fn.max(vim.tbl_map(
    vim.fn.strdisplaywidth,
    stripped_paths
  ))

  local linenr_maxw = vim.fn.max(vim.tbl_map(
    vim.fn.strdisplaywidth,
    linenrs
  ))

  -- Finally, we can construct the lines
  local l = {}
  for idx = 1, #texts do
    local line = string.format(
      '%-' .. path_maxw .. 's' .. '|%-' .. linenr_maxw .. 's|%s',
      stripped_paths[idx],
      linenrs[idx],
      texts[idx]
    )
    table.insert(l, line)

    if types[idx] ~= '' then
      vim.fn.sign_place(
        0,
        'qfviewSignGroup',
        signs[types[idx]],
        qflist.qfbufnr,
        { lnum = idx, priority = 10 }
      )
    end
  end

  return l
end

function M.setup(options)
  vim.api.nvim_set_option('quickfixtextfunc', "v:lua.require'qfview'.qftextfunc")
end


return M
