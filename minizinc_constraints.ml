(****************************************************************************)
(*                                                                          *)
(*    This file is part of Zephyrus.                                        *)
(*                                                                          *)
(*    Zephyrus is free software: you can redistribute it and/or modify      *)
(*    it under the terms of the GNU General Public License as published by  *)
(*    the Free Software Foundation, either version 3 of the License, or     *)
(*    (at your option) any later version.                                   *)
(*                                                                          *)
(*    Zephyrus is distributed in the hope that it will be useful,           *)
(*    but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*    GNU General Public License for more details.                          *)
(*                                                                          *)
(*    You should have received a copy of the GNU General Public License     *)
(*    along with Zephyrus.  If not, see <http://www.gnu.org/licenses/>.     *)
(*                                                                          *)
(****************************************************************************)

open Helpers

open Aeolus_types_t
open Aeolus_types_output.Plain

open Typing_context
open Variable_keys



let cost_var_name = "cost_var"

let sanitize_name name =
  let lowercased_name = String.lowercase name
  in
  BatString.filter_map (fun c ->
    match c with 
    | 'a'..'z' -> Some c 
    | '0'..'9' -> Some c
    | '@'
    | ' '      -> None
    | _        -> Some '_'
  ) lowercased_name

let string_of_element element =
  match element with
  | ComponentType (component_type_name) -> Printf.sprintf "component_type_%s" (string_of_component_type_name component_type_name)
  | Port          (port_name)           -> Printf.sprintf "port_%s"           (string_of_port_name           port_name)
  | Package       (package_name)        -> Printf.sprintf "package_%s"        (string_of_package_name        package_name)

let string_of_variable_key variable_key =
  match variable_key with
  | GlobalElementVariable   (element) ->
      Printf.sprintf 
        "global_element_%s" 
        (sanitize_name (string_of_element element))

  | LocalElementVariable    (location_name, element) ->
      Printf.sprintf
        "local_element_%s_%s"
        (sanitize_name (string_of_location_name location_name))
        (sanitize_name (string_of_element element))

  | BindingVariable         (port_name, providing_component_type_name, requiring_component_type_name) ->
      Printf.sprintf
        "binding_%s_%s_%s"      
        (sanitize_name (string_of_port_name           port_name))
        (sanitize_name (string_of_component_type_name providing_component_type_name))
        (sanitize_name (string_of_component_type_name requiring_component_type_name))

  | LocalRepositoryVariable (location_name, repository_name) ->
      Printf.sprintf
        "local_repository_%s_%s"
        (sanitize_name (string_of_location_name   location_name))
        (sanitize_name (string_of_repository_name repository_name))

  | LocalResourceVariable   (location_name, resource_name) ->
      Printf.sprintf
        "local_resource_%s_%s"
        (sanitize_name (string_of_location_name location_name))
        (sanitize_name (string_of_resource_name resource_name))

  | SpecificationVariable   (spec_variable_name) ->
      Printf.sprintf 
        "spec_var_%s"
        (sanitize_name (string_of_spec_variable_name spec_variable_name))

let create_minizinc_variable variable_key =
  (variable_key, string_of_variable_key variable_key)

let create_minizinc_variables variable_keys =
  (List.map create_minizinc_variable variable_keys)

let get_minizinc_variable minizinc_variables variable_key =
  List.assoc variable_key minizinc_variables

let get_minizinc_variable_reverse minizinc_variables minizinc_variable =
  try
    if minizinc_variable = cost_var_name 
    then None
    else Some (BatList.assoc_inv minizinc_variable minizinc_variables)
  with
  | Not_found -> failwith (Printf.sprintf "get_minizinc_variable_reverse: no minizinc variable \"%s\"" minizinc_variable)
  

let string_of_minizinc_variables minizinc_variables =
  lines_of_strings 
  (
    List.map (fun (variable_key, minizinc_variable) ->
      Printf.sprintf "%s => \"%s\"" (Variable_keys.string_of_variable_key variable_key) minizinc_variable
    ) minizinc_variables
  )

module C = Generic_constraints

let minizinc_max_int = 10000

let rec string_of_unary_arith_op op =
  match op with
  | C.Abs -> "abs"

and string_of_binary_arith_op op =
  match op with
  | C.Add -> "+"
  | C.Sub -> "-"
  | C.Mul -> "*"
  | C.Div -> "div"
  | C.Mod -> "mod"

and string_of_nary_arith_op op =
  match op with
  | C.Sum -> "+"

and unit_of_nary_arith_op op =
  match op with
  | C.Sum -> "0"

and string_of_binary_arith_cmp_op op =
  match op with
  | C.Lt  -> "<"
  | C.LEq -> "<="
  | C.Eq  -> "="
  | C.GEq -> ">="
  | C.Gt  -> ">"
  | C.NEq -> "<>"

and string_of_binary_cstr_op op =
  match op with
  | C.And         -> "/\\"
  | C.Or          -> "\\/"
  | C.Impl        -> "->"
  | C.IfAndOnlyIf -> "<->"
  | C.Xor         -> "xor" (* TODO *)

and string_of_unary_cstr_op op =
  match op with
  | C.Not -> "not"

and string_of_var var =
  match var with
  | C.NamedVar  (var_key) -> string_of_variable_key var_key
  
and string_of_expr expr = 
  match expr with
  | C.Const (const) -> 
    (
      match const with
      | C.Int (const) -> Printf.sprintf "%d" const
      | C.Inf (plus)  -> Printf.sprintf "%s%d" (if plus then "" else "-") minizinc_max_int
    )

  | C.Var (var) ->
      Printf.sprintf "%s" (string_of_var var)

  | C.Reified (cstr) ->
      Printf.sprintf "(bool2int %s)" (string_of_cstr cstr)
  
  | C.UnaryArithExpr (op, expr) ->
      Printf.sprintf "(%s (%s))"
      (string_of_unary_arith_op op)
      (string_of_expr expr)

  | C.BinaryArithExpr (op, lexpr, rexpr) ->
      Printf.sprintf "(%s %s %s)" 
      (string_of_expr lexpr)
      (string_of_binary_arith_op op)
      (string_of_expr rexpr)

  | C.NaryArithExpr (op, exprs) ->
      Printf.sprintf "(%s)"
      (if exprs = [] 
       then unit_of_nary_arith_op op
       else
         (String.concat
           (Printf.sprintf " %s " (string_of_nary_arith_op op))
           (List.map string_of_expr exprs) ) )

  | C.BinaryArithCmpExpr (op, lexpr, rexpr) ->
      Printf.sprintf "(bool2int %s)"
      (string_of_cstr (C.BinaryArithCmpCstr (op, lexpr, rexpr)))


and string_of_cstr cstr = 
  match cstr with
  | C.TrueCstr  -> "true" 
  | C.FalseCstr -> "false"

  | C.BinaryArithCmpCstr (op, lexpr, rexpr) ->
      Printf.sprintf "(%s %s %s)" 
      (string_of_expr lexpr)
      (string_of_binary_arith_cmp_op op)
      (string_of_expr rexpr)

  | C.BinaryCstrOpCstr (op, lcstr, rcstr) ->
      Printf.sprintf "(%s %s %s)" 
      (string_of_cstr lcstr)
      (string_of_binary_cstr_op op)
      (string_of_cstr rcstr)

  | C.UnaryCstrOpCstr (op, cstr) ->
      Printf.sprintf "(%s (%s))"
      (string_of_unary_cstr_op op)
      (string_of_cstr cstr)


let translate_constraints minizinc_variables generated_cstrs minimize_expr =
  
  let minizinc_of_variable type_string name_string = 
    Printf.sprintf "var %s : %s;\n" type_string name_string
  
  and minizinc_of_constraints_group_name constraints_group_name_string = 
    Printf.sprintf "\n%% + %s constraints\n" constraints_group_name_string
  
  and minizinc_of_constraint constraint_string = 
    Printf.sprintf "constraint %s;\n" constraint_string
  
  and minizinc_of_output_variable variable_key_string variable_value_string = 
    Printf.sprintf "  \"%s = \" , show(%s), \";\\n\"" variable_key_string variable_value_string

  in

  let constants_string =
    Printf.sprintf "int: max_int = %d;" minizinc_max_int
  
  
  and variables_string = 

    let strings_of_variables =
    List.map (fun (var_key, var_name) -> 
      match Variables.variable_kind_of_variable_key var_key with 
      | Variables.BooleanVariable ->   minizinc_of_variable "0..1"       var_name
      | Variables.NaturalVariable ->   minizinc_of_variable "0..max_int" var_name
    ) minizinc_variables

    and optimization_variable_string = minizinc_of_variable "int"   cost_var_name
    in

    String.concat "" (strings_of_variables @ [optimization_variable_string])

  
  and constraints_string =

    let strings_of_constraints =
      List.flatten (
        List.map (fun (constraints_group_name, cstrs) ->

          let constraints_group_name_string =
            minizinc_of_constraints_group_name constraints_group_name

          and cstrs_strings =
            List.map (fun cstr ->
              minizinc_of_constraint (string_of_cstr cstr)
            ) cstrs

          in

          constraints_group_name_string :: cstrs_strings

        ) generated_cstrs
      )
    
    and optimization_variable_constraint_string = 
      Printf.sprintf "%s%s"
        (minizinc_of_constraints_group_name "current optimization")
        (minizinc_of_constraint ("cost_var = " ^ (string_of_expr minimize_expr)))

    in

    String.concat "" (strings_of_constraints @ [optimization_variable_constraint_string])

  
  and solve_string =
    Printf.sprintf "solve minimize cost_var;"

  
  and output_string =

    let output_variable_strings =
      List.map (fun (key, var) ->
        minizinc_of_output_variable (string_of_variable_key key) (get_minizinc_variable minizinc_variables key)
      ) minizinc_variables

    and optimization_variable_output_string =
      minizinc_of_output_variable cost_var_name cost_var_name

    in
    
    Printf.sprintf
      "output [\n%s\n];"
      (String.concat ",\n" (output_variable_strings @ [optimization_variable_output_string]))
  

  in
  Printf.sprintf
    "%% ======= MiniZinc file automatically generated by Zephyrus =======\n\n%% === Constants ===\n%s\n\n\n%% === Variables ===\n%s\n\n%% === Constraints ===\n%s\n\n%% === Optimization function ===\n%s\n\n\n%% === Output definition ===\n%s\n" 
    constants_string
    variables_string
    constraints_string 
    solve_string
    output_string


let solution_of_bound_minizinc_variables minizinc_variables (bound_variables : (string * int) list) : Solution.solution_with_cost =

  let solution : Solution.solution =
    BatList.filter_map ( fun (minizinc_variable, value) ->
      match get_minizinc_variable_reverse minizinc_variables minizinc_variable with
      | Some key -> Some (key, value)
      | None     -> None
    ) bound_variables

  and cost : int =
    List.assoc cost_var_name bound_variables
  
  in
  (solution, cost)

