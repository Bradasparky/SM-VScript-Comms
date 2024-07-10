const MAX_PROXIES = 7;
const PROXY_NAME = "sm-vscript-proxy_";
const PRESERVED_CLASSNAME = "point_commentary_viewpoint";

// Parameter props
const PROP_ENTITY = "m_hEffectEntity";
const PROP_BOOL = "m_bWrap";
const PROP_INT = "m_iHealth";
const PROP_FLOAT = "m_flFramerate";
const PROP_STRING = "m_szMaterialName";
const PROP_VECTOR = "m_vecViewOffset";
const PROP_PARAM_COUNT = "m_iFrameStart";
const PROP_FUNC = "m_szMaterialVar";
const PROP_RETURN_TYPE = "m_iFrameEnd";
const PROP_SCOPE = "m_iMaxHealth";
const PROP_ERROR = "m_szMaterialVar";
const PROP_PARAM_ARRAY = "m_szMaterialVarValue";

enum VScriptReturnType
{
	Invalid,
    Void,
    Entity,
    Bool,
    Int,
    Float,
    String,
	Vector,
	QAngle
};

enum VScriptParamType
{
	Invalid,
    Entity,
    Bool,
    Int,
    Float,
    String,
	Vector,
	QAngle
};

enum VScriptScope
{
	Invalid,
	RootTable,
	Proxy,
	EntityInstance
};

class VScriptCall_
{
	proxies = [];
	scriptscope = null;
	worldspawn = null;
	roottable = getroottable();

	function InitializeProxies()
	{
		proxies = [];

		for (local i = 0; i < MAX_PROXIES; i++)
		{
			local proxy = null;
			local targetname = PROXY_NAME + i;

			while (proxy = Entities.FindByClassname(proxy, PRESERVED_CLASSNAME))
			{
				if (NetProps.GetPropString(proxy, "m_iName") == targetname)
				{
					proxies.push(proxy);
					break;
				}
			}
		}
	}

	function GetParamCount()
	{
		return NetProps.GetPropInt(proxies[6], PROP_PARAM_COUNT);
	}

	function GetFunctionName()
	{
		return NetProps.GetPropString(proxies[5], PROP_FUNC);
	}

	function GetReturnType()
	{
		return NetProps.GetPropInt(proxies[6], PROP_RETURN_TYPE);
	}

	function GetScriptScope()
	{
		return NetProps.GetPropInt(proxies[6], PROP_SCOPE);
	}

	function GetParamArray()
	{
		return NetProps.GetPropString(proxies[6], PROP_PARAM_ARRAY);
	}

	function SetError(error)
	{
		NetProps.SetPropString(proxies[6], PROP_ERROR, error);
	}

	function GetEntityInstanceIndex()
	{
		return NetProps.GetPropString(proxies[0], "m_szMaterialName").tointeger();
	}

	function OnReceiveVScriptCall()
	{
		local func = GetFunctionName();
		local scope = GetScriptScope();
		local params = GetParamArray();
		local currentparam = 0;
		local args = [];

		switch (scope)
		{
			case VScriptScope.RootTable:
				{
					if (!(func in roottable))
					{
						SetError("Failed to find " + func + " in the roottable.");
						return;
					}

					args.push(roottable);
					scope = roottable;
					break;
				}
			case VScriptScope.Proxy:
				{
					if (!(func in scriptscope))
					{
						SetError("Failed to find " + func + " in the script scope of custom_scripts.nut.");
						return;
					}

					args.push(scriptscope);
					scope = scriptscope;
					break;
				}
			case VScriptScope.EntityInstance:
				{
					local entity = null;
					local index = GetEntityInstanceIndex();

					// worldspawn is an exception because EntIndexToHScript returns null if 0 is passed
					if (index == 0)
					{
						entity = worldspawn;
					}
					else
					{
						entity = EntIndexToHScript(index);

						if (entity == null)
						{
							SetError("Failed to find an entity instance with the index " + index + ".");
							return;
						}
					}

					if (!(func in entity))
					{
						SetError("Failed to find VScript function " + func + " on entity instance " + entity.GetClassname() + ".");
						return;
					}

					++currentparam;
					args.push(entity);
					scope = entity;
					break;
				}
			default: SetError("An invalid VScriptScope was passed."); return;
		}

		// Read params that were set in SM in sequential order. Max of 16 params
		// If the scriptscope is an entity instance, skip the first parameter
		local count = GetParamCount();
		for (; currentparam < count; currentparam++)
		{
			local value = "";
			switch (currentparam)
			{
				case 0: value = NetProps.GetPropString(proxies[0], "m_szMaterialName"); break;
				case 1: value = NetProps.GetPropString(proxies[0], "m_szMaterialVar"); break;
				case 2: value = NetProps.GetPropString(proxies[0], "m_szMaterialVarValue"); break;
				case 3: value = NetProps.GetPropString(proxies[1], "m_szMaterialName"); break;
				case 4: value = NetProps.GetPropString(proxies[1], "m_szMaterialVar"); break;
				case 5: value = NetProps.GetPropString(proxies[1], "m_szMaterialVarValue"); break;
				case 6: value = NetProps.GetPropString(proxies[2], "m_szMaterialName"); break;
				case 7: value = NetProps.GetPropString(proxies[2], "m_szMaterialVar"); break;
				case 8: value = NetProps.GetPropString(proxies[2], "m_szMaterialVarValue"); break;
				case 9: value = NetProps.GetPropString(proxies[3], "m_szMaterialName"); break;
				case 10: value = NetProps.GetPropString(proxies[3], "m_szMaterialVar"); break;
				case 11: value = NetProps.GetPropString(proxies[3], "m_szMaterialVarValue"); break;
				case 12: value = NetProps.GetPropString(proxies[4], "m_szMaterialName"); break;
				case 13: value = NetProps.GetPropString(proxies[4], "m_szMaterialVar"); break;
				case 14: value = NetProps.GetPropString(proxies[4], "m_szMaterialVarValue"); break;
				case 15: value = NetProps.GetPropString(proxies[5], "m_szMaterialName"); break;
			}

			// Convert the string to the expected type before appending to args
			switch (params[currentparam] - '0')
			{
				case VScriptParamType.Entity:
					{
						local index = value.tointeger();
						if (index == 0)
						{
							args.append(worldspawn);
						}
						else
						{
							local ent_param = EntIndexToHScript(index);

							if (ent_param == null)
							{
								SetError("Invalid entity index " + index + " was passed to the function " + func + " as parameter " + (currentparam + 1) + ".");
								return;
							}

							args.append(ent_param);
						}

						break;
					}
				case VScriptParamType.Bool: args.append(!!value.tointeger()); break;
				case VScriptParamType.Int: args.append(value.tointeger()); break;
				case VScriptParamType.Float: args.append(value.tofloat()); break;
				case VScriptParamType.String: args.append(value); break;
				case VScriptParamType.Vector:
					{
						local str_vec = split(value, " ");
						local vec = Vector(str_vec[0].tofloat(), str_vec[1].tofloat(), str_vec[2].tofloat());
						args.append(vec);
						break;
					}
				case VScriptParamType.QAngle:
					{
						local str_ang = split(value, " ");
						local ang = QAngle(str_ang[0].tofloat(), str_ang[1].tofloat(), str_ang[2].tofloat());
						args.append(ang);
						break;
					}
				default: printl("An invalid VScriptParameterType was passed."); return;
			}
		}

		// Try in the case that the function errors, then we can log the error in Sourcemod
		try
		{
			local returnval = scope.rawget(func).acall(args);

			// Set the return value into it's designated netprop of the expected type
			switch (GetReturnType())
			{
				case VScriptReturnType.Void: break;
				case VScriptReturnType.Entity: NetProps.SetPropEntity(proxies[6], PROP_ENTITY, returnval); break;
				case VScriptReturnType.Bool: NetProps.SetPropBool(proxies[6], PROP_BOOL, returnval); break;
				case VScriptReturnType.Int: NetProps.SetPropInt(proxies[6], PROP_INT, returnval); break;
				case VScriptReturnType.Float: NetProps.SetPropFloat(proxies[6], PROP_FLOAT, returnval); break;
				case VScriptReturnType.String: NetProps.SetPropString(proxies[6], PROP_STRING, returnval == null ? "\0" : returnval); break;
				case VScriptReturnType.Vector: NetProps.SetPropVector(proxies[6], PROP_VECTOR, returnval); break;
				case VScriptReturnType.QAngle: NetProps.SetPropVector(proxies[6], PROP_VECTOR, Vector(returnval.x, returnval.y, returnval.z)); break;
			}
		}
		catch (exception)
		{
			// Allow SM to log the error by reading this string.
			// Erroring is 99% guaranteed to be because the function didn't return the expected type
			printl(exception + ". Make sure to set the correct return type for " + func + ".");
			SetError(exception);
		}
	}
};
::VScriptCall <- VScriptCall_();
VScriptCall.scriptscope = this;
VScriptCall.worldspawn = Entities.FindByClassname(null, "worldspawn");

function OnReceiveVScriptCall()
{
	VScriptCall.OnReceiveVScriptCall();
}

function InitializeProxies()
{
	VScriptCall.InitializeProxies();
}

IncludeScript("sm_vscript_comms/custom_scripts.nut");