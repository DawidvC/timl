(* collect open variables *)

structure CollectVar = struct
open Expr

fun collect_var_aux_i_ibind f d acc (Bind (_, b) : ('a * 'b) ibind) = f (d + 1) acc b

fun collect_var_long_id d (m, (x, r)) =
  case m of
      SOME _ => [(m, (x, r))]
    | NONE =>
      if x >= d then [(NONE, (x - d, r))]
      else []
  
local
  fun f d(*depth*) acc b =
    case b of
	VarI x => collect_var_long_id d x @ acc
      | ConstIN n => acc
      | ConstIT x => acc
      | UnOpI (opr, i, r) => f d acc i
      | DivI (i, n) => f d acc i
      | ExpI (i, n) => f d acc i
      | BinOpI (opr, i1, i2) => 
        let
          val acc = f d acc i1
          val acc = f d acc i2
        in
          acc
        end
      | Ite (i1, i2, i3, r) =>
        let
          val acc = f d acc i1
          val acc = f d acc i2
          val acc = f d acc i3
        in
          acc
        end
      | TrueI r => acc
      | FalseI r => acc
      | TTI r => acc
      | IAbs (b, bind, r) =>
        collect_var_aux_i_ibind f d acc bind
      | AdmitI r => acc
      | UVarI a => acc
in
val collect_var_aux_i_i = f
fun collect_var_i_i b = f 0 [] b
end

local
  fun f d acc b =
    case b of
	True r => acc
      | False r => acc
      | Not (p, r) => f d acc p
      | BinConn (opr,p1, p2) =>
        let
          val acc = f d acc p1
          val acc = f d acc p2
        in
          acc
        end
      | BinPred (opr, i1, i2) => 
        let
          val acc = collect_var_aux_i_i d acc i1
          val acc = collect_var_aux_i_i d acc i2
        in
          acc
        end
      | Quan (q, bs, bind, r) => collect_var_aux_i_ibind f d acc bind
in
val collect_var_aux_i_p = f
fun collect_var_i_p b = f 0 [] b
end

local
  fun f d acc b =
    case b of
	Basic s => acc
      | Subset (b, bind, r) => collect_var_aux_i_ibind collect_var_aux_i_p d acc bind
      | UVarS a => acc
      | SortBigO (b, i, r) => collect_var_aux_i_i d acc i
      | SAbs (s, bind, r) => collect_var_aux_i_ibind f d acc bind
      | SApp (s, i) =>
        let
          val acc = f d acc s
          val acc = collect_var_aux_i_i d acc i
        in
          acc
        end
in
val collect_var_aux_i_s = f
fun collect_var_i_s b = f 0 [] b
end

fun collect_var_aux_t_ibind f d acc (Bind (_, b) : ('a * 'b) ibind) = f d acc b
fun collect_var_aux_i_tbind f d acc (Bind (_, b) : ('a * 'b) tbind) = f d acc b
fun collect_var_aux_t_tbind f d acc (Bind (_, b) : ('a * 'b) tbind) = f (d + 1) acc b

fun collect_var_aux_i_k d acc (_, sorts) =
  foldl (fn (s, acc) => collect_var_aux_i_s d acc s) acc sorts
                                                                        
local
  fun f d acc b =
    case b of
	Arrow (t1, i, t2) =>
        let
          val acc = f d acc t1
          val acc = collect_var_aux_i_i d acc i
          val acc = f d acc t2
        in
          acc
        end
      | TyNat (i, _) => collect_var_aux_i_i d acc i
      | TyArray (t, i) =>
        let
          val acc = f d acc t
          val acc = collect_var_aux_i_i d acc i
        in
          acc
        end
      | Unit _ => acc
      | Prod (t1, t2) =>
        let
          val acc = f d acc t1
          val acc = f d acc t2
        in
          acc
        end
      | UniI (s, bind, _) =>
        let
          val acc = collect_var_aux_i_s d acc s
          val acc = collect_var_aux_i_ibind f d acc bind
        in
          acc
        end
      | MtVar _ => acc
      | MtApp (t1, t2) =>
        let
          val acc = f d acc t1
          val acc = f d acc t2
        in
          acc
        end
      | MtAbs (k, bind, _) =>
        let
          val acc = collect_var_aux_i_k d acc k
          val acc = collect_var_aux_i_tbind f d acc bind
        in
          acc
        end
      | MtAppI (t, i) =>
        let
          val acc = f d acc t
          val acc = collect_var_aux_i_i d acc i
        in
          acc
        end
      | MtAbsI (s, bind, r) =>
        let
          val acc = collect_var_aux_i_s d acc s
          val acc = collect_var_aux_i_ibind f d acc bind
        in
          acc
        end
      | BaseType _ => acc
      | UVar _ => acc
in
val collect_var_aux_i_mt = f
fun collect_var_i_mt b = f 0 [] b
end

local
  fun f d acc b =
    case b of
	Arrow (t1, i, t2) =>
        let
          val acc = f d acc t1
          val acc = f d acc t2
        in
          acc
        end
      | TyNat (i, _) => acc
      | TyArray (t, i) => f d acc t
      | Unit _ => acc
      | Prod (t1, t2) =>
        let
          val acc = f d acc t1
          val acc = f d acc t2
        in
          acc
        end
      | UniI (s, bind, _) => collect_var_aux_t_ibind f d acc bind
      | MtVar x => collect_var_long_id d x @ acc
      | MtApp (t1, t2) =>
        let
          val acc = f d acc t1
          val acc = f d acc t2
        in
          acc
        end
      | MtAbs (k, bind, _) => collect_var_aux_t_tbind f d acc bind
      | MtAppI (t, i) => f d acc t
      | MtAbsI (s, bind, r) => collect_var_aux_t_ibind f d acc bind
      | BaseType _ => acc
      | UVar _ => acc
in
val collect_var_aux_t_mt = f
fun collect_var_t_mt b = f 0 [] b
end

end