// CONSTS
integer DEBUG = TRUE;
integer CHANNEL = -130104;
string  SIGNATURE = "falcon-control";

string SIGNATURE_CAB     = "falcon-cab";
string SIGNATURE_DOORWAY = "falcon-doorway";
string SIGNAUTRE_BUTTONS = "falcon-buttons";

integer NOT_FOUND = -1; // ll* functions often return -1 to indicate 'not found'
float   FLOAT_MAX = 3.402823466E+38;

float PAIRING_TIME = 3.0;
float SETUP_TIME   = 6.0;

integer SHAFTS_MAX = 4;
integer FLOORS_MAX = 16;

integer MSG_IDX_SIG    = 0;
integer MSG_IDX_IDENT  = 1;
integer MSG_IDX_CMD    = 2;
integer MSG_IDX_PARAMS = 3;

integer IDENT_IDX_BANK  = 0;
integer IDENT_IDX_SHAFT = 1;
integer IDENT_IDX_FLOOR = 2;

// description identifiers
// 0: bank, 1: shaft, 2: floor
list   identifiers;

// list of all `cab` objects
// [string ident, key cab_key, ...]
list    cabs;
integer cabs_stride = 2;

// list of all `doorway` object
// [string ident, key doorways_key, ...]
list    doorways;
integer doorways_stride = 2;

// list of all `call_buttons` objects
// [string desc, key buttons_key, ...]
list    buttons;
integer buttons_stride = 2;

// important objects/ids
key uuid  = NULL_KEY;
key owner = NULL_KEY;

// state etc
integer listen_handle;
string current_state;

/*
 * Debug output `msg` via llOwnerSay if the global variable DEBUG is TRUE
 */
debug(string msg)
{
    if (DEBUG)
    {
        llOwnerSay(llGetScriptName() + "@" + llGetObjectName() + ": " + msg);
    }
}

/*
 * Parses an identifier string into a list of 3 elements, using `sep` 
 * as the separator to split the string into tokens. See these examples:
 * - parse_ident("bank1:shaft1:7", ":") => ["bank1", "shaft1", "7"]
 * - parse_ident("bank1", ":")          => ["bank1", "", ""]
 * - parse_ident("bank1::4, ":")        => ["bank1", "", "4"]
 * - parse_ident("", ":")               => ["", "", ""]
 */
list parse_ident(string ident, string sep)
{
    list tks = llParseString2List(ident, [sep], []);
    return [llList2String(tks, 0), llList2String(tks, 1), llList2String(tks, 2)];
}

process_message(integer chan, string name, key id, string msg)
{
    // Debug print the received message
    debug(" < `" + msg + "`");
    
    // Get details about the sender
    list details = llGetObjectDetails(id, ([OBJECT_NAME, OBJECT_DESC, 
                                            OBJECT_POS, OBJECT_ROT, OBJECT_OWNER]));
   
    // Abort if the message came from someone else's object
    if (owner != llList2Key(details, 4))
    {
        return;
    }

    // Split the message on spaces and extract the first two tokens
    list    tokens     = llParseString2List(msg, [" "], []);
    integer num_tokens = llGetListLength(tokens);
    string  signature  = llList2String(tokens, MSG_IDX_SIG);
    string  ident      = llList2String(tokens, MSG_IDX_IDENT);
    string  command    = llList2String(tokens, MSG_IDX_CMD);
    list    params     = llList2List(tokens, MSG_IDX_PARAMS, num_tokens - 1);
    
    if (command == "pong")
    {
        handle_cmd_pong(signature, id, ident);
        return;
    }
    
    if (command == "status")
    {
        handle_cmd_status(signature, id, ident, params);
    }
}

handle_cmd_pong(string sig, key id, string ident)
{
    // Currently nothing
    debug("Received PONG from " + sig + " (" + ident + ")");
}

handle_cmd_status(string sig, key id, string ident, list params)
{
    if (sig == "falcon-cab")
    {
        cabs = add_component(cabs, id, ident);
        return;
    }
    if (sig == "falcon-doorway")
    {
        doorways = add_component(doorways, id, ident);
        return;
    }
    if (sig == "falcon-buttons")
    {
        buttons = add_component(buttons, id, ident);
        return;
    }
}

/*
 * Send a message to the object with UUID `id`.
 * Note: this function depends on the globals `SIGNATURE`, `CHANNEL`
 *       and `identifiers`.
 */ 
send_message(key id, string cmd, list params)
{
    list msg = [SIGNATURE, llDumpList2String(identifiers, ":"),
                cmd,  llDumpList2String(params, " ")];
    llRegionSayTo(id, CHANNEL, llDumpList2String(msg, " "));
}

/*
 * Broadcast a message to all objects in the region.
 * Note: this function depends on the globals `SIGNATURE`, `CHANNEL`
 *       and `identifiers`.
 */
send_broadcast(string cmd, list params)
{
    list msg = [SIGNATURE, llDumpList2String(identifiers, ":"),
                cmd,  llDumpList2String(params, " ")];
    llRegionSay(CHANNEL, llDumpList2String(msg, " "));
}

/*
 * Adds the elevator cab with UUID `id` and identifier string `ident` 
 * to the list of cabs, unless `id` is already in the list.
 */
add_cab(key id, string ident)
{
    cabs = add_component(cabs, id, ident);
}

list add_component(list comps, key id, string ident)
{
    if (llListFindList(comps, (list) id) == NOT_FOUND)
    {
        comps += [ident, id];
    }
    return comps;
}

integer all_components_in_place()
{
    // Sort the doorways (by ident-string, which means by floor)
    doorways = llListSort(doorways, doorways_stride, TRUE);
    
    // Get number of cabs in our list
    integer num_cabs = llGetListLength(cabs) / cabs_stride;
    
    // Abort if we don't know of any cabs
    if (num_cabs == 0)
    {
        return FALSE;
    }
    
    // Go through all cabs and see if there are at least 2 doorways
    integer i;
    for (i = 0; i < num_cabs; ++i)
    {
        string ident = llList2String(cabs, i * cabs_stride);
        list tokens = parse_ident(ident, ":");
        string shaft = llList2String(tokens, IDENT_IDX_SHAFT);
        integer num_doorways = num_doorways_per_shaft(shaft);
        if (num_doorways < 2)
        {
            return FALSE;
        }
    }
    
    return TRUE;
}

integer num_doorways_per_shaft(string shaft)
{
    integer num_doorways = llGetListLength(doorways) / doorways_stride;
    integer num_doorways_per_shaft = 0;
    
    integer i;
    for (i = 0; i < num_doorways; ++i)
    {
        string ident = llList2String(doorways, i * doorways_stride);
        list   tokens = parse_ident(ident, ":");
        
        if (llList2String(tokens, IDENT_IDX_SHAFT) == shaft)
        {
            ++num_doorways_per_shaft;
        }
    }
    
    return num_doorways_per_shaft;
}

integer all_components_setup()
{
    // TODO
    return FALSE;
}

integer init()
{
    uuid = llGetKey();
    owner = llGetOwner();
    identifiers = parse_ident(llGetObjectDesc(), ":");
    
    return TRUE;
}

default
{
    state_entry()
    {
        current_state = "default";
        init();
    }

    touch_start(integer total_number)
    {
        state pairing; 
    }

    state_exit()
    {
        // Nothing (yet)
    }
}

/*
 * Broadcasting a pairing request to all objects in in the region, then waiting
 * for a reply from suitable components (same owner, same elevator bank).
 */
state pairing
{
    state_entry()
    {
        current_state = "pairing";
        
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
        
        debug("Started pairing process...");
        send_broadcast("pair", []);
        llSetTimerEvent(PAIRING_TIME);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    timer()
    {        
        llSetTimerEvent(0.0);
        if (all_components_in_place())
        {
            llOwnerSay("Pairing done. Everything is in place.");
            state setup; 
        }
        else
        {
            llOwnerSay("Pairing done. Some components are missing.");
            state default;
        }
    }
    
    state_exit()
    {
        // Nothing (yet)
    }
}

state setup
{
    state_entry()
    {
        current_state = "setup";
        
        debug("Started setup process...");
        // TODO parse configuration notecard
        // TODO figure out which doorway is 'base' doorway
        // TODO get 'base' doorways position/rotation
        // TODO send 'setup' message to all components
        llSetTimerEvent(SETUP_TIME);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    timer()
    {        
        llSetTimerEvent(0.0);
        if (all_components_setup())
        {
            llOwnerSay("Setup done. All systems ready.");
            state ready; 
        }
        else
        {
            llOwnerSay("Setup failed.");
            state default;
        }
    }
    
    state_exit()
    {
        // Nothing yet
    }
}

state ready
{
    state_entry()
    {
        current_state = "ready";
        
        debug("System is in operation...");
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    state_exit()
    {
        // Nothing yet
    }
}
