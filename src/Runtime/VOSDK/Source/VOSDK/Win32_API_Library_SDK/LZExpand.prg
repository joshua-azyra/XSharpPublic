_DLL FUNC LZStart() AS INT PASCAL:LZ32.LZStart


_DLL FUNC LZDone() AS VOID PASCAL:LZ32.LZDone


_DLL FUNC CopyLZFile(hfRsc AS INT, fhDest AS INT) AS LONG PASCAL:LZ32.CopyLZFile

_DLL FUNC LZCopy(hfRsc AS INT, fhDest AS INT) AS LONG PASCAL:LZ32.LZCopy


_DLL FUNC GetExpandedName(lpszSource AS PSZ, lpszBuffer AS PSZ);
	AS INT PASCAL:LZ32.GetExpandedNameA


_DLL FUNC LZOpenFile(lpFileName AS PSZ, lpReopenBuf AS _winOFSTRUCT, wStyle AS WORD);
	AS INT PASCAL:LZ32.LZOpenFileA


_DLL FUNC LZSeek(hFile AS INT, iOffset AS LONG, iOrigin AS INT);
	AS LONG PASCAL:LZ32.LZSeek



_DLL FUNC LZRead(hFile AS INT, lpBuffer AS PSZ, cbRead AS INT);
	AS INT PASCAL:LZ32.LZRead

_DLL FUNC LZClose(hFile AS INT) AS VOID PASCAL:LZ32.LZClose



#region defines
DEFINE LZERROR_BADINHANDLE   := (-1)
DEFINE LZERROR_BADOUTHANDLE  := (-2)
DEFINE LZERROR_READ          := (-3)
DEFINE LZERROR_WRITE         := (-4)
DEFINE LZERROR_GLOBALLOC     := (-5)
DEFINE LZERROR_GLOBLOCK      := (-6)
DEFINE LZERROR_BADVALUE      := (-7)
DEFINE LZERROR_UNKNOWNALG    := (-8)
#endregion