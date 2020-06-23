#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required
#define TEAM_INFECTED                        3
#define SPRITE_MODEL3            "materials/vgui/healthbar_white.vmt"
#define SPRITE_MODEL2            "materials/vgui/s_panel_healing_mini_prog.vmt"
#define SPRITE_MODEL             "materials/vgui/hud/zombieteamimage_tank.vmt"
#define SPRITE_MODEL4            "materials/vgui/healthbar_orange.vmt"
#define SPRITE_DEATH             "materials/sprites/death_icon.vmt"

//RIP DIMINUIR?

static bool   g_bL4D2Version;

static int TankSprite[MAXPLAYERS+1];
static int TankHealth[MAXPLAYERS+1];
static bool TankNow[MAXPLAYERS+1];
static bool TankIncapped[MAXPLAYERS+1];
static float LastUseTime[MAXPLAYERS+1];

static int AlgorithmType = 2;
static bool EnableGlow = false;
static ConVar hCvar_Precache;
static bool g_bValidMap;

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();
    if (engine != Engine_Left4Dead2 && engine != Engine_Left4Dead)
    {
         strcopy(error, err_max, "This plugin only runs in the \"Left 4 Dead 2\" and \"Left 4 Dead 1\" game."); // Spitter class is only available in L4D2
         return APLRes_SilentFailure;
    }

    g_bL4D2Version = (engine == Engine_Left4Dead2);

    return APLRes_Success;
}

public void OnPluginStart()
{
    hCvar_Precache 				= CreateConVar("l4d_hp_tank_show_precache",	"c1m3_mall",	"Prevent pre-caching models on these maps, separate by commas (no spaces). Enabling plugin on these maps will crash the server.", FCVAR_NOTIFY );

    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("tank_killed", event_TankKilled);
    HookEvent("player_hurt", OnPlayerHurt);
    /* SI Boomer events */
    HookEvent("player_now_it", _HG_UpdateGlow_NowIT_Event);
    HookEvent("player_no_longer_it", _HG_UpdateGlow_NoLongerIt_Event);
}

public void OnMapStart()
{
	g_bValidMap = true;

	char sCvar[256];
	hCvar_Precache.GetString(sCvar, sizeof(sCvar));

	if( sCvar[0] != '\0' )
	{
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		Format(sMap, sizeof(sMap), ",%s,", sMap);
		Format(sCvar, sizeof(sCvar), ",%s,", sCvar);

		if( StrContains(sCvar, sMap, false) != -1 )
			g_bValidMap = false;
	}

	if( g_bValidMap )
	{
        PrecacheModel(SPRITE_MODEL, true);
        PrecacheModel(SPRITE_MODEL2, true);
        PrecacheModel(SPRITE_MODEL3, true);
        PrecacheModel(SPRITE_MODEL4, true);
        PrecacheModel(SPRITE_DEATH, true);
    }
}

public void _HG_UpdateGlow_NowIT_Event( Event event, const char[] sName, bool bDontBroadcast )
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!g_bValidMap || client <= 0 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED) return;
    L4D2_RemoveEntityGlow(client);
    TankNow[client] = true;
}

public void _HG_UpdateGlow_NoLongerIt_Event( Event event, const char[] sName, bool bDontBroadcast )
{
    if(!g_bValidMap) return;

    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    TankNow[client] = false;

    int nowHP = GetClientHealth(client);
    int maxHP = TankHealth[client];

    if (TankHealth[client] == -1)
         return;

    float fCountdownHeat = float(nowHP) / maxHP;

    if (g_bL4D2Version && EnableGlow)
    {
        L4D2_SetEntityGlow_Type(client, view_as<L4D2GlowType>(3));
        L4D2_SetEntityGlow_MaxRange(client, 0);
        L4D2_SetEntityGlow_MinRange(client, 0);

        bool bHalfHp = false;
        bHalfHp = fCountdownHeat <= 0.5 ? true : false;

        int color[3];
        if (AlgorithmType == 1)
        {
            color[0] = bHalfHp ? 255 : RoundFloat(255.0 * ((1.0 - fCountdownHeat) * 2));
            color[1] = bHalfHp ? RoundFloat(255.0 * (fCountdownHeat) * 2) : 255;
            color[2] = 0;
        }
        else if (AlgorithmType == 2)
        {
            color[0] = RoundFloat(255 * (1 - fCountdownHeat));
            color[1] = RoundFloat(255 * fCountdownHeat);
            color[2] = 0;
        }

        L4D2_SetEntityGlow_Color(client, color);
        if (fCountdownHeat <= 0.1)
            L4D2_SetEntityGlow_Flashing(client, true);
    }
}

public Action event_TankKilled( Event event, const char[] sName, bool bDontBroadcast )
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!g_bValidMap || client <= 0 || client > MaxClients|| !IsClientInGame(client))
        return;

    if (!TankIncapped[client])
    {
        TankHealth[client] = -1;
        int env_sprite = TankSprite[client];

        if (!IsValidEntity(env_sprite))
            return;

        if (!IsModelPrecached(SPRITE_DEATH))
            PrecacheModel(SPRITE_DEATH, true);
        DispatchKeyValue(env_sprite, "model", SPRITE_DEATH);
        DispatchKeyValue(env_sprite, "rendercolor", "127 0 0");
        DispatchKeyValue(env_sprite, "renderamt", "240");
        DispatchSpawn(env_sprite);

        if (g_bL4D2Version && EnableGlow)
            L4D2_SetEntityGlow_Flashing(client, true);
    }
}


enum L4D2GlowType
{
    L4D2GlowType_None     = 0, // OFF
    L4D2GlowType_OnUse    = 1,
    L4D2GlowType_OnLookAt = 2,
    L4D2GlowType_Constant = 3
};

/**
 * Removes entity glow and reset it to default value.
 *
 * @param entity    Entity index.
 * @noreturn
 */
void L4D2_RemoveEntityGlow(int entity)
{
    L4D2_SetEntityGlow_Type(entity, L4D2GlowType_None);
    L4D2_SetEntityGlow_MaxRange(entity, 0);
    L4D2_SetEntityGlow_MinRange(entity, 0);
    L4D2_SetEntityGlow_Color(entity, {0, 0, 0});
    L4D2_SetEntityGlow_Flashing(entity, false);
}

/**
 * Get the specific L4D2 zombie class id from the client.
 *
 * @return L4D          1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2         1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED

 */

public Action OnPlayerHurt( Event event, const char[] sName, bool bDontBroadcast )
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!g_bValidMap || !client || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_INFECTED || TankHealth[client] == -1)
        return Plugin_Continue;

    if (g_bL4D2Version)
    {
        if (GetZombieClass(client) != 8)
            return Plugin_Continue;
    }
    else
    {
        if (GetZombieClass(client) != 5)
            return Plugin_Continue;
    }

    int nowHP = GetEventInt(event, "health");
    int maxHP = TankHealth[client];

    if (TankHealth[client] == -1)
         return Plugin_Continue;

    int env_sprite = TankSprite[client];

    if (!IsValidEntity(env_sprite))
        return Plugin_Continue;

    if (IsPlayerIncapped(client))
    {
        if (!TankIncapped[client])
        {
            TankIncapped[client] = true;
            DispatchKeyValue(env_sprite, "targetname", "tanksprite");
            if (!IsModelPrecached(SPRITE_DEATH))
                PrecacheModel(SPRITE_DEATH, true);
            DispatchKeyValue(env_sprite, "model", SPRITE_DEATH);
            DispatchKeyValue(env_sprite, "rendercolor", "127 0 0");
            DispatchKeyValue(env_sprite, "renderamt", "240");
            DispatchSpawn(env_sprite);

            if (g_bL4D2Version && EnableGlow)
                L4D2_SetEntityGlow_Flashing(client, true);
        }

        return Plugin_Continue;
    }

    float fCountdownHeat = float(nowHP) / maxHP;

    char sTemp[12];

    bool bHalfHp = false;
    bHalfHp = fCountdownHeat <= 0.5 ? true : false;
    if (AlgorithmType == 1)
        Format(sTemp, sizeof(sTemp), "%i %i 0", bHalfHp ? 255 : RoundFloat(255.0 * ((1.0 - fCountdownHeat) * 2)), bHalfHp ? RoundFloat(255.0 * (fCountdownHeat) * 2) : 255);
    else
        Format(sTemp, sizeof(sTemp), "%i %i 0", RoundFloat(255 * (1 - fCountdownHeat)), RoundFloat(255 * fCountdownHeat));
    DispatchKeyValue(env_sprite, "rendercolor", sTemp);
    DispatchKeyValue(env_sprite, "model", SPRITE_MODEL3);
    DispatchKeyValue(env_sprite, "renderamt", "240");

    if (g_bL4D2Version && EnableGlow)
    {
        if (!TankNow[client])
        {
            L4D2_SetEntityGlow_Type(client, view_as<L4D2GlowType>(3));
            L4D2_SetEntityGlow_MaxRange(client, 0);
            L4D2_SetEntityGlow_MinRange(client, 0);

            int color[3];
            if (AlgorithmType == 1)
            {
                color[0] = bHalfHp ? 255 : RoundFloat(255.0 * ((1.0 - fCountdownHeat) * 2));
                color[1] = bHalfHp ? RoundFloat(255.0 * (fCountdownHeat) * 2) : 255;
                color[2] = 0;
            }
            else if (AlgorithmType == 2)
            {
                color[0] = RoundFloat(255 * (1 - fCountdownHeat));
                color[1] = RoundFloat(255 * fCountdownHeat);
                color[2] = 0;
            }

            L4D2_SetEntityGlow_Color(client, color);
            if (fCountdownHeat <= 0.1)
                L4D2_SetEntityGlow_Flashing(client, true);
        }
    }

    LastUseTime[client] = GetEngineTime();

    return Plugin_Continue;
}





/**
 * Get the specific L4D2 zombie class id from the client.
 *
 * @return L4D          1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2         1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED

 */
int GetZombieClass(int client)
{
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}


int iSwitch = 0;

public void Event_TankSpawn( Event event, const char[] sName, bool bDontBroadcast )
{
    if (!g_bValidMap) return;

    int client =    GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsValidClient(client))
    {
        TankHealth[client] = -1;
        TankNow[client] = false;
        TankIncapped[client] = false;
        CreateTimer(0.1, Timer_TankSprite, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(1.0, Timer_HealthModifierSet, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

        if (g_bL4D2Version && EnableGlow)
        {
            L4D2_SetEntityGlow_Type(client, view_as<L4D2GlowType>(3));
            L4D2_SetEntityGlow_MaxRange(client, 0);
            L4D2_SetEntityGlow_MinRange(client, 0);
            L4D2_SetEntityGlow_Color(client, view_as<int>({0, 255, 0}));
            L4D2_SetEntityGlow_Flashing(client, false);
        }

        iSwitch = iSwitch +1;
        if (iSwitch > 4)
        iSwitch = 1;
        int env_sprite = CreateEntityByName("env_sprite");

        if (!IsValidEntity(env_sprite))
            return;

        // decl String:Buffer[64];
        // Format(Buffer, sizeof(Buffer), "client%i", client);
        // DispatchKeyValue(env_sprite, "targetname", Buffer);

        if (!IsModelPrecached(SPRITE_MODEL3))
            PrecacheModel(SPRITE_MODEL3, true);
        DispatchKeyValue(env_sprite, "model", SPRITE_MODEL3);
        DispatchKeyValue(env_sprite, "rendermode", "1");
        DispatchKeyValue(env_sprite, "rendercolor", "0 255 0");
        DispatchKeyValue(env_sprite, "renderamt", "240");
        DispatchKeyValue(env_sprite, "disablereceiveshadows", "1");
        DispatchKeyValue(env_sprite, "spawnflags", "1");
        DispatchKeyValueFloat(env_sprite, "fademindist", 600.0);
        DispatchKeyValueFloat(env_sprite, "fademaxdist", 600.0);

        DispatchSpawn(env_sprite);
        DispatchKeyValue(env_sprite, "renderamt", "0");

        SetVariantString("!activator");
        AcceptEntityInput(env_sprite, "SetParent", client);

        float vPos[3];
        // vPos[0] = 200.0;
        // vPos[1] = 200.0;
        vPos[2] = 100.0;

        TeleportEntity(env_sprite, vPos, NULL_VECTOR, NULL_VECTOR);

        TankSprite[client] = env_sprite;
    }
}

public Action Timer_HealthModifierSet(Handle timer, int client)
{
    if (IsValidClient(client) && !IsPlayerGhost(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_INFECTED && GetClientHealth(client) > 0 && TankHealth[client] == -1)
    {
       TankHealth[client] = GetClientHealth(client);
       return Plugin_Stop;
    }

    return Plugin_Continue;

}

public Action Timer_TankSprite(Handle timer, int client)
{
    int env_sprite = TankSprite[client];

    if (!IsValidEntity(env_sprite)||!IsValidEdict(env_sprite))
        return Plugin_Stop;

    if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 3)
	{
		if(IsValidEntRef(env_sprite))
			AcceptEntityInput(env_sprite, "Kill");
		return Plugin_Stop;
	}
	
    if (g_bL4D2Version)
    {
        if (GetZombieClass(client) != 8)
		{
			if(IsValidEntRef(env_sprite))
				AcceptEntityInput(env_sprite, "Kill");
			return Plugin_Stop;
		}
    }
    else
    {
        if (GetZombieClass(client) != 5)
		{
			if(IsValidEntRef(env_sprite))
				AcceptEntityInput(env_sprite, "Kill");
			return Plugin_Stop;
		}
    }

    //if (IsPlayerIncapped(client))
	//{
	//	if(IsValidEntRef(env_sprite))
	//		AcceptEntityInput(env_sprite, "Kill");
	//	return Plugin_Stop;
	//}

    if (GetEngineTime()-LastUseTime[client] >= 2.0)
    {
        DispatchKeyValue(env_sprite, "model", SPRITE_MODEL3);
        DispatchKeyValue(env_sprite, "renderamt", "0");
    }



    return Plugin_Continue;
}

bool IsValidClient(int client)
{
    return (1 <= client <= MaxClients && IsClientInGame(client));
}

/**
 * Validates if the client is a ghost.
 *
 * @param client        Client index.
 * @return              True if client is a ghost, false otherwise.
 */
bool IsPlayerGhost(int client)
{
    return GetEntProp(client, Prop_Send, "m_isGhost", 1) == 1;
}

/**
 * Validates if the offset is valid.
 *
 * @param entity    Entity index.
 * @param propName  Property name.
 * @return          True if the offset is valid, false otherwise.
 */
bool IsValidOffset(int entity, char[] propName)
{
    char sNetClass[128];
    GetEntityNetClass(entity, sNetClass, sizeof(sNetClass));

    int iOffset = FindSendPropInfo(sNetClass, propName);

    return iOffset > 0;
}

/**
 * Set entity glow type.
 *
 * @param entity    Entity index.
 * @param type      Glow type.
 * @noreturn
 */
void L4D2_SetEntityGlow_Type(int entity, L4D2GlowType type)
{
    if (!IsValidEntity(entity))
        return;

    if (!IsValidOffset(entity, "m_iGlowType"))
        return;

    SetEntProp(entity, Prop_Send, "m_iGlowType", type);
}

/**
 * Set entity glow max range.
 *
 * @param entity    Entity index.
 * @param maxRange  Glow max range.
 * @noreturn
 */
void L4D2_SetEntityGlow_MaxRange(int entity, int maxRange)
{
    if (!IsValidEntity(entity))
        return;

    if (!IsValidOffset(entity, "m_nGlowRange"))
        return;

    SetEntProp(entity, Prop_Send, "m_nGlowRange", maxRange);
}

/**
 * Set entity glow min range.
 *
 * @param entity    Entity index.
 * @param minRange  Glow min range.
 * @noreturn
 */
void L4D2_SetEntityGlow_MinRange(int entity, int minRange)
{
    if (!IsValidEntity(entity))
        return;

    if (!IsValidOffset(entity, "m_nGlowRangeMin"))
        return;

    SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
}

/**
 * Set entity glow color.
 *
 * @param entity    Entity index.
 * @param color     Glow color, RGB.
 * @noreturn
 */
void L4D2_SetEntityGlow_Color(int entity, int color[3])
{
    if (!IsValidEntity(entity))
        return;

    if (!IsValidOffset(entity, "m_glowColorOverride"))
        return;

    SetEntProp(entity, Prop_Send, "m_glowColorOverride", color[0] + (color[1] * 256) + (color[2] * 65536));
}

/**
 * Set entity glow flashing state.
 *
 * @param entity    Entity index.
 * @param flashing  Whether glow will be flashing.
 * @noreturn
 */
void L4D2_SetEntityGlow_Flashing(int entity, bool flashing)
{
    if (!IsValidEntity(entity))
        return;

    if (!IsValidOffset(entity, "m_bFlashing"))
        return;

    SetEntProp(entity, Prop_Send, "m_bFlashing", flashing);
}

bool IsPlayerIncapped(int client)
{
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE && entity!= -1 )
		return true;
	return false;
}