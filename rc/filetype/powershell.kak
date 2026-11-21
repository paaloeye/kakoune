# https://learn.microsoft.com/en-us/powershell
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
# Ref: https://learn.microsoft.com/en-us/powershell/scripting/lang-spec/chapter-15
# 
# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.](ps1|psm1|psd1) %{
    set-option buffer filetype powershell
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook global WinSetOption filetype=powershell %<
    require-module powershell

    hook window ModeChange pop:insert:.* -group powershell-trim-indent powershell-trim-indent
    hook window InsertChar \n -group powershell-indent powershell-indent-on-new-line
    hook window InsertChar [)}] -group powershell-indent powershell-indent-on-closing
    hook -once -always window WinSetOption filetype=.* %< remove-hooks window powershell-.+ >
>

hook -group powershell-highlight global WinSetOption filetype=powershell %{
    add-highlighter window/powershell ref powershell
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/powershell }
}

provide-module powershell %§

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/powershell regions
add-highlighter shared/powershell/code default-region group

# Comments and strings. The escape character in PowerShell is the backtick, and
# a quote is also escaped by doubling it.
add-highlighter shared/powershell/block_comment region '<#'     '#>'             fill comment
add-highlighter shared/powershell/comment       region '#'      '$'              fill comment
add-highlighter shared/powershell/here_double   region '@"\h*$' '^"@'            group
add-highlighter shared/powershell/here_single   region "@'\h*$" "^'@"            fill string
add-highlighter shared/powershell/double_string region '"'      '(?<!`)(?:``)*"' group
add-highlighter shared/powershell/single_string region "'"      "'"              fill string
                                                                                                                      
add-highlighter shared/powershell/here_double/fill fill string
add-highlighter shared/powershell/here_double/escape regex '`.' 0:meta
add-highlighter shared/powershell/here_double/expansion regex '(?<!`)(?:``)*\K\$(?:(?:\w+:)?\w+|\{[^}\n]+\}|[?^$])' 0:value

add-highlighter shared/powershell/double_string/fill fill string
add-highlighter shared/powershell/double_string/escape regex '`.' 0:meta
add-highlighter shared/powershell/double_string/expansion regex '(?<!`)(?:``)*\K\$(?:(?:\w+:)?\w+|\{[^}\n]+\}|[?^$])' 0:value

# Code
add-highlighter shared/powershell/code/number              regex (?i)\b(?:0x[0-9a-f]+|\d+(?:\.\d+)?(?:e[-+]?\d+)?)(?:[kmgtp]b|[lud])?\b 0:value
add-highlighter shared/powershell/code/type                regex \[[A-Za-z_][\w.]*(?:`\d+)?(?:\[\h*,*\h*\])?\] 0:type
add-highlighter shared/powershell/code/variable            regex \$(?:(?:\w+:)?\w+|\{[^}\n]+\}|[?^$]) 0:variable
add-highlighter shared/powershell/code/splat               regex @\w+ 0:variable
add-highlighter shared/powershell/code/constant            regex (?i)\$(?:true|false|null)\b 0:value
add-highlighter shared/powershell/code/function_name       regex (?i)\b(?:function|filter|workflow)\h+(?:(?:global|script|local|private):)?([\w-]+) 1:function
add-highlighter shared/powershell/code/parameter           regex (?<=\s)-[A-Za-z]\w*:? 0:attribute
add-highlighter shared/powershell/code/keyword             regex (?i)(?<![-$\w.:])\b(?:begin|break|catch|class|clean|continue|data|define|do|dynamicparam|else|elseif|end|enum|exit|filter|finally|for|foreach|from|function|hidden|if|in|inlineScript|param|parallel|process|return|sequence|static|switch|throw|trap|try|until|using|var|while|workflow)\b(?![-:]) 0:keyword
add-highlighter shared/powershell/code/comparison_operator regex (?i)(?<=\s)-(?:[ci]?(?:eq|ne|gt|ge|lt|le|like|notlike|match|notmatch|contains|notcontains|in|notin|replace|split)|is|isnot|as|and|or|xor|not|band|bor|bxor|bnot|shl|shr|join|f)\b 0:operator
add-highlighter shared/powershell/code/symbolic_operator   regex [-+*/%=!<>|&]+|\.\.|::|\? 0:operator
add-highlighter shared/powershell/code/cmdlet              regex (?i)\b(?:Add|Approve|Assert|Backup|Block|Build|Checkpoint|Clear|Close|Compare|Complete|Compress|Confirm|Connect|Convert|ConvertFrom|ConvertTo|Copy|Debug|Deny|Disable|Disconnect|Dismount|Edit|Enable|Enter|Exit|Expand|Export|Find|Format|Get|Grant|Group|Hide|Import|Initialize|Install|Invoke|Join|Limit|Lock|Measure|Merge|Mount|Move|New|Open|Optimize|Out|Ping|Pop|Protect|Publish|Push|Read|Receive|Redo|Register|Remove|Rename|Repair|Request|Reset|Resolve|Restart|Restore|Resume|Revoke|Save|Search|Select|Send|Set|Show|Skip|Sort|Split|Start|Step|Stop|Submit|Suspend|Switch|Sync|Tee|Test|Trace|Unblock|Undo|Uninstall|Unlock|Unprotect|Unpublish|Unregister|Update|Use|Wait|Watch|Where|Write)-[A-Za-z]\w*\b 0:builtin
                                                           
# Commands
# ‾‾‾‾‾‾‾‾

define-command -hidden powershell-trim-indent %[
    # remove trailing white spaces
    try %[ execute-keys -draft -itersel x s \h+$ <ret> d ]
]

define-command -hidden powershell-indent-on-new-line %[
    evaluate-commands -draft -itersel %[
        # preserve previous line indent
        try %[ execute-keys -draft <semicolon> K <a-&> ]
        # remove trailing white spaces from the previous line
        try %[ execute-keys -draft k : powershell-trim-indent <ret> ]
        # indent after lines ending with an opening bracket or a here-string opener
        try %[ execute-keys -draft , k x <a-k> [{(]\h*$ <ret> j <a-gt> ]
        # deindent a closing bracket that follows the cursor
        try %[ execute-keys -draft x <a-k> ^\h*[)}] <ret> gh / [)}] <ret> m <a-S> 1<a-&> ]
    ]
]

define-command -hidden powershell-indent-on-closing %[
    # align a lone closing bracket with its opening line
    evaluate-commands -draft -itersel %[
        try %[ execute-keys -draft <a-h> <a-k> ^\h+[)}]$ <ret> h m <a-S> 1<a-&> ]
    ]
]

§
