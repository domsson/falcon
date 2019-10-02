// CONSTS
integer DEBUG = TRUE;
string  SIGNATURE = "falcon-control";
integer CHANNEL = -130104;
integer NOT_FOUND = -1; // ll* functions often return -1 to indicate 'not found'

float PING_TIME = 3.0;

integer listen_handle;

// description identifiers
// 0: bank, 1: shaft, 2: floor
list identifiers;

// list of all `cab` objects
// [key cab_key, string desc ...]
list    cabs;
integer cabs_stride = 2;

// list of all `doorway` object
// [key doorways_key, string desc ...]
list    doorways;
integer doorways_stride = 2;

// list of all `call_buttons` objects
// [key buttons_key, string desc ...]
list    buttons;
integer buttons_stride = 2;

key owner;

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
        handle_cmd_pong(signature, id, llList2String(details, 1));
        return;
    }
}

handle_cmd_pong(string sig, key id, string desc)
{
    if (sig == "falcon-cab")
    {
        cabs = add_component(cabs, id, desc);
        return;
    }
    if (sig == "falcon-doorway")
    {
        doorways = add_component(doorways, id, desc);
        return;
    }
    if (sig == "falcon-buttons")
    {
        buttons = add_component(buttons, id, desc);
        return;
    }
}

/*
 * Send a message to the object with UUID `id`.
 */ 
send_message(key id, string cmd, string params)
{
    string msg = SIGNATURE + " " + cmd + " " + params;
    llRegionSayTo(id, CHANNEL, msg);
}

/*
 * Broadcast a message to all objects in the region.
 */
send_broadcast(string cmd, string params)
{
    string msg = SIGNATURE + " " + cmd + " " + params;
    llRegionSay(CHANNEL, msg);
}

/*
 * Adds the elevator cab with UUID `id` and name `name` 
 * to the list of cabs, unless `id` is already in the list.
 */
add_cab(key id, string desc)
{
    cabs = add_component(cabs, id, desc);
}

list add_component(list comps, key id, string desc)
{
    if (llListFindList(comps, (list) id) == NOT_FOUND)
    {
        comps += [id, desc];
    }
    return comps;
}

integer all_components_in_place()
{
    // TODO: this needs to check if there are at least two doors for EACH cab,
    //       not just how many cabs/doorways there are in general...
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

integer init()
{
    owner = llGetOwner();
    identifiers = parse_desc(":");
    
    return TRUE;
}

default
{
    state_entry()
    {
        init();
    }

    touch_start(integer total_number)
    {
       state pinging; 
    }

    state_exit()
    {
        // Nothing (yet)
    }
}

/*
 * Broadcasting a ping to all objects in a quest to find all relevant elevator 
 * system components that belong to the same owner and operate in the same bank.
 */
state pinging
{
    state_entry()
    {
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
        send_broadcast("ping", llList2String(identifiers, 0));
        llSetTimerEvent(PING_TIME);
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
            llOwnerSay("Time's up and everything is in place, let's move on!");   
        }
        else
        {
            llOwnerSay("Time's up but not all components are in place. Aborting.");
        }
    }
    
    state_exit()
    {
        // Nothing (yet)
    }
}
