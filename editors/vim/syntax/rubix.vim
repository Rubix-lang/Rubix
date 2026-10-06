" Vim syntax file
" Language: Rubix (*.bix)
" Maintainer: Rubix Core Team

if exists("b:current_syntax")
  finish
endif

syn keyword rubixKeyword fn let mut type enum match if else loop for in use module return fail print
syn keyword rubixType Integer Float Boolean String Void Any Int Bool Option Result Thread Mutex AtomicInt Channel
syn keyword rubixConstructor Some None Ok Err
syn keyword rubixBoolean true false
syn keyword rubixLogical and or not

syn match rubixComment "#.*$"
syn region rubixString start='"' end='"' contains=rubixEscape
syn match rubixEscape "\\." contained
syn match rubixNumber "\<\d\+\>"
syn match rubixFloat "\<\d\+\.\d\+\>"
syn match rubixOperator "[:=+\-*/%<>=!?]"

hi def link rubixKeyword Keyword
hi def link rubixType Type
hi def link rubixConstructor Structure
hi def link rubixBoolean Boolean
hi def link rubixLogical Operator
hi def link rubixComment Comment
hi def link rubixString String
hi def link rubixEscape Special
hi def link rubixNumber Number
hi def link rubixFloat Float
hi def link rubixOperator Operator

let b:current_syntax = "rubix"
