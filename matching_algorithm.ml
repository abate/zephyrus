
(* TODO: This should be made into a module with compare and decrement functions. *)
type provide_arity = FiniteProvide of int | InfiniteProvide
type require_arity = int

module type REQUIRER_PROVIDER_TYPES =
  sig

    type requirer_key_t
    type provider_key_t
    type result_t

    module Requirers :
    sig
      type t
      val iter : ( (requirer_key_t * require_arity) -> unit) -> t -> unit
    end

    module Providers :
    sig
      type t
      val is_empty  : t -> bool
      val max_value : t -> (provider_key_t * provide_arity)
      val remove    : provider_key_t -> t -> t
      val decrement : provider_key_t -> t -> t
    end

    module Results :
    sig
      type t
      val empty : t
      val add   : requirer_key_t -> provider_key_t -> t -> t
    end

  end


module type REQUIRER_PROVIDER_TYPE_PARAMETER =
  sig
    type requirer_key_t
    type provider_key_t 
  end

module List_requirer_provider_types =
  functor (Requirer_provider_type_parameter : REQUIRER_PROVIDER_TYPE_PARAMETER) ->
  struct

    module Type_Parameter = Requirer_provider_type_parameter

    type requirer_key_t = Type_Parameter.requirer_key_t
    type provider_key_t = Type_Parameter.provider_key_t

    type result_t = {
      requires : requirer_key_t;
      provides : provider_key_t;
    }

    module Requirers =
      struct

        type t = (requirer_key_t * require_arity) list

        let iter = List.iter

      end
    
    module Providers =
      struct
    
        type t = (provider_key_t * provide_arity) list
        
        let is_empty l = 
          ( (List.length l) = 0 )
        
        let max_value l =
          let rec max_value_helper l max =
            match max with
            | (_, InfiniteProvide) -> max
            | (_, FiniteProvide max_value) ->
                (
                  match l with
                  | [] -> max
                  
                  | (key, InfiniteProvide)     :: t ->
                      max_value_helper t (key, InfiniteProvide)
                  
                  | (key, FiniteProvide value) :: t -> 
                      if (value > max_value ) 
                      then max_value_helper t (key, FiniteProvide value)
                      else max_value_helper t max
                )
          in
          max_value_helper l (List.hd l)
    
        let remove key l =
          List.remove_assoc key l
    
        let decrement key l =
          List.map (fun (kkey, value) ->
            if kkey = key
            then
              (
                match value with
                | InfiniteProvide     -> (kkey, value)
                | FiniteProvide value -> (kkey, FiniteProvide (value - 1))
              )
            else 
              (kkey, value)
          ) l
    
      end
    
    module Results =
      struct
    
        type t = result_t list
    
        let empty = []
    
        let add requires provides l =
          let result = {
            requires = requires;
            provides = provides;
          }
          in 
          (result :: l)
    
      end

end

module type MATCH_REQUIRERS_WITH_PROVIDERS =
  functor (Requirer_provider_types : REQUIRER_PROVIDER_TYPES) ->
  sig
    val matching_algorithm : 
      Requirer_provider_types.Requirers.t -> 
      Requirer_provider_types.Providers.t -> 
      Requirer_provider_types.Results.t option
  end


module Match_requirers_with_providers : MATCH_REQUIRERS_WITH_PROVIDERS =
  functor (Requirer_provider_types : REQUIRER_PROVIDER_TYPES) ->
  struct

    open Requirer_provider_types
    (* Gives direct access to modules:
       + Requirers
       + Providers
       + Results 
    *)

    (* Exception raised when finding a correct matching is impossible. *)
    exception Impossible

    let matching_algorithm requirers providers =
      try  
        (* The "result" variable accumulates the bindings between providers and requirers. *)
        let result = ref Results.empty
  
        (* The "providers" variable holds the current information about available providers and their capacity. *)
        and providers = ref providers
        in
  
        (* We need to bind each requirer to a number of different providers that he requies. *)
        Requirers.iter ( fun (requirer_key, requirer_value) ->
          (* "requirer_key"   is the name of the requirer. *)
          (* "requirer_value" is the number of different providers this requirer requires. *)
  
          (* The "providers_lefts" variable holds all the providers that this requirer is not bound to yet. 
             With each step it will become smaller, as our requirer will be bound to another provider. *)
          let providers_left = ref !providers in
  
          (* We repeat the process of binding our requirer to a different provider as many times as it requires.  *)
          for k = 1 to requirer_value do
  
            (* If there are no more providers not bound to our requirer left, we have lost. *)
            if Providers.is_empty !providers_left
            then raise Impossible
  
            else
  
              (* We take the provider which has the most ports left unbound (and which is not bound to our requirer). *)
              let (provider_key, provider_value) =
                Providers.max_value !providers_left
              in
  
              (* If the best provider available has no more ports left unbound, then we have lost. *)
              if provider_value = (FiniteProvide 0)
              then raise Impossible
  
              (* Else we can bind the requirer to the provider and adjust the other variables accordingly. *)
              else
  
                (* We add this requirer-provider binding to the results. *)
                result         := Results.add          requirer_key provider_key !result;
  
                (* This provider is now bound to current requirer, so it becomes unavailable, as all
                   the providers bound to a given requirer must be different. *)
                providers_left := Providers.remove     provider_key !providers_left;
  
                (* This provider has one more unbound port left for binding. *)
                providers      := Providers.decrement  provider_key !providers;
          done;
        ) requirers;
        
        (* As we have bound all the ports of all the requirers, we have won! Congratulations! *)
        (Some !result)
  
      (* We have encountered an unsolvable situation somewhere during the algorithm. Thus, it is not possible 
         tho correctly satisfy the requirements of all the requirers with the available providers. *)
      with
      | Impossible -> None

  end


module Requirer_provider_type_param_string =
  struct 
      type key_t = string
      type requirer_key_t = key_t
      type provider_key_t = key_t
  end

module String_list_requirer_provider_types =
  List_requirer_provider_types(Requirer_provider_type_param_string)

module List_match_requirers_with_providers =
  Match_requirers_with_providers(String_list_requirer_provider_types)
