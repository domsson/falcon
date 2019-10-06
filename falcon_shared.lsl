// Functions that will be used in several of the falcon scripts

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
    
    // TODO: component-specific code goes here
}

/*
 * Given the strided list `l` (with a stide of `s`), this function attempts 
 * to find the string member `m`, which is at stride offset `o`, then returns 
 * the index (at the beginning of the stride) of the element containing it.
 * If the member couldn't be found, NOT_FOUND (-1) is returned.
 */
integer get_strided_index_by_member(list l, integer s, integer o, string m)
{
    integer num_items = get_strided_length(l, s);
    integer i;
    
    for (i = 0; i < num_items; ++i)
    {
        string member = llList2String(l, i * s + o);
        if (member == m)
        {
            return i;
        }
    }
    return NOT_FOUND;
}
