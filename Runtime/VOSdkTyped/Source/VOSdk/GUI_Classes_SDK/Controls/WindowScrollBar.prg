
//Todo: WIndowScrollBar classes
CLASS WindowHorizontalScrollBar INHERIT WindowScrollBar

    /// <include file="Gui.xml" path="doc/WindowHorizontalScrollBar.ctor/*" />
CONSTRUCTOR(oOwner)
	SUPER(oOwner)

END CLASS

CLASS WindowScrollBar INHERIT ScrollBar

    /// <include file="Gui.xml" path="doc/WindowScrollBar.ctor/*" />
CONSTRUCTOR(oOwner, xID, oPoint, oDimension, lDataAware)
	SUPER(oOwner, xID, oPoint, oDimension, lDataAware)


RETURN
END CLASS

CLASS WindowVerticalScrollBar INHERIT WindowScrollBar
    /// <include file="Gui.xml" path="doc/WindowVerticalScrollBar.ctor/*" />
CONSTRUCTOR(oOwner)
	SUPER(oOwner)


END CLASS

