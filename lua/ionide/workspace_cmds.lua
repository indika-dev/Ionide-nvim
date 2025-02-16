M = {}

function M.wipe_data_and_restart()
	local data_dir, client = extract_data_dir(vim.api.nvim_get_current_buf())
	if not data_dir or not client then
		vim.notify(
			"Data directory wasn't detected. "
				.. "You must call `start_or_attach` at least once and the cmd must include a `-data` parameter (or `--data` if using the official `jdtls` wrapper)"
		)
		return
	end
	local opts = {
		prompt = "Are you sure you want to wipe the data folder: " .. data_dir .. " and restart? ",
	}
	vim.ui.select({ "Yes", "No" }, opts, function(choice)
		if choice ~= "Yes" then
			return
		end
		vim.schedule(function()
			local bufs = vim.lsp.get_buffers_by_client_id(client.id)
			client.stop()
			vim.wait(30000, function()
				return vim.lsp.get_client_by_id(client.id) == nil
			end)
			vim.fn.delete(data_dir, "rf")
			local client_id
			if vim.bo.filetype == "java" then
				client_id = lsp.start(client.config)
			else
				client_id = vim.lsp.start_client(client.config)
			end
			if client_id then
				for _, buf in ipairs(bufs) do
					lsp.buf_attach_client(buf, client_id)
				end
			end
		end)
	end)
end

function M.show_logs()
	local data_dir = extract_data_dir(vim.api.nvim_get_current_buf())
	if data_dir then
		vim.cmd("split | e " .. data_dir .. "/.metadata/.log | normal G")
	end
	if vim.fn.has("nvim-0.8") == 1 then
		vim.cmd("vsplit | e " .. vim.fn.stdpath("log") .. "/lsp.log | normal G")
	else
		vim.cmd("vsplit | e " .. vim.fn.stdpath("cache") .. "/lsp.log | normal G")
	end
end

return M
