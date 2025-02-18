local M = {}

local initialized = false

M.get_ls_from_mason = function()
	local result = M.get_from_mason_registry("fsautocomplete", "fsautocomplete/fsautocomplete")
	if #result > 0 then
		return result[1]
	end
	return nil
end

M.get_from_mason_registry = function(package_name, key_prefix)
	local success, mason_registry = pcall(require, "mason-registry")
	local result = {}
	if success then
		mason_registry.refresh()
		local mason_package
		if mason_registry.has_package(package_name) then
			mason_package = mason_registry.get_package(package_name)
		else
			return result
		end
		if mason_package:is_installed() then
			local install_path = mason_package:get_install_path()
			mason_package:get_receipt():if_present(function(recipe)
				for key, value in pairs(recipe.links.share) do
					if key:sub(1, #key_prefix) == key_prefix then
						table.insert(result, install_path .. "/" .. value)
					end
				end
			end)
		end
	end
	return result
end

local request = function(bufnr, method, params, handler)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "fsautocomplete" })
  local _, client = next(clients)
  if not client then
    vim.notify("No LSP client with name `fsautocomplete` available", vim.log.levels.WARN)
    return
  end
  local co
  if not handler then
    co = coroutine.running()
    if co then
      handler = function(err, result, ctx)
        coroutine.resume(co, err, result, ctx)
      end
    end
  end
  client.request(method, params, handler, bufnr)
  if co then
    return coroutine.yield()
  end
end

M.setup = function(config)
	if initialized then
		return
	end
	initialized = true
	local opts = vim.tbl_deep_extend("keep", config or {}, require("ionide.config"))
	if not opts.ls_path then
		opts.ls_path = M.get_ls_from_mason() -- get ls from mason-registry
	end
	if not opts.ls_path then
		-- try to find ls on standard installation path of vscode
		opts.ls_path = require("ionide.dotnet").find_one("fsautocomplete")
	end
	if not opts.ls_path then
		-- all possibilities finding the language server failed
		vim.notify("FSAutocomplete is not installed", vim.log.levels.WARN)
		return
	end
	M.init_lsp_commands()

	if opts.autocmd then
		require("ionide.init").setup(opts)
	end
	return opts
end

M.init_lsp_commands = function()
	-- see  https://github.com/mfussenegger/nvim-jdtls/blob/29255ea26dfb51ef0213f7572bff410f1afb002d/lua/jdtls.lua#L819
	if not vim.lsp.handlers["workspace/executeClientCommand"] then
		vim.lsp.handlers["workspace/executeClientCommand"] = function(_, params, ctx) -- luacheck: ignore 122
			local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
			local commands = client.commands or {}
			local global_commands = vim.lsp.commands
			local fn = commands[params.command] or global_commands[params.command]
			if fn then
				local ok, result = pcall(fn, params.arguments, ctx)
				if ok then
					return result
				else
					return vim.lsp.rpc_response_error(vim.lsp.protocol.ErrorCodes.InternalError, result)
				end
			else
				return vim.lsp.rpc_response_error(
					vim.lsp.protocol.ErrorCodes.MethodNotFound,
					"Command " .. params.command .. " not supported on client"
				)
			end
		end
	end
end

local function signature(filePath, line, character, cont, outer_ctx)
  local bufnr = assert(outer_ctx.bufnr, '`outer_ctx` must have bufnr property')
  local params = { textDocument = { uri = vim.uri_from_fname(filePath) }, position = { line = line, character = character } }
require("ionide.async").run(function()
     local err, result = request(bufnr, 'fsharp/signature', params)
    if err then
      print("Could not execute fsharp/signature: " .. err.message)
      return
    end
    if not result then
      return
    end
    if result.exists then
      local prompt = string.format(
        "Method 'toString()' already exists in '%s'. Do you want to replace it?",
        result.type
      )
      local choice = ui.pick_one({"Replace", "Cancel"}, prompt, tostring)
      if choice == "Cancel" then
        return
      end
    end
    local fields = ui.pick_many(result.fields, 'Include item in toString?', function(x)
      return string.format('%s: %s', x.name, x.type)
    end)
    local e, edit = request(bufnr, 'java/generateToString', { context = params; fields = fields; })
    if e then
      print("Could not execute java/generateToString: " .. e.message)
    elseif edit then
      vim.lsp.util.apply_workspace_edit(edit, offset_encoding)
    end
  end)
end
    return s:call('fsharp/signature', s:TextDocumentPositionParams(a:filePath, a:line, a:character), a:cont)
endfunction

return M
