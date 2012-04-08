#!/usr/bin/env lua
-- Egil Hjelmeland, 2012; License MIT
--[[ Reads luac listings and reports global variable usage
-- Lines where a global is written to are marked with 's'
-- Globals not preloaded in Lua is marked with  '!!!'
-- Name of 'luac' can be overridden with environment variable LUAC ]]

local _G,arg,io,ipairs,os,string,table,tonumber
    = _G,arg,io,ipairs,os,string,table,tonumber

-- If true, omit standard globals.
--
local show_standard = false

-- If true, use the original output style.
--
-- By default, the output is "compiler style" -- one line per symbol,
-- in a format that Emacs etc can use to jump to that location.
--
local old_style_output = false

-- if true, only show the first occurance of a given symbol in a file
local omit_duplicates = false

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
			if ok and not show_standard and _G[g] then
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
		
	local prev_name 
	if not old_style_output then
		for _, v in ipairs(global_list) do
			if v.name ~= prev_name then
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
				prev_name = v.name
			end
		end
	else
		-- print globals, grouped per name

		io.write('\n'..filename..'\n')

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

local nargs = select ('#', ...)
local cmd = string.match (arg[0], "([^/]*)$")

local usage = 'Usage: '..cmd.. ' [OPTION...] LUA_SRC_FILE...'
local help = [[List global variables in Lua files

  -o, --old                  Use old output format
  -s, --show-standard        Show standard symbols
  -d, --omit-duplicates      Only show first use of a symbol in each file

By default, the Lua compiler is invoked as "luac".  The environment
variable LUAC can be used override this.]]

if nargs == 0 then
	io.stderr:write (usage.."\n")
	os.exit (1)
end

local luac = os.getenv ('LUAC') or 'luac'
local fd = io.popen( luac .. ' -v'  ) 
local luavm_ver = fd:read():match('Lua (%d.%d)')

for i = 1, select ('#', ...) do
	local filename = select (i, ...)
	if filename == '-o' or filename == '--old' then
		old_style_output = true
	elseif filename == '-s' or filename == '--show-standard' then
		show_standard = true
	elseif filename == '-d' or filename == '--omit-duplicates' then
		omit_duplicates = true
	elseif filename == '--help' then
		print(usage)
		print(help)
		os.exit (0)
	else
		process_file( filename , luac, luavm_ver)
	end
end
