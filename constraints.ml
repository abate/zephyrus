
open Aeolus_types_j

open Helpers
open Typing_context
open Variable_keys

open Generic_constraints


(* Translating the universe *)

let translate_universe_and_initial_configuration universe initial_configuration =
  let create_constraints_functions = [
    ("component types",  Component_type_global_constraints.create_component_type_global_constraints);
    ("location",         Location_constraints.create_location_constraints           initial_configuration);
    ("repository",       Repository_constraints.create_repository_constraints       initial_configuration);
    ("package",          Package_constraints.create_package_constraints             initial_configuration);
    ("resource",         Resource_constraints.create_resource_constraints           initial_configuration)
  ]
  in
  List.map (fun (constraints_group_name, create_constraints_function) ->
    let constraints = create_constraints_function universe
    in
    (constraints_group_name, constraints)
  ) create_constraints_functions


(* Translating the specification *)

let translate_specification specification initial_configuration =
  [("specification", Specification_constraints.create_specification_constraints initial_configuration specification)]

(*

(* Translating the specification *)

type specification_constraints = cstr list

let translate_specification : specification -> specification_constraints =
  Specification_constraints.create_specification_constraints

*)

let string_of_generated_constraint = string_of_cstr

(* Printing *)
let string_of_generated_constraints constraints =
  let string_of_generated_constraint_list constraints =
    let strings = List.map string_of_generated_constraint constraints in
    lines_of_strings strings
  in
  let strings =
    List.map (fun (constraints_group_name, constraints) ->

      Printf.sprintf "+ %s constraints:\n%s\n" constraints_group_name (string_of_generated_constraint_list constraints)
      
    ) constraints
  in
  Printf.sprintf
    "\n%s\n"
    (lines_of_strings strings)
