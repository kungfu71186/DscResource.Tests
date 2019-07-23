# culture="en-US"
ConvertFrom-StringData @'
    VerboseParsingFunctions  = Attempting to parse the specified functions: [{0}].
    VerboseParsingParameters = Attempting to parse the parameters for each function: [{0}].
    VerboseFindParameters    = Attempting to parse the parameters for the '{0}' function.
    DidNotFindAnyFunctions   = Could not find the any of the functions specified [{0}] in the resource '{1}'.
    DidNotFindFunction       = Could not find the following functions: [{0}], but will continue with the ones that were found: [{1}]
    NoParametersFound        = Could not find any parameters for the function '{0}'.
    GetModuleInfo            = Retreiving module information for: '{0}'.
    ErrorGetModuleInfo       = Unable to module information for the resource: '{0}'.
    ErrorParseAST            = There were errors when attempting to parse the module file '{0}' | {1}.
'@
