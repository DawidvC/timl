structure MergeModules = struct

fun merge_module (mid, m(* , ctx as (sctx, kctx, cctx, tctx) *)) acc =
  case m of
      ModComponents (decls, _) =>
      let
        val acc = unpackage_e_decls mid 0 acc
        val acc = unpackage_c_decls mid 0 acc
        val acc = unpackage_t_decls mid 0 acc
        val acc = unpackage_i_decls mid 0 acc
      in
        decls @ acc
      end
    | _ => raise Unimpl "merge_module"
        
fun do_merge_modules ms decls = foldr merge_module decls ms

fun remove_Top_DAbsIdx2 m =
  case m of
      ModComponents (decls, r) =>
      let
        fun on_decl d =
          case d of
              DAbsIdx2 a =>
              let
                val () = println "Warning: can't translate module-level [absidx] yet. They will be converted to [idx]"
              in
                DAbsIdx a
              end
            | _ => d
        val decls = app on_decl decls
      in
        ModComponents (decls, r)
      end
    | _ => raise Unimpl "remove_Top_AbsIdx2"
  

open RemoveOpen
       
fun merge_modules ms decls =
  let
    val decls = remove_DOpen_decls decls
    val ms = map (mapSnd remove_DOpen_m) ms
    val ms = map (mapSnd remove_Top_DAbsIdx2) ms
  in
    do_merge_modules ms decls
  end
    
end
