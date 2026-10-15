local M = {}

-- Setup keybindings and buffer options for the tmux scrollback viewer
function M.setup(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  -- Ensure buffer is configured as markdown and read-only
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
  vim.wo.wrap = true

  -- Keybindings for quick dismissal
  local function quit_viewer()
    vim.cmd("qa!")
  end

  vim.keymap.set("n", "q", quit_viewer, { buffer = buf, silent = true, desc = "Quit scrollback popup" })
  vim.keymap.set("n", "<Esc>", quit_viewer, { buffer = buf, silent = true, desc = "Quit scrollback popup" })

  -- Diagram Hopping: Next Mermaid Diagram (n or ])
  local function next_mermaid()
    local cur = vim.api.nvim_win_get_cursor(0)
    -- Move cursor down 1 line to search past current match if already on fence
    pcall(vim.cmd, "normal! j")
    local line = vim.fn.search([[^```\s*\(mermaid\|diagram-mermaid\)]], "W")
    if line == 0 then
      -- Wrap around from the top of the buffer
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      line = vim.fn.search([[^```\s*\(mermaid\|diagram-mermaid\)]], "W")
      if line == 0 then
        vim.api.nvim_win_set_cursor(0, cur)
        vim.notify("󰄧 No Mermaid diagrams found in scrollback", vim.log.levels.WARN, { title = "Scrollback" })
        return
      end
    end
    vim.cmd("normal! zz")
    local ok_snacks, Snacks = pcall(require, "snacks")
    if ok_snacks and Snacks.image and Snacks.image.doc then
      Snacks.image.doc.hover()
    end
  end

  -- Diagram Hopping: Previous Mermaid Diagram (N or [)
  local function prev_mermaid()
    local cur = vim.api.nvim_win_get_cursor(0)
    local line = vim.fn.search([[^```\s*\(mermaid\|diagram-mermaid\)]], "bW")
    if line == 0 then
      -- Wrap around from the bottom of the buffer
      local total_lines = vim.api.nvim_buf_line_count(buf)
      vim.api.nvim_win_set_cursor(0, { total_lines, 0 })
      line = vim.fn.search([[^```\s*\(mermaid\|diagram-mermaid\)]], "bW")
      if line == 0 then
        vim.api.nvim_win_set_cursor(0, cur)
        vim.notify("󰄧 No Mermaid diagrams found in scrollback", vim.log.levels.WARN, { title = "Scrollback" })
        return
      end
    end
    vim.cmd("normal! zz")
    local ok_snacks, Snacks = pcall(require, "snacks")
    if ok_snacks and Snacks.image and Snacks.image.doc then
      Snacks.image.doc.hover()
    end
  end

  vim.keymap.set("n", "n", next_mermaid, { buffer = buf, silent = true, desc = "Next Mermaid diagram" })
  vim.keymap.set("n", "]", next_mermaid, { buffer = buf, silent = true, desc = "Next Mermaid diagram" })
  vim.keymap.set("n", "N", prev_mermaid, { buffer = buf, silent = true, desc = "Previous Mermaid diagram" })
  vim.keymap.set("n", "[", prev_mermaid, { buffer = buf, silent = true, desc = "Previous Mermaid diagram" })

  -- Yank Mermaid Chart (yc: entire block with fences; yC: inner graph syntax only)
  local function yank_mermaid(inner_only)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local total_lines = vim.api.nvim_buf_line_count(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, total_lines, false)

    -- Look backwards from cursor to find opening fence
    local start_idx = nil
    for i = cursor_line, 1, -1 do
      if lines[i]:match("^```%s*mermaid") or lines[i]:match("^```%s*diagram%-mermaid") then
        start_idx = i
        break
      elseif i < cursor_line and lines[i]:match("^```%s*$") then
        break
      end
    end

    -- If cursor wasn't inside, look forwards
    if not start_idx then
      for i = cursor_line, total_lines do
        if lines[i]:match("^```%s*mermaid") or lines[i]:match("^```%s*diagram%-mermaid") then
          start_idx = i
          break
        end
      end
    end

    if not start_idx then
      vim.notify("󰄧 Cursor is not inside or near a Mermaid block", vim.log.levels.WARN, { title = "Yank Mermaid" })
      return
    end

    -- Find closing fence
    local end_idx = nil
    for i = start_idx + 1, total_lines do
      if lines[i]:match("^```%s*$") then
        end_idx = i
        break
      end
    end

    if not end_idx then
      vim.notify("󰄧 Unclosed Mermaid block", vim.log.levels.WARN, { title = "Yank Mermaid" })
      return
    end

    local extract_start = inner_only and (start_idx + 1) or start_idx
    local extract_end = inner_only and (end_idx - 1) or end_idx

    local chart_lines = {}
    for i = extract_start, extract_end do
      table.insert(chart_lines, lines[i])
    end

    local content = table.concat(chart_lines, "\n")
    vim.fn.setreg("+", content)
    vim.fn.setreg('"', content)

    local label = inner_only and "syntax only" or "with code fence"
    vim.notify(string.format("󰄧 Copied Mermaid chart (%d lines, %s) to clipboard!", #chart_lines, label), vim.log.levels.INFO, { title = "Yank Mermaid" })
  end

  vim.keymap.set("n", "yc", function() yank_mermaid(false) end, { buffer = buf, silent = true, desc = "Yank Mermaid diagram with fences" })
  vim.keymap.set("n", "yC", function() yank_mermaid(true) end, { buffer = buf, silent = true, desc = "Yank Mermaid graph syntax only" })

  -- Enter opens Lightbox Modal if cursor is on/inside a diagram or media
  vim.keymap.set("n", "<CR>", function()
    local ok_snacks, Snacks = pcall(require, "snacks")
    if ok_snacks and Snacks.image and Snacks.image.doc then
      Snacks.image.doc.at_cursor(function(src)
        if src then
          vim.cmd("ImageLightbox")
        else
          vim.cmd("normal! j")
        end
      end)
    else
      vim.cmd("normal! j")
    end
  end, { buffer = buf, silent = true, desc = "Open Lightbox if on diagram / move down" })
end

return M
