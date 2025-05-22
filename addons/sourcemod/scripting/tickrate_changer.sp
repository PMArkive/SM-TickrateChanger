#pragma newdecls required
#pragma semicolon 1

#include <dhooks>

// The range check in the engine is wrong
#define MINIMUM_TICK_INTERVAL	(0.0011)
#define MAXIMUM_TICK_INTERVAL	(0.0999)

ConVar sm_tickrate;

Address sv;	// CBaseServer
int m_flTickInterval;	// sv -> CBaseServer::m_flTickInterval

// Tick interval to update in engine
float g_flTickInterval = -1.0;

public Plugin myinfo =
{
	name = "Runtime Tickrate Changer",
	author = "Mikusch, ficool2",
	description = "Allows changing the server's tickrate at runtime.",
	version = "1.0.2",
	url = "https://github.com/Mikusch/SM-TickrateChanger"
}

public void OnPluginStart()
{
	GameData gamedata = new GameData("tickrate_changer");
	if (!gamedata)
		ThrowError("Failed to find gamedata/tickrate_changer.txt");
	
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, "CServerGameDLL::GetTickInterval");
	if (detour == null)
		ThrowError("Failed to setup 'CServerGameDLL::GetTickInterval' detour");
	
	detour.Enable(Hook_Pre, CServerGameDLL_GetTickInterval);
	
	detour = DynamicDetour.FromConf(gamedata, "SV_ActivateServer");
	if (detour == null)
		ThrowError("Failed to setup 'SV_ActivateServer' detour");
	
	detour.Enable(Hook_Pre, SV_ActivateServer);
	
	sm_tickrate = CreateConVar("sm_tickrate", "-1", "Tickrate of the server, requires a level change to take effect. Set to -1 to use the default tickrate.");
	
	sv =  gamedata.GetMemSig("sv");
	if (sv == Address_Null)
		ThrowError("Failed to find 'sv' signature");
	
	m_flTickInterval = gamedata.GetOffset("CBaseServer::m_flTickInterval");
	if (m_flTickInterval == -1)
		ThrowError("Failed to find 'CBaseServer::m_flTickInterval' offset");
	
	delete gamedata;
	
	// To set tickrate on server start, before any configs can run
	float tickrate = GetCommandLineParamFloat("-tickrate");
	if (tickrate)
	{
		sm_tickrate.FloatValue = tickrate;
		g_flTickInterval = GetDesiredTickInterval();
	}
	
	RegPluginLibrary("tickrate_changer");
}

float GetDesiredTickInterval()
{
	float tickrate = sm_tickrate.FloatValue;
	if (tickrate == -1.0)
		return tickrate;
	
	return Clamp(1.0 / tickrate, MINIMUM_TICK_INTERVAL, MAXIMUM_TICK_INTERVAL);
}

stock any Min(any a, any b)
{
	return (a <= b) ? a : b;
}

stock any Max(any a, any b)
{
	return (a >= b) ? a : b;
}

stock any Clamp(any val, any min, any max)
{
	return Min(Max(val, min), max);
}

static MRESReturn CServerGameDLL_GetTickInterval(DHookReturn ret)
{
	if (g_flTickInterval == -1.0)
		return MRES_Ignored;
	
	// Need to update CBaseServer::m_flTickInterval to avoid mismatch
	StoreToAddress(sv + view_as<Address>(m_flTickInterval), g_flTickInterval, NumberType_Int32);
	
	ret.Value = g_flTickInterval;
	return MRES_Supercede;
}

static MRESReturn SV_ActivateServer(DHookReturn ret)
{
	g_flTickInterval = GetDesiredTickInterval();
	return MRES_Ignored;
}
