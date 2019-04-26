function i=whichstr(str,list)
% Finds the indices where str occurs in list, where list is a cell vector of strings.
% Returns empty is the string is not in the list.
i=find(strcmp(str,list));

end
