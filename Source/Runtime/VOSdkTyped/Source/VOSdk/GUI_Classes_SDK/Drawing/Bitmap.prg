

/// <include file="Gui.xml" path="doc/Bitmap/*" />
CLASS Bitmap INHERIT VObject
    PROTECT oImage AS System.Drawing.Image


    OPERATOR IMPLICIT ( bm AS Bitmap) AS System.Drawing.Image
        RETURN bm:oImage



    /// <exclude />
    ACCESS __Bitmap AS System.Drawing.Bitmap
        RETURN (System.Drawing.Bitmap) oImage

    /// <exclude />
    METHOD __SetImage(oNewImage AS System.Drawing.Image) AS VOID
        IF (oImage != NULL_OBJECT)
            oImage:Dispose()
        ENDIF
        oImage := oNewImage
        RETURN


    /// <include file="Gui.xml" path="doc/Bitmap.Destroy/*" />
    METHOD Destroy() AS USUAL

        IF (oImage != NULL_OBJECT)
            oImage:Dispose()
            oImage := NULL_OBJECT
        ENDIF
        SUPER:Destroy()
        RETURN NIL


    /// <include file="Gui.xml" path="doc/Bitmap.Handle/*" />
    METHOD Handle() AS IntPtr STRICT
        //Todo ?
        RETURN IntPtr.Zero

    /// <include file="Gui.xml" path="doc/Bitmap.ctor/*" />
    CONSTRUCTOR(xResourceID, kLoadOption, iWidth, iHeight)
        //Todo handle various options
        LOCAL hInst AS PTR
        LOCAL lpszBitmap AS PTR
        LOCAL hBitMap as PTR
        LOCAL oResourceID as ResourceID

        SUPER()
        IF xResourceID IS System.Drawing.Image var oBmp
            oImage := oBmp
            RETURN
        ELSEIF IsNumeric(xResourceID) .OR. IsSymbol(xResourceID) .OR. IsString(xResourceID)
            oResourceID := ResourceID{xResourceID}
        ELSEIF IsPtr(xResourceID) //
            oImage := System.Drawing.Image.FromHbitmap((IntPtr) xResourceID)
            RETURN
        ELSEIF !IsInstanceOfUsual(xResourceID, #ResourceID)
            WCError{#Init, #Bitmap, __WCSTypeError, xResourceID, 1}:Throw()
            GC.SuppressFinalize( SELF )
        ELSE
            oResourceID := xResourceID
        ENDIF

        DEFAULT(@kLoadOption, LR_DEFAULTCOLOR)
        IF ! IsLong(iWidth)
            iWidth := 0
        ENDIF
        IF ! IsLong(iHeight)
            iHeight := 0
        ENDIF

        IF IsString(xResourceID) .and. File(xResourceID)
            oImage := System.Drawing.Image.FromFile(xResourceID)
        ELSE
            hInst := oResourceID:Handle()
            lpszBitmap := oResourceID:Address()

            hBitMap := GuiWin32.LoadImage(hInst, lpszBitmap, IMAGE_BITMAP, iWidth, iHeight, kLoadOption)
            IF hBitMap != NULL_PTR
                oImage  := System.Drawing.Image.FromHbitmap(hBitMap)
            ENDIF
        ENDIF


        RETURN


    /// <include file="Gui.xml" path="doc/Bitmap.Size/*" />
    ACCESS Size AS Dimension
        IF oImage != NULL_OBJECT
            RETURN (Dimension) oImage:Size
        ENDIF
        RETURN Dimension{}

    /// <include file="Gui.xml" path="doc/Icon.FromFile/*" />
    STATIC METHOD FromFile(cFile AS STRING	) AS BitMap
        IF File(cFile)
            VAR oImage := System.Drawing.Image.FromFile(FPathName())
            RETURN Bitmap{oImage}
        ENDIF
        RETURN NULL
END CLASS
