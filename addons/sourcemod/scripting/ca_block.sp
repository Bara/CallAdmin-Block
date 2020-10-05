#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <calladmin>
#include <multicolors>
#include <autoexecconfig>

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

bool g_bBlocked[MAXPLAYERS + 1] =  { false, ... };

ConVar g_cTag = null;
ConVar g_cDebug = null;
ConVar g_cDatabase = null;

Database g_dDB = null;


public Plugin myinfo = 
{
    name = "CallAdmin Block",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("CABlock_IsClientBlocked", Native_IsClientBlocked);

    RegPluginLibrary("cablock");

    return APLRes_Success;
}

public int Native_IsClientBlocked(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return g_bBlocked[client];
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");

    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.cablock");
    g_cDebug = AutoExecConfig_CreateConVar("cablock_debug", "0", "Enable debug mode to log all queries", _, true, 0.0, true, 1.0);
    g_cTag = AutoExecConfig_CreateConVar("cablock_plugin_tag", "{darkblue}[CA-Block]{default}", "Chat Tag for every message from this plugin");
    g_cDatabase = AutoExecConfig_CreateConVar("cablock_database", "cablock", "Which database should be used? This name must exist in your databases.cfg!");
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    RegAdminCmd("sm_cablock", Command_CABlock, ADMFLAG_GENERIC);
    RegAdminCmd("sm_caunblock", Command_CAUnBlock, ADMFLAG_GENERIC);
    RegAdminCmd("sm_cablockoff", Command_CABlockOff, ADMFLAG_GENERIC);
    RegAdminCmd("sm_caunblockoff", Command_CAUnBlockOff, ADMFLAG_GENERIC);
}

public void OnConfigsExecuted()
{
    char sBuffer[128];
    g_cTag.GetString(sBuffer, sizeof(sBuffer));
    CSetPrefix(sBuffer);

    if (g_dDB != null)
    {
        delete g_dDB;
    }

    connectSQL();
}

public void OnClientPostAdminCheck(int client)
{
    if(IsClientValid(client))
    {
        CheckClient(client);
    }
}

public void OnClientDisconnect(int client)
{
    g_bBlocked[client] = false;
}

stock void CheckClient(int client)
{
    char sSteamID[32];
    if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
    {
        LogError("Auth failed for client index %d", client);
        return;
    }
    
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT blocked FROM cablock WHERE steamid = \"%s\" ORDER BY id DESC LIMIT 1;", sSteamID);
    
    if (g_cDebug.BoolValue)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(SQL_CheckClient, sQuery, GetClientUserId(client));
}

public Action CallAdmin_OnReportPre(int client, int target, const char[] reason)
{
    if (g_bBlocked[client])
    {
        CPrintToChat(client, "You have been blocked from using CallAdmin!");
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Command_CABlock(int client, int args)
{
    if (args != 1)
    {
        CReplyToCommand(client, "sm_cablock <#UserID/Name>");
        CReplyToCommand(client, "Alternative: sm_cablockoff <SteamID (example: STEAM_1:X:XXXXXX>");
        return Plugin_Handled;
    }

    char sArg1[MAX_NAME_LENGTH];
    GetCmdArg(1, sArg1, sizeof(sArg1));
    int target = FindTarget(client, sArg1, true, true);

    if (!IsClientValid(target))
    {
        CReplyToCommand(client, "Target is invalid");
        return Plugin_Handled;
    }

    if (g_bBlocked[client])
    {
        CReplyToCommand(client, "Target is already blocked!");
        return Plugin_Handled;
    }
    else
    {
        char sQuery[512], sName[MAX_NAME_LENGTH], sAdmin[MAX_NAME_LENGTH], sID[32], sAID[32];
        
        GetClientAuthId(target, AuthId_Steam2, sID, sizeof(sID));
        GetClientName(target, sName, sizeof(sName));

        if (IsClientValid(client))
        {
            GetClientAuthId(client, AuthId_Steam2, sAID, sizeof(sAID));
            GetClientName(client, sAdmin, sizeof(sAdmin));
        }
        else
        {
            Format(sAID, sizeof(sAID), "0");
            Format(sAdmin, sizeof(sAdmin), "CONSOLE");
        }

        g_dDB.Format(sQuery, sizeof(sQuery), "INSERT INTO `cablock` (`time`, `action`, `steamid`, `name`, `admin`, `adminName`, `blocked`) VALUES (UNIX_TIMESTAMP(), \"block\", \"%s\", \"%s\", \"%s\", \"%s\", '1');", sID, sName, sAID, sAdmin);
        
        if (g_cDebug.BoolValue)
        {
            LogMessage(sQuery);
        }
        
        g_dDB.Query(SQL_InsertBlock, sQuery, GetClientUserId(target));

        CPrintToChatAll("{green}%N {default}is now blocked for the calladmin usage!", target);
    }

    return Plugin_Handled;
}

public Action Command_CAUnBlock(int client, int args)
{
    if (args != 1)
    {
        CReplyToCommand(client, "sm_caunblock <#UserID/Name>");
        CReplyToCommand(client, "Alternative: sm_caunblockoff <SteamID (example: STEAM_1:X:XXXXXX>");
        return Plugin_Handled;
    }

    char sArg1[MAX_NAME_LENGTH];
    GetCmdArg(1, sArg1, sizeof(sArg1));
    int target = FindTarget(client, sArg1, true, true);

    if (!IsClientValid(target))
    {
        CReplyToCommand(client, "Target is invalid");
        return Plugin_Handled;
    }

    if (!g_bBlocked[client])
    {
        CReplyToCommand(client, "Target isn't blocked!");
        return Plugin_Handled;
    }
    else
    {
        char sQuery[512], sName[MAX_NAME_LENGTH], sAdmin[MAX_NAME_LENGTH], sID[32], sAID[32];
        
        GetClientAuthId(target, AuthId_Steam2, sID, sizeof(sID));
        GetClientName(target, sName, sizeof(sName));

        if (IsClientValid(client))
        {
            GetClientAuthId(client, AuthId_Steam2, sAID, sizeof(sAID));
            GetClientName(client, sAdmin, sizeof(sAdmin));
        }
        else
        {
            Format(sAID, sizeof(sAID), "0");
            Format(sAdmin, sizeof(sAdmin), "CONSOLE");
        }

        g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE `cablock` SET `time` = UNIX_TIMESTAMP(), `action` = \"unblock\", `name` = \"%s\", `admin` = \"%s\", `adminName` = \"%s\", `blocked` = '0' WHERE steamid = \"%s\" ORDER BY id DESC LIMIT 1;", sName, sAID, sAdmin, sID);

        if (g_cDebug.BoolValue)
        {
            LogMessage(sQuery);
        }

        g_dDB.Query(SQL_UpdateBlock, sQuery, GetClientUserId(target));

        CPrintToChatAll("{green}%N {default}is now blocked for the calladmin usage!", target);
    }

    return Plugin_Handled;
}

public Action Command_CABlockOff(int client, int args)
{
    if (args != 1)
    {
        CReplyToCommand(client, "sm_cablockoff <SteamID (example: STEAM_1:X:XXXXXX>");
        CReplyToCommand(client, "Alternative: sm_cablock <#UserID/Name>");
        return Plugin_Handled;
    }

    char sID[MAX_NAME_LENGTH];
    GetCmdArg(1, sID, sizeof(sID));

    if (StrContains(sID, "STEAM_1", false) == -1)
    {
        CReplyToCommand(client, "Invalid steamid, must start with 'STEAM_1'");
        return Plugin_Handled;
    }

    char sQuery[512], sName[MAX_NAME_LENGTH], sAdmin[MAX_NAME_LENGTH], sAID[32];
    
    Format(sName, sizeof(sName), "Offline Block");

    if (IsClientValid(client))
    {
        GetClientAuthId(client, AuthId_Steam2, sAID, sizeof(sAID));
        GetClientName(client, sAdmin, sizeof(sAdmin));
    }
    else
    {
        Format(sAID, sizeof(sAID), "0");
        Format(sAdmin, sizeof(sAdmin), "CONSOLE");
    }

    g_dDB.Format(sQuery, sizeof(sQuery), "INSERT INTO `cablock` (`time`, `action`, `steamid`, `name`, `admin`, `adminName`, `blocked`) VALUES (UNIX_TIMESTAMP(), \"block\", \"%s\", \"%s\", \"%s\", \"%s\", '1');", sID, sName, sAID, sAdmin);
    
    if (g_cDebug.BoolValue)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(SQL_InsertBlockOff, sQuery);

    CPrintToChatAll("Added {green}%s {default}to the block database!", sID);

    return Plugin_Handled;
}

public Action Command_CAUnBlockOff(int client, int args)
{
    if (args != 1)
    {
        CReplyToCommand(client, "sm_caunblockoff <SteamID (example: STEAM_1:X:XXXXXX>");
        CReplyToCommand(client, "Alternative: sm_caunblock <#UserID/Name>");
        return Plugin_Handled;
    }

    char sID[MAX_NAME_LENGTH];
    GetCmdArg(1, sID, sizeof(sID));

    if (StrContains(sID, "STEAM_1", false) == -1)
    {
        CReplyToCommand(client, "Invalid steamid, must start with 'STEAM_1'");
        return Plugin_Handled;
    }

    char sQuery[512], sName[MAX_NAME_LENGTH], sAdmin[MAX_NAME_LENGTH], sAID[32];
    
    Format(sName, sizeof(sName), "Offline Unblock");

    if (IsClientValid(client))
    {
        GetClientAuthId(client, AuthId_Steam2, sAID, sizeof(sAID));
        GetClientName(client, sAdmin, sizeof(sAdmin));
    }
    else
    {
        Format(sAID, sizeof(sAID), "0");
        Format(sAdmin, sizeof(sAdmin), "CONSOLE");
    }

    g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE `cablock` SET `time` = UNIX_TIMESTAMP(), `action` = \"unblock\", `name` = \"%s\", `admin` = \"%s\", `adminName` = \"%s\", `blocked` = '0' WHERE steamid = \"%s\" ORDER BY id DESC LIMIT 1;", sName, sAID, sAdmin, sID);
    
    if (g_cDebug.BoolValue)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(SQL_UpdateBlockOff, sQuery);

    CPrintToChatAll("{green}%s {default}was removed from the block database!", sID);

    return Plugin_Handled;
}

stock bool IsClientValid(int client, bool bots = false)
{
    if (client > 0 && client <= MaxClients)
    {
        if(IsClientInGame(client) && (bots || !IsFakeClient(client)) && !IsClientSourceTV(client))
        {
            return true;
        }
    }
    
    return false;
}

void connectSQL()
{
    char sDatabase[64];
    g_cDatabase.GetString(sDatabase, sizeof(sDatabase));

    if (SQL_CheckConfig(sDatabase))
    {
        Database.Connect(OnSQLConnect, sDatabase);
    }
    else
    {
        SetFailState("Can't find an entry in your databases.cfg with the name \"%s\"", sDatabase);
        return;
    }
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
    if (db == null)
    {
        SetFailState("(OnSQLConnect) Can't connect to mysql");
        return;
    }
    
    g_dDB = db;
    CreateTable();
}

void CreateTable()
{
    char sQuery[1024];
    Format(sQuery, sizeof(sQuery),
    "CREATE TABLE IF NOT EXISTS `cablock` ( \
        `id` INT NOT NULL AUTO_INCREMENT, \
        `time` int(12) NOT NULL, \
        `action` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `steamid` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `name` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `admin` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `adminName` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `blocked` tinyint NOT NULL, \
        PRIMARY KEY (`id`) \
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
    
    if (g_cDebug.BoolValue)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(SQL_CreateTable, sQuery);
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_CreateTable) Fail at Query: %s", error);
        return;
    }
    else
    {
        LoopClients(i)
        {
            CheckClient(i);
        }
    }
}

public void SQL_CheckClient(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_CheckClient) Fail at Query: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);

        if (IsClientValid(client))
        {
            if (results.RowCount > 0 && results.FetchRow())
            {
                g_bBlocked[client] = view_as<bool>(results.FetchInt(0));
            }
        }
    }
}

public void SQL_InsertBlock(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_InsertBlock) Fail at Query: %s", error);
        return;
    }
    else
    {
        int target = GetClientOfUserId(userid);

        if (IsClientValid(target))
        {
            g_bBlocked[target] = true;
        }
    }
}

public void SQL_InsertBlockOff(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_InsertBlockOff) Fail at Query: %s", error);
        return;
    }
}

public void SQL_UpdateBlock(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_UpdateBlock) Fail at Query: %s", error);
        return;
    }
    else
    {
        int target = GetClientOfUserId(userid);

        if (IsClientValid(target))
        {
            g_bBlocked[target] = false;
        }
    }
}

public void SQL_UpdateBlockOff(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_UpdateBlockOff) Fail at Query: %s", error);
        return;
    }
}
