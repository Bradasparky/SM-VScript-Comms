# SM-VScript-Comms

Are you tired of having to use gamedata to call functions VScript provides? Is finding gamedata in the first place too complex and time consuming of a task for how simple your use case for a VScript function is? Have you ever thought to yourself "I wish there was a simpler way I could call VScript functions from SourcePawn..." What about calling your own custom VScript functions that gamedata can't help you with in the first place?

This library allows for plugins to call into VScript from an entity's scope, the root table, or from within the `custom_scripts.nut` file provided.

#### Notes

* As an admin with `ADMFLAG_ROOT` access, use the `vscript_comms_reload` command to reload the `custom_scripts.nut` file.
* To make sure the VScript code that makes this plugin work **stays** working, please do not edit the `sm-vscript-comms.nut` file.
* This plugin uses one `info_teleport_destination` to contain the script's scope, and 7 `material_modify_control` for storing parameter values inside netprops.
* Both of the entities used as proxies for communication between SourcePawn and VScript are present in all Source 1 games.
* For Team Fortress 2, the `sm-vscript-comms.nut` file will run each time the "recalculate_holidays" event fires, meaning `custom_scripts.nut` will refresh.

#### Limitations

* Functions from inactive scripts cannot be called.
* Functions from other scripts cannot be called unless they are in the root table.
* The only types that can be returned are the following:
    * Entities (As an index)
    * `bool`
    * `int`
    * `float`
    * `char[]` (Up to 255 in size)
    * `float[3]`
    * `void`
* Excluding `void`, the above are the only types that can be used as parameters.

## For A List Of Functions
> [!IMPORTANT]
> <details>
> <summary> Click Here</summary>
> 
> **For preparing a VScript function**
> * `StartPrepVScriptCall` - Starts the preparation of a `VScriptHandle`.
> * `PrepVScriptCall_SetFunction` - Takes a string.
> * `PrepVScriptCall_AddParameter` - Can be called up to 16 times. Adds parameters in sequential order. Takes an `eVScriptParamType`.
> * `PrepVScriptCall_SetReturnType` - Takes an `eVScriptReturnType`.
> * `EndPrepVScriptCall` - Returns an initialized `VScriptHandle`.
> 
> **For calling a VScript function and pushing parameters**
> * `StartVScriptFunc` - Starts a VScript function call. Takes a `VScriptHandle`.
> * `VScriptFunc_PushEntity`
> * `VScriptFunc_PushBool`
> * `VScriptFunc_PushInt`
> * `VScriptFunc_PushFloat`
> * `VScriptFunc_PushString`
> * `VScriptFunc_PushVector`
> * `VScriptFunc_PushQAngle`
> 
> **Fires a function ...**
> * `FireVScriptFunc_Void` -  ... with a `void` return type.
> * `FireVScriptFunc_ReturnAny` - ... and can return an entity index, `bool`, `int`, or `float`.
> * `FireVScriptFunc_ReturnString` - ... and can return a `char[]` array.
> * `FireVScriptFunc_ReturnVector` - ... and can return a Vector or QAngle into a `float[3]`.
> </details>

## Demonstration

**Step 1.** For the function we want to call, let's use the `Example` function in `scripts/vscripts/sm_vscript_comms/custom_scripts.nut`.
```squirrel
function Example(e, b, i, f, s, v, q)
{
    printl(e);
    printl(b);
    printl(i);
    printl(f);
    printl(s);
    printl(v);
    printl(q);
    return "Hi There! From VScript.";
}
```

**Step 2.** In our SourcePawn plugin, we need to set up a VScript function handle. This is similar to setting up an `SDKCall` in SourcePawn. Note that `VScriptScope_Proxy` is passed into `StartPrepVScriptCall`. This is because the `"Example"` function is within the `custom_scripts.nut` file. All files included within it will also need to be accessed using `VScriptScope_Proxy`.
```SourcePawn
VScriptHandle hExample;

public void OnPluginStart()
{
    hExample = VScriptSetup_Example();
}

VScriptHandle VScriptSetup_Example()
{
    StartPrepVScriptCall(VScriptScope_Proxy);
    PrepVScriptCall_SetFunction("Example");
    PrepVScriptCall_SetReturnType(VScriptReturnType_String);
    PrepVScriptCall_AddParameter(VScriptParamType_Entity);
    PrepVScriptCall_AddParameter(VScriptParamType_Bool);
    PrepVScriptCall_AddParameter(VScriptParamType_Int);
    PrepVScriptCall_AddParameter(VScriptParamType_Float);
    PrepVScriptCall_AddParameter(VScriptParamType_String);
    PrepVScriptCall_AddParameter(VScriptParamType_Vector);
    PrepVScriptCall_AddParameter(VScriptParamType_QAngle);
    return EndPrepVScriptCall();
}
```

**Step 3.** Here's how we push parameters and get a return value from `hExample`. This is similar to calling a `Function` in SourcePawn.
```SourcePawn
void VScriptCall_Example(int e, bool b, int i, float f, char[] s, float v[3], float q[3], char[] szReturn, int iSize)
{
    StartVScriptFunc(hExample);
    VScriptFunc_PushEntity(e);
    VScriptFunc_PushBool(b);
    VScriptFunc_PushInt(i);
    VScriptFunc_PushFloat(f);
    VScriptFunc_PushString(s);
    VScriptFunc_PushVector(v);
    VScriptFunc_PushQAngle(q);
    FireVScriptFunc_ReturnString(szReturn, iSize);
}
```

**Final Step 4.** Now let's call the function and see what console says.
```SourcePawn
char szReturn[24];
VScriptCall_Example(0, true, 2, 3.456789, "Hello! From SM.", { 0.1, 1.2, 2.3 }, { 4.5, 6.7, 8.9 }, szReturn, sizeof(szReturn));
PrintToServer("%s", szReturn);
```
**Console Output**
```
([0] worldspawn)
true
2
3.45679
Hello! From SM.
(vector : (0.100000, 1.200000, 2.299999)
(qangle : (4.500000, 6.699999, 8.899999)
Hi There! From VScript.
```

## License

None of my business
