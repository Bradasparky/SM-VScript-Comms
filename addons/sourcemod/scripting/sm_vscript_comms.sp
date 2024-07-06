#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sm_vscript_comms>

#define MAX_PROXIES 7
#define MAX_VSCRIPT_PARAMS 16
#define VSCRIPT_FILE "sm-vscript-comms"
#define PROXY_NAME "sm-vscript-proxy_"
#define SCOPE_NAME "sm-vscript-scope"
#define PRESERVED_CLASSNAME "point_commentary_viewpoint"
#define INVALID_VSCRIPT_HANDLE view_as<VScriptHandleInternal>(INVALID_HANDLE)

// Parameter Types
#define PROP_ENTITY "m_hEffectEntity"
#define PROP_BOOL "m_bWrap"
#define PROP_INT "m_iHealth"
#define PROP_FLOAT "m_flFramerate"
#define PROP_STRING "m_szMaterialName"
#define PROP_VECTOR "m_vecViewOffset"
#define PROP_PARAM_COUNT "m_iFrameStart"
#define PROP_FUNC "m_szMaterialVar"
#define PROP_RETURN_TYPE "m_iFrameEnd"
#define PROP_SCOPE "m_iMaxHealth"
#define PROP_ERROR "m_szMaterialVar"
#define PROP_PARAM_ARRAY "m_szMaterialVarValue"

public Plugin myinfo =
{
    name = "SM-VScript",
    author = "Bradsparky",
    description = "Call VScript functions from sourcepawn",
    version = "1.0",
};

int iScopeEnt, iProxies[MAX_PROXIES];
VScriptCall tCurrentCall;
VScriptHandleInternal hCurrentHandle = INVALID_VSCRIPT_HANDLE;

stock static const char szParamCountToString[][] =
{
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"
};

stock static const char szReturnTypeName[][] =
{
    "Invalid", "Void", "Entity", "Bool", "Int", "Float", "String", "Vector", "QAngle"
};

stock static const char szParamTypeName[][] =
{
    "Invalid", "Entity", "Bool", "Int", "Float", "String", "Vector", "QAngle"
};

enum struct VScriptCall
{
    int iParamCount;
    int iCurrentParam;
    eVScriptReturnType eReturnType;
    char szFunc[256];
    char szParamArray[MAX_VSCRIPT_PARAMS];

    void Reset()
    {
        char szReset[MAX_VSCRIPT_PARAMS];
        this.szParamArray = szReset;
        this.iParamCount = 0;
        this.iCurrentParam = 0;
        this.szFunc = "\0";
    }

    /*
    *   Netprop Proxies
    */

    void SetProxyScriptScope(eVScriptScope iScope)
    {
        SetEntProp(iProxies[6], Prop_Data, PROP_SCOPE, iScope);
    }

    void SetProxyFunction(char[] szFunc)
    {
        SetEntPropString(iProxies[5], Prop_Data, PROP_FUNC, szFunc);
    }

    void SetProxyParamCount(int iParamCount)
    {
        SetEntProp(iProxies[6], Prop_Data, PROP_PARAM_COUNT, iParamCount);
    }

    void SetProxyReturnType(eVScriptReturnType eReturnType)
    {
        SetEntProp(iProxies[6], Prop_Data, PROP_RETURN_TYPE, eReturnType);
    }

    void SetProxyParamArray(char[] szParams)
    {
        SetEntPropString(iProxies[6], Prop_Send, PROP_PARAM_ARRAY, szParams);
    }

    void PushProxyParameter(char[] szValue, eVScriptParamType eParamType)
    {
        int iParamCount = this.iParamCount;
        int iCurrentParam = this.iCurrentParam;

        if (iCurrentParam == iParamCount)
        {
            ThrowError("Failed to call %s. Cannot push more than %i parameters.", 
                tCurrentCall.szFunc, iParamCount);
        }

        if (this.szParamArray[iCurrentParam] - '0' != view_as<int>(eParamType))
        {
            char iParamType = this.szParamArray[iCurrentParam] - '0';
            ThrowError("Failed to call %s. Pushed the wrong type for parameter %i. Expected VScriptFunc_Push%s.", 
                tCurrentCall.szFunc, iCurrentParam + 1, szParamTypeName[iParamType]);
        }

        switch (this.iCurrentParam++)
        {
            case 0: SetEntPropString(iProxies[0], Prop_Data, "m_szMaterialName", szValue);
            case 1: SetEntPropString(iProxies[0], Prop_Data, "m_szMaterialVar", szValue);
            case 2: SetEntPropString(iProxies[0], Prop_Data, "m_szMaterialVarValue", szValue);
            case 3: SetEntPropString(iProxies[1], Prop_Data, "m_szMaterialName", szValue);
            case 4: SetEntPropString(iProxies[1], Prop_Data, "m_szMaterialVar", szValue);
            case 5: SetEntPropString(iProxies[1], Prop_Data, "m_szMaterialVarValue", szValue);
            case 6: SetEntPropString(iProxies[2], Prop_Data, "m_szMaterialName", szValue);
            case 7: SetEntPropString(iProxies[2], Prop_Data, "m_szMaterialVar", szValue);
            case 8: SetEntPropString(iProxies[2], Prop_Data, "m_szMaterialVarValue", szValue);
            case 9: SetEntPropString(iProxies[3], Prop_Data, "m_szMaterialName", szValue);
            case 10: SetEntPropString(iProxies[3], Prop_Data, "m_szMaterialVar", szValue);
            case 11: SetEntPropString(iProxies[3], Prop_Data, "m_szMaterialVarValue", szValue);
            case 12: SetEntPropString(iProxies[4], Prop_Data, "m_szMaterialName", szValue);
            case 13: SetEntPropString(iProxies[4], Prop_Data, "m_szMaterialVar", szValue);
            case 14: SetEntPropString(iProxies[4], Prop_Data, "m_szMaterialVarValue", szValue);
            case 15: SetEntPropString(iProxies[5], Prop_Data, "m_szMaterialName", szValue);
        }
    }
}

public void OnPluginStart()
{
    RegAdminCmd("vscript_comms_reload", Command_VScriptCommsReload, ADMFLAG_ROOT);

    if (GetEngineVersion() == Engine_TF2)
    {
        HookEvent("recalculate_holidays", OnRecalculateHoliday);
    }
}

Action Command_VScriptCommsReload(int iClient, int iArgs)
{
    InitializeProxies();
    ReplyToCommand(iClient, "[SM] Successfully reloaded custom_scripts.nut");
    return Plugin_Handled;
}

void OnRecalculateHoliday(Event hEvent, const char[] szName, bool bDontBroadcast)
{
    InitializeProxies();
}

public void OnMapStart()
{
    InitializeProxies();
}

void InitializeProxies()
{
    for (int i; i < sizeof(iProxies); i++)
    {
        iProxies[i] = -1;
        bool bFound;
        char szProxyName[20];
        Format(szProxyName, sizeof(szProxyName), "%s%i", PROXY_NAME, i);

        // Find existing proxy by targetname
        while ((iProxies[i] = FindEntityByClassname(iProxies[i], PRESERVED_CLASSNAME)) != -1)
        {
            char szTargetName[20];
            GetEntPropString(iProxies[i], Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));

            if (StrEqual(szTargetName, szProxyName))
            {
                iProxies[i] = EntIndexToEntRef(iProxies[i]);
                bFound = true;
                break;
            }
        }

        // Create the proxy if not found
        if (!bFound)
        {
            iProxies[i] = EntIndexToEntRef(CreateEntityByName("material_modify_control"));
            if (!IsValidEdict(iProxies[i]))
            {
                SetFailState("Failed to create a proxy.");
            }

            DispatchKeyValue(iProxies[i], "targetname", szProxyName); // Same as m_iName
            DispatchSpawn(iProxies[i]);
            SetEntPropString(iProxies[i], Prop_Data, "m_iClassname", PRESERVED_CLASSNAME); // Preserve post round
        }
    }
    
    bool bFound;
    iScopeEnt = -1;
    while ((iScopeEnt = FindEntityByClassname(iScopeEnt, PRESERVED_CLASSNAME)) != -1)
    {
        char szTargetName[20];
        GetEntPropString(iScopeEnt, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));

        if (StrEqual(szTargetName, SCOPE_NAME))
        {
            bFound = true;
            break;
        }
    }

    if (!bFound)
    {
        iScopeEnt = EntIndexToEntRef(CreateEntityByName("info_teleport_destination"));
        if (!IsValidEdict(iScopeEnt))
        {
            SetFailState("Failed to create scope.");
        }

        DispatchKeyValue(iScopeEnt, "targetname", SCOPE_NAME); // Same as m_iName
        DispatchSpawn(iScopeEnt);
        SetEntPropString(iScopeEnt, Prop_Data, "m_iClassname", PRESERVED_CLASSNAME); // Preserve post round
    }

    InitializeVScriptProxies();
}

void InitializeVScriptProxies()
{
    SetVariantString(VSCRIPT_FILE);
    AcceptEntityInput(iScopeEnt, "RunScriptFile");

    SetVariantString("InitializeProxies");
    AcceptEntityInput(iScopeEnt, "CallScriptFunction");
}

methodmap VScriptHandleInternal < StringMap
{
    public VScriptHandleInternal(eVScriptScope eScriptScope)
    {
        VScriptHandleInternal hCall = view_as<VScriptHandleInternal>(new StringMap());
        hCall.iParamCount = 0;
        hCall.eScriptScope = eScriptScope;
        hCall.eReturnType = VScriptReturnType_Invalid;
        return hCall;
    }

    property int iParamCount
    {
        public get()
        {
            int i; this.GetValue("iParamCount", i);
            return i;
        }
        public set(int i)
        {
            this.SetValue("iParamCount", i);
        }
    }

    property eVScriptReturnType eReturnType
    {
        public get()
        {
            eVScriptReturnType i; this.GetValue("eReturnType", i);
            return i;
        }
        public set(eVScriptReturnType i)
        {
            this.SetValue("eReturnType", i);
        }
    }

    property eVScriptScope eScriptScope
    {
        public get()
        {
            eVScriptScope i; this.GetValue("eScriptScope", i);
            return i;
        }
        public set(eVScriptScope i)
        {
            this.SetValue("eScriptScope", i);
        }
    }
    
    public void GetParamArray(char[] szParams, int iSize)
    {
        this.GetString("Params", szParams, iSize);
    }

    public void SetParamArray(char[] szParams)
    {
        this.SetString("Params", szParams);
    }

    public void GetFunction(char[] szName, int iSize)
    {
        this.GetString("Func", szName, iSize);
    }

    public void SetFunctionName(char[] szName)
    {
        this.SetString("Func", szName);
    }
    
    public eVScriptReturnType GetReturnType()
    {
        return this.eReturnType;
    }

    public void SetReturnType(eVScriptReturnType eReturnType)
    {
        this.eReturnType = eReturnType;
    }

    public eVScriptScope GetScriptScope()
    {
        return this.eScriptScope;
    }

    public void SetScriptScope(eVScriptScope eScriptScope)
    {
        this.eScriptScope = eScriptScope;
    }

    public int GetParamCount()
    {
        return this.iParamCount;
    }
    
    public void SetNextParamType(eVScriptParamType eParamType)
    {
        char szParams[MAX_VSCRIPT_PARAMS];
        this.GetParamArray(szParams, sizeof(szParams));
        szParams[this.iParamCount] = '0' + view_as<int>(eParamType);
        this.SetParamArray(szParams);
    }
}

/*
*   Prepare VScript Handle
*/

void StartPrepVScriptCall_Internal(eVScriptScope eScriptScope)
{
    if (hCurrentHandle != INVALID_VSCRIPT_HANDLE)
    {
        ThrowError("Cannot call StartPrepVScriptCall while another is in progress. Use EndPrepVScriptCall to end the previous call before starting another.");
    }

    if (!(VScriptScope_Invalid < eScriptScope <= VScriptScope_EntityInstance))
    {
        ThrowError("Failed to call StartPrepVScriptCall. Tried to set an invalid script scope %i.", eScriptScope);
    }

    hCurrentHandle = new VScriptHandleInternal(eScriptScope);
}

void PrepVScriptCall_SetFunction_Internal(char[] szFunc)
{
    if (szFunc[0] == '\0')
    {
        delete hCurrentHandle;
        ThrowError("Failed to call PrepVScriptCall_SetFunction. Function cannot start with a null terminator '\0'.");
    }

    hCurrentHandle.SetFunctionName(szFunc);
}

void PrepVScriptCall_AddParameter_Internal(eVScriptParamType eParamType)
{
    if (!hCurrentHandle.GetParamCount() 
        && hCurrentHandle.GetScriptScope() == VScriptScope_EntityInstance
        && eParamType != VScriptParamType_Entity)
    {
        delete hCurrentHandle;
        ThrowError("Failed to call PrepVScriptCall_AddParameter. The first parameter type must be VScriptParamType_Entity with the script scope set to VScriptScope_EntityInstance.");
    }

    if (!(VScriptParamType_Invalid < eParamType <= VScriptParamType_QAngle))
    {
        delete hCurrentHandle;
        ThrowError("Failed to call PrepVScriptCall_AddParameter. Tried to set an invalid parameter type %i.", eParamType);
    }

    if (hCurrentHandle.iParamCount == MAX_VSCRIPT_PARAMS)
    {
        delete hCurrentHandle;
        ThrowError("Failed to add %s parameter. Cannot add more than %i parameters.", szParamTypeName[eParamType], MAX_VSCRIPT_PARAMS);
    }
    
    hCurrentHandle.SetNextParamType(eParamType);
    hCurrentHandle.iParamCount++;
}

void PrepVScriptCall_SetReturnType_Internal(eVScriptReturnType eReturnType)
{
    if (!(VScriptReturnType_Invalid < eReturnType <= VScriptReturnType_QAngle))
    {
        delete hCurrentHandle;
        ThrowError("Failed to call PrepVScriptCall_SetReturnType. Tried to set an invalid return type %i.", eReturnType);
    }

    hCurrentHandle.SetReturnType(eReturnType);
}

VScriptHandleInternal EndPrepVScriptCall_Internal()
{
    if (hCurrentHandle == INVALID_VSCRIPT_HANDLE)
    {
        delete hCurrentHandle;
        ThrowError("Failed to call EndPrepVScriptCall. No active call is in progress.");
    }

    char szFunc[256];
    hCurrentHandle.GetFunction(szFunc, sizeof(szFunc));

    if (szFunc[0] == '\0')
    {
        delete hCurrentHandle;
        ThrowError("Failed to call EndPrepVScriptCall. No function was specified. Use PrepVScriptCall_SetFunction.");
    }
    
    eVScriptReturnType eReturnType = hCurrentHandle.GetReturnType();

    if (eReturnType == VScriptReturnType_Invalid)
    {
        delete hCurrentHandle;
        ThrowError("Failed to call EndPrepVScriptCall. No return type was specified. Use PrepVScriptCall_SetReturnType.");
    }
    
    return SetInvalidAndReturn(hCurrentHandle);
}

VScriptHandleInternal SetInvalidAndReturn(VScriptHandleInternal& hHandle)
{
    VScriptHandleInternal hNewHandle = hHandle;
    hHandle = INVALID_VSCRIPT_HANDLE;
    return hNewHandle;
}

/*
*   Call VScript Function   
*/

void StartVScriptFunc_Internal(VScriptHandleInternal hCall)
{
    if (!hCall)
    {
        ThrowError("Failed to call StartVScriptFunc. Passed an invalid VScriptHandleInternal.");
    }

    tCurrentCall.Reset();
    
    int iParamCount = hCall.GetParamCount();
    eVScriptReturnType eReturnType = hCall.GetReturnType();
    char szFunc[256], szParamArray[MAX_VSCRIPT_PARAMS];
    hCall.GetFunction(szFunc, sizeof(szFunc));
    hCall.GetParamArray(szParamArray, sizeof(szParamArray));
    tCurrentCall.SetProxyFunction(szFunc);
    tCurrentCall.SetProxyParamArray(szParamArray);
    tCurrentCall.SetProxyParamCount(iParamCount);
    tCurrentCall.SetProxyReturnType(eReturnType);
    tCurrentCall.SetProxyScriptScope(hCall.GetScriptScope());

    tCurrentCall.iParamCount = iParamCount;
    tCurrentCall.eReturnType = eReturnType;
    tCurrentCall.szParamArray = szParamArray;
    tCurrentCall.szFunc = szFunc;
}

void VScriptFunc_PushEntity_Internal(int i)
{
    char szEntity[8];
    FormatEx(szEntity, sizeof(szEntity), "%i", i);
    tCurrentCall.PushProxyParameter(szEntity, VScriptParamType_Entity);
}

void VScriptFunc_PushBool_Internal(bool i)
{
    char szBool[3];
    FormatEx(szBool, sizeof(szBool), "%i", i);
    tCurrentCall.PushProxyParameter(szBool, VScriptParamType_Bool);
}

void VScriptFunc_PushInt_Internal(int i)
{
    char szInt[12];
    FormatEx(szInt, sizeof(szInt), "%i", i);
    tCurrentCall.PushProxyParameter(szInt, VScriptParamType_Int);
}

void VScriptFunc_PushFloat_Internal(float i)
{
    char szFloat[20];
    FormatEx(szFloat, sizeof(szFloat), "%f", i);
    tCurrentCall.PushProxyParameter(szFloat, VScriptParamType_Float);
}

void VScriptFunc_PushString_Internal(char[] i)
{
    tCurrentCall.PushProxyParameter(i, VScriptParamType_String);
}

void VScriptFunc_PushVector_Internal(float i[3])
{
    // Maximum size of material props are 255, but in order to append the 's', the input string can only be 254
    char szVector[128];
    FormatEx(szVector, sizeof(szVector), "%f %f %f", i[0], i[1], i[2]);
    tCurrentCall.PushProxyParameter(szVector, VScriptParamType_Vector);
}

void VScriptFunc_PushQAngle_Internal(float i[3])
{
    // Maximum size of material props are 255, but in order to append the 's', the input string can only be 254
    char szQAngle[128];
    FormatEx(szQAngle, sizeof(szQAngle), "%f %f %f", i[0], i[1], i[2]);
    tCurrentCall.PushProxyParameter(szQAngle, VScriptParamType_QAngle);
}

void FireVScriptFunc_Void_Internal()
{
    FireVScriptFunc();

    eVScriptReturnType eReturnType = tCurrentCall.eReturnType;

    switch (eReturnType)
    {
        case VScriptReturnType_Void: return;
        case VScriptReturnType_Entity, VScriptReturnType_Bool, VScriptReturnType_Int, VScriptReturnType_Float:
        {
            ThrowError("FireVScriptFunc_Void does not match the expected return type %s. Use FireVScriptFunc_ReturnAny", szReturnTypeName[eReturnType]);
        }
        case VScriptReturnType_String:
        {
            ThrowError("FireVScriptFunc_Void does not match the expected return type String. Use FireVScriptFunc_ReturnString");
        }
        case VScriptReturnType_Vector, VScriptReturnType_QAngle: 
        {
            ThrowError("FireVScriptFunc_Void does not match the expected return type %s. Use FireVScriptFunc_ReturnVector", szReturnTypeName[eReturnType]);
        }
        default:
        {
            ThrowError("FireVScriptFunc_Void fired with an invalid return type.");
        }
    }
}

any FireVScriptFunc_ReturnAny_Internal()
{
    FireVScriptFunc();

    eVScriptReturnType eReturnType = tCurrentCall.eReturnType;

    switch (eReturnType)
    {
        case VScriptReturnType_Entity:
        {
            return GetEntPropEnt(iProxies[6], Prop_Data, PROP_ENTITY);
        }
        case VScriptReturnType_Bool:
        {
            return !!GetEntProp(iProxies[6], Prop_Data, PROP_BOOL);
        }
        case VScriptReturnType_Int:
        {
            return GetEntProp(iProxies[6], Prop_Data, PROP_INT);
        }
        case VScriptReturnType_Float:
        {
            return GetEntPropFloat(iProxies[6], Prop_Data, PROP_FLOAT);
        }
        case VScriptReturnType_String:
        {
            ThrowError("FireVScriptFunc_ReturnAny does not match the expected return type String. Use FireVScriptFunc_String.");
        }
        case VScriptReturnType_Void:
        {
            ThrowError("FireVScriptFunc_ReturnAny does not match the expected return type Void. Use FireVScriptFunc_Void.");
        }
        case VScriptReturnType_Vector, VScriptReturnType_QAngle: 
        {
            ThrowError("FireVScriptFunc_ReturnAny does not match the expected return type %s. Use FireVScriptFunc_ReturnVector", szParamTypeName[eReturnType]);
        }
        default:
        {
            ThrowError("FireVScriptFunc_ReturnAny fired with an invalid return type.");
        }
    }

    return -1;
}

void FireVScriptFunc_ReturnString_Internal(char[] szReturnValue = "", int iSize = -1)
{
    FireVScriptFunc();

    eVScriptReturnType eReturnType = tCurrentCall.eReturnType;

    switch (eReturnType)
    {
        case VScriptReturnType_String:
        {
            GetEntPropString(iProxies[6], Prop_Send, PROP_STRING, szReturnValue, iSize);
        }
        case VScriptReturnType_Void:
        {
            ThrowError("FireVScriptFunc_ReturnString does not match the expected return type Void. Use FireVScriptFunc_Void.");
        }
        case VScriptReturnType_Entity, VScriptReturnType_Bool, VScriptReturnType_Int, VScriptReturnType_Float:
        {
            ThrowError("FireVScriptFunc_ReturnString does not match the expected return type %s. Use FireVScriptFunc_ReturnAny", szReturnTypeName[eReturnType]);
        }
        case VScriptReturnType_Vector, VScriptReturnType_QAngle: 
        {
            ThrowError("FireVScriptFunc_ReturnString does not match the expected return type %s. Use FireVScriptFunc_ReturnVector", szParamTypeName[eReturnType]);
        }
        default:
        {
            ThrowError("FireVScriptFunc_ReturnString fired with an invalid return type.");
        }
    }
}

void FireVScriptFunc_ReturnVector_Internal(float vVec[3] = NULL_VECTOR)
{
    FireVScriptFunc();

    eVScriptReturnType eReturnType = tCurrentCall.eReturnType;

    switch (eReturnType)
    {
        case VScriptReturnType_Vector, VScriptReturnType_QAngle:
        {
            GetEntPropVector(iProxies[6], Prop_Data, PROP_VECTOR, vVec);
        }
        case VScriptReturnType_Void:
        {
            ThrowError("FireVScriptFunc_ReturnVector does not match the expected return type Void. Use FireVScriptFunc_Void.");
        }
        case VScriptReturnType_Entity, VScriptReturnType_Bool, VScriptReturnType_Int, VScriptReturnType_Float:
        {
            ThrowError("FireVScriptFunc_ReturnVector does not match the expected return type %s. Use FireVScriptFunc_ReturnAny");
        }
        case VScriptReturnType_String:
        {
            ThrowError("FireVScriptFunc_ReturnVector does not match the expected return type String. Use FireVScriptFunc_String.");
        }
        default:
        {
            ThrowError("FireVScriptFunc_ReturnVector fired with an invalid return type.");
        }
    }
}

void FireVScriptFunc()
{
    SetVariantString("OnReceiveVScriptCall");
    AcceptEntityInput(iScopeEnt, "CallScriptFunction");

    char szError[256];
    GetEntPropString(iProxies[6], Prop_Send, PROP_ERROR, szError, sizeof(szError));

    if (szError[0] != '\0')
    {
        SetEntPropString(iProxies[6], Prop_Send, PROP_ERROR, "\0");
        ThrowError("%s", szError);
    }
}

/*
*   Natives
*/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iSize)
{
    RegPluginLibrary("sm_vscript_comms");

    CreateNative("StartPrepVScriptCall", Native_StartPrepVScriptCall);
    CreateNative("PrepVScriptCall_SetFunction", Native_PrepVScriptCall_SetFunction);
    CreateNative("PrepVScriptCall_AddParameter", Native_PrepVScriptCall_AddParameter);
    CreateNative("PrepVScriptCall_SetReturnType", Native_PrepVScriptCall_SetReturnType);
    CreateNative("EndPrepVScriptCall", Native_EndPrepVScriptCall);
    CreateNative("StartVScriptFunc", Native_StartVScriptFunc);
    CreateNative("VScriptFunc_PushEntity", Native_VScriptFunc_PushEntity);
    CreateNative("VScriptFunc_PushBool", Native_VScriptFunc_PushBool);
    CreateNative("VScriptFunc_PushInt", Native_VScriptFunc_PushInt);
    CreateNative("VScriptFunc_PushFloat", Native_VScriptFunc_PushFloat);
    CreateNative("VScriptFunc_PushString", Native_VScriptFunc_PushString);
    CreateNative("VScriptFunc_PushVector", Native_VScriptFunc_PushVector);
    CreateNative("VScriptFunc_PushQAngle", Native_VScriptFunc_PushQAngle);
    CreateNative("FireVScriptFunc_Void", Native_FireVScriptFunc_Void);
    CreateNative("FireVScriptFunc_ReturnAny", Native_FireVScriptFunc_ReturnAny);
    CreateNative("FireVScriptFunc_ReturnString", Native_FireVScriptFunc_ReturnString);
    CreateNative("FireVScriptFunc_ReturnVector", Native_FireVScriptFunc_ReturnVector);

    return APLRes_Success;
}

any Native_StartPrepVScriptCall(Handle hPlugin, int iParams)
{
    StartPrepVScriptCall_Internal(view_as<eVScriptScope>(GetNativeCell(1)));
    return 0;
}

any Native_PrepVScriptCall_SetFunction(Handle hPlugin, int iParams)
{
    char szFunc[256];
    GetNativeString(1, szFunc, sizeof(szFunc));
    PrepVScriptCall_SetFunction_Internal(szFunc);
    return 0;
}

any Native_PrepVScriptCall_AddParameter(Handle hPlugin, int iParams)
{
    PrepVScriptCall_AddParameter_Internal(view_as<eVScriptParamType>(GetNativeCell(1)));
    return 0;
}

any Native_PrepVScriptCall_SetReturnType(Handle hPlugin, int iParams)
{
    PrepVScriptCall_SetReturnType_Internal(view_as<eVScriptReturnType>(GetNativeCell(1)));
    return 0;
}

any Native_EndPrepVScriptCall(Handle hPlugin, int iParams)
{
    VScriptHandleInternal hCall = EndPrepVScriptCall_Internal();
    return TransferHandleToPlugin(hCall, hPlugin);
}

VScriptHandleInternal TransferHandleToPlugin(VScriptHandleInternal& hCall, Handle hPlugin)
{
    VScriptHandleInternal hClone = view_as<VScriptHandleInternal>(CloneHandle(hCall, hPlugin));
    delete hCall;
    return hClone;
}

any Native_StartVScriptFunc(Handle hPlugin, int iParams)
{
    StartVScriptFunc_Internal(GetNativeCell(1));
    return 0;
}

any Native_VScriptFunc_PushEntity(Handle hPlugin, int iParams)
{
    VScriptFunc_PushEntity_Internal(GetNativeCell(1));
    return 0;
}

any Native_VScriptFunc_PushBool(Handle hPlugin, int iParams)
{
    VScriptFunc_PushBool_Internal(!!GetNativeCell(1));
    return 0;
}

any Native_VScriptFunc_PushInt(Handle hPlugin, int iParams)
{
    VScriptFunc_PushInt_Internal(GetNativeCell(1));
    return 0;
}

any Native_VScriptFunc_PushFloat(Handle hPlugin, int iParams)
{
    VScriptFunc_PushFloat_Internal(view_as<float>(GetNativeCell(1)));
    return 0;
}

any Native_VScriptFunc_PushString(Handle hPlugin, int iParams)
{
    char szFunc[256];
    GetNativeString(1, szFunc, sizeof(szFunc));
    VScriptFunc_PushString_Internal(szFunc);
    return 0;
}

any Native_VScriptFunc_PushVector(Handle hPlugin, int iParams)
{
    float vVec[3];
    GetNativeArray(1, vVec, sizeof(vVec));
    VScriptFunc_PushVector_Internal(vVec);
    return 0;
}

any Native_VScriptFunc_PushQAngle(Handle hPlugin, int iParams)
{
    float vAng[3];
    GetNativeArray(1, vAng, sizeof(vAng));
    VScriptFunc_PushQAngle_Internal(vAng);
    return 0;
}

any Native_FireVScriptFunc_Void(Handle hPlugin, int iParams)
{
    FireVScriptFunc_Void_Internal();
    return 0;
}

any Native_FireVScriptFunc_ReturnAny(Handle hPlugin, int iParams)
{
    return FireVScriptFunc_ReturnAny_Internal();
}

any Native_FireVScriptFunc_ReturnString(Handle hPlugin, int iParams)
{
    int iLength = GetNativeCell(2); 
    char[] szString = new char[iLength];
    FireVScriptFunc_ReturnString_Internal(szString, iLength);
    SetNativeString(1, szString, iLength);
    return 0;
}

any Native_FireVScriptFunc_ReturnVector(Handle hPlugin, int iParams)
{
    float vVec[3];
    FireVScriptFunc_ReturnVector_Internal(vVec);
    SetNativeArray(1, vVec, sizeof(vVec));
    return 0;
}