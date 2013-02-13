
open Aeolus_types_j
open Typing_context
open Variable_keys
open Generic_constraints

let element_exprs_to_sum
  ( get_element_resource_consumption_funtion : 'a -> resource_consumption ) 
  ( local_element_variable_key_function      : 'a -> variable_key )
  ( elements : 'a list )
  : expr list = 
  
  List.map ( fun element ->
    
    let consume_arity     = get_element_resource_consumption_funtion element
    and local_element_var = var (local_element_variable_key_function element)
    in

    (* Part of the sum: consumes(element_name, resource_name) * N(location_name, element_name) *)
    ( (const2expr consume_arity) *~ (var2expr local_element_var) )
      
  ) elements



let create_local_resource_constraints configuration universe =

  let location_names       = get_location_names  configuration
  and resource_names       = get_resource_names  universe
  
  and component_types      = get_component_types universe
  and packages             = get_packages        universe
  
  in
  
  List.flatten (
    List.map (fun location_name ->
      List.map (fun resource_name ->
  
        (* The left side expression: *)
        let local_resource_var =
          var (LocalResourceVariable (location_name, resource_name))
  
        in
  
        (* The rights side expression: *)
  
        (* First part of the sum: component types *)
        let sum_of_local_consumption_by_components = 
          
          let component_type_exprs_to_sum = 
            element_exprs_to_sum
              (fun (component_type : component_type) -> get_component_type_resource_consumption component_type resource_name)
              (fun component_type -> (LocalElementVariable (location_name, (ComponentType component_type.component_type_name))))
              component_types
          in
          (sum component_type_exprs_to_sum)
        
        in
  
        (* Second part of the sum: packages *)
        let sum_of_local_consumption_by_packages = 
          
          let package_exprs_to_sum = 
            element_exprs_to_sum
              (fun (package : package) -> get_package_resource_consumption package resource_name)
              (fun (package : package) -> (LocalElementVariable (location_name, (Package package.package_name))))
              (packages : package list)
          in
          (sum package_exprs_to_sum)
        
        in
        
        (* The constraint :  *)
        ( (var2expr local_resource_var) >=~ (sum_of_local_consumption_by_components +~ sum_of_local_consumption_by_packages) )
  
        (* Name        : *)
        (* Description : *)
        (* Constraint  : *)
  
      ) resource_names
    ) location_names
  )


let create_initial_configuration_resource_constraints configuration universe =

  let locations       = get_locations      configuration
  and resource_names       = get_resource_names universe
  in

  List.flatten (
    List.map (fun location ->

      let location_name = location.location_name
      in

      List.map (fun resource_name ->

        (* The left side expression: *)
        let local_resource_var =
          var (LocalResourceVariable (location_name, resource_name))
  
        in

        (* The rights side expression: *)
        let resource_provide_arity =
          get_resource_provide_arity location resource_name

        in

        (* The constraint :  *)
        ( (var2expr local_resource_var) =~ (const2expr resource_provide_arity) )

        (* Name        : *)
        (* Description : *)
        (* Constraint  : *)

      ) resource_names
    ) locations
  )



let create_resource_constraints configuration universe : cstr list =

  (* A list of constraint generating functions to use: *)
  let create_constraints_functions =
    [create_local_resource_constraints;
     create_initial_configuration_resource_constraints]
  in

  (* Generate the constraints! *)

  (* For each constraint generating function *)
  List.flatten (
    List.map (fun create_constraints_function -> 
    
    (* Create the constraint *)
    create_constraints_function configuration universe 

  ) create_constraints_functions )