%token <int>    INT
%token <float>  FLOAT64
%token <char>   RUNE
%token <string> STRING
%token <string> IDEN

%token EOF
%token PLUS MINUS TIMES DIV PERCENT
%token BITAND BITOR CIRCUMFLEX
%token BANG ASSIGNMENT

%token LCHEVRON RCHEVRON
%token LPAREN RPAREN
%token LBRACKET RBRACKET
%token LBRACE RBRACE
%token LSHIFT RSHIFT

%token COMMA DOT SEMICOLON COLON

%token BITNAND
%token PLUSEQ MINUSEQ TIMESEQ DIVEQ PERCENTEQ AMPEQ BITOREQ BITXOREQ
%token LSHIFTEQ RSHIFTEQ BITNANDEQ

%token BOOL_AND BOOL_OR
(* %token LARROW *)
%token INC DEC
%token EQUALS NOTEQUALS
%token LTEQ GTEQ

%token COLONEQ
(* %token ELLIPSIS *)
%token BREAK
%token CASE
(* %token CHAN *)
(* %token CONST *)
%token CONTINUE
%token DEFAULT
(* %token DEFER *)
%token ELSE
(* %token FALLTHROUGH *)
%token FOR
%token FUNC
(* %token GO *)
(* %token GOTO *)
%token IF
(* %token IMPORT *)
(* %token INTERFACE *)
(* %token MAP *)
%token PACKAGE
(* %token RANGE *)
%token RETURN
(* %token SELECT *)
%token STRUCT
%token SWITCH
%token TYPE
%token VAR

(* GoLite keywords *)
(*
%token T_INT T_FLOAT64 T_BOOL T_RUNE T_STRING
*)
%token PRINT PRINTLN APPEND

%left BOOL_OR
%left BOOL_AND
%left EQUALS NOTEQUALS LCHEVRON LTEQ RCHEVRON GTEQ
%left PLUS MINUS BITOR CIRCUMFLEX
%left TIMES DIV PERCENT LSHIFT RSHIFT BITAND BITNAND
%nonassoc UOP
%nonassoc LBRACKET DOT
%nonassoc LPAREN 


%%
