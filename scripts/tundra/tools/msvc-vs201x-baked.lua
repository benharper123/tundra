-- Copyright 2010 Andreas Fredriksson
--
-- This file is part of Tundra.
--
-- Tundra is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Tundra is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Tundra.  If not, see <http://www.gnu.org/licenses/>.

-- Ben Harper:
-- msvc-vs201x-baked.lua - Use packaged up compilers, headers, libraries,
-- so that we can deploy a build environment with a simple file copy.
-- We use a few lines of setup inside our tundra.lua script to setup
-- the appropriate variables for this tool:
-- TargetArch, VcVersion, RootDir, SdkDir
-- This has been tested with VS 2012 and VS 2013

module(..., package.seeall)

local native = require "tundra.native"
local os = require "os"

if native.host_platform ~= "windows" then
	error("the msvc toolset only works on windows hosts")
end

local function get_host_arch()
	local snative = native.getenv("PROCESSOR_ARCHITECTURE")
	local swow = native.getenv("PROCESSOR_ARCHITEW6432", "")
	if snative == "AMD64" or swow == "AMD64" then
		return "x64"
	elseif snative == "IA64" or swow == "IA64" then
		return "itanium";
	else
		return "x86"
	end
end

local compiler_dirs = {
	["x86"] = {
		["x86"] = "bin\\",
		["x64"] = "bin\\x86_amd64\\",
		["arm"] = "bin\\x86_arm\\",
	},
	["x64"] = {
		["x86"] = "bin\\",
		["x64"] = "bin\\amd64\\",
		["arm"] = "bin\\x86_arm\\",
	},
}

local function setup(env, options)
	options = options or {}
	local target_arch = options.TargetArch or "x86"
	local host_arch = options.HostArch or get_host_arch()
	local vcversion = options.VcVersion or "11.0"
	-- When moving to 2013, we also moved to the latest (August 2014) version of the 8.1 SDK, which
	-- moved its libs under 'winv6.3'
	local sdk_has_versioned_lib_dir = vcversion == '12.0'

	local binDir = compiler_dirs[host_arch][target_arch]

	if not binDir then
		errorf("can't build target arch %s on host arch %s", target_arch, host_arch)
	end

	local sdkDir = options.SdkDir
	local sdkBinDir = sdkDir .. "\\bin\\" .. target_arch;
	local vc_dir = options.RootDir .. "\\VC\\"

	local cl_exe = '"' .. vc_dir .. binDir .. "cl.exe" ..'"'
	local lib_exe = '"' .. vc_dir .. binDir .. "lib.exe" ..'"'
	local link_exe = '"' .. vc_dir .. binDir .. "link.exe" ..'"'

	if vcversion == '11.0' then
		env:set("VCVERSION_YEAR", "vs2012")
	elseif vcversion == '12.0' then
		env:set("VCVERSION_YEAR", "vs2013")
	else
		errorf("Unrecognized vsversion %s", vcversion)
	end

	env:set('CC', cl_exe)
	env:set('CXX', cl_exe)
	env:set('LIB', lib_exe)
	env:set('LD', link_exe)

	-- Set up the MS SDK associated with visual studio

	env:set_external_env_var("WindowsSdkDir", sdkDir)
	env:set_external_env_var("INCLUDE",
		sdkDir .. "\\Include\\shared;" ..
		sdkDir .. "\\Include\\um;" ..
		sdkDir .. "\\Include\\WinRT;" ..
		vc_dir .. "\\include;" ..
		vc_dir .. "atlmfc\\include;")

	env:set('RC', '"' .. sdkBinDir .. "\\rc.exe" ..'"')

	local sdkLibBaseDir
	if sdk_has_versioned_lib_dir then
		sdkLibBaseDir = "Lib\\winv6.3"
	else
		sdkLibBaseDir = "Lib\\win8"
	end

	local sdkLibDir
	local vcLibDir

	if "x86" == target_arch then
		sdkLibDir = sdkLibBaseDir .. "\\um\\x86"
		vcLibDir = "lib"
	elseif "x64" == target_arch then
		sdkLibDir = sdkLibBaseDir .. "\\um\\x64"
		vcLibDir = "lib\\amd64"
	elseif "arm" == target_arch then
		sdkLibDir = sdkLibBaseDir .. "\\um\\arm"
		vcLibDir = "lib\\arm"
	else
		errorf("Don't know how to define LIB dir for %s", target_arch)
	end

	local libString =
		sdkDir .. "\\" .. sdkLibDir .. ";" ..
		vc_dir .. vcLibDir .. ";" ..
		vc_dir .. "atlmfc\\" .. vcLibDir .. ";"

	env:set_external_env_var("LIB", libString)
	env:set_external_env_var("LIBPATH", libString)

	local path = { }
	local vc_root = vc_dir:sub(1, -4)
	if binDir ~= "\\bin\\" then
		path[#path + 1] = vc_dir .. "\\bin"
	end
	path[#path + 1] = vc_root .. "Common7\\Tools" -- drop vc\ at end
	path[#path + 1] = vc_root .. "Common7\\IDE" -- drop vc\ at end
	path[#path + 1] = sdkDir
	path[#path + 1] = vc_dir .. binDir
	path[#path + 1] = env:get_external_env_var('PATH')

	env:set_external_env_var("PATH", table.concat(path, ';'))
end

function apply(env, options)
	-- Load basic MSVC environment setup first. We're going to replace the paths to
	-- some tools.
	tundra.unitgen.load_toolset('msvc', env)
	setup(env, options)
end
