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
    list tokens = llParseString2List(llGetObjectDesc(), [sep], []);
    return [llList2String(tokens, 0), llList2String(tokens, 1), llList2String(tokens, 1)];
}
