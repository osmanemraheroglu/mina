open Core_kernel
open Mina_base
open Mina_block

module Common = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }

      let to_latest = Fn.id

      let to_yojson {scan_state= _; pending_coinbase} =
        `Assoc
          [ ("scan_state", `String "<opaque>")
          ; ( "pending_coinbase"
            , Pending_coinbase.Stable.V1.to_yojson pending_coinbase ) ]
    end
  end]

  let create ~scan_state ~pending_coinbase = {scan_state; pending_coinbase}

  let scan_state t = t.scan_state

  let pending_coinbase t = t.pending_coinbase
end

module Historical = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { transition: External_transition.Validated.Stable.V2.t
        ; common: Common.Stable.V1.t
        ; staged_ledger_target_ledger_hash: Ledger_hash.Stable.V1.t }

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; common: Common.Stable.V1.t
        ; staged_ledger_target_ledger_hash: Ledger_hash.Stable.V1.t }

      let to_latest {transition; common; staged_ledger_target_ledger_hash} =
        let transition = External_transition.Validated.Stable.V1.to_latest transition in
        {V2.transition; common; staged_ledger_target_ledger_hash}
    end
  end]

  let transition t = t.transition

  let staged_ledger_target_ledger_hash t = t.staged_ledger_target_ledger_hash

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common

  let of_breadcrumb breadcrumb =
    let transition = External_transition.Validated.lift @@ Breadcrumb.validated_transition breadcrumb in
    let staged_ledger = Breadcrumb.staged_ledger breadcrumb in
    let scan_state = Staged_ledger.scan_state staged_ledger in
    let pending_coinbase =
      Staged_ledger.pending_coinbase_collection staged_ledger
    in
    let staged_ledger_target_ledger_hash =
      Staged_ledger.hash staged_ledger |> Staged_ledger_hash.ledger_hash
    in
    let common = Common.create ~scan_state ~pending_coinbase in
    {transition; common; staged_ledger_target_ledger_hash}
end

module Limited = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { transition: External_transition.Validated.Stable.V2.t
        ; protocol_states:
            Mina_state.Protocol_state.Value.Stable.V1.t
            Mina_base.State_hash.With_state_hashes.Stable.V1.t
            list
        ; common: Common.Stable.V1.t }

      let to_yojson {transition; protocol_states= _; common} =
        `Assoc
          [ ("transition", External_transition.Validated.Stable.V2.to_yojson transition)
          ; ("protocol_states", `String "<opaque>")
          ; ("common", Common.Stable.V1.to_yojson common) ]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; protocol_states:
            ( Mina_base.State_hash.Stable.V1.t
            * Mina_state.Protocol_state.Value.Stable.V1.t )
            list
        ; common: Common.Stable.V1.t }

      let to_yojson {transition; protocol_states= _; common} =
        `Assoc
          [ ("transition", External_transition.Validated.Stable.V1.to_yojson transition)
          ; ("protocol_states", `String "<opaque>")
          ; ("common", Common.Stable.V1.to_yojson common) ]

      let to_latest {transition; protocol_states; common} =
        let transition = External_transition.Validated.Stable.V1.to_latest transition in
        let protocol_states =
          List.map protocol_states ~f:(fun (state_hash, s) ->
            { With_hash.data = s
            ; hash = {Mina_base.State_hash.State_hashes.state_hash; state_body_hash = None} })
        in
        {V2.transition; protocol_states; common}

      let of_v2 {V2.transition; protocol_states; common} =
        let transition = External_transition.Validated.Stable.V1.of_v2 transition in
        let protocol_states =
          List.map protocol_states ~f:(fun s ->
            Mina_base.State_hash.With_state_hashes.(state_hash s, data s))
        in
        {transition; protocol_states; common}

      let transition t = t.transition

      let state_hash t = 
        Mina_block.Validated.state_hash @@ External_transition.Validated.lower @@ External_transition.Validated.Stable.V1.to_latest t.transition

      let protocol_states t = t.protocol_states

      let scan_state t = Common.scan_state t.common

      let pending_coinbase t = Common.pending_coinbase t.common

      let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
        let common = {Common.scan_state; pending_coinbase} in
        {transition; common; protocol_states}
    end
  end]

  [%%define_locally
  Stable.Latest.(to_yojson)]

  let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
    let common = {Common.scan_state; pending_coinbase} in
    {transition; common; protocol_states}

  let transition t = t.transition

  let hashes t = let x, _ = External_transition.Validated.lower t.transition in With_hash.hash x

  let protocol_states t = t.protocol_states

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = {hash: State_hash.Stable.V1.t; common: Common.Stable.V1.t}
      [@@driving to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = {hash: State_hash.t; common: Common.t}
  [@@driving to_yojson]

  let hash t = t.hash

  let of_limited_v1 (l : Limited.Stable.V1.t) =
    let hash = Limited.Stable.V1.state_hash l in
    {hash; common= l.common}

  let of_limited (l : Limited.t) =
    let hash = Mina_block.Validated.state_hash (External_transition.Validated.lower l.transition) in
    {hash; common= l.common}

  let upgrade t ~transition ~protocol_states =
    let hash = hash t in
    assert (
      State_hash.equal
    (Mina_block.Validated.state_hash @@ External_transition.Validated.lower transition) 
        hash ) ;
    let protocol_states =
      List.map protocol_states ~f:(fun (state_hash, s) ->
        { With_hash.data = s
        ; hash = {Mina_base.State_hash.State_hashes.state_hash; state_body_hash = None} })
    in
    ignore
      ( Staged_ledger.Scan_state.check_required_protocol_states
          t.common.scan_state
          ~protocol_states
        |> Or_error.ok_exn
        : Mina_state.Protocol_state.value State_hash.With_state_hashes.t list ) ;
    {Limited.transition; protocol_states; common= t.common}

  let create ~hash ~scan_state ~pending_coinbase =
    let common = {Common.scan_state; pending_coinbase} in
    {hash; common}

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common
end

type t =
  { transition: External_transition.Validated.t
  ; staged_ledger: Staged_ledger.t
  ; protocol_states: Mina_state.Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t list }

let minimize {transition; staged_ledger; protocol_states= _} =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common = Common.create ~scan_state ~pending_coinbase in
  {Minimal.hash= Mina_block.Validated.state_hash @@ External_transition.Validated.lower transition; common}

let limit {transition; staged_ledger; protocol_states} =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common = Common.create ~scan_state ~pending_coinbase in
  {Limited.transition; common; protocol_states}
