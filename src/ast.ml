module Ctx = Map.Make(String)
(* make a new module that's a list of maps? *)

type id = string
(* can a variable have the same name as a type? *)
(* type tm_id = string *)
(* type tp_id = string *)

type binop = Plus | Minus | Times | Div
type unop = Neg | Pos

(* type info =  *)

type 'a exprF = ILit of int
        | FLit of float
        | BLit of bool
        | RLit of char
        | SLit of string
        | Iden of id
        (* | TIden of tp_id *)
        | Bexp of binop * 'a * 'a
        | Uexp of unop * 'a
type expr = expr exprF

(* reverse t_rec and t_expr so that t_stmt doesn't need a type field? *)
type t_expr = t_rec exprF
and t_rec = { exp : t_expr; typ : id; }
(*type t_expr = (t_expr * id) exprF*)


type 'e assignment = (id * 'e) list

type ('e,'s) stmtF = Assign of 'e assignment
       | Print of 'e
       | If_stmt of 'e * 's list * 's list option 
       | For_stmt of ('e * ('e assignment * 'e assignment) option) option
                     * 's list
       | Empty

type stmt = (expr, stmt) stmtF
(*type t_stmt = (t_expr * id, t_stmt) stmtF*)

type declaration = Dec of id * id

type ast = Prog of stmt list
(* type t_ast = TProg of t_stmt list *)


let str_of_binop = function
  | PLUS -> "+"
  | MINUS -> "-"
  | TIMES -> "*"
  | DIV -> "/"
  | _ -> failwith "string not yet declared"

let str_of_unop = function
  | NEG -> "-"
  | _ -> failwith "string not yet declared"
