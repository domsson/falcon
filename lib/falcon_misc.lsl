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
