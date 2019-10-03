// CONSTS
integer DEBUG = TRUE;
string  SIGNATURE = "falcon-control";
integer CHANNEL = -130104;
integer NOT_FOUND = -1; // ll* functions often return -1 to indicate 'not found'

float PAIRING_TIME = 3.0;
float SETUP_TIME = 6.0;

integer SHAFTS_MAX = 4;
integer FLOORS_MAX = 16;

// description identifiers
// 0: bank, 1: shaft, 2: floor
list identifiers;
string description;

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
key uuid = NULL_KEY;
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
 * Parses the object's description string into a list of 3 elements, using `sep` 
 * as the separator to split the string into tokens. See these examples:
 * - parse_desc("bank1:cab1:7", ":") => ["bank1", "cab1", "7"]
 * - parse_desc("bank1", ":")        => ["bank1", "", ""]
 * - parse_desc("bank1::4, ":")      => ["bank1", "", "4"]
 * - parse_desc("", ":")             => ["", "", ""]
 */
list parse_desc(string sep)
{
    list tks = llParseString2List(llGetObjectDesc(), [sep], []);
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
    string  signature  = llList2String(tokens, 0);   
    string  command    = llList2String(tokens, 1);
    list    parameters = llList2List(tokens, 2, num_tokens - 1);
    
    if (command == "pong")
    {
        handle_cmd_pong(signature, id, parameters);
        return;
    }
    
    if (command == "status")
    {
        handle_cmd_status(signature, id, parameters);
    }
}

handle_cmd_pong(string sig, key id, list params)
{
    // Currently nothing
    debug("Received PONG from " + sig + " (" + (string) params + ")");
}

handle_cmd_status(string sig, key id, list params)
{
    if (sig == "falcon-cab")
    {
        cabs = add_component(cabs, id, llList2String(params, 0));
        return;
    }
    if (sig == "falcon-doorway")
    {
        doorways = add_component(doorways, id, llList2String(params, 0));
        return;
    }
    if (sig == "falcon-buttons")
    {
        buttons = add_component(buttons, id, llList2String(params, 0));
        return;
    }
}

/*
 * Send a message to the object with UUID `id`.
 */ 
send_message(key id, string cmd, list params)
{
    string msg = SIGNATURE + " " + cmd + " " + llDumpList2String(params, "");
    llRegionSayTo(id, CHANNEL, msg);
}

/*
 * Broadcast a message to all objects in the region.
 */
send_broadcast(string cmd, list params)
{
    string msg = SIGNATURE + " " + cmd + " " + llDumpList2String(params, "");
    llRegionSay(CHANNEL, msg);
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
    // TODO: this needs to check if there are at least two doors for EACH cab,
    //       not just how many cabs/doorways there are in general...
    
    doorways = llListSort(doorways, 2, TRUE); // Sort doorways
    
    if (llGetListLength(cabs) < 1)
    {
        return FALSE;
    } 
    if (llGetListLength(doorways) < 2)
    {
        return FALSE;
    }
    return TRUE;
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
    description = llGetObjectDesc();
    identifiers = parse_desc(":");
    
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
        send_broadcast("pair", [llList2String(identifiers, 0)]);
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
