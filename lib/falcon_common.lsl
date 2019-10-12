/*
 * Debug output `msg` via llOwnerSay if the global variable DEBUG is TRUE
 */
debug(string msg)
{
    if (DEBUG)
    {
        llOwnerSay(msg);
    }
}

print_state_info()
{
     debug("State: " + current_state + " (" + (string) llGetUsedMemory() + ")");
}

/*
 * Rounds the given float to the given number of digits in the fractional part.
 */
float round(float val, integer digits)
{
    float factor = llPow(10, digits);
    return llRound(val * factor) / factor;
}

/*
 * Get the length of the strided list `l`, given it's stride length `s`.
 */
integer get_strided_length(list l, integer s)
{
    return llGetListLength(l) / s;
}

/*
 * Parses an identifier string into a list of 3 elements, using `sep` 
 * as the separator to split the string into tokens. An empty string 
 * will yield a list with three empty string elements.
 */
list parse_ident(string ident, string sep)
{
    list tks = llParseString2List(ident, [sep], []);
    return [llList2String(tks,0), llList2String(tks,1), llList2String(tks,2)];
}

/*
 * Returns this component's ident string, which should originally have come 
 * from its description field.
 */
string get_ident()
{
    // This is all this does at the moment, yes. But wait, don't delete this
    // function yet! The point is that we might implement some more advanced
    // logic here in the future. Caching the description string, for example.
    return llGetObjectDesc();
}

/*
 * Send a message to the object with UUID `id`.
 * Note: this function depends on the globals `SIGNATURE` and `CHANNEL`.
 */ 
send_message(key id, string cmd, list params)
{
    list msg = [SIGNATURE, get_ident(),
                cmd, llDumpList2String(params, " ")];
    llRegionSayTo(id, CHANNEL, llDumpList2String(msg, " "));
}

/*
 * Broadcast a message to all objects in the region.
 * Note: this function depends on the globals `SIGNATURE` and `CHANNEL`.
 */
send_broadcast(string cmd, list params)
{
    list msg = [SIGNATURE, get_ident(),
                cmd, llDumpList2String(params, " ")];
    llRegionSay(CHANNEL, llDumpList2String(msg, " "));
}
