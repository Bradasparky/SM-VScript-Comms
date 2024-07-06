#if defined _sm_vscript_comms_included_
    #endinput
#endif
#define _sm_vscript_comms_included_

enum eVScriptReturnType
{
    VScriptReturnType_Invalid,
    VScriptReturnType_Void,
    VScriptReturnType_Entity,
    VScriptReturnType_Bool,
    VScriptReturnType_Int,
    VScriptReturnType_Float,
    VScriptReturnType_String,
    VScriptReturnType_Vector,
    VScriptReturnType_QAngle
}

enum eVScriptParamType
{
    VScriptParamType_Invalid,
    VScriptParamType_Entity,
    VScriptParamType_Bool,
    VScriptParamType_Int,
    VScriptParamType_Float,
    VScriptParamType_String,
    VScriptParamType_Vector,
    VScriptParamType_QAngle
}

enum eVScriptScope
{
    VScriptScope_Invalid,
    VScriptScope_RootTable,
    VScriptScope_Proxy,
    VScriptScope_EntityInstance
}

methodmap VScriptHandle {}

/**
 * Prepares the creation of a VScriptHandle
 *
 * @param eScriptScope  An enum value from eVScriptScope enum
 */
native void StartPrepVScriptCall(eVScriptScope eScriptScope);

/**
 * Sets the VScript function name for VScriptHandle being prepared
 *
 * @param szFunc        Function name in VScript
 */
native void PrepVScriptCall_SetFunction(char[] szFunc);

/**
 * Adds a sequential parameter type to the VScriptHandle being prepared
 *
 * @param eParamType    An enum value from eVScriptParamType
 */
native void PrepVScriptCall_AddParameter(eVScriptParamType eParamType);

/**
 * Sets the return type of the VScriptHandle being prepared
 *
 * @param eReturnType   An enum value from eVScriptReturnType
 */
native void PrepVScriptCall_SetReturnType(eVScriptReturnType eReturnType);

/**
 * Prepares the creation of a VScriptHandle
 *
 * @return An initialized VScriptHandle to be called via StartVScriptFunc
 */
native VScriptHandle EndPrepVScriptCall();

/**
 * Starts a VScript function call using an initialized VScriptHandle
 */
native void StartVScriptFunc(VScriptHandle hCall);

/**
 * Pushes a sequential entity parameter to the current VScript function call
 * Warning: The entity must exist or else EntIndexToHScript will error
 */
native void VScriptFunc_PushEntity(int iEntity);

/**
 * Pushes a sequential boolean parameter to the current VScript function call
 */
native void VScriptFunc_PushBool(int bValue);

/**
 * Pushes a sequential integer parameter to the current VScript function call
 */
native void VScriptFunc_PushInt(int iValue);

/**
 * Pushes a sequential float parameter to the current VScript function call
 */
native void VScriptFunc_PushFloat(float flValue);

/**
 * Pushes a sequential string parameter to the current VScript function call
 */
native void VScriptFunc_PushString(char[] szValue);

/**
 * Pushes a sequential Vector parameter to the current VScript function call
 */
native void VScriptFunc_PushVector(float vVec[3]);

/**
 * Pushes a sequential QAngle parameter to the current VScript function call
 */
native void VScriptFunc_PushQAngle(float vAng[3]);

/**
 * Fires the current VScript function call without returning a value
 * Warning: Only use this if the VScriptHandle passed into StartVScriptFunc
 * has a void return type
 */
native void FireVScriptFunc_Void();

/**
 * Fires the current VScript function call and returns an any type
 * Warning: Only use this if the VScriptHandle passed into StartVScriptFunc
 * returns an entity, boolean, integer, or float
 */
native any FireVScriptFunc_ReturnAny();

/**
 * Fires the current VScript function call without returning a value
 * Warning: Only use this if the VScriptHandle passed into StartVScriptFunc
 * has a string return type
 */
native void FireVScriptFunc_ReturnString(char[] szValue = "", int iSize = -1);

/**
 * Fires the current VScript function call without returning a value
 * Warning: Only use this if the VScriptHandle passed into StartVScriptFunc
 * has a Vector or QAngle return type
 */
native void FireVScriptFunc_ReturnVector(float vVec[3] = NULL_VECTOR);

public SharedPlugin __pl_sm_vscript_comms = 
{
    name = "sm_vscript_comms",
    file = "sm_vscript_comms.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};