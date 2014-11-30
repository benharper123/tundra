module(..., package.seeall)

function apply(env, options)
  -- load the generic assembly toolset first
  tundra.unitgen.load_toolset("generic-asm", env)

  env:set_many {
    ["NASM"] = "nasm",
    ["ASMCOM"] = "$(NASM) -o $(@) $(ASMINCPATH:n:p-I) $(ASMDEFS:p-D) $(ASMDEFS_$(CURRENT_VARIANT:u):p-D) $(ASMOPTS) $(ASMOPTS_$(CURRENT_VARIANT:u)) $(<)",
    ["ASMINC_KEYWORDS"] = { "%include" },
  }
end
