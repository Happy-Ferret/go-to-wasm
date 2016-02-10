{
  open Lexing
  open Parser

  let insert_semic = ref false

  let keywords = ["break"; "case"; "chan"; "const"; "continue"; "default";
                  "defer"; "else"; "fallthrough"; "for"; "func"; "go"; "goto";
                  "if"; "import"; "interface"; "map"; "package"; "range";
                  "return"; "select"; "struct"; "switch"; "type"; "var";
                  "int"; "float64"; "bool"; "rune"; "string";
                  "print"; "println"; "append"]
}

let ascii     = ['A'-'Z' 'a'-'z' '0'-'9' ' ' '!' '"' '#' '$' '%' '&' '\''
                 '(' ')' '*' '+' ',' '-' '.' '/' ':' ';' '<' '=' '>' '?'
                 '@' '[' '\\' ']' '^' '_' '`' '{' '|' '}' '~']

let eol       = '\r' | '\n' | ('\r' '\n')
let letter    = ['A'-'Z' 'a'-'z' '_']
let dec_digit = ['0'-'9']
let oct_digit = ['0'-'7']
let hex_digit = ['0'-'9' 'A'-'F' 'a'-'f']
let esc_char  = '\\' ('a' | 'b' | 'f' | 'n' | 'r' | 't' | 'v' | '\\' | '\'')
let r_str_lit = '`' (ascii | esc_char)* '`'
let i_str_lit = '"' ascii* '"'

let int_lit   = dec_digit+ | oct_digit+ | hex_digit+
let flt_lit   = (dec_digit+ '.' dec_digit*) | '.'? dec_digit+
let bool_lit  = "true" | "false"
let rune_lit  = ascii | esc_char
let str_lit   = r_str_lit | i_str_lit
let ident     = letter (letter | dec_digit)*

rule token = parse
  | eof           { EOF }
  | [' ' '\t']+   { token lexbuf }

(* Go keywords *)
  | "break"       { insert_semic:=true;  BREAK }
  | "case"        { insert_semic:=false; CASE }
  | "chan"        { insert_semic:=false; CHAN }
  | "const"       { insert_semic:=false; CONST }
  | "continue"    { insert_semic:=true;  CONTINUE }
  | "default"     { insert_semic:=false; DEFAULT }
  | "defer"       { insert_semic:=false; DEFER }
  | "else"        { insert_semic:=false; ELSE }
  | "fallthrough" { insert_semic:=true;  FALLTHROUGH }
  | "for"         { insert_semic:=false; FOR }
  | "func"        { insert_semic:=false; FUNC }
  | "go"          { insert_semic:=false; GO }
  | "goto"        { insert_semic:=false; GOTO }
  | "if"          { insert_semic:=false; IF }
  | "import"      { insert_semic:=false; IMPORT }
  | "interface"   { insert_semic:=false; INTERFACE}
  | "map"         { insert_semic:=false; MAP }
  | "package"     { insert_semic:=false; PACKAGE }
  | "range"       { insert_semic:=false; RANGE }
  | "return"      { insert_semic:=true;  RETURN }
  | "select"      { insert_semic:=false; SELECT }
  | "struct"      { insert_semic:=false; STRUCT }
  | "switch"      { insert_semic:=false; SWITCH }
  | "type"        { insert_semic:=false; TYPE }
  | "var"         { insert_semic:=false; VAR }

(* GoLite keywords *)
  | "int"         { insert_semic:=false; T_INT }
  | "float64"     { insert_semic:=false; T_FLOAT64 }
  | "bool"        { insert_semic:=false; T_BOOL }
  | "rune"        { insert_semic:=false; T_RUNE }
  | "string"      { insert_semic:=false; T_STRING }
  | "print"       { insert_semic:=false; PRINT }
  | "println"     { insert_semic:=false; PRINTLN }
  | "append"      { insert_semic:=false; APPEND }

(* Operators *)
  | '+'           { insert_semic:=false; PLUS }
  | '-'           { insert_semic:=false; MINUS }
  | '*'           { insert_semic:=false; TIMES }
  | '/'           { insert_semic:=false; DIV }
  | '%'           { insert_semic:=false; PERCENT }
  | '&'           { insert_semic:=false; BITAND }
  | '|'           { insert_semic:=false; BITOR }
  | '^'           { insert_semic:=false; CIRCUMFLEX }
  | '<'           { insert_semic:=false; LCHEVRON }
  | '>'           { insert_semic:=false; RCHEVRON }
  | '='           { insert_semic:=false; ASSIGNMENT }
  | '!'           { insert_semic:=false; BANG }
  | '('           { insert_semic:=false; LPAREN }
  | ')'           { insert_semic:=true;  RPAREN }
  | '['           { insert_semic:=false; LBRACKET }
  | ']'           { insert_semic:=true;  RBRACKET }
  | '{'           { insert_semic:=false; LBRACE }
  | '}'           { insert_semic:=true;  RBRACE }
  | ','           { insert_semic:=false; COMMA }
  | '.'           { insert_semic:=false; DOT }
  | ';'           { insert_semic:=false; SEMICOLON }
  | ':'           { insert_semic:=false; COLON }
  | "<<"          { insert_semic:=false; LSHIFT }
  | ">>"          { insert_semic:=false; RSHIFT }
  | "&^"          { insert_semic:=false; BITNAND }
  | "+="          { insert_semic:=false; PLUSEQ }
  | "-="          { insert_semic:=false; MINUSEQ }
  | "*="          { insert_semic:=false; TIMESEQ }
  | "/="          { insert_semic:=false; DIVEQ }
  | "%="          { insert_semic:=false; PERCENTEQ }
  | "&="          { insert_semic:=false; AMPEQ }
  | "|="          { insert_semic:=false; BITOREQ }
  | "^="          { insert_semic:=false; BITNOTEQ }
  | "<<="         { insert_semic:=false; LSHIFTEQ }
  | ">>="         { insert_semic:=false; RSHIFTEQ }
  | "&^="         { insert_semic:=false; BITNANDEQ }
  | "&&"          { insert_semic:=false; BOOL_AND }
  | "||"          { insert_semic:=false; BOOL_OR }
  | "<-"          { insert_semic:=false; LARROW }
  | "++"          { insert_semic:=true;  INC }
  | "--"          { insert_semic:=true;  DEC }
  | "=="          { insert_semic:=false; EQUALS }
  | "!="          { insert_semic:=false; NOTEQUALS }
  | "<="          { insert_semic:=false; LTEQ }
  | ">="          { insert_semic:=false; GTEQ }
  | ":="          { insert_semic:=false; COLONEQ }
  | "..."         { insert_semic:=false; ELLIPSIS }

(* Comments *)
  | "//" [^'\r''\n']*                { token lexbuf }
  | "/*" ([^'*'] | "*" [^'/'])* "*/" { token lexbuf }

(* Literals *)
  | int_lit as n  { insert_semic:=true; INT (int_of_string n) }
  | flt_lit as f  { insert_semic:=true; FLOAT64 (float_of_string f) }
  | bool_lit as b { insert_semic:=true; BOOL (bool_of_string b) }
  | rune_lit as c { insert_semic:=true; RUNE c.[0] }
  | str_lit as s  { insert_semic:=true; STRING s }

(* Identifiers *)
  | ident as x {
      let l = String.lowercase x in
      if List.mem l keywords
      then Error.print_error
        lexbuf.lex_curr_p
        (Printf.sprintf "cannot use reserved word '%s' as identifier" x)
      else (insert_semic:=true; ID x)
    }

(* Semicolons *)
  | eol {
      new_line lexbuf;
      if !insert_semic
      then (insert_semic:=false; SEMICOLON)
      else (insert_semic:=false; token lexbuf)
    }

(* Unknown *)
  | _ {
      Error.print_error
        lexbuf.lex_curr_p
        (Printf.sprintf "unexpected token '%s'" (lexeme lexbuf))
    }
