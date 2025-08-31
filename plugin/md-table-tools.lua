print("Starting my-plugin (local version)")

local M = {}

---
--- Rendered text object
--- @class R represents the rendered text object
---
local R = {}
R.__index = R

---
--- Constructor for rendered text
--- @param o table template object with `o.lines` talbe of strings as initial content
--- @return R new instance
---
function R:new(o)
	o = o or {}
	setmetatable(o, self)
	o.lines = {}
	return o
end

---
--- Constructor for rendered text
--- Constructs a rendered text object from a string repeating the same
--- line
--- @param text string string that is repeated
--- @param lines number number of lines `text` is repeated
--- @return R new instance
---
function R:new_from_literal(text, lines)
	local o = self:new({})
	for _ = 1, lines, 1 do
		o:add_line(text)
	end
	return o
end

---
--- Get the height of the rendered text
--- This is the number of lines the rendered text consists of
--- @return number height
---
function R:get_height()
	return #self.lines
end

---
--- Get the width of the rendered block
--- This is the length of the longest line the rendered text block contains
--- @return number width
---
function R:get_width()
	local max_len = 0
	for _, v in ipairs(self.lines) do
		max_len = math.max(max_len, vim.fn.strchars(v))
	end
	return max_len
end

---
--- Add a line to the rendered text as the first line
--- @param l string the line to add to the rendered text
--- @return self
---
function R:add_line_before(l)
	table.insert(self.lines, 1, l)
	return self
end

---
--- Add a line of text to the rendered text as the last line
--- @param l string the line to add to the rendered text
--- @return self
---
function R:add_line(l)
	local len = #self.lines
	self.lines[len + 1] = l
	return self
end

---
--- Get a copy of all lines in the rendered output
--- @return table of strings
---
function R:get_lines()
	local copy = {}
	for k, v in ipairs(self.lines) do
		copy[k] = v
	end
	return copy
end

---
--- Adds a rendered text block below this one.
--- The added text block is not changed, but `self` is changed
--- @param o R the rendered text block to add
--- @return self
---
function R:add_below(o)
	local nl = o:get_lines()
	local len = self:get_height()
	for k, v in ipairs(nl) do
		self.lines[len + k] = v
	end
	return self
end

---
--- Places an other rendered text block to the right of the current block.
--- Example:
--- self:
--- aaaa
--- aa
--- a
--- aaaaa
---
--- o:
--- bbbb
---   bb
---
--- result:
--- aaaa ssbbbb
--- aa   ss  bb
--- a    ss
--- aaaaass
---
--- s is the separator provided in the options
---
--- if `self` has fewer lines than o, then `self` is padded with
--- `options.default` to have as many lines as `o`
---
--- @param o R the text block to add
--- @param options table of options that control how `o` is added to `self`
---        options.default string the line added to `self` before the rendering if
---        `self` has less lines than `o`. By default it is the empty string.
---        options.separator string the characters added between  `self` and
---        `o`. By default it is the empty string.
--- @return self
---
function R:add_left(o, options)
	options = options or {}
	options.separator = options.separator or ""
	options.default = options.default or ""

	local width = self:get_width()
	local left_lines = self:get_height()
	local right_lines = o:get_height()

	-- Make the current result as high as the one we want to put left of it...
	for _ = left_lines + 1, right_lines, 1 do
		self:add_line(options.default)
	end

	for k, v in ipairs(self.lines) do
		local l = v
		local r = o.lines[k] or ""
		-- print("add_left(): l: [" .. l .. "] r: [" .. r .. "]")

		l = l .. string.rep(" ", width - vim.fn.strchars(l))
		l = l .. options.separator
		l = l .. r

		self.lines[k] = l
	end
	return self
end

---
--- Prints the rendered results into `nvim` output.
--- Mainly used for debug purpuses.
--- @return self
function R:print()
	for k, v in ipairs(self.lines) do
		print(k, v)
	end
	return self
end

---
--- Align the rendered results left, right or center.
--- The width of the rendered results is `self:get_width()`.
--- The height of the rendered results is `self:get_height()`
--- @param alignment string can have the value "left", "right", "center" or
--- "none". Anything else is treated as none.
---
function R:align(alignment, width)
	-- Make sure column fits into the requested width
	-- If not, increase the width...
	local width = math.max(self:get_width(), width or 0)

	local new_lines = {}
	for _, v in ipairs(self.lines) do
		-- print("align: ", k, v)
		local line = vim.trim(tostring(v))
		local padding_width = width - vim.fn.strchars(line)

		if alignment == "left" then
			-- all is good
			do
			end
		elseif alignment == "right" then
			line = string.rep(" ", padding_width) .. line
		elseif alignment == "center" then
			line = string.rep(" ", padding_width / 2) .. line
		end

		new_lines[#new_lines + 1] = line
	end

	self.lines = new_lines
	return self
end

---
--- Utility function that calls a function on every rendered line, 1-by-1, and
--- saves the result for the line as a new rendered line.
--- Can be useful for adding padding, shifting results, basically everything
--- that can be done line-by-line.
--- @param f function function(l) l.reverse() end
--- @return self
---
function R:transform_lines(f)
	for k, v in ipairs(self.lines) do
		self.lines[k] = f(v)
	end
	return self
end

local function max_of_arrays(a1, a2)
	print("Getting max of 2 arrays")
	print(vim.inspect(a1))
	print(vim.inspect(a2))
	local result = {}
	for k, v in pairs(a1) do
		result[k] = v or 0
	end

	for k, v in pairs(a2) do
		result[k] = math.max(result[k] or 0, v or 0)
	end

	return result
end

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

local function dbg(s)
	if not M.debug then
		return
	end
	local line = debug.getinfo(2).currentline
	s = vim.inspect(s)
	print("Debug at: " .. line .. " | " .. (s or "<???>"))
end

local function determine_column_allignment(dr)
	local result = {}

	for node, _node_name in dr:iter_children() do
		if node:type() == "pipe_table_delimiter_cell" then
			local start_row, start_col, end_row, end_col = node:range()
			local text = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
			local text = vim.trim(table.concat(text, "\n") or "")

			local alignment = "none"

			local starts_with_colon = string.sub(text, 1, 1) == ":"
			local ends_with_colon = string.sub(text, -1, -1) == ":"

			if starts_with_colon and ends_with_colon then
				alignment = "center"
			elseif starts_with_colon then
				alignment = "left"
			elseif ends_with_colon then
				alignment = "right"
			else
				alignment = "none"
			end

			result[#result + 1] = alignment
		else
			dbg("Unexpected node type: " .. node:type())
		end
	end

	return result
end

function M.format_table()
	dbg("Format table start")
	local parser = vim.treesitter.get_parser(0, "markdown") -- current buffer
	local tree = parser:parse()[1]
	local root = tree:root()

	-- print(root:range())
	local query = vim.treesitter.query.parse(
		"markdown",
		[[
    (pipe_table ) @table
    ]]
	)

	dbg(query)
	dbg(vim.inspect(query))
	for _pattern, match, metadata in query:iter_matches(root, 0, 0, -1) do
		for id, nodes in pairs(match) do
			-- local _name = query.captures[id]
			for _, node in ipairs(nodes) do
				-- local _node_data = metadata[id]
				-- dbg("Node_data |" .. vim.inspect(node_data))
				-- dbg "N:"
				-- dbg(node:type())
				M.format_single_table(node)
			end
		end
		-- dbg "Item matched:"
		-- dbg(vim.inspect(match))
		-- vim.treesitter.get_node_text(match, 0)
	end
	dbg("Format table end")
end

local function render_table_header(h, r_header)
	local index = 1
	for node, _node_name in h:iter_children() do
		if node:type() == "pipe_table_cell" then
			local column_renderer = r_header[index] or R:new({})
			r_header[index] = column_renderer
			index = index + 1

			-- TODO: Actually render what is in the sub-structures of the cell
			local start_row, start_col, end_row, end_col = node:range()
			local text = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
			local text = trim(table.concat(text, "\n") or "")

			column_renderer:add_line(text)
			-- print("Text added: " .. text)
			-- column_renderer:print()
		elseif node:type() == "|" then
			-- Quietly ignore '|' nodes that seem to be retuned by tree-sitter between
			-- cells
			do
			end
		else
			dbg("Unexpected node type: " .. node:type())
		end
	end
end

local function render_table_row(r, r_body)
	render_table_header(r, r_body)
end

function M.format_table_under_cursor()
	-- Get current cursor...
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))

	-- Get current piper_table node...
	local node = vim.treesitter.get_node({ bufnr = 0, row = row, col = col })
	while node do
		if node:type() == "pipe_table" then
			break
		end

		node = node:parent()
	end

	-- Check piper table
	if not node then
		vim.notify("No table found at cursor position")
		return
	end

	-- Check for syntax error
	if node:has_error() then
		vim.notify("Table contains a formatting error")
		return
	end

	local formatted_table = M.format_single_table(node)
	local start_row, start_col, end_row, end_col = node:range()

	local formatted_table_lines = formatted_table:get_lines()

	local current_buffer_line_count = vim.api.nvim_buf_line_count(0)
	if end_row >= current_buffer_line_count then
		end_row = current_buffer_line_count - 1
		local end_line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
		end_col = vim.fn.strchars(end_line)
	else
		-- According to treesitter, the first empty line after the table belongs to
		-- the table...
		formatted_table_lines[#formatted_table_lines + 1] = ""
	end

	vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, formatted_table_lines)
end

function M.format_single_table(t)
	dbg("Formatting table start")

	local rendered_headers = {}
	local rendered_bodies = {}
	local alignment = {}

	for child_node, _child_name in t:iter_children() do
		if child_node:type() == "pipe_table_header" then
			render_table_header(child_node, rendered_headers)
		elseif child_node:type() == "pipe_table_row" then
			render_table_row(child_node, rendered_bodies)
		elseif child_node:type() == "pipe_table_delimiter_row" then
			alignment = determine_column_allignment(child_node)
		else
			dbg("Unexpected node type: " .. child_node:type())
		end
	end

	-- Now set metatables to return default values
	-- (setting them earlier screws up parsing the header, might need to change
	-- that)
	setmetatable(rendered_headers, {
		__index = function()
			return R:new({}):add_line("")
		end,
	})
	setmetatable(rendered_bodies, {
		__index = function()
			return R:new({})
		end,
	})
	setmetatable(alignment, { __index = "none" })

	local rendered_table = R:new({})

	local cols = math.max(#rendered_bodies, #rendered_headers, #alignment)
	local pad_func = function(s)
		return " " .. s .. " "
	end

	for i = 1, cols, 1 do
		local col_width = math.max(3, rendered_bodies[i]:get_width(), rendered_headers[i]:get_width())

		local separator = string.rep("-", col_width)
		local column_alignment = alignment[i]

		if column_alignment == "left" then
			separator = ":" .. separator .. "-"
		elseif column_alignment == "center" then
			separator = ":" .. separator .. ":"
		elseif column_alignment == "right" then
			separator = "-" .. separator .. ":"
		else
			separator = "-" .. separator .. "-"
		end

		local rendered_header = R:new({})

		rendered_header:add_below(rendered_headers[i])
		rendered_header:align(alignment[i] or "none", col_width)
		rendered_header:transform_lines(pad_func)

		local rendered_body = R:new({})
		rendered_body:add_below(rendered_bodies[i])
		rendered_body:align(alignment[i] or "none", col_width)
		rendered_body:transform_lines(pad_func)

		local rendered_column = R:new({})

		rendered_column:add_below(rendered_header)
		rendered_column:add_line(separator)
		rendered_column:add_below(rendered_body)

		rendered_table:add_left(rendered_column, { separator = "|" })
	end

	rendered_table:add_left(R:new({}), { separator = "|" })
	if M.debug then
		rendered_table:print()
	end

	-- dbg(vim.inspect(alignment))
	dbg("Formatting table end")
	return rendered_table
end

-- Setup user command
function M.setup(opt)
	-- vim.api.nvim_create_user_command("FT", M.align_markdown_tables, { desc = "Align markdown tables" })
	opt = opt or {}
	local format_table_under_cursor_command = opt.format_table_under_cursor_command or "FT"
	M.debug = opt.debug or false
	vim.api.nvim_create_user_command(
		format_table_under_cursor_command,
		-- command,
		function()
			M.format_table_under_cursor()
		end,
		{ desc = "Format Markdown table under cursor" }
	)
end

M.setup()

return M
--
-- return M
--
-- Issues
--
-- Correctly do the keyboard/command binding
--
-- Create a full buffer format command for all tables:
--   Re-insert the formatted text into the buffer into the right position and
--   right offset
--
-- Extend with formatting paragraphs/text blocks/lists)
--
-- Extend with add column/delete column functionality
