open Ast
open Context
open Ho 
open AuxFunctions
(* open ToBase *)

type auxVal = (string * int * string * Context.info) list
(* key: fName, val: name * depth * typName * typ *)
let auxTable : (string, auxVal) Hashtbl.t = Hashtbl.create 1337
let currFName = ref "_main_" (* change name? *)
(* let mklist() = Hashtbl.add auxTable !currFName [] *)

let tadd name kind ctx =
  let fList = try Hashtbl.find auxTable !currFName with
               | Not_found -> []
  in
  add name kind ctx;
  let depth = scope_depth (get_scope name ctx) in
  (* let wastTyp = "i64" in (\* change this to get wast type!! *\) *)
  let t1,t2 = match find name ctx with
    | Some(typ) -> (Context.typ_to_str typ, typ)
    | _ -> failwith "not found"
  in
  Hashtbl.add auxTable !currFName (fList@[(name,depth,t1,t2)])
  (* optimize this later? *)

let typecheck_error pos msg = Error.print_error pos ("[typecheck] " ^ msg)

let rec valid_return_path stmts =
  let rec inner ebreak (econt,path_safe) stmt = match stmt with
    | (Return(_),_)  -> (false, true)
    | (Continue,_)   -> (true, false)
    | (Break,_)      -> ebreak
    | (For_stmt(po1, eo, po2, ps),_) -> 
       (List.fold_left (inner (econt, path_safe))
                       (econt, path_safe)
                       (List.rev ps))
      
    | (Switch_stmt(_, _, ps),_) -> 
      let cases = List.map (inner (econt,path_safe) (econt,path_safe)) ps in
      let cont = List.map fst cases in
      let rc = (List.fold_left (fun acc x -> acc && x) true cont) in
      let rp = (List.fold_left (fun acc (tc,tp) -> acc && ((not tc) && tp)) true cases) in
      (rc, rp)

    | (Block(ps),_)
    | (Switch_clause(_, ps),_) ->
      (List.fold_left (inner ebreak)
                      (econt,path_safe)
                      (List.rev ps))
 
    | (If_stmt(po,e,ps,pso),_) ->
       let (tc,tp) = (List.fold_left
                      (inner ebreak)
                      (econt,path_safe)
                      (List.rev ps))
       in
       let (ec,ep) = (defaulto
                      (List.fold_left
                       (inner ebreak)
                       (econt,path_safe))
                      (econt,path_safe)
                      (mapo List.rev pso))
       in
       (tc && ec, ((not tc)&& tp) && ((not ec)&&ep))
    | _ -> (econt, path_safe)

  in
  let (tc,tr) = List.fold_left (inner (false,false)) (false,false) (List.rev stmts) in
  tr

let typeAST (Prog((pkg,_),decls) : Untyped.ast) =

  let rec tTyp g (t:Untyped.uttyp): Typed.uttyp =
   match t with
    | TSimp((i,p)) -> if in_context i g
                      then TSimp(i, get_scope i g)
                      else typecheck_error p "Use of undefined type"
    | TStruct(tl) ->
       let rec tc l acc = match l with
         | (("_",p),_)::xs -> tc xs acc
         | ((i,p),_)::xs -> if List.mem i acc
                            then typecheck_error p "Duplicate field in struct definiton"
                            else tc xs (i::acc)
         | [] -> ()
       in
       tc tl [];
       TStruct(List.map (fun ((i,_), t) -> (i, tTyp g t)) tl)
    | TArray(at,s) -> TArray(tTyp g at, s)
    | TSlice(st) -> TSlice(tTyp g st)
    | TFn(args, rtn) -> TFn(List.map (tTyp g) args, tTyp g rtn)
    | TKind(t) -> TKind(tTyp g t)
    | TVoid -> TVoid
  in

  (* let rec tExpr gamma = function *)
  let rec tExpr g (e,pos) : Typed.annotated_texpr =
  match e with
    | ILit(d) -> (ILit d, (pos, sure (get_type_instance "int" g), g))
    | FLit(f) -> (FLit f, (pos, sure (get_type_instance "float64" g), g))
    | RLit(c) -> (RLit c, (pos, sure (get_type_instance "rune" g), g))
    | SLit(s) -> (SLit s, (pos, sure (get_type_instance "string" g), g))
    (* | Parens(e) -> 
       let (_,(_,typ)) as te = tExpr g e in
       (Parens te, (pos, typ)) *)
    | Bexp(op,e1,e2) -> 
       let (_,(_,typ1,_)) as te1 = tExpr g e1 in
       let (_,(_,typ2,_)) as te2 = tExpr g e2 in       
       (* let base = unify g typ1 typ2 in *)
       let base = if same_type typ1 typ2
       then typ1
       else typecheck_error pos "Mismatched type"
       in (* allow for defined types *)
       let t = 
         (match op with
          | Boolor
            | Booland   when isBool base  -> sure (get_type_instance "bool" g)
          | Equals
            | Notequals	when isComparable base -> sure (get_type_instance "bool" g)
          | Lt
            | Lteq	
            | Gt
            | Gteq 	when isOrdered base -> sure (get_type_instance "bool" g)
          | Plus        when isString base  -> base
          | Plus
            | Minus	
            | Times	
            | Div
            | Modulo	when isNumeric base -> base
          | Bitor
            | Bitxor
            | Lshift
            | Rshift
            | Bitand
            | Bitnand 	when isInteger base -> base
          | _ -> typecheck_error pos
                 (Printf.sprintf
                  "Mismatch with '%s' operation: %s %s %s"
                  (bop_to_str op)
                  (typ_to_str typ1)
                  (bop_to_str op)
                  (typ_to_str typ2)))

       in (Bexp(op,te1,te2), (pos, t, g))

    | Uexp(op,e) -> 
       let (_,(_,typ,_)) as te = tExpr g e in
       let base = if true then typ else failwith "not done" in (* check defined types *)
       let t = (match op with
                | Positive	when isNumeric base -> base
                | Negative	when isNumeric base -> base
                | Boolnot	when isBool base -> base
                | Bitnot	when isInteger base -> base
                | _ -> typecheck_error pos ("Mismatch with '" ^ uop_to_str op ^ "' operation"))
                 (* change to allow for new types *)
                 (* let te = typeExpr gamma e *)
       in (Uexp(op,te), (pos, t, g))

   (* | Fn_call((Iden((x,ipos)),_), [e]) when defaulto isCastable false (find x g) ->*)
    | Fn_call((Iden((x,ipos)),_),[e]) when defaulto isCastable false (get_type_instance x g)->
       let (_,(_,t,_)) as te = tExpr g e in
       if (isCastable t)
       then
         let tx = sure (get_type_instance x g) in
         (Fn_call((Iden(x), (ipos, TKind(tx),get_scope x g)), [te]), (pos, tx, g))
       else typecheck_error pos ("Type `" ^ (typ_to_str t) ^ "` is not castable")

    | Fn_call(fid, es) -> 
       let (_,(_,t,_)) as tfid = tExpr g fid in
       let (fargs,ft) = begin
         match t with
          | TFn(fargs,ft) -> (fargs,ft)
          | _ -> ([TVoid], TVoid)
       end in
       let texps = List.map (tExpr g) es in
       let tes = List.map (fun (_, (_,t,_)) -> t) texps in
       let typecheck_args ta te = begin
         if not (same_type ta te) 
         then typecheck_error pos ("Function argument mistmatch between "^typ_to_str ta^" and "^typ_to_str te)
         else ()
       end in
       (try
          List.iter2 typecheck_args fargs tes
        with
         | _ -> typecheck_error pos ("Wrong number of arguments"));
       (Fn_call(tfid,texps), (pos, ft, g))

    (* append id? *)
    | Append((i,ipos), e) ->
       let t = (match find i g with
       (* let t = (match mapo sTyp2 (find i g) with *)
         | Some(TSlice(t)) -> t
         | Some(t) -> begin
             match get_base_type t with
               | Some(TSlice(t)) -> t
               | _ -> typecheck_error pos  ("`" ^ i ^ "` must be a slice")
           end
         | None -> typecheck_error ipos ("variable `" ^ i ^ "` is undefined"))
       in
       let (_,(_,typ,_)) as te = tExpr g e in
       if same_type t typ then begin
          (Append((i),te), (pos, TSlice t, g))
       end else
          typecheck_error pos ("Mismatch in slice between \"" ^ typ_to_str t ^ "\" and \"" ^ typ_to_str typ)

    | Iden(i, ipos) -> begin
        (* let (typo,ind) = find i g in *)
        (* match typo with !!!*)
        match find i g with
          | Some(t) -> (Iden(i), (pos, t, (get_scope i g)))
          | None -> typecheck_error ipos ("variable `" ^ i ^ "` is undefined")
      end
    | AValue(r,e) ->
       let (_,(p1,typ1,_)) as tr = tExpr g r in
       let (_,(p2,typ2,_)) as te = tExpr g e in
       let ot = (match sure (get_base_type typ1) with
         | TArray(t,_)
         | TSlice(t) -> t
         | _ -> typecheck_error p1 "Non-indexable value");
       in
       (if same_type typ2 (sure (get_type_instance "int" g))
        then (AValue(tr,te), (pos, ot, g))
        else typecheck_error p2 "Array index must have type int");

    | SValue(e, (i,ip)) ->
       let te = tExpr g e in
       let (_,(_,etyp,_)) = te in
      
       let (_,ftyp) = (match sure (get_base_type etyp) with
         | TStruct(tl) -> begin
             try
               List.find (function | (f,_) -> i=f) tl
             with 
              |   Not_found -> typecheck_error ip ("Invalid struct field `"^i^"`")
           end
         | _ -> typecheck_error pos "Expression not of type struct")
       in
       (SValue(te,(i)), (pos, ftyp, g))
  in


  let rec tStmt frt g ((p, pos): Untyped.annotated_utstmt) : Typed.annotated_utstmt = match p with 
    | Assign(xs,es) -> 
       (* let txs = List.map (tExpr g) xs in *)
       let tes = List.map (tExpr g) es in
       let zipped = zip xs tes in
       let check_assign = function
         | ((Iden(("_",p)),_), (e,(ep,et,_))) -> (Iden("_"),(p,et,g))
         | (lhs, (e,(ep,et,_))) ->
              let (_,(_,t,_)) as tlhs = (tExpr g lhs) in
              if not (same_type t et)
              then typecheck_error pos "Type mismatch in assign"
              else tlhs
       in
       let txs = List.map check_assign zipped in
       (Assign(txs, tes), (pos, g))
    | Print(es) -> 
      let texps = List.map (tExpr g) es in
      (List.iter (fun (_,(p,t,_)) ->
                   if not (isBaseType (sTyp t))
                   then typecheck_error p "Print argument not of base type") texps);
      (Print(texps), (pos, g))
    | Println(es) ->
      let texps = List.map (tExpr g) es in
      (List.iter (fun (_,(p,t,_)) ->
                   if not (isBaseType (sTyp t))
                   then typecheck_error p "Print argument not of base type") texps);
      (Println(texps), (pos, g))
    | If_stmt(po,e,ps,pso) ->
       let tinit = mapo (tStmt frt g) po in
       let (_,(_,typ,_)) as tcond = tExpr g e in
       let btyp = sTyp2 typ in
       if not (same_type btyp (sure (get_type_instance "bool" g)))
       then typecheck_error pos "If condition must have type bool";
       let gthen = scope g in
       let tthen = List.map (tStmt frt gthen) ps in
       unscope gthen;
       let gelse = scope g in
       let telse = (match pso with
           | Some(ps) -> Some((List.map (tStmt frt gelse)) ps)
           | None -> None)
       in
       unscope gelse;
       (If_stmt(tinit, tcond, tthen, telse), (pos,g))

    | Switch_stmt(po, None, ps) -> 
       let tpo = mapo (fun p -> tStmt frt g p) po in
       let check_clause = function
         | (Switch_clause(Some(exps), ps),p) ->
             let es = List.map (tExpr g) exps in
             List.iter
              (fun (_,(p,t,_)) ->
                 if not (same_type t (sure (get_type_instance "bool" g)))
                 then typecheck_error p "Cases expression does not match switch")
               es;
             let g' = scope g in
             (Switch_clause(Some(es), List.map (tStmt frt g') ps), (p, g))
         | (Switch_clause(None, ps),p) ->
             let g' = scope g in
             (Switch_clause(None, List.map (tStmt frt g') ps), (p, g))
         | (_,p) -> typecheck_error p "Unexpected statement in switch clause"
       in

       let clauses = List.map check_clause ps in
       (Switch_stmt(tpo, None, clauses), (pos, g))

    | Switch_stmt(po, Some(exp), ps) -> 
       let tpo = mapo (fun p -> tStmt frt g p) po in
       let (_,(_,et,_)) as teo = (fun e -> tExpr g e) exp in

       let check_clause = function
         | (Switch_clause(Some(exps), ps),p) ->
             let es = List.map (tExpr g) exps in
             List.iter
              (fun (_,(p,t,_)) ->
                 if not (same_type t et)
                 then typecheck_error p "Cases expression does not match switch")
               es;
             let g' = scope g in
             (Switch_clause(Some(es), List.map (tStmt frt g') ps), (p,g))
         | (Switch_clause(None, ps),p) ->
             let g' = scope g in
             (Switch_clause(None, List.map (tStmt frt g') ps), (p,g))
         | (_,p) -> typecheck_error p "Unexpected statement in switch clause"
       in

       let clauses = List.map check_clause ps in
       (Switch_stmt(tpo, Some(teo), clauses), (pos,g))
(*
       let tps = List.map (tStmt frt g) ps in
       (* check that parent has same type as children *)
       let _ = (match teo,ps with
                | Some(pare), [Switch_clause(Some(exps), ps),pos1] ->
                   let g' = scope g in
                   let teso = pare::(List.map (tExpr g') exps) in
                   let _ = if all_same (fun x -> snd (snd x)) teso then ()
                           else typecheck_error pos1 "Type mismatch in switch" in
                   ()
                | _ -> ()) in
*)
    (* at some point, we don't need to have the the following two cases, leaving them here for now *)
    | Switch_clause(Some(exps), ps) ->
       let g' = scope g in
       let teso = (List.map (tExpr g') exps) in
       let _ = if all_same (fun (_,(_,t,_)) -> t) teso then ()
               else typecheck_error pos "Type mismatch in switch" in
       let tps = List.map (tStmt frt g') ps in
       (Switch_clause(Some(teso), tps),(pos, g))
    | Switch_clause(None, ps) ->
       let tps = List.map (tStmt frt g) ps in
       (Switch_clause(None, tps),(pos,g))

    | For_stmt(po1, eo, po2, ps) -> 
       let tpo1 = match po1 with
                   | Some(p) -> Some(tStmt frt g p)
                   | None -> None
       in
       let teo  = mapo (tExpr g) eo in

       (match teo with 
         | None -> ()
         | Some(_,(_,t,_)) when (same_type (sTyp2 t) (sure (get_type_instance "bool" g))) -> ()
         | _ -> typecheck_error pos "Condition is not a boolean expression");

       let tpo2 = (match po2 with
                   | Some(p) -> Some(tStmt frt g p)
                   | None -> None)
       in
       let ng = scope g in
       let tps  = List.map (tStmt frt ng) ps in
       (For_stmt(tpo1, teo, tpo2, tps), (pos,g))

    | Var_stmt(decls) ->
       let tc_vardecl ((i,ipos), e, t) =
         if in_scope i g then typecheck_error ipos ("Variable \""^ i ^"\" already declared in scope");
         
         let te = match e with
           | None -> None
           | Some(e) -> Some(tExpr g e)
         in
         let tt = match te, t with
           | None, None -> typecheck_error ipos "Neither type or expression provided to variable declaration"
           | None, Some(t) -> tTyp g t
           | Some((e,(_,etyp,_))), Some(t) ->
               let tt = tTyp g t in 
               if same_type etyp tt
               then tt
               else typecheck_error ipos ("Conflicting type for variable declaration `" ^ i ^ "`")
           | Some((_,(_,etyp,_))), None -> etyp
         in
         (if is_type tt
          then ()
          else typecheck_error ipos ("Invalid type for `" ^ i ^ "`"));
         tadd i tt g;
         (* (i, te, Some(tt), newIndex()) *)
         (i, te, Some(tt))
       in

       let ls = List.map (List.map tc_vardecl) decls in
       (Var_stmt(ls), (pos,g))

    | SDecl_stmt(ds) ->
       let tds = List.map (fun ((i,_), e) -> (i, tExpr g e)) ds in

       List.iter (function
                   | (_, (_,(p,TVoid,_))) -> 
                     typecheck_error p "Cannot assign void"
                   | _ -> ())
                 tds;

       if not (List.exists (function
                             | ("_", _) -> false
                             | (i, _) ->  not (in_scope i g))
                           tds)
       then typecheck_error pos "Short declaration should define at least one new variable";
       let rec tc l acc = match l with
         | (("_",p),_)::xs -> tc xs acc
         | ((i,p),_)::xs -> if List.mem i acc
                            then typecheck_error p "Duplicate lhs in short declaration"
                            else tc xs (i::acc)
         | [] -> ()
       in
       tc ds [];

       List.iter (fun (i, (e,(_,te,_))) ->
                   if (in_scope i g)
                   then match find i g with
                     | None -> () (* Impossible *)
                     | Some(t) -> begin
                        if not (same_type t te)
                        then typecheck_error pos ("Type mismatch with variable `" ^ i ^ "`")
                       end
                   else
                     tadd i te g)
                 tds;

       (SDecl_stmt(tds), (pos,g))

    | Type_stmt(typ_decls) -> 
       let tl = List.map (fun (i, t) -> (i,TKind(tTyp g t))) typ_decls in
       let tl = List.map
                  (fun ((i,ipos), t) ->
                    if in_scope i g
                    then typecheck_error ipos ("Type `" ^ i ^ "` already declared in scope")
                    else (tadd i t g; (i,t)))
                  tl
       in
       (Type_stmt(tl), (pos,g))
    | Expr_stmt e ->
       let te = tExpr g e in
       (Expr_stmt(te),(pos,g))
    | Return(None) ->
       if not (same_type frt TVoid)
       then typecheck_error pos "Function should return a value"
       else (Return(None),(pos,g))
    | Return(Some(e)) ->
       let (_,(_,typ,_)) as te = tExpr g e in
       if same_type frt typ
       then (Return(Some(te)), (pos,g))
       else typecheck_error pos "Unexpected return type"
    | Break -> (Break, (pos,g))
    | Block(stmts) ->
       let ng = scope g in 
       let tstmts = List.map (tStmt frt ng) stmts in
       unscope ng;
       (Block(tstmts), (pos,g))
    | Continue -> (Continue, (pos,g))
    | Empty_stmt -> (Empty_stmt, (pos,g))

  in


  let rec tDecl g ((d,pos): Untyped.annotated_utdecl) : Typed.annotated_utdecl = match d with

    | Var_decl(decls) -> 
       let tc_vardecl ((i,ipos), e, t) =
         let te = match e with
           | None -> None
           | Some(e) -> Some(tExpr g e)
         in

         (if in_scope i g then typecheck_error ipos ("Variable \""^ i ^"\" already declared in scope"));
         
         let tt = match te, t with
           | None, None -> typecheck_error ipos "Neither type or expression provided to variable declaration"
           | None, Some(t) -> tTyp g t
           | Some((e,(_,etyp,_))), Some(t) ->
               let tt = tTyp g t in 
               if same_type etyp tt
               then tt
               else typecheck_error ipos ("Conflicting type for variable declaration " ^ i)
           | Some((_,(_,etyp,_))), None -> etyp
         in
         (if is_type tt
          then ()
          else typecheck_error ipos ("Invalid type for `" ^ i ^ "`"));
         tadd i tt g;
         (i, te, Some(tt))
       in

       let ls = List.map (List.map tc_vardecl) decls in
       (Var_decl(ls), pos)




    | Type_decl(typ_decls) -> 
       let tl = List.map (fun (i, t) -> (i,TKind(tTyp g t))) typ_decls in
       let tl = List.map
                  (fun ((i,ipos), t) ->
                    if in_scope i g
                    then typecheck_error ipos ("Type `" ^ i ^ "` already declared in scope")
                    else (tadd i t g; (i,t)))
                  tl
       in
       (Type_decl(tl), pos)
    | Func_decl((fId,_), args, typ, stmts) ->
       currFName := fId;
       (* mklist(); *)
       (* indexCount := List.length args; *)
       if in_scope fId g
       then typecheck_error pos ("Function \"" ^ fId ^ "\" already declared")
       else begin
           
           let targs = List.map (fun((i,ipos), t) ->
                                  let vt = tTyp g t in
                                  if not (is_type vt)
                                  then typecheck_error ipos ("Function argument doesn't have a valid type")
                                   (* ((i,ipos), vt, newIndex ())) args in *)
                                  else ((i,ipos), vt))
                                args
           in
           let tl = List.map snd targs in
           let rtntyp = tTyp g typ in
           
           add fId (TFn(tl, rtntyp)) g;

           let ng = scope g in  
           let targs1 = List.map (fun((i,ipos),t) ->
                           if in_scope i ng
                           then typecheck_error
                                  ipos
                                  ("Parameter name `" ^ i ^ "` use twice")
                           else (add i t ng; (i, t)))
                                targs
           in

         let tstmts = List.map (tStmt rtntyp ng) stmts in
         (match typ with
          | TVoid -> ()
          | _ -> if not (valid_return_path tstmts)
                 then typecheck_error pos ("Execution paths with no returns in function"));

         unscope ng;
         currFName := "_main_";
         (Func_decl(fId, targs1, rtntyp, tstmts), pos)
       end


    (* | Func_decl((fId,_), args, typ, stmts) -> *)
    (*    currFName := fId; *)
    (*    (\* mklist(); *\) *)
    (*    (\* indexCount := List.length args; *\) *)
    (*    if in_scope fId g *)
    (*    then typecheck_error pos ("Function \"" ^ fId ^ "\" already declared") *)
    (*    else begin *)
           
    (*        let targs = List.map (fun((i,ipos), t) -> let vt = tTyp g t in *)
    (*                                                      (\* ((i,ipos), vt, newIndex ())) args in *\) *)
    (*                                                      ((i,ipos), vt)) args in *)
    (*        let tl = List.map snd targs in *)
    (*        let rtntyp = tTyp g typ in *)
           
    (*        add fId (TFn(tl, rtntyp)) g; *)

    (*        let ng = scope g in   *)
    (*        let targs1 = List.map (fun((i,ipos),t) -> *)
    (*                         if in_scope i ng *)
    (*                         then typecheck_error *)
    (*                                ipos *)
    (*                                ("Parameter name `" ^ i ^ "` use twice") *)
    (*                         else *)
    (*                           (match sTyp t with *)
    (*                            | TKind(_) -> (add i t ng; (i, t)) *)
    (*                            | _ -> typecheck_error ipos  *)
    (*                                                   ("Parameter type of `" ^ i ^ "` is not valid") *)
    (*                       )) targs *)
    (*        in *)

    (*        let tstmts = List.map (tStmt rtntyp ng) stmts in *)
    (*        (match typ with *)
    (*         | TVoid -> () *)
    (*         | _ -> if not (valid_return_path tstmts) *)
    (*                then typecheck_error pos ("Execution paths with no returns in function")); *)

    (*        unscope ng; *)
    (*        currFName := "_main_"; *)
    (*        (Func_decl(fId, targs1, rtntyp, tstmts), pos) *)
    (*      end *)

  and tDecls gamma ds = List.map (tDecl gamma) ds
  in
  let ctx = (init ()) in begin
      tadd "int"     (TKind (TSimp("#",ctx))) ctx;
    tadd "bool"    (TKind (TSimp("#",ctx))) ctx;
    tadd "string"  (TKind (TSimp("#",ctx))) ctx;
    tadd "rune"    (TKind (TSimp("#",ctx))) ctx;
    tadd "float64" (TKind (TSimp("#",ctx))) ctx;
    tadd "true"    (sure (get_type_instance "bool" ctx)) ctx;
    tadd "false"   (sure (get_type_instance "bool" ctx)) ctx;
    let decls = tDecls (scope ctx) decls in
    unscope ctx;
    unscope ctx;
    (Prog(pkg, decls), auxTable)
  end

