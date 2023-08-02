(* hard_fork.ml -- run nodes with fork config, epoch ledger *)

open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let fork_config : Runtime_config.Fork_config.t =
    { previous_state_hash =
        "3NKSiqFZQmAS12U8qeX4KNo8b4199spwNh7mrSs4Ci1Vacpfix2Q"
    ; previous_length = 300000
    ; previous_global_slot = 500000
    }

  let config =
    let open Test_config in
    let make_timing ~min_balance ~cliff_time ~cliff_amount ~vesting_period
        ~vesting_increment : Mina_base.Account_timing.t =
      let open Currency in
      Timed
        { initial_minimum_balance = Balance.of_nanomina_int_exn min_balance
        ; cliff_time = Mina_numbers.Global_slot_since_genesis.of_int cliff_time
        ; cliff_amount = Amount.of_nanomina_int_exn cliff_amount
        ; vesting_period = Mina_numbers.Global_slot_span.of_int vesting_period
        ; vesting_increment = Amount.of_nanomina_int_exn vesting_increment
        }
    in
    let staking_accounts : Test_Account.t list =
      [ { account_name = "untimed-node-a-key"
        ; balance = "400000"
        ; timing = Untimed (* 400_000_000_000_000 *)
        }
      ; { account_name = "untimed-node-b-key"
        ; balance = "300000"
        ; timing = Untimed (* 300_000_000_000_000 *)
        }
      ; { account_name = "timed-node-c-key"
        ; balance = "30000"
        ; timing =
            make_timing ~min_balance:10_000_000_000_000 ~cliff_time:8
              ~cliff_amount:0 ~vesting_period:4
              ~vesting_increment:5_000_000_000_000
        }
      ; { account_name = "snark-node-key1"; balance = "0"; timing = Untimed }
      ; { account_name = "snark-node-key2"; balance = "0"; timing = Untimed }
      ]
    in
    let staking : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 42)
      in
      let epoch_ledger = staking_accounts in
      { epoch_ledger; epoch_seed }
    in
    (* next accounts superset of staking accounts, with balances changed *)
    let next_accounts : Test_Account.t list =
      [ { account_name = "untimed-node-a-key"
        ; balance = "200000"
        ; timing = Untimed
        }
      ; { account_name = "untimed-node-b-key"
        ; balance = "350000"
        ; timing = Untimed (* 300_000_000_000_000 *)
        }
      ; { account_name = "timed-node-c-key"
        ; balance = "40000"
        ; timing =
            make_timing ~min_balance:10_000_000_000_000 ~cliff_time:8
              ~cliff_amount:0 ~vesting_period:4
              ~vesting_increment:5_000_000_000_000
        }
      ; { account_name = "fish1"; balance = "100"; timing = Untimed }
      ; { account_name = "snark-node-key1"; balance = "0"; timing = Untimed }
      ; { account_name = "snark-node-key2"; balance = "0"; timing = Untimed }
      ]
    in
    let next : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 1729)
      in
      let epoch_ledger = next_accounts in
      { epoch_ledger; epoch_seed }
    in
    { default with
      requires_graphql = true
    ; epoch_data =
        Some { staking; next = Some next }
        (* the genesis ledger contains the staking ledger plus some other accounts *)
    ; genesis_ledger =
        staking_accounts
        @ [ { account_name = "fish1"; balance = "100"; timing = Untimed }
          ; { account_name = "fish2"; balance = "100"; timing = Untimed }
          ]
    ; block_producers =
        [ { node_name = "untimed-node-a"; account_name = "untimed-node-a-key" }
        ; { node_name = "untimed-node-b"; account_name = "untimed-node-b-key" }
        ; { node_name = "timed-node-c"; account_name = "timed-node-c-key" }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key1"
          ; worker_nodes = 4
          }
    ; snark_worker_fee = "0.0002"
    ; num_archive_nodes = 1
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        ; fork = Some fork_config
        }
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize (Core.String.Map.data all_nodes))
    in
    let untimed_node_a =
      Core.String.Map.find_exn
        (Network.block_producers network)
        "untimed-node-a"
    in
    let untimed_node_b =
      Core.String.Map.find_exn
        (Network.block_producers network)
        "untimed-node-b"
    in
    let timed_node_c =
      Core.String.Map.find_exn (Network.block_producers network) "timed-node-c"
    in
    let fish1 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish1"
    in
    let fish2 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish2"
    in
    let sender = fish2.keypair in
    let receiver = fish1.keypair in
    [%log info] "extra genesis keypairs: %s"
      (List.to_string [ fish1.keypair; fish2.keypair ]
         ~f:(fun { Signature_lib.Keypair.public_key; _ } ->
           public_key |> Signature_lib.Public_key.to_bigstring
           |> Bigstring.to_string ) ) ;
    let receiver_pub_key =
      receiver.public_key |> Signature_lib.Public_key.compress
    in
    let sender_pub_key =
      sender.public_key |> Signature_lib.Public_key.compress
    in
    let sender_account_id = Account_id.create sender_pub_key Token_id.default in
    let%bind { nonce = sender_current_nonce; _ } =
      Integration_test_lib.Graphql_requests.must_get_account_data ~logger
        (Network.Node.get_ingress_uri untimed_node_b)
        ~account_id:sender_account_id
    in
    let amount = Currency.Amount.of_mina_string_exn "10" in
    let fee = Currency.Fee.of_mina_string_exn "1" in
    let memo = "" in
    let valid_until = Mina_numbers.Global_slot_since_genesis.max_value in
    let payload =
      let payment_payload =
        { Payment_payload.Poly.receiver_pk = receiver_pub_key; amount }
      in
      let body = Signed_command_payload.Body.Payment payment_payload in
      let common =
        { Signed_command_payload.Common.Poly.fee
        ; fee_payer_pk = sender_pub_key
        ; nonce = sender_current_nonce
        ; valid_until
        ; memo = Signed_command_memo.create_from_string_exn memo
        }
      in
      { Signed_command_payload.Poly.common; body }
    in
    let raw_signature =
      Signed_command.sign_payload sender.private_key payload
      |> Signature.Raw.encode
    in
    (* setup complete *)
    let%bind () =
      section "send a single signed payment between 2 fish accounts"
        (let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_payment_with_raw_sig
             (Network.Node.get_ingress_uri untimed_node_b)
             ~logger
             ~sender_pub_key:(Signed_command_payload.fee_payer_pk payload)
             ~receiver_pub_key:(Signed_command_payload.receiver_pk payload)
             ~amount ~fee
             ~nonce:(Signed_command_payload.nonce payload)
             ~memo ~valid_until ~raw_signature
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node untimed_node_b) ) )
    in
    let%bind () =
      section "send a single payment from timed account using available liquid"
        (let amount = Currency.Amount.of_mina_int_exn 1_000 in
         let receiver = untimed_node_a in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = timed_node_c in
         let%bind sender_pub_key = pub_key_of_node sender in
         let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_online_payment
             ~logger
             (Network.Node.get_ingress_uri timed_node_c)
             ~sender_pub_key ~receiver_pub_key ~amount ~fee
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node timed_node_c) ) )
    in
    let%bind () =
      section_hard
        "send out a bunch more txns to fill up the snark ledger, then wait for \
         proofs to be emitted"
        (let receiver = untimed_node_a in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = untimed_node_b in
         let%bind sender_pub_key = pub_key_of_node sender in
         let%bind _ =
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~amount:Currency.Amount.one ~fee ~node:sender 10
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis
              ~test_config:config ~num_proofs:1 ) )
    in
    let%bind () =
      section_hard
        "checking height, global slot since genesis in precomputed blocks"
        (let%bind () =
           Network.Node.dump_precomputed_blocks ~logger untimed_node_a
         in
         let%bind.Deferred files = Sys.ls_dir "." in
         Format.eprintf "FILES: %s@." (String.concat files ~sep:",") ;
         let precomputed_block_files =
           List.filter files ~f:(fun file ->
               String.is_prefix file ~prefix:"3N"
               && String.is_suffix file ~suffix:".json" )
         in
         Format.eprintf "PRECOMP FILES: %s@."
           (String.concat precomputed_block_files ~sep:",") ;
         let block_data =
           List.map precomputed_block_files ~f:(fun fn ->
               match In_channel.read_all fn |> Yojson.Safe.from_string with
               | `Assoc items ->
                   let find item =
                     match
                       List.Assoc.find_exn items ~equal:String.equal item
                     with
                     | `String s ->
                         Int.of_string s
                     | _ ->
                         failwith "Expected item to be a string"
                   in
                   let height = find "height" in
                   let global_slot_since_genesis =
                     find "global_slot_since_genesis"
                   in
                   let global_slot_since_hard_fork =
                     find "global_slot_since_hard_fork"
                   in
                   ( height
                   , global_slot_since_genesis
                   , global_slot_since_hard_fork )
               | _ ->
                   failwith "Expected precomputed block to be a record" )
         in
         let%bind () =
           Malleable_error.List.iter block_data
             ~f:(fun (h, since_genesis, since_fork) ->
               Format.eprintf "BLOCK: HEIGHT: %d SINCE_GEN: %d SINCE_FORK: %d@."
                 h since_genesis since_fork ;
               let bad_height = h <= fork_config.previous_length in
               let bad_slot =
                 since_genesis <= fork_config.previous_global_slot
               in
               if bad_height && bad_slot then
                 Malleable_error.hard_error
                   (Error.of_string
                      "Block height and slot not greater than in fork config" )
               else if bad_height then
                 Malleable_error.hard_error
                   (Error.of_string
                      "Block height not greater than in fork config" )
               else if bad_slot then
                 Malleable_error.hard_error
                   (Error.of_string "Block slot not greater than in fork config")
               else return () )
         in
         return () )
    in
    section_hard "running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ (Network.archive_nodes network |> Core.Map.data))
       in
       check_replayer_logs ~logger logs )
end
