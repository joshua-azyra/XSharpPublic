//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by a tool.
//     ANTLR Version: 4.6.1-SNAPSHOT
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

// Generated from E:\XSharp\Dev\src\Compiler\src\Compiler\XSharpCodeAnalysis\Parser\XSharpLexer.g4 by ANTLR 4.6.1-SNAPSHOT

// Unreachable code detected
#pragma warning disable 0162
// The variable '...' is assigned but its value is never used
#pragma warning disable 0219
// Missing XML comment for publicly visible type or member '...'
#pragma warning disable 1591
// Ambiguous reference in cref attribute
#pragma warning disable 419

namespace LanguageService.CodeAnalysis.XSharp.SyntaxParser {
using Antlr4.Runtime;
using Antlr4.Runtime.Atn;
using Antlr4.Runtime.Misc;
using DFA = Antlr4.Runtime.Dfa.DFA;

[System.CodeDom.Compiler.GeneratedCode("ANTLR", "4.6.1-SNAPSHOT")]
[System.CLSCompliant(false)]
public partial class XSharpLexer : Lexer {
	public const int
		FIRST_KEYWORD=1, ACCESS=2, ALIGN=3, AS=4, ASPEN=5, ASSIGN=6, BEGIN=7, 
		BREAK=8, CALLBACK=9, CASE=10, CAST=11, CLASS=12, CLIPPER=13, DECLARE=14, 
		DEFINE=15, DIM=16, DLL=17, DLLEXPORT=18, DO=19, DOWNTO=20, ELSE=21, ELSEIF=22, 
		END=23, ENDCASE=24, ENDDO=25, ENDIF=26, EXIT=27, EXPORT=28, FASTCALL=29, 
		FIELD=30, FOR=31, FUNCTION=32, GLOBAL=33, HIDDEN=34, IF=35, IIF=36, INHERIT=37, 
		INIT1=38, INIT2=39, INIT3=40, INSTANCE=41, IS=42, IN=43, LOCAL=44, LOOP=45, 
		MEMBER=46, MEMVAR=47, METHOD=48, NAMEOF=49, NEXT=50, OTHERWISE=51, PARAMETERS=52, 
		PASCAL=53, PRIVATE=54, PROCEDURE=55, PROTECTED=56, PUBLIC=57, RECOVER=58, 
		RETURN=59, SELF=60, SEQUENCE=61, SIZEOF=62, STATIC=63, STEP=64, STRICT=65, 
		SUPER=66, THISCALL=67, TO=68, TYPEOF=69, UNION=70, UPTO=71, USING=72, 
		WHILE=73, WINCALL=74, CATCH=75, FINALLY=76, THROW=77, FIRST_POSITIONAL_KEYWORD=78, 
		ABSTRACT=79, AUTO=80, CASTCLASS=81, CONSTRUCTOR=82, CONST=83, DEFAULT=84, 
		DELEGATE=85, DESTRUCTOR=86, ENUM=87, EVENT=88, EXPLICIT=89, FOREACH=90, 
		GET=91, IMPLEMENTS=92, IMPLICIT=93, IMPLIED=94, INITONLY=95, INTERFACE=96, 
		INTERNAL=97, LOCK=98, NAMESPACE=99, NEW=100, OPERATOR=101, OUT=102, PARTIAL=103, 
		PROPERTY=104, REPEAT=105, SCOPE=106, SEALED=107, SET=108, STRUCTURE=109, 
		TRY=110, TUPLE=111, UNTIL=112, VALUE=113, VIRTUAL=114, VOSTRUCT=115, ADD=116, 
		ARGLIST=117, ASCENDING=118, ASYNC=119, ASTYPE=120, AWAIT=121, BY=122, 
		CHECKED=123, DESCENDING=124, EQUALS=125, EXTERN=126, FIXED=127, FROM=128, 
		GROUP=129, INIT=130, INTO=131, JOIN=132, LET=133, NOP=134, OF=135, ON=136, 
		ORDERBY=137, OVERRIDE=138, PARAMS=139, REMOVE=140, SELECT=141, STACKALLOC=142, 
		SWITCH=143, UNCHECKED=144, UNSAFE=145, VAR=146, VOLATILE=147, WHEN=148, 
		WHERE=149, YIELD=150, WITH=151, LAST_POSITIONAL_KEYWORD=152, FIRST_TYPE=153, 
		ARRAY=154, BYTE=155, CODEBLOCK=156, DATE=157, DWORD=158, FLOAT=159, INT=160, 
		LOGIC=161, LONGINT=162, OBJECT=163, PSZ=164, PTR=165, REAL4=166, REAL8=167, 
		REF=168, SHORTINT=169, STRING=170, SYMBOL=171, USUAL=172, VOID=173, WORD=174, 
		CHAR=175, INT64=176, UINT64=177, DYNAMIC=178, DECIMAL=179, DATETIME=180, 
		CURRENCY=181, BINARY=182, NINT=183, NUINT=184, LAST_TYPE=185, UDC_KEYWORD=186, 
		SCRIPT_REF=187, SCRIPT_LOAD=188, ASSIGNMENT=189, DEFERRED=190, ENDCLASS=191, 
		EXPORTED=192, FREEZE=193, FINAL=194, INLINE=195, INTRODUCE=196, NOSAVE=197, 
		READONLY=198, SHARING=199, SHARED=200, SYNC=201, ENDDEFINE=202, LPARAMETERS=203, 
		OLEPUBLIC=204, EXCLUDE=205, THISACCESS=206, HELPSTRING=207, DIMENSION=208, 
		NOINIT=209, THEN=210, FOX_M=211, LAST_KEYWORD=212, FIRST_NULL=213, NIL=214, 
		NULL=215, NULL_ARRAY=216, NULL_CODEBLOCK=217, NULL_DATE=218, NULL_OBJECT=219, 
		NULL_PSZ=220, NULL_PTR=221, NULL_STRING=222, NULL_SYMBOL=223, NULL_FOX=224, 
		LAST_NULL=225, FIRST_OPERATOR=226, LT=227, LTE=228, GT=229, GTE=230, EQ=231, 
		EEQ=232, SUBSTR=233, NEQ=234, NEQ2=235, INC=236, DEC=237, PLUS=238, MINUS=239, 
		DIV=240, MOD=241, EXP=242, LSHIFT=243, RSHIFT=244, TILDE=245, MULT=246, 
		QQMARK=247, QMARK=248, AND=249, OR=250, NOT=251, BIT_NOT=252, BIT_AND=253, 
		BIT_OR=254, BIT_XOR=255, ASSIGN_OP=256, ASSIGN_ADD=257, ASSIGN_SUB=258, 
		ASSIGN_EXP=259, ASSIGN_MUL=260, ASSIGN_DIV=261, ASSIGN_MOD=262, ASSIGN_BITAND=263, 
		ASSIGN_BITOR=264, ASSIGN_LSHIFT=265, ASSIGN_RSHIFT=266, ASSIGN_XOR=267, 
		ASSIGN_QQMARK=268, LOGIC_AND=269, LOGIC_OR=270, LOGIC_NOT=271, LOGIC_XOR=272, 
		FOX_AND=273, FOX_OR=274, FOX_NOT=275, FOX_XOR=276, LPAREN=277, RPAREN=278, 
		LCURLY=279, RCURLY=280, LBRKT=281, RBRKT=282, COLON=283, COMMA=284, PIPE=285, 
		AMP=286, ADDROF=287, ALIAS=288, DOT=289, COLONCOLON=290, BACKSLASH=291, 
		ELLIPSIS=292, BACKBACKSLASH=293, LAST_OPERATOR=294, FIRST_CONSTANT=295, 
		FALSE_CONST=296, TRUE_CONST=297, HEX_CONST=298, BIN_CONST=299, INT_CONST=300, 
		DATE_CONST=301, DATETIME_CONST=302, REAL_CONST=303, INVALID_NUMBER=304, 
		SYMBOL_CONST=305, CHAR_CONST=306, STRING_CONST=307, ESCAPED_STRING_CONST=308, 
		INTERPOLATED_STRING_CONST=309, INCOMPLETE_STRING_CONST=310, TEXT_STRING_CONST=311, 
		BRACKETED_STRING_CONST=312, BINARY_CONST=313, LAST_CONSTANT=314, PP_FIRST=315, 
		PP_COMMAND=316, PP_DEFINE=317, PP_ELSE=318, PP_ENDIF=319, PP_ENDREGION=320, 
		PP_ERROR=321, PP_IF=322, PP_IFDEF=323, PP_IFNDEF=324, PP_INCLUDE=325, 
		PP_LINE=326, PP_REGION=327, PP_STDOUT=328, PP_TRANSLATE=329, PP_UNDEF=330, 
		PP_WARNING=331, PP_PRAGMA=332, PP_TEXT=333, PP_ENDTEXT=334, PP_LAST=335, 
		MACRO=336, UDCSEP=337, ID=338, DOC_COMMENT=339, SL_COMMENT=340, ML_COMMENT=341, 
		LINE_CONT=342, LINE_CONT_OLD=343, SEMI=344, WS=345, NL=346, EOS=347, UNRECOGNIZED=348, 
		LAST=349;
	public const int
		XMLDOCCHANNEL=2, DEFOUTCHANNEL=3, PREPROCESSORCHANNEL=4;
	public static string[] modeNames = {
		"DEFAULT_MODE"
	};

	public static readonly string[] ruleNames = {
		"UNRECOGNIZED"
	};


	public XSharpLexer(ICharStream input)
		: base(input)
	{
		_interp = new LexerATNSimulator(this,_ATN);
	}

	private static readonly string[] _LiteralNames = {
	};
	private static readonly string[] _SymbolicNames = {
		null, "FIRST_KEYWORD", "ACCESS", "ALIGN", "AS", "ASPEN", "ASSIGN", "BEGIN", 
		"BREAK", "CALLBACK", "CASE", "CAST", "CLASS", "CLIPPER", "DECLARE", "DEFINE", 
		"DIM", "DLL", "DLLEXPORT", "DO", "DOWNTO", "ELSE", "ELSEIF", "END", "ENDCASE", 
		"ENDDO", "ENDIF", "EXIT", "EXPORT", "FASTCALL", "FIELD", "FOR", "FUNCTION", 
		"GLOBAL", "HIDDEN", "IF", "IIF", "INHERIT", "INIT1", "INIT2", "INIT3", 
		"INSTANCE", "IS", "IN", "LOCAL", "LOOP", "MEMBER", "MEMVAR", "METHOD", 
		"NAMEOF", "NEXT", "OTHERWISE", "PARAMETERS", "PASCAL", "PRIVATE", "PROCEDURE", 
		"PROTECTED", "PUBLIC", "RECOVER", "RETURN", "SELF", "SEQUENCE", "SIZEOF", 
		"STATIC", "STEP", "STRICT", "SUPER", "THISCALL", "TO", "TYPEOF", "UNION", 
		"UPTO", "USING", "WHILE", "WINCALL", "CATCH", "FINALLY", "THROW", "FIRST_POSITIONAL_KEYWORD", 
		"ABSTRACT", "AUTO", "CASTCLASS", "CONSTRUCTOR", "CONST", "DEFAULT", "DELEGATE", 
		"DESTRUCTOR", "ENUM", "EVENT", "EXPLICIT", "FOREACH", "GET", "IMPLEMENTS", 
		"IMPLICIT", "IMPLIED", "INITONLY", "INTERFACE", "INTERNAL", "LOCK", "NAMESPACE", 
		"NEW", "OPERATOR", "OUT", "PARTIAL", "PROPERTY", "REPEAT", "SCOPE", "SEALED", 
		"SET", "STRUCTURE", "TRY", "TUPLE", "UNTIL", "VALUE", "VIRTUAL", "VOSTRUCT", 
		"ADD", "ARGLIST", "ASCENDING", "ASYNC", "ASTYPE", "AWAIT", "BY", "CHECKED", 
		"DESCENDING", "EQUALS", "EXTERN", "FIXED", "FROM", "GROUP", "INIT", "INTO", 
		"JOIN", "LET", "NOP", "OF", "ON", "ORDERBY", "OVERRIDE", "PARAMS", "REMOVE", 
		"SELECT", "STACKALLOC", "SWITCH", "UNCHECKED", "UNSAFE", "VAR", "VOLATILE", 
		"WHEN", "WHERE", "YIELD", "WITH", "LAST_POSITIONAL_KEYWORD", "FIRST_TYPE", 
		"ARRAY", "BYTE", "CODEBLOCK", "DATE", "DWORD", "FLOAT", "INT", "LOGIC", 
		"LONGINT", "OBJECT", "PSZ", "PTR", "REAL4", "REAL8", "REF", "SHORTINT", 
		"STRING", "SYMBOL", "USUAL", "VOID", "WORD", "CHAR", "INT64", "UINT64", 
		"DYNAMIC", "DECIMAL", "DATETIME", "CURRENCY", "BINARY", "NINT", "NUINT", 
		"LAST_TYPE", "UDC_KEYWORD", "SCRIPT_REF", "SCRIPT_LOAD", "ASSIGNMENT", 
		"DEFERRED", "ENDCLASS", "EXPORTED", "FREEZE", "FINAL", "INLINE", "INTRODUCE", 
		"NOSAVE", "READONLY", "SHARING", "SHARED", "SYNC", "ENDDEFINE", "LPARAMETERS", 
		"OLEPUBLIC", "EXCLUDE", "THISACCESS", "HELPSTRING", "DIMENSION", "NOINIT", 
		"THEN", "FOX_M", "LAST_KEYWORD", "FIRST_NULL", "NIL", "NULL", "NULL_ARRAY", 
		"NULL_CODEBLOCK", "NULL_DATE", "NULL_OBJECT", "NULL_PSZ", "NULL_PTR", 
		"NULL_STRING", "NULL_SYMBOL", "NULL_FOX", "LAST_NULL", "FIRST_OPERATOR", 
		"LT", "LTE", "GT", "GTE", "EQ", "EEQ", "SUBSTR", "NEQ", "NEQ2", "INC", 
		"DEC", "PLUS", "MINUS", "DIV", "MOD", "EXP", "LSHIFT", "RSHIFT", "TILDE", 
		"MULT", "QQMARK", "QMARK", "AND", "OR", "NOT", "BIT_NOT", "BIT_AND", "BIT_OR", 
		"BIT_XOR", "ASSIGN_OP", "ASSIGN_ADD", "ASSIGN_SUB", "ASSIGN_EXP", "ASSIGN_MUL", 
		"ASSIGN_DIV", "ASSIGN_MOD", "ASSIGN_BITAND", "ASSIGN_BITOR", "ASSIGN_LSHIFT", 
		"ASSIGN_RSHIFT", "ASSIGN_XOR", "ASSIGN_QQMARK", "LOGIC_AND", "LOGIC_OR", 
		"LOGIC_NOT", "LOGIC_XOR", "FOX_AND", "FOX_OR", "FOX_NOT", "FOX_XOR", "LPAREN", 
		"RPAREN", "LCURLY", "RCURLY", "LBRKT", "RBRKT", "COLON", "COMMA", "PIPE", 
		"AMP", "ADDROF", "ALIAS", "DOT", "COLONCOLON", "BACKSLASH", "ELLIPSIS", 
		"BACKBACKSLASH", "LAST_OPERATOR", "FIRST_CONSTANT", "FALSE_CONST", "TRUE_CONST", 
		"HEX_CONST", "BIN_CONST", "INT_CONST", "DATE_CONST", "DATETIME_CONST", 
		"REAL_CONST", "INVALID_NUMBER", "SYMBOL_CONST", "CHAR_CONST", "STRING_CONST", 
		"ESCAPED_STRING_CONST", "INTERPOLATED_STRING_CONST", "INCOMPLETE_STRING_CONST", 
		"TEXT_STRING_CONST", "BRACKETED_STRING_CONST", "BINARY_CONST", "LAST_CONSTANT", 
		"PP_FIRST", "PP_COMMAND", "PP_DEFINE", "PP_ELSE", "PP_ENDIF", "PP_ENDREGION", 
		"PP_ERROR", "PP_IF", "PP_IFDEF", "PP_IFNDEF", "PP_INCLUDE", "PP_LINE", 
		"PP_REGION", "PP_STDOUT", "PP_TRANSLATE", "PP_UNDEF", "PP_WARNING", "PP_PRAGMA", 
		"PP_TEXT", "PP_ENDTEXT", "PP_LAST", "MACRO", "UDCSEP", "ID", "DOC_COMMENT", 
		"SL_COMMENT", "ML_COMMENT", "LINE_CONT", "LINE_CONT_OLD", "SEMI", "WS", 
		"NL", "EOS", "UNRECOGNIZED", "LAST"
	};
	public static readonly IVocabulary DefaultVocabulary = new Vocabulary(_LiteralNames, _SymbolicNames);

	[System.Obsolete("Use Vocabulary instead.")]
	public static readonly string[] tokenNames = GenerateTokenNames(DefaultVocabulary, _SymbolicNames.Length);

	private static string[] GenerateTokenNames(IVocabulary vocabulary, int length) {
		string[] tokenNames = new string[length];
		for (int i = 0; i < tokenNames.Length; i++) {
			tokenNames[i] = vocabulary.GetLiteralName(i);
			if (tokenNames[i] == null) {
				tokenNames[i] = vocabulary.GetSymbolicName(i);
			}

			if (tokenNames[i] == null) {
				tokenNames[i] = "<INVALID>";
			}
		}

		return tokenNames;
	}

	[System.Obsolete("Use IRecognizer.Vocabulary instead.")]
	public override string[] TokenNames
	{
		get
		{
			return tokenNames;
		}
	}

	[NotNull]
	public override IVocabulary Vocabulary
	{
		get
		{
			return DefaultVocabulary;
		}
	}

	public override string GrammarFileName { get { return "XSharpLexer.g4"; } }

	public override string[] RuleNames { get { return ruleNames; } }

	public override string[] ModeNames { get { return modeNames; } }

	public override string SerializedAtn { get { return _serializedATN; } }

	public static readonly string _serializedATN =
		"\x3\xAF6F\x8320\x479D\xB75C\x4880\x1605\x191C\xAB37\x2\x15F\a\b\x1\x4"+
		"\x2\t\x2\x3\x2\x3\x2\x2\x2\x2\x3\x3\x2\x15E\x3\x2\x2\x6\x2\x3\x3\x2\x2"+
		"\x2\x3\x5\x3\x2\x2\x2\x5\x6\v\x2\x2\x2\x6\x4\x3\x2\x2\x2\x3\x2\x2";
	public static readonly ATN _ATN =
		new ATNDeserializer().Deserialize(_serializedATN.ToCharArray());
}
} // namespace LanguageService.CodeAnalysis.XSharp.SyntaxParser
