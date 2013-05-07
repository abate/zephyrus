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
open Typing_context
open Variables
open Generic_constraints

type optimization_function =
  | Satisfy          (* Output the first solution found that satisfies the constraints. *)
  | Maximize of expr (* Search for the solution that maximizes the given expression. *)
  | Minimize of expr (* Search for the solution that minimizes the given expression. *)

let cost_expr_number_of_all_components universe = 
  let component_type_names = get_component_type_names universe
  in
  sum 
    (List.map (fun component_type_name -> 
      var2expr (var (GlobalElementVariable (ComponentType component_type_name))) 
    ) component_type_names)


let cost_expr_number_of_all_packages initial_configuration universe =
  let location_names = get_location_names initial_configuration
  and package_names  = get_package_names  universe
  in
  sum (
    List.flatten (
      List.map (fun location_name ->
        List.map (fun package_name ->

          var2expr (var (LocalElementVariable (location_name, (Package package_name))))

        ) package_names
      ) location_names
    )
  )


type used_or_free = Used | Free

let cost_expr_number_of_used_or_free_locations used_or_free initial_configuration universe only_components_count =
  let component_type_names = get_component_type_names universe
  and package_names        = get_package_names        universe
  and location_names       = get_location_names       initial_configuration
  in

  let used_locations =
    List.map (fun location_name ->
      
      let local_components_and_packages =
        sum (

          (* Components *)
          (List.map (fun component_type_name ->
            var2expr (var (LocalElementVariable (location_name, (ComponentType component_type_name)))) 
          ) component_type_names)
          
          @
          
          if only_components_count
          then []
          else
            (* Packages *)
            (List.map (fun package_name ->
              var2expr (var (LocalElementVariable (location_name, (Package package_name)))) 
            ) package_names)

        )
      
      in 
      match used_or_free with
      | Used -> reify ( local_components_and_packages >~ (int2expr 0) )
      | Free -> reify ( local_components_and_packages =~ (int2expr 0) )

    ) location_names

  in
  let total_number_of_used_locations = (sum used_locations)
  in
  total_number_of_used_locations

let cost_expr_number_of_used_locations = cost_expr_number_of_used_or_free_locations Used
let cost_expr_number_of_free_locations = cost_expr_number_of_used_or_free_locations Free


let compact initial_configuration universe =
  (* 
    First minimize the number of used locations,
    then minimize the number of components,  (useful only if we can have multiple components of the same component type on one machine)
    finally minimize the number of packages. (so we do not have useless packages) 
  *)
  [
    Minimize (cost_expr_number_of_used_locations initial_configuration universe false);
    Minimize (cost_expr_number_of_all_components                       universe      );
    Minimize (cost_expr_number_of_all_packages   initial_configuration universe      );
  ]


let spread initial_configuration universe =
  (* 
    First minimize the number of components,
    then maximize the number of used locations, (counting only locations with at least one component)
    finally minimize the number of packages.
  *)
  [
    Minimize (cost_expr_number_of_all_components                       universe     );
    Maximize (cost_expr_number_of_used_locations initial_configuration universe true);
    Minimize (cost_expr_number_of_all_packages   initial_configuration universe     );
  ]


let cost_expr_difference_of_components initial_configuration universe =
  let component_type_names = get_component_type_names universe
  and location_names       = get_location_names       initial_configuration
  in

  let local_differences_of_number_of_components = 
    
    List.flatten (
      List.map (fun location_name ->
        List.map (fun component_type_name ->
          
          let number_of_components_in_initial_configuration =
            List.length (
              List.filter (fun component -> 
                (component.component_type = component_type_name) && (component.component_location = location_name)
              ) initial_configuration.configuration_components
            )

          and number_of_components_in_final_configuration =
            var (LocalElementVariable (location_name, (ComponentType component_type_name)))

          in

          let local_difference_of_number_of_components = 
            abs ( 
              (var2expr number_of_components_in_final_configuration) 
              -~
              (int2expr number_of_components_in_initial_configuration) 
            )
          
          in
          local_difference_of_number_of_components

        ) component_type_names
      ) location_names
    )
    
  in
  let total_difference_of_number_of_components = (sum local_differences_of_number_of_components)
  in
  total_difference_of_number_of_components


let cost_expr_difference_of_packages initial_configuration universe =
  let package_names  = get_package_names  universe
  and location_names = get_location_names initial_configuration
  in

  let local_differences_of_package_installation = 
    
    List.flatten (
      List.map (fun location_name ->

        let initial_package_names = get_location_packages_installed initial_configuration location_name
        in

        List.map (fun package_name ->

          let is_package_installed_in_initial_configuration =
            List.mem package_name initial_package_names

          and is_package_installed_in_final_configuration = 
            var (LocalElementVariable (location_name, (Package package_name)))

          in

          let local_difference_of_package_installation = 

            abs ( 
              (var2expr is_package_installed_in_final_configuration)
              -~
              (int2expr (if is_package_installed_in_initial_configuration then 1 else 0))
            )

          in

          local_difference_of_package_installation
            
        ) package_names
      ) location_names
    )

  in
  let total_difference_of_package_installation = (sum local_differences_of_package_installation)
  in
  total_difference_of_package_installation


let conservative initial_configuration universe =
  (* First minimize the number of changed components,
     then minimize the number of used locations       (so machines which do not have components now will be also freed of packages),
     finally minimize the number of changed packages. (so on machines which are not empty we will try to keep previous packages even if they are useless) *)
  [
    Minimize (cost_expr_difference_of_components initial_configuration universe      );
    Minimize (cost_expr_number_of_used_locations initial_configuration universe false);
    Minimize (cost_expr_difference_of_packages   initial_configuration universe      );
  ]