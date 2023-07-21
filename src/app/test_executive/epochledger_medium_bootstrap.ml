open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =

    let k=2 in
    
    let open Test_config in
    { default with
      k
    ; slots_per_epoch = 3 *  8  * k 
    ; requires_graphql = true
    ; genesis_ledger =
        [ { account_name = "node-a-key"; balance = "1000"; timing = Untimed }
        ; { account_name = "node-b-key"; balance = "1000"; timing = Untimed }
        ; { account_name = "node-c-key"; balance = "0"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ; { node_name = "node-c"; account_name = "node-c-key" }
        ]
     ;  proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.medium
        }
    }
    
  (*
     There are 3 cases of bootstrap that we need to test:

     1: short bootstrap-- bootstrap where node has been down for less than 2k+1 blocks
     2: medium bootstrap-- bootstrap where node has been down for more than 2k+1 blocks, OR equivalently when the blockchain is longer than 2k+1 blocks and a node goes down and resets to a fresh state, thereby resetting at the genesis block, before reconnecting to the network
     3: long bootstrap-- bootstrap where node has been down for more than 42k slots (2 epochs) where each epoch emitted at least 1 parallel scan state proof
  *)

let send_padding_transactions ~fee ~logger ~n nodes =
    let sender = List.nth_exn nodes 0 in
    let receiver = List.nth_exn nodes 1 in
    let open Malleable_error.Let_syntax in
    let%bind sender_pub_key = pub_key_of_node sender in
    let%bind receiver_pub_key = pub_key_of_node receiver in
    repeat_seq ~n ~f:(fun () ->
        Network.Node.must_send_payment ~logger sender ~sender_pub_key
          ~receiver_pub_key ~amount:Currency.Amount.one ~fee
        >>| ignore )

  (* this test is the medium bootstrap test *)

  let run network t =
    let slot_ms = Option.value_exn config.proof_config.block_window_duration_ms in
    (* time for 1 epoch *)
    let epoch_ms = config.slots_per_epoch * slot_ms |> Float.of_int in 
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let block_producer_nodes =
      Network.block_producers network |> Core.String.Map.data
    in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize (Core.String.Map.data all_nodes))
    in
    let node_a =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let node_b =
      Core.String.Map.find_exn (Network.block_producers network) "node-b"
    in
    let node_c =
      Core.String.Map.find_exn (Network.block_producers network) "node-c"
    in
    
    (*let%bind () =
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      send_padding_transactions block_producer_nodes ~fee ~logger
        ~n:1000
    in
     *) 
    let%bind () =
      section "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section "restart node after 2k+1, ie 5, blocks"
        (let%bind () = Node.stop node_c in
        let%bind () =
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          send_padding_transactions block_producer_nodes ~fee ~logger
          ~n:36 (* sending 36 txn *)
        in
         [%log info] "%s stopped, will now wait for 1 epoch"
           (Node.id node_c) ;
        (* let%bind () = wait_for t (Wait_condition.blocks_to_be_produced 5) in *)
         let%bind () =  Malleable_error.lift (Async.after (Time.Span.of_ms epoch_ms)) in
        (*
          Wait for staking epoch ledger
                let%bind () = wait_for t (Wait_condition.epoch_ledger_being_updated ~ledger:`staking)
        in
        *)
         let%bind () =
          let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
          send_padding_transactions block_producer_nodes ~fee ~logger
          ~n:36 (* sending 36 txn *)
        in
         [%log info] "%s waiting 1 epoch to complete"
           (Node.id node_c) ;
        let%bind () =  Malleable_error.lift (Async.after (Time.Span.of_ms epoch_ms)) in
        (*
          Once Jiawei checks in this code will work
                let%bind () = wait_for t (Wait_condition.epoch_ledger_being_updated ~ledger:`Next)
        in
        *)
         [%log info] "  epoch completed start the node %s"
          (Node.id node_c) ;
         let%bind () = Node.start ~fresh_state:true node_c in
         [%log info]
           "%s started again, will now wait for this node to initialize"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.node_to_initialize node_c) in
         wait_for t
           (Wait_condition.nodes_to_synchronize [ node_a; node_b; node_c ]) )
    in

    section "network is fully connected after one node was restarted"
      (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
       let%bind final_connectivity_data =
         fetch_connectivity_data ~logger (Core.String.Map.data all_nodes)
       in
       assert_peers_completely_connected final_connectivity_data )
end
