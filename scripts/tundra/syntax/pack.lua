module(..., package.seeall)

local path = require "tundra.path"
local nodegen = require "tundra.nodegen"
local depgraph = require "tundra.depgraph"

local _packgen = {}

-- This is quite a hack job. I want to move to plain old .zip files anyway.
function _packgen:create_dag(env, data, deps)
	local out_fn = "$(OBJECTDIR)$(SEP)" .. path.get_filename(data.Output)
	return depgraph.make_node {
	    Env = env,
		Pass = data.Pass,
		Label = "Create .pak file $(@)",
		Action = "$(OBJECTDIR)$(SEP)pack c $(@) " .. data.InputSpec,
		InputFiles = data.Input,
		OutputFiles = { out_fn },
		Dependencies = deps,
	}
end

local blueprint = {
	Name = { Type = "string" },
	Pass = { Required = false, Type = "pass", Help = "Pass", },
	Input = { Required = true, Type = "table", Help = "Input files", },
	InputSpec = { Required = true, Type = "string", Help = "Command line to pack.exe", },
	Output = { Required = true, Type = "string", Help = "Output .pak file", },
}

nodegen.add_evaluator("PackFile", _packgen, blueprint)
