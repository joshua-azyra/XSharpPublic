
/// <summary>List of error codes used in the XSharp VTP support. <br />
/// Each error code represents a translatable string in the string table inside XSharp.Core.
/// </summary>


DELEGATE VFPErrorMessage( resid AS DWORD , args PARAMS OBJECT[]) AS STRING
GLOBAL oVFPErrorMessage AS VFPErrorMessage

ENUM XSharp.VFPErrors
    // Make sure that the member names do not collide with the member names inside the VOErrors Enum
    MEMBER XS_VFP_BASE   := 1
    MEMBER INVALID_DATE
    MEMBER INVALID_MONTH
    MEMBER INVALID_FORMAT
    MEMBER INVALID_DB_OBJECT
    MEMBER INVALID_DB_PROPERTY_NAME
    MEMBER INVALID_FIELD_SPEC
    MEMBER INVALID_FIELDNAME
    MEMBER STATEMENT_HANDLE_INVALID
    MEMBER STATEMENT_HANDLE_NOTSHARED
    MEMBER COMMAND_PARAMETER_REQUIRED
    MEMBER SQLCOLUMNS_CTYPE
    MEMBER PROPERTY_UNKNOWN
    MEMBER INVALID_RANGE
    MEMBER WITH_STACK_EMPTY
    MEMBER VARIABLE_NOT_ARRAY
    MEMBER VARIABLE_DOES_NOT_EXIST
    MEMBER ONE_DIM_NO_COLUMNS
    MEMBER ATTRIBUTE_OUT_OF_RANGE
    MEMBER PROPERTY_NOT_FOUND
    MEMBER MULTI_DIM_EXPECTED
    MEMBER SUBARRAY_TOO_SMALL
    MEMBER COLLATION_NOT_FOUND

END ENUM
