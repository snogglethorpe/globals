#!/usr/bin/env lua
-- Egil Hjelmeland, 2012; License MIT
--[[ Reads luac listings and reports global variable usage
-- Lines where a global is written to are marked with 's'
-- Globals not preloaded in Lua is marked with  '!!!'
-- Name of 'luac' can be overridden with environment variable LUAC ]]

local _G,arg,io,ipairs,os,string,table,tonumber
    = _G,arg,io,ipairs,os,string,table,tonumber

-- if true, omit standard globals
local omit_standard = false

-- if true, use "compiler style" output (one line per symbol, in a
-- format that Emacs etc can use to jump to that location)
local compiler_style_output = false

local function process_file(filename, luac, luavm_ver)
	local global_list = {} -- global usages {{name=, line=, op=''},...}
	local name_list = {}   -- list of global names
	
	-- run luac, read listing,  store GETGLOBAL/SETGLOBAL lines in global_list
	do  
		local fd = io.popen( luac.. ' -p -l '.. filename ) 

		while 1 do
		local s=fd:read()
			if s==nil then break end
			local ok,_,l,op,g
			if luavm_ver == '5.2' then
				ok,_,l,op,g=string.find(s,'%[%-?(%d*)%]%s*([GS])ETTABUP.-;%s+_ENV "([^"]+)"(.*)$')
			else   -- assume 5.1
				ok,_,l,op,g=string.find(s,'%[%-?(%d*)%]%s*([GS])ETGLOBAL.-;%s+(.*)$')
			end
			if ok and omit_standard and _G[g] then
				ok = false
			end
			if ok then
				local set = false
				if op=='S' then set = true end -- s means set global
				table.insert(global_list, {name=g, line=tonumber(l), set = set})
			end
		end
	end

	table.sort (global_list,
		function(a,b)
			if a.name < b.name then return true end
			if a.name > b.name then return false end 
			if a.line < b.line then return true end
			return false
		end )
		
	if compiler_style_output then
		for _, v in ipairs(global_list) do
			local msg = ""
			if v.set then
				msg = "definition of"
			else
				msg = "reference to"
			end
			msg = msg.." "..'"'..v.name..'"'
			if _G[v.name] then
				msg = msg.." (standard symbol)"
			end
			print (filename..":"..v.line..": "..msg)
		end
	else
		-- print globals, grouped per name

		io.write('\n'..filename..'\n')

		local prev_name 
		for _, v in ipairs(global_list) do
			local name =   v.name 
			local unknown = '   '
			if not _G[name] then unknown = '!!!' end
			if name ~= prev_name then
				if prev_name then io.write('\n') end
				table.insert(name_list,name)
				prev_name=name
				io.write(string.format (  ' %s %-12s :', unknown, name))
			end
			local set_str = ''
			if io.set then
				set_str = 's'
			end
			io.write(' ',v.line..set_str)
			
		end
		io.write('\n')

		-- print globals declaration list
		local list = table.concat(name_list, ',')
		io.write('\n')
		io.write('local ' .. list .. '\n')
		io.write('    = ' .. list .. '\n')
		io.write('\n\n')
	end
end

if not arg[1] then
	io.write(
		table.concat({ 
			'globals.lua - list global variables in Lua files',
			'usage: globals.lua [<option>...]  <inputfiles>',
			"  -o, --omit-standard : Don't show standard symbols",
			'  <inputfiles> : list of Lua files ',
			'',
			"  environment variable 'LUAC' overrides name of 'luac'",
			''
	},'\n' ))
	return
end

local luac = os.getenv ('LUAC') or 'luac'
local fd = io.popen( luac .. ' -v'  ) 
local luavm_ver = fd:read():match('Lua (%d.%d)')

for i = 1, select ('#', ...) do
	local filename = select (i, ...)
	if filename == '-o' or filename == '--omit-standard' then
		omit_standard = true
	elseif filename == '-c' or filename == '--compiler-style' then
		compiler_style_output = true
	else
		process_file( filename , luac, luavm_ver)
	end
end
