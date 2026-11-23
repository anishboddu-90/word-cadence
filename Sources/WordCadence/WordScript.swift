enum WordScript {
    static let source = """
    on dispatchCommand(operation, args)
        with timeout of 4 seconds
            tell application id "com.microsoft.Word"
                if operation is "list" then
                    set results to {}
                    repeat with doc in (get documents)
                        set end of results to {(name of doc as text), (full name of doc as text)}
                    end repeat
                    return results
                end if

                set docName to item 1 of args
                set docPath to item 2 of args
                set chosen to missing value
                repeat with candidate in (get documents)
                    if my sameText((name of candidate as text), docName) and my sameText((full name of candidate as text), docPath) then
                        if chosen is not missing value then error "More than one Word document has that name and path." number 7001
                        set chosen to contents of candidate
                    end if
                end repeat
                if chosen is missing value then error "The target document was closed or renamed." number 7001
                set editProtection to protection type of chosen
                if read only of chosen or (editProtection is not no document protection and editProtection is not allow only revisions) then
                    error "The target Word document is read-only or protected." number 7001
                end if
                set endPosition to (end of content of text object of chosen) - 1
                set tailStart to endPosition - 48
                if tailStart < 0 then set tailStart to 0
                set tailRange to create range chosen start tailStart end endPosition
                set tailText to content of tailRange as text
                if operation is "start" then
                    set targetWindow to active window of chosen
                    if item 3 of args is true then
                        repeat 8 times
                            set targetWindow to active window of chosen
                            if window state of targetWindow is window state minimize then
                                return {endPosition, tailText}
                            end if
                            set window state of targetWindow to window state minimize
                            delay 0.15
                        end repeat
                        error "Word could not minimize the selected window." number 7002
                    end if

                    if window state of targetWindow is window state minimize then
                        set window state of targetWindow to window state normal
                    end if
                    activate object chosen
                    activate
                    repeat 8 times
                        if window state of active window of chosen is not window state minimize then
                            set frontDocument to active document
                            if my sameText((name of frontDocument as text), docName) and my sameText((full name of frontDocument as text), docPath) then
                                return {endPosition, tailText, (caption of active window of chosen as text)}
                            end if
                        end if
                        delay 0.1
                    end repeat
                    error "Word could not show the selected document window." number 7001
                end if

                set expectedPosition to item 3 of args
                set expectedTail to item 4 of args
                set removal to item 5 of args
                set insertion to item 6 of args
                if endPosition is not expectedPosition or not my sameText(tailText, expectedTail) then
                    error "The end of the Word document changed during writing. The run stopped." number 7001
                end if
                set editStart to endPosition
                set editEnd to endPosition
                if removal is not "" then
                    set editStart to item 7 of args
                    if editStart < tailStart or editStart ≥ endPosition then error "The pending correction is unavailable." number 7001
                    set editEnd to editStart + 1
                    set checkRange to create range chosen start editStart end editEnd
                    if not my sameText((content of checkRange as text), removal) then
                        error "The pending correction no longer matches." number 7001
                    end if
                end if
                set editRange to create range chosen start editStart end editEnd
                set content of editRange to insertion
                set newEnd to (end of content of text object of chosen) - 1
                set tailStart to newEnd - 48
                if tailStart < 0 then set tailStart to 0
                set tailRange to create range chosen start tailStart end newEnd
                return {newEnd, (content of tailRange as text)}
            end tell
        end timeout
    end dispatchCommand

    on sameText(leftText, rightText)
        return (id of leftText) is (id of rightText)
    end sameText
    """
}
