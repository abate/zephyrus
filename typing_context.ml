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


open Aeolus_types_t
open Aeolus_types_output.Plain

open ExtLib

open Helpers


(** handling errors when something demanded does not exist *)
type something_does_not_exist =
  | ComponentTypeInUniverse                of component_type_name
  | ComponentTypeImplementationInUniverse  of component_type_name
  | RepositoryInUniverse                   of repository_name
  | PackageInRepository                    of package_name * repository_name
  | LocationInTheConfiguration             of location_name

let does_not_exist what = 
  let fail_message =
    match what with
    | ComponentTypeInUniverse (component_type_name) -> 
        Printf.sprintf 
          "the component type %s does not exist in this universe" 
          (string_of_component_type_name component_type_name)

    | ComponentTypeImplementationInUniverse (component_type_name) -> 
        Printf.sprintf 
          "the component type %s implementation does not exist in this universe" 
          (string_of_component_type_name component_type_name)

    | RepositoryInUniverse (repository_name) ->
        Printf.sprintf 
          "the repository %s does not exist in this universe" 
          (string_of_repository_name repository_name)

    | PackageInRepository (package_name, repository_name) ->
        Printf.sprintf 
          "the package %s does not exist in the repository %s" 
          (string_of_package_name    package_name)
          (string_of_repository_name repository_name)

    | LocationInTheConfiguration (location_name) ->
        Printf.sprintf 
          "the location %s does not exist in this configuration" 
          (string_of_location_name location_name)
  in
  failwith fail_message




(** universe *)


(** component_type *)

let get_component_type_names universe =
  List.map ( fun component_type -> 
      component_type.component_type_name
  ) universe.universe_component_types

let get_component_types universe = universe.universe_component_types

let get_component_type universe component_type_name =
  try
    List.find (fun component_type ->
      component_type.component_type_name = component_type_name 
    ) universe.universe_component_types
  with
  | Not_found -> 
      does_not_exist (ComponentTypeInUniverse (component_type_name))

(** port *)

let get_port_names universe =
  List.unique ( 
    List.flatten ( 
      List.map ( fun component_type -> 
        
        (
          List.map (fun (port_name, _) -> 
            port_name
          ) component_type.component_type_provide
        )
        @
        (
          List.map (fun (port_name, _) -> 
            port_name
          ) component_type.component_type_require
        )
        @
        component_type.component_type_conflict
    
      ) universe.universe_component_types
    ) 
  )

let get_provide_arity component_type port_name =
  try
    List.assoc port_name component_type.component_type_provide
  with
  | Not_found -> (`FiniteProvide 0)

let get_require_arity component_type port_name =
  try
    List.assoc port_name component_type.component_type_require
  with
  | Not_found -> 0

let is_in_conflict component_type port_name =
  List.mem port_name component_type.component_type_conflict

let requirers universe port_name =
  List.filter_map (fun component_type ->
    if List.exists (fun (required_port_name, require_arity) ->
         (required_port_name = port_name) && (require_arity > 0)
       ) component_type.component_type_require
    then Some (component_type.component_type_name)
    else None
  ) universe.universe_component_types

let providers universe port_name =
  List.filter_map (fun component_type ->
    if List.exists (fun (provided_port_name, provide_arity) ->
         (provided_port_name = port_name) 
         && 
         (match provide_arity with
          | `FiniteProvide i -> i > 0
          | `InfiniteProvide -> true )
       ) component_type.component_type_provide
    then Some (component_type.component_type_name)
    else None
  ) universe.universe_component_types

let conflicters universe port_name =
  List.filter_map (fun component_type ->
    if List.exists (fun conflicted_port_name ->
         conflicted_port_name = port_name
       ) component_type.component_type_conflict
    then Some (component_type.component_type_name)
    else None
  ) universe.universe_component_types


(** repository *)

let get_repository_names universe =
  List.map ( fun repository -> 
      repository.repository_name
  ) universe.universe_repositories

let get_repositories universe = universe.universe_repositories

let get_repository universe repository_name =
  try
    List.find (fun repository ->
      repository.repository_name = repository_name 
    ) universe.universe_repositories
  with
  | Not_found -> 
      does_not_exist (RepositoryInUniverse (repository_name))


(** package *)

let get_package_names universe =
  List.unique ( 
    List.flatten ( 
      List.map ( fun repository -> 
        List.flatten ( 
          List.map (fun package -> 
            
            (
              [package.package_name]
              @
              (List.flatten package.package_depend)
              @
              (package.package_conflict)
            )

          ) repository.repository_packages
        )
      ) universe.universe_repositories
    ) 
  )

let get_packages universe =
  List.flatten ( 
    List.map ( fun repository -> 
      repository.repository_packages  
    ) universe.universe_repositories
  ) 

let get_repository_package_names repository =
  List.map ( fun package ->
    package.package_name
  ) repository.repository_packages

let get_repository_packages repository = 
  repository.repository_packages

let get_package repository package_name =
  try
    List.find (fun package ->
      package.package_name = package_name 
    ) repository.repository_packages
  with
  | Not_found ->
      does_not_exist (PackageInRepository (package_name, repository.repository_name))

let get_component_type_implementation universe component_type_name =
  try
    List.assoc component_type_name universe.universe_implementation
  with
  (* If this component type is not on the universe implementation list, 
   * this does not mean it does not exist, but that it simply does not
   * need any packages to implement it. *)
  | Not_found -> [] 

  (* Alternative interpretation: *)
  (* does_not_exist (ComponentTypeImplementationInUniverse (component_type_name)) *)


(** resource *)

let consumed_resources_of_resource_consumption_list 
  (resource_consumption_list : (resource_name * resource_consumption) list)
  : resource_name list =

  List.filter_map (fun (resource_name, resource_consumption) ->
    if resource_consumption > 0
    then Some(resource_name)
    else None
  ) resource_consumption_list

let get_resource_names universe =

  List.unique (

    (* Resource names mentioned in all component types. *)
    List.flatten ( 
      List.map (fun component_type -> 
        consumed_resources_of_resource_consumption_list 
          component_type.component_type_consume
      ) universe.universe_component_types
    )
    
    @

    (* Resource names mentioned in all packages. *)
    List.flatten ( 
      List.map ( fun repository -> 
        List.flatten (
          List.map (fun package -> 
            consumed_resources_of_resource_consumption_list 
              package.package_consume
          ) repository.repository_packages
        )
      ) universe.universe_repositories
    )

  )

let get_component_type_resource_consumption component_type resource_name =
  try
    List.assoc resource_name component_type.component_type_consume
  with
  | Not_found -> 0

let get_package_resource_consumption package resource_name =
  try
    List.assoc resource_name package.package_consume
  with
  | Not_found -> 0





(** configuration *)


(** location *)

let get_location_names configuration =
  List.unique (
    List.map (fun location -> 
      location.location_name
    ) configuration.configuration_locations
  )

let get_locations configuration = configuration.configuration_locations

let get_location configuration location_name = 
  try
    List.find (fun location ->
      location.location_name = location_name 
    ) (get_locations configuration)
  with
  | Not_found -> 
      does_not_exist (LocationInTheConfiguration (location_name))

let get_location_components configuration location_name =
  List.filter (fun component -> 
    component.component_location = location_name
  ) configuration.configuration_components

let get_location_packages_installed configuration location_name =
  let location = get_location configuration location_name
  in
  location.location_packages_installed

let get_location_resource_provide_arity location resource_name =
  try
    List.assoc resource_name location.location_provide_resources
  with
  | Not_found -> 0
