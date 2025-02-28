﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//
//------------------------------------------------------------------------------

using System;
using System.Linq;
using System.Runtime.InteropServices;
using Microsoft.VisualStudio.OLE.Interop;
using Microsoft.VisualStudio;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Text.Editor;
using Microsoft.VisualStudio.Utilities;
using System.ComponentModel.Composition;
using Microsoft.VisualStudio.Language.Intellisense;
using Microsoft.VisualStudio.TextManager.Interop;
using Microsoft.VisualStudio.Text;
using XSharpModel;
using Microsoft.VisualStudio.Editor;
using Microsoft.VisualStudio.Text.Tagging;
using System.Collections.Generic;
using LanguageService.SyntaxTree;
using LanguageService.CodeAnalysis.XSharp;
using static XSharp.LanguageService.XSharpFormattingCommandHandler;
using LanguageService.CodeAnalysis.XSharp.SyntaxParser;
using System.Text;
#pragma warning disable CS0649 // Field is never assigned to, for the imported fields
#if !ASYNCCOMPLETION
namespace XSharp.LanguageService
{
    [Export(typeof(IVsTextViewCreationListener))]
    [Name("XSharp Completion Provider")]
    [TextViewRole(PredefinedTextViewRoles.Editable)]
    [ContentType(XSharpConstants.LanguageName)]
    internal class XSharpCompletionProvider : IVsTextViewCreationListener
    {

        [Import]
        internal IVsEditorAdaptersFactoryService AdapterService;

        [Import]
        internal ICompletionBroker CompletionBroker { get; set; }

        [Import]
        internal IBufferTagAggregatorFactoryService BufferTagAggregatorFactoryService { get; set; }
        public void VsTextViewCreated(IVsTextView textViewAdapter)
        {
            if (XEditorSettings.DisableCodeCompletion)
                return;
            ITextView textView = AdapterService.GetWpfTextView(textViewAdapter);
            if (textView == null)
                return;
            textView.Properties.GetOrCreateSingletonProperty(
                 () => new XSharpCompletionCommandHandler(textViewAdapter,
                    textView,
                    CompletionBroker,
                    BufferTagAggregatorFactoryService
                    ));
        }
    }

    internal class XSharpCompletionCommandHandler : IOleCommandTarget
    {
        readonly ITextView _textView;
        readonly ICompletionBroker _completionBroker;
        private ICompletionSession _completionSession;
        private readonly IOleCommandTarget m_nextCommandHandler;
        private readonly ITagAggregator<IClassificationTag> _tagAggregator;
        bool completionWasSelected = false;
        XSharpSignatureHelpCommandHandler _signatureCommandHandler = null;

        internal XSharpCompletionCommandHandler(IVsTextView textViewAdapter, ITextView textView,
            ICompletionBroker completionBroker, IBufferTagAggregatorFactoryService aggregator)
        {
            this._textView = textView;
            this._completionBroker = completionBroker;
            this._completionSession = null;
            this._tagAggregator = aggregator.CreateTagAggregator<IClassificationTag>(_textView.TextBuffer);
            //add this to the filter chain
            textViewAdapter.AddCommandFilter(this, out m_nextCommandHandler);
        }


        public int Exec(ref Guid pguidCmdGroup, uint nCmdID, uint nCmdexecopt, IntPtr pvaIn, IntPtr pvaOut)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            int result = VSConstants.S_OK;
            bool handled = false;
            Guid cmdGroup = pguidCmdGroup;
            // 1. Pre-process before anybody else has a chance
            if (XEditorSettings.DisableCodeCompletion)
            {
                ;
            }
            else if (pguidCmdGroup == VSConstants.VSStd2K)
            {
                switch (nCmdID)
                {
                    case (int)VSConstants.VSStd2KCmdID.COMPLETEWORD:
                    case (int)VSConstants.VSStd2KCmdID.AUTOCOMPLETE:
                    case (int)VSConstants.VSStd2KCmdID.SHOWMEMBERLIST:
                        // in this case we WANT to include keywords in the list
                        // when they type LOCA we want to include LOCAL as well
                        handled = StartCompletionSession(nCmdID, '\0', true);
                        break;
                    case (int)VSConstants.VSStd2KCmdID.RETURN:
                        handled = CompleteCompletionSession('\0');
                        break;
                    case (int)VSConstants.VSStd2KCmdID.TAB:
                        handled = CompleteCompletionSession('\t');
                        break;
                    case (int)VSConstants.VSStd2KCmdID.CANCEL:
                        handled = CancelCompletionSession();
                        break;
                    case (int)VSConstants.VSStd2KCmdID.TYPECHAR:
                        char ch = GetTypeChar(pvaIn);
                        if (_completionSession != null)
                        {
                            switch (ch)
                            {
                                case '_':
                                    // do nothing now. Let the provider filter the list for us.
                                    break;

                                case '=':
                                    // typed :=
                                    CancelCompletionSession();
                                    break;
                                case '.':
                                    handled = CompleteCompletionSession(ch);
                                    break;
                                case ':':
                                    if (nextChar() == '=')
                                    {
                                        CancelCompletionSession();
                                    }
                                    else
                                    {
                                        handled = CompleteCompletionSession(ch);
                                    }
                                    break;
                                default:
                                    if (char.IsLetterOrDigit(ch))
                                    {
                                        ; // do nothing
                                    }
                                    else if (XEditorSettings.CommitChars.Contains(ch))
                                    {
                                        handled = CompleteCompletionSession(ch);
                                    }
                                    else
                                    {
                                        CancelCompletionSession();
                                    }

                                    break;
                            }
                            //
                        }

                        break;
                    default:
                        break;
                }
            }
            else if (pguidCmdGroup == VSConstants.GUID_VSStandardCommandSet97)
            {
                switch (nCmdID)
                {
                    case (int)VSConstants.VSStd97CmdID.Undo:
                    case (int)VSConstants.VSStd97CmdID.Redo:
                        CancelCompletionSession();
                        break;

                    default:
                        break;
                }
            }
            // 2. Let others do their thing
            // Let others do their thing
            if (!handled)
            {
                if (_completionSession != null)
                {
                    if (_completionSession.SelectedCompletionSet != null)
                    {
                        completionWasSelected = _completionSession.SelectedCompletionSet.SelectionStatus.IsSelected;
                    }
                }
                result = m_nextCommandHandler.Exec(ref cmdGroup, nCmdID, nCmdexecopt, pvaIn, pvaOut);
            }
            // 3. Post process
            if (ErrorHandler.Succeeded(result) && !XEditorSettings.DisableCodeCompletion)
            {
                if (pguidCmdGroup == VSConstants.VSStd2K)
                {
                    switch (nCmdID)
                    {
                        case (int)VSConstants.VSStd2KCmdID.BACKSPACE:
                            FilterCompletionSession('\0');
                            break;

                        case (int)VSConstants.VSStd2KCmdID.RETURN:
                            // Check if we are inside a XMLDoc comment ///
                            InjectXMLDoc();
                            break;

                        case (int)VSConstants.VSStd2KCmdID.TYPECHAR:
                            char ch = GetTypeChar(pvaIn);
                            if (_completionSession == null)
                            {
                                switch (ch)
                                {
                                    case ':':
                                    case '.':
                                        StartCompletionSession(nCmdID, ch);
                                        break;
                                    case '/':
                                        InsertXMLDoc();
                                        break;
                                    default:
                                        //completeCurrentToken(nCmdID, ch);
                                        break;
                                }
                            }
                            else
                            {
                                FilterCompletionSession(ch);
                            }
                            break;
                        default:
                            break;

                    }
                }
            }

            return result;
        }

        /// <summary>
        /// Push XMLDoc /// after a return char if we are just after an existing line with XMLDoc
        /// </summary>
        private void InjectXMLDoc()
        {
            try
            {
                // Retrieve Position
                SnapshotPoint caret = _textView.Caret.Position.BufferPosition;
                var line = caret.GetContainingLine();
                if ((line.LineNumber >= _textView.TextSnapshot.LineCount - 1) || (line.LineNumber == 0))
                    return;
                // Do not classify here. Not really needed yet
                ITextSnapshotLine lineUp = _textView.TextSnapshot.GetLineFromLineNumber(line.LineNumber - 1);
                ITextSnapshotLine lineDown = _textView.TextSnapshot.GetLineFromLineNumber(line.LineNumber + 1);
                string prevLine = lineUp.GetText();
                string nextLine = lineDown.GetText().Trim();
                var afterADocComment = prevLine.Trim().StartsWith("///");
                var beforeDocComment = nextLine.StartsWith("///") || String.IsNullOrEmpty(nextLine);
                // Ok, check the content
                if (afterADocComment && beforeDocComment)
                {
                    // Get the line
                    // To retrieve the text and align to it
                    int count = prevLine.TakeWhile(Char.IsWhiteSpace).Count();
                    string prefix;
                    if (prevLine.Length >= count + 4)
                        prefix = prevLine.Substring(0, count + 4); // copy starting whitespace + /// + separator
                    else
                        prefix = prevLine + " ";
                    _textView.TextBuffer.Insert(caret.Position, prefix);
                    // Move the Caret
                    _textView.Caret.MoveTo(new SnapshotPoint(_textView.TextSnapshot, caret.Position + prefix.Length));
                }
            }
            catch (Exception e)
            {
                WriteOutputMessage("InjectXMLDoc: error " + e.Message);
            }
        }

        /// <summary>
        /// Insert XMLDoc Comments
        /// </summary>
        private void InsertXMLDoc()
        {
            try
            {
                // Retrieve Position
                SnapshotPoint caret = _textView.Caret.Position.BufferPosition;
                var line = caret.GetContainingLine();
                if (line.LineNumber >= _textView.TextSnapshot.LineCount - 1)
                    return;
                string lineText = line.GetText();
                // Remove all type of spaces
                lineText = lineText.Trim(' ', '\t');
                // XMLDoc ?
                if (lineText == "///")
                {
                    // Check next && previous Line . No need to classify here. We'll do that later
                    // when we're not next to a comment
                    var lineDown = _textView.TextSnapshot.GetLineFromLineNumber(line.LineNumber + 1);
                    var nextToAComment = lineDown.GetText().Trim().StartsWith("///");
                    if (!nextToAComment && line.LineNumber > 0)
                    {
                        var lineUp = _textView.TextSnapshot.GetLineFromLineNumber(line.LineNumber - 1);
                        nextToAComment = lineUp.GetText().Trim().StartsWith("///");

                    }
                    if (!nextToAComment)
                    {
                        // force buffer to be classified to see if we are on a line before a comment
                        var classifier = _textView.TextBuffer.GetClassifier();
                        _ = classifier.ClassifyWhenNeededAsync();
                        var doc = _textView.TextBuffer.GetDocument();
                        if (doc == null)
                            return;
                        // Make sure that the entity list matches the contents of the buffer
                        // Parse the entities
                        classifier.Parse();
                        var entity = _textView.FindEntity(lineDown.Start);
                        if (entity != null && entity.Range.StartLine > line.LineNumber)
                        {
                            // Default information
                            // Retrieve the original line, and keep the prefix
                            lineText = line.GetText().TrimEnd();
                            string prefix = lineText.Remove(lineText.Length - 3, 3);
                            // Insert XMLDoc template
                            var sb = new StringBuilder();
                            sb.AppendLine($" <summary>\r\n{prefix}/// \r\n{prefix}/// </summary>");
                            var member = entity as XSourceMemberSymbol;
                            var type = entity as XSourceTypeSymbol;
                            if (type != null && type.Kind == Kind.Delegate)
                            {
                                // delegate have a generated Invoke method with the parameters and return type
                                member = type.Members.First() as XSourceMemberSymbol;
                            }
                            IList<string> typeParameters = null;
                            if (member != null)
                            {
                                typeParameters = member.TypeParameters;
                                // Now fill with retrieved information
                                foreach (var param in member.Parameters)
                                {
                                    sb.AppendLine(prefix + $"/// <param name=\"{param.Name}\"></param>");
                                }
                                if (member.Kind.IsProperty())
                                {
                                    sb.AppendLine(prefix + "/// <value></value>");
                                }
                                else if (member.Kind.HasReturnType() && !member.Kind.IsField())
                                {
                                    if ((string.Compare(member.ReturnType, "void", true) != 0))
                                    {
                                        sb.AppendLine(prefix + "/// <returns></returns>");
                                    }
                                }
                            }
                            if (type != null)
                            {
                                typeParameters = type.TypeParameters;
                            }
                            if (typeParameters != null)
                            {
                                foreach (var typeparam in typeParameters)
                                {
                                    sb.AppendLine(prefix + $"/// <typeparam name=\"{typeparam}\"></typeparam>");
                                }
                            }
                            // remove last CRLF from sb
                            if (sb.Length > 2)
                                sb.Length = sb.Length - 2;
                            _textView.TextBuffer.Insert(_textView.Caret.Position.BufferPosition.Position, sb.ToString());
                            // Move the Caret in the Summary area
                            ITextSnapshotLine moveToline = _textView.TextSnapshot.GetLineFromLineNumber(line.LineNumber + 1);
                            SnapshotPoint point = new SnapshotPoint(moveToline.Snapshot, moveToline.End.Position);
                            _textView.Caret.MoveTo(point);
                        }
                    }
                }
            }
            catch (Exception e)
            {
                WriteOutputMessage("InsertXMLDoc: error " + e.Message);
            }
        }

        private void completeCurrentToken(uint nCmdID, char ch)
        {
            if (!CompletionAllowed(ch))
            {
                return;
            }
            SnapshotPoint caret = _textView.Caret.Position.BufferPosition;
            if (char.IsLetterOrDigit(ch) || ch == '_')
            {
                var line = caret.GetContainingLine();

                var lineText = line.GetText();
                var pos = caret.Position - line.Start.Position;
                int chars = 0;
                // count the number of characters in the current word. When > limit set in the options dialog then trigger completion
                for (int i = pos - 1; i >= 0; i--)
                {
                    var c = lineText[i];
                    if (!char.IsLetterOrDigit(c) && c != '_')
                    {
                        break;
                    }
                    chars++;
                    if (chars >= XEditorSettings.CompleteNumChars)
                        break;
                }
                if (chars >= XEditorSettings.CompleteNumChars)
                {
                    StartCompletionSession(nCmdID, '\0', true, true);
                }
            }
        }

        private void FilterCompletionSession(char ch)
        {

            WriteOutputMessage("FilterCompletionSession()");
            if (_completionSession == null)
                return;

            WriteOutputMessage(" --> in Filter");
            if (_completionSession.SelectedCompletionSet != null)
            {
                WriteOutputMessage(" --> Filtering ?");
                _completionSession.SelectedCompletionSet.Filter();
                if (_completionSession.SelectedCompletionSet.Completions.Count == 0)
                {
                    CancelCompletionSession();
                }
                else
                {
                    WriteOutputMessage(" --> Selecting ");
                    _completionSession.SelectedCompletionSet.SelectBestMatch();
                    _completionSession.SelectedCompletionSet.Recalculate();
                }
            }

        }


        bool CancelCompletionSession()
        {
            if (_completionSession == null)
            {
                return false;
            }
            _completionSession.Dismiss();
            return true;
        }

        bool CompleteCompletionSession(char ch)
        {
           if (_completionSession == null)
            {
                return false;
            }
            if (!_completionSession.SelectedCompletionSet.SelectionStatus.IsSelected)
            {
                CancelCompletionSession();
                return false;
            }
            bool commit = false;
            bool moveBack = false;
            Completion completion = null;
            XSCompletion xscompletion = null;
            ITextCaret caret = null;
            WriteOutputMessage("CompleteCompletionSession()");
            if (_completionSession.SelectedCompletionSet != null)
            {
                bool addDelim = false;

                if (_completionSession.SelectedCompletionSet.SelectionStatus.Completion != null)
                {
                    completion = _completionSession.SelectedCompletionSet.SelectionStatus.Completion;
                }
                xscompletion = completion as XSCompletion;
                Kind kind = Kind.Unknown;
                if (xscompletion != null)
                {
                    kind = xscompletion.Kind;
                }
                bool ctor = false;
                // some tokens need to be added to the insertion text.
                switch (kind)
                {
                    case Kind.Keyword:
                        formatKeyword(completion);
                        break;
                    case Kind.Class:
                    case Kind.Structure:
                    case Kind.Constructor:
                        ctor = true;
                        goto default;
                    default:
                        switch (ch)
                        {
                            case '{' when ctor:
                            case '}' when ctor:
                                if (!completion.InsertionText.EndsWith("{"))
                                    completion.InsertionText += "{";
                                break;
                            case '\t': // Tab
                            case '\r': // CR
                            case '\n': // CR
                            case '.': // DOT
                            case ':': // COLON
                            case '\0':
                                break;
                            default:
                                var s = ch.ToString();
                                if (!completion.InsertionText.EndsWith(s))
                                    completion.InsertionText += s;
                                break;
                        }
                        break;
                }
                if ((_completionSession.SelectedCompletionSet.Completions.Count > 0) && (_completionSession.SelectedCompletionSet.SelectionStatus.IsSelected))
                {

                    if (XEditorSettings.CompletionAutoPairs)
                    {
                        caret = _completionSession.TextView.Caret;
                        addDelim = true;
                        WriteOutputMessage(" --> select " + completion.InsertionText);
                        if (kind == Kind.Constructor)
                        {
                            completion.InsertionText += "{";
                        }
                        else if (kind.HasParameters() && ! kind.IsProperty() && !completion.InsertionText.EndsWith("("))
                        {
                            if (!XEditorSettings.DisableAutoOpen)
                            {
                                completion.InsertionText += "(";
                            }
                        }
                    }
                    commit = true;
                }
                else
                {
                    if (completion != null)
                    {
                        // Push the completion char into the InsertionText if needed
                        if (ch != '\0' && !completion.InsertionText.EndsWith(ch.ToString()))
                        {
                            completion.InsertionText += ch;
                        }
                        if (XEditorSettings.CompletionAutoPairs)
                        {
                            caret = _completionSession.TextView.Caret;
                            addDelim = true;
                        }
                    }
                    commit = true;
                }
                if (addDelim)
                {
                    if (completion.InsertionText.EndsWith("("))
                    {
                        moveBack = true;
                        completion.InsertionText += ")";
                    }
                    else if (completion.InsertionText.EndsWith("{"))
                    {
                        moveBack = true;
                        completion.InsertionText += "}";
                    }
                    else if (completion.InsertionText.EndsWith("["))
                    {
                        moveBack = true;
                        completion.InsertionText += "]";
                    }

                }
            }
            if (commit)
            {
                WriteOutputMessage(" --> Commit");
                var session = _completionSession;
                session.Properties.TryGetProperty(XsCompletionProperties.Type, out IXTypeSymbol type);
                string insertionText = completion.InsertionText;
                session.Properties.TryGetProperty(XsCompletionProperties.Char, out char triggerChar);
                if (ch == '.' || ch == ':')
                {
                    if (insertionText.IndexOfAny("({".ToCharArray()) == -1)
                        completion.InsertionText += ch;

                }
                _completionSession.Commit();
                if (moveBack && (caret != null))
                {
                    caret.MoveToPreviousCaretPosition();
                }
                // if a method or constructor was chosen, then trigger the signature help
                if (insertionText.Contains('(') || insertionText.Contains('{'))
                {
                    TriggerSignatureHelp(type, insertionText, triggerChar);
                }
                return true;
            }

            WriteOutputMessage(" --> Dismiss");
            _completionSession.Dismiss();


            return false;
        }
        bool StartCompletionSession(uint nCmdId, char typedChar, bool includeKeywords = false, bool autoType = false)
        {
            WriteOutputMessage("StartCompletionSession()");

            if (_completionSession != null)
            {
                if (!_completionSession.IsDismissed)
                    return false;
            }
            if (!CompletionAllowed(typedChar))
                return false;
            SnapshotPoint caret = _textView.Caret.Position.BufferPosition;
            ITextSnapshot snapshot = caret.Snapshot;

            if (!_completionBroker.IsCompletionActive(_textView))
            {
                _completionSession = _completionBroker.CreateCompletionSession(_textView, snapshot.CreateTrackingPoint(caret, PointTrackingMode.Positive), true);
            }
            else
            {
                _completionSession = _completionBroker.GetSessions(_textView)[0];
            }

            _completionSession.Dismissed += OnCompletionSessionDismiss;
            //_completionSession.Committed += OnCompletionSessionCommitted;
            _completionSession.SelectedCompletionSetChanged += SelectedCompletionSetChanged;

            _completionSession.Properties[XsCompletionProperties.Command] = nCmdId;
            _completionSession.Properties[XsCompletionProperties.Char] = typedChar;
            _completionSession.Properties[XsCompletionProperties.AutoType] = autoType;
            _completionSession.Properties[XsCompletionProperties.Type] = null;
            _completionSession.Properties[XsCompletionProperties.IncludeKeywords] = includeKeywords;
            _completionSession.Properties[XsCompletionProperties.Filter] = "";
            try
            {
                _completionSession.Start();
                if (!CompletionAllowed(typedChar))
                    _completionSession.Dismiss();
            }
            catch (Exception e)
            {
                XSettings.LogException(e, "Start Completion failed");
            }
            return true;
        }

        internal bool HasActiveSession => _completionSession != null;

        private void SelectedCompletionSetChanged(object sender, ValueChangedEventArgs<CompletionSet> e)
        {
            if (e.NewValue.SelectionStatus.IsSelected == false)
            {
                ;
            }
        }

        private void TriggerSignatureHelp(IXTypeSymbol type, string method, char triggerChar)
        {
            // it MUST be the case....
            WriteOutputMessage("OnCompletionSessionCommitted()");

            if (triggerChar == '{' || triggerChar == '}')
            {
                if (method.EndsWith("{}"))
                    method = method.Substring(0, method.Length - 2);
                else if (method.EndsWith("{"))
                    method = method.Substring(0, method.Length - 1);
                //triggerChar = '{';
            }
            else
            {
                if (method.EndsWith("()"))
                    method = method.Substring(0, method.Length - 2);
                else if (method.EndsWith("("))
                    method = method.Substring(0, method.Length - 1);
                //triggerChar = '(';
            }

            // send command to editor to Signature Helper
            if (_signatureCommandHandler == null)
            {
                _signatureCommandHandler = _textView.Properties.GetProperty<XSharpSignatureHelpCommandHandler>(typeof(XSharpSignatureHelpCommandHandler));
            }
            if (_signatureCommandHandler != null)
            {
                _signatureCommandHandler.StartSignatureSession( type, method, triggerChar);
            }

            //
            //
        }

        private void OnCompletionSessionDismiss(object sender, EventArgs e)
        {
            if (_completionSession.SelectedCompletionSet != null)
            {
                _completionSession.SelectedCompletionSet.Filter();
            }
            //
            _completionSession.Dismissed -= OnCompletionSessionDismiss;
            _completionSession.SelectedCompletionSetChanged -= SelectedCompletionSetChanged;
            _completionSession = null;
        }

        public int QueryStatus(ref Guid pguidCmdGroup, uint cCmds, OLECMD[] prgCmds, IntPtr pCmdText)
        {
            Microsoft.VisualStudio.Shell.ThreadHelper.ThrowIfNotOnUIThread();
            return m_nextCommandHandler.QueryStatus(ref pguidCmdGroup, cCmds, prgCmds, pCmdText);
        }
        internal void WriteOutputMessage(string strMessage)
        {
            if (XSettings.EnableCodeCompletionLog && XSettings.EnableLogging)
            {
                XSettings.LogMessage("XSharp.Completion:" + strMessage);
            }
        }
        private char GetTypeChar(IntPtr pvaIn)
        {
            return (char)(ushort)Marshal.GetObjectForNativeVariant(pvaIn);
        }
        private char curChar()
        {
            // the caret is AFTER the last character !
            var caret = _textView.Caret.Position.BufferPosition;
            var pos = caret.Position;
            if (pos == 0)
                return '\0';
            return _textView.TextSnapshot.GetText(pos - 1, 1)[0];
        }

        private char prevChar()
        {
            // the caret is AFTER the last character !
            // assume the text is   ABC:|DEF where the caret is represented by the |
            // so pos = the next char 'D'
            // pos -1 is the current char ':'
            // and pos - 2 is the previous char 'C'
            var caret = _textView.Caret.Position.BufferPosition;
            var pos = caret.Position;
            if (pos < 2)
                return '\0';
            return _textView.TextSnapshot.GetText(pos - 2, 1)[0];
        }
        private char nextChar()
        {
            // the caret is AFTER the last character !
            var caret = _textView.Caret.Position.BufferPosition;
            var pos = caret.Position;
            if (pos == _textView.TextSnapshot.Length)
                return '\0';
            return _textView.TextSnapshot.GetText(pos, 1)[0];
        }
        private bool IsWs(char c)
        {
            switch (c)
            {
                case ' ':
                case '\t':
                case '\0':
                case '\r':
                case '\n':
                    return true;
            }
            return char.IsWhiteSpace(c);
        }
        private bool CompletionAllowed(char c)
        {
            // := should never produce a list
            if (c == ':' && nextChar() == '=')
                return false;
            // single character should not trigger completion
            var p = prevChar();
            var n = nextChar();
            if (c == '\0')
                c = curChar();
            if (IsWs(p) && IsWs(n))
            {
                // no completion for single character
                return false;
            }
            if (!IsWs(n))
            {
                if (c != ':' && c != '.')
                {
                    // only allow completion before a non whitespace
                    // after a ':' or .'.'
                    if (p != ':' || p != '.')
                    {
                        return false;
                    }
                }
            }
            var caret = _textView.Caret.Position.BufferPosition;
            var line = caret.GetContainingLine();
            var pos = caret.Position - line.Start;
            SnapshotSpan lineSpan = new SnapshotSpan(line.Start, pos);
            var tags = _tagAggregator.GetTags(lineSpan);
            var tag = tags.LastOrDefault();
            var classification = tag?.Tag?.ClassificationType?.Classification;
            return !classification.IsClassificationCommentOrString();
        }

        void formatKeyword(Completion completion)
        {
            completion.InsertionText = XSettings.FormatKeyword(completion.InsertionText);
        }

    }
}
#endif
