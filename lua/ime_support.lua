-- IMEの切り替えを自動で行うスクリプト
--
-- デフォルトでは、挿入モード時、通常モード時に半角に切り替える。
--
--
-- TODO: Insertモードに切り替えた後、しばらくVirtual TextとしてIMEモードを表示する

local M = {}

local app = {
	disabled = false,
	exec_path = nil,
	ime_mode = {
		hankaku = "0",
		zenkaku = "1"
	}
}

local changed_listeners = { }

function M.register_listener(func)
	table.insert(changed_listeners, func)
end

function fire_changed()
	for _, listener in pairs(changed_listeners) do
		listener()
	end
end

function switch(mode)
	vim.system({app.exec_path, mode}):wait()
end

function retrieve_ime_mode()
	return vim.trim(vim.system({app.exec_path}):wait().stdout)
end

function get_ins_ime()
	return vim.b.ImeModeOnInsert or app.ime_mode.hankaku
end

-- 現在のバッファにおける挿入モード時のIMEのモードを設定する。
-- 必要に応じて、 fire_changed() を呼び出す。
function set_ins_ime(mode)
	local before = get_ins_ime()
	vim.b.ImeModeOnInsert = mode
	if before ~= mode then
		fire_changed()
	end
end

function M.toggle_ins_ime()
	local m = app.ime_mode
	local new_mode = get_ins_ime() == m.hankaku and m.zenkaku or m.hankaku
	set_ins_ime(new_mode)
end

function M.is_ins_hankaku()
	return get_ins_ime() == app.ime_mode.hankaku
end

function disable_on_error(func, ...)
	if app.disabled then
		return
	end
	local status, err = pcall(func, ...)
	if not status then
		print("ERROR. ime_support disabled")
		print(err)
		app.disabled = true
	end
end

function on_insert()
	switch(get_ins_ime())
end

function on_normal()
	switch(app.ime_mode.hankaku)
end

function leave_insert()
	set_ins_ime(retrieve_ime_mode())
end

local last_vim_mode = nil
function on_mode_changed()
	disable_on_error(function()
		local vim_mode = vim.fn.mode()
		if last_vim_mode == "i" and last_vim_mode ~= vim_mode then
			leave_insert()
		end
		if vim_mode == "i" then
			on_insert()
		else
			on_normal()
		end
		last_vim_mode = vim_mode
	end)
end

-- 一定時間操作が無かった場合、IMEのモードをリセットする。
function on_cursorhold()
	disable_on_error(function()
		set_ins_ime(nil)
	end)
end

function on_focused()
	disable_on_error(function()
		if vim.fn.mode() ~= "i" then
			switch(app.ime_mode.hankaku)
		end
	end)
end

function M.setup(opts)
	app.exec_path = vim.fs.normalize(opts.exec_path)

	if not vim.uv.fs_stat(app.exec_path) then
		vim.notify("my_ime_support: exec_path doesn't exist. (" .. app.exec_path .. ")", vim.log.levels.ERROR)
		return
	end

	local group_id = vim.api.nvim_create_augroup("my-ime-support", {})

	vim.api.nvim_create_autocmd({ "ModeChanged" }, {
		group = group_id,
		callback = on_mode_changed
	})
	vim.api.nvim_create_autocmd({ "CursorHold" }, {
		group = group_id,
		callback = on_cursorhold
	})
	vim.api.nvim_create_autocmd({ "FocusGained", "UIEnter" }, {
		group = group_id,
		callback = on_focused
	})
end

return M
