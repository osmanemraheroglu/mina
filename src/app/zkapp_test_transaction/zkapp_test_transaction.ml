open Core_kernel
open Async
open Mina_base
open Signature_lib
open Cli_lib.Arg_type
open Zkapp_test_transaction_lib.Commands

module Flags = struct
  open Command

  let default_fee = Currency.Fee.of_mina_string_exn "1"

  let min_fee = Currency.Fee.of_mina_string_exn "0.003"

  let memo =
    Param.flag "--memo" ~doc:"STRING Memo accompanying the transaction"
      Param.(optional string)

  let fee =
    Param.flag "--fee"
      ~doc:
        (Printf.sprintf
           "FEE Amount you are willing to pay to process the transaction \
            (default: %s) (minimum: %s)"
           (Currency.Fee.to_mina_string default_fee)
           (Currency.Fee.to_mina_string min_fee) )
      (Param.optional txn_fee)

  let amount =
    Param.flag "--receiver-amount" ~doc:"NN Receiver amount in Mina"
      (Param.required txn_amount)

  let nonce =
    Param.flag "--nonce" ~doc:"NN Nonce of the fee payer account"
      Param.(required txn_nonce)

  let common_flags =
    Command.(
      let open Let_syntax in
      let%map keyfile =
        Param.flag "--fee-payer-key"
          ~doc:
            "KEYFILE Private key file for the fee payer of the transaction \
             (should already be in the ledger)"
          Param.(required string)
      and fee = fee
      and nonce = nonce
      and memo = memo
      and debug =
        Param.flag "--debug" Param.no_arg
          ~doc:"Debug mode, generates transaction snark"
      in
      (keyfile, fee, nonce, memo, debug))
end

let create_zkapp_account =
  let create_command ~debug ~sender ~sender_nonce ~fee ~fee_payer
      ~fee_payer_nonce ~zkapp_keyfile ~amount ~memo () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      create_zkapp_account ~debug ~sender ~sender_nonce ~fee ~fee_payer
        ~fee_payer_nonce ~zkapp_keyfile ~amount ~memo
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a zkApp transaction that creates a zkApp account"
      (let%map fee_payer, fee, fee_payer_nonce, memo, debug = Flags.common_flags
       and sender =
         Param.flag "--sender-key"
           ~doc:
             "KEYFILE Private key file for the sender of the transaction \
              (should already be in the ledger)"
           Param.(required string)
       and sender_nonce =
         Param.flag "--sender-nonce" ~doc:"NN Nonce of the sender account"
           Param.(required txn_nonce)
       and zkapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file for the zkApp account to be created"
           Param.(required string)
       and amount = Flags.amount in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       create_command ~debug ~sender ~sender_nonce ~fee ~fee_payer
         ~fee_payer_nonce ~zkapp_keyfile ~amount ~memo ))

let upgrade_zkapp =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
      ~verification_key ~zkapp_uri ~auth () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      upgrade_zkapp ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
        ~verification_key ~zkapp_uri ~auth
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a zkApp transaction that updates the verification key"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and zkapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file for the zkApp account to be upgraded"
           Param.(required string)
       and verification_key =
         Param.flag "--verification-key"
           ~doc:"VERIFICATION_KEY the verification key for the zkApp account"
           Param.(required string)
       and zkapp_uri_str =
         Param.flag "--zkapp-uri" ~doc:"URI the URI for the zkApp account"
           Param.(optional string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change the verification key"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       let zkapp_uri = Zkapp_basic.Set_or_keep.of_option zkapp_uri_str in
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
         ~verification_key ~zkapp_uri ~auth ))

let transfer_funds_one_receiver =
  let create_command ~debug ~sender ~sender_nonce ~fee ~fee_payer
      ~fee_payer_nonce ~memo ~receiver ~amount () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      transfer_funds ~debug ~sender ~sender_nonce ~fee ~fee_payer
        ~fee_payer_nonce ~memo
        ~receivers:(Deferred.return [ (receiver, amount) ])
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a zkApp Transaction that makes one transfer to the receiver \
         account"
      (let%map fee_payer, fee, fee_payer_nonce, memo, debug = Flags.common_flags
       and sender =
         Param.flag "--sender-key"
           ~doc:
             "KEYFILE Private key file for the sender of the transaction \
              (should already be in the ledger)"
           Param.(required string)
       and sender_nonce =
         Param.flag "--sender-nonce" ~doc:"NN Nonce of the sender account"
           Param.(required txn_nonce)
       and receiver =
         Param.flag "--receiver"
           ~doc:"PUBLIC_KEY the public key of the receiver"
           Param.(required public_key_compressed)
       and amount = Flags.amount in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwithf "Fee must at least be %s"
           (Currency.Fee.to_mina_string Flags.min_fee)
           () ;
       create_command ~debug ~sender ~sender_nonce ~fee ~fee_payer
         ~fee_payer_nonce ~memo ~receiver ~amount ))

let transfer_funds =
  let create_command ~debug ~sender ~sender_nonce ~fee ~fee_payer
      ~fee_payer_nonce ~memo ~receivers () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      transfer_funds ~debug ~sender ~sender_nonce ~fee ~fee_payer
        ~fee_payer_nonce ~memo ~receivers
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  let read_key_and_amount count =
    let read () =
      let open Deferred.Let_syntax in
      printf "Receiver Key:%!" ;
      match%bind Reader.read_line (Lazy.force Reader.stdin) with
      | `Ok key -> (
          let pk =
            Signature_lib.Public_key.Compressed.of_base58_check_exn key
          in
          printf !"Amount:%!" ;
          match%map Reader.read_line (Lazy.force Reader.stdin) with
          | `Ok amt ->
              let amount = Currency.Amount.of_mina_string_exn amt in
              (pk, amount)
          | `Eof ->
              failwith "Invalid amount" )
      | `Eof ->
          failwith "Invalid key"
    in
    let rec go ?(prompt = true) count keys =
      if count <= 0 then return keys
      else if prompt then (
        printf "Continue? [N/y]\n%!" ;
        match%bind Reader.read_line (Lazy.force Reader.stdin) with
        | `Ok r ->
            if String.Caseless.equal r "y" then
              let%bind key = read () in
              go (count - 1) (key :: keys)
            else return keys
        | `Eof ->
            return keys )
      else
        let%bind key = read () in
        go (count - 1) (key :: keys)
    in
    printf "Enter at most %d receivers (Base58Check encoding) and amounts\n%!"
      count ;
    let%bind ks = go ~prompt:false 1 [] in
    go (count - 1) ks
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a zkApp transaction that makes multiple transfers from one \
         account"
      (let%map fee_payer, fee, fee_payer_nonce, memo, debug = Flags.common_flags
       and sender =
         Param.flag "--sender-key"
           ~doc:
             "KEYFILE Private key file for the sender of the transaction \
              (should already be in the ledger)"
           Param.(required string)
       and sender_nonce =
         Param.flag "--sender-nonce" ~doc:"NN Nonce of the sender account"
           Param.(required txn_nonce)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwithf "Fee must at least be %s"
           (Currency.Fee.to_mina_string Flags.min_fee)
           () ;
       let max_keys = 10 in
       let receivers = read_key_and_amount max_keys in
       create_command ~debug ~sender ~sender_nonce ~fee ~fee_payer
         ~fee_payer_nonce ~memo ~receivers ))

let update_state =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile ~app_state
      () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      update_state ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile ~app_state
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a zkApp transaction that updates zkApp state"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and zkapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file of the zkApp account to be updated"
           Param.(required string)
       and app_state =
         Param.flag "--zkapp-state"
           ~doc:
             "String(hash)|Integer(field element) a list of 8 elements that \
              represent the zkApp state (Use empty string for no-op)"
           Param.(listed string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
         ~app_state ))

let update_zkapp_uri =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~zkapp_uri
      ~auth () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      update_zkapp_uri ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
        ~zkapp_uri ~auth
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a zkApp transaction that updates the zkApp URI"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file of the zkApp account to be updated"
           Param.(required string)
       and zkapp_uri =
         Param.flag "--zkapp-uri"
           ~doc:"SNAPP_URI The string to be used as the updated zkApp URI"
           Param.(required string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change the zkApp URI"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~zkapp_uri ~auth ))

let update_action_state =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
      ~action_state () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      update_action_state ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
        ~action_state
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a zkApp transaction that updates zkApp state"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and zkapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file of the zkApp account to be updated"
           Param.(required string)
       and action_state0 =
         Param.flag "--sequence-state0"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             required
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string ))
       and action_state1 =
         Param.flag "--sequence-state1"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string ))
       and action_state2 =
         Param.flag "--sequence-state2"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string ))
       and action_state3 =
         Param.flag "--sequence-state3"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string ))
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let action_state =
         List.filter_map
           ~f:(fun s -> if List.is_empty s then None else Some (Array.of_list s))
           [ action_state0; action_state1; action_state2; action_state3 ]
       in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
         ~action_state ))

let update_token_symbol =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~token_symbol ~auth () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      update_token_symbol ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
        ~token_symbol ~auth
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a zkApp transaction that updates token symbol"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file of the zkApp account to be updated"
           Param.(required string)
       and token_symbol =
         Param.flag "--token-symbol"
           ~doc:"TOKEN_SYMBOL The string to be used as the updated token symbol"
           Param.(required string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change the token symbol"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~token_symbol ~auth ))

let update_permissions =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
      ~snapp_update ~current_auth () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      update_snapp ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
        ~snapp_update ~current_auth
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a zkApp transaction that updates the permissions of a zkApp \
         account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and zkapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file of the zkApp account to be updated"
           Param.(required string)
       and edit_state =
         Param.flag "--edit-state" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and send =
         Param.flag "--send" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and receive =
         Param.flag "--receive" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and access =
         Param.flag "--access" ~doc:"Proof|Signature|Either|None"
           Param.(optional_with_default "None" string)
       and set_permissions =
         Param.flag "--set-permissions" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_delegate =
         Param.flag "--set-delegate" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_verification_key =
         Param.flag "--set-verification-key" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_zkapp_uri =
         Param.flag "--set-zkapp-uri" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and edit_action_state =
         Param.flag "--set-sequence-state" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_token_symbol =
         Param.flag "--set-token-symbol" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and increment_nonce =
         Param.flag "--increment-nonce" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_voting_for =
         Param.flag "--set-voting-for" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_timing =
         Param.flag "--set-timing" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and current_auth =
         Param.flag "--current-auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change permissions"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let permissions : Permissions.t Zkapp_basic.Set_or_keep.t =
         Zkapp_basic.Set_or_keep.Set
           { Permissions.Poly.edit_state = Util.auth_of_string edit_state
           ; send = Util.auth_of_string send
           ; receive = Util.auth_of_string receive
           ; access = Util.auth_of_string access
           ; set_permissions = Util.auth_of_string set_permissions
           ; set_delegate = Util.auth_of_string set_delegate
           ; set_verification_key = Util.auth_of_string set_verification_key
           ; set_zkapp_uri = Util.auth_of_string set_zkapp_uri
           ; edit_action_state = Util.auth_of_string edit_action_state
           ; set_token_symbol = Util.auth_of_string set_token_symbol
           ; increment_nonce = Util.auth_of_string increment_nonce
           ; set_voting_for = Util.auth_of_string set_voting_for
           ; set_timing = Util.auth_of_string set_timing
           }
       in
       let snapp_update = { Account_update.Update.dummy with permissions } in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
         ~snapp_update
         ~current_auth:(Util.auth_of_string current_auth) ))

let update_timings =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
      ~snapp_update ~current_auth () =
    let open Deferred.Let_syntax in
    let%map zkapp_command =
      update_snapp ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
        ~snapp_update ~current_auth
    in
    Util.print_snapp_transaction ~debug zkapp_command ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a zkApp transaction that updates the timings of a zkApp \
         account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and zkapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file of the zkApp account to be updated"
           Param.(required string)
       and initial_minimum_balance =
         Param.flag "--initial-minimum-balance"
           ~doc:"initial minimum balance as int"
           Param.(required int)
       and cliff_time =
         Param.flag "--cliff-time" ~doc:"cliff time in int" Param.(required int)
       and cliff_amount =
         Param.flag "--cliff-amount" ~doc:"cliff amount in int"
           Param.(required int)
       and vesting_period =
         Param.flag "--vesting-period" ~doc:"vesting period in int"
           Param.(required int)
       and vesting_increment =
         Param.flag "--vesting-increment" ~doc:"vesting increment in int"
           Param.(required int)
       and current_auth =
         Param.flag "--current-auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change permissions"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let timing =
         Zkapp_basic.Set_or_keep.Set
           ( { initial_minimum_balance =
                 Currency.Balance.of_mina_int_exn initial_minimum_balance
             ; cliff_time =
                 Mina_numbers.Global_slot_since_genesis.of_int cliff_time
             ; cliff_amount = Currency.Amount.of_mina_int_exn cliff_amount
             ; vesting_period =
                 Mina_numbers.Global_slot_span.of_int vesting_period
             ; vesting_increment =
                 Currency.Amount.of_mina_int_exn vesting_increment
             }
             : Account_update.Update.Timing_info.value )
       in
       let snapp_update = { Account_update.Update.dummy with timing } in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_mina_string Flags.min_fee) ) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
         ~snapp_update
         ~current_auth:(Util.auth_of_string current_auth) ))

let test_zkapp_with_genesis_ledger =
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a trivial zkApp transaction and genesis ledger with \
         verification key for testing"
      (let%map keyfile =
         Param.flag "--fee-payer-key"
           ~doc:
             "KEYFILE Private key file for the fee payer of the transaction \
              (should be in the genesis ledger)"
           Param.(required string)
       and zkapp_keyfile =
         Param.flag "--zkapp-account-key"
           ~doc:"KEYFILE Private key file to create a new zkApp account"
           Param.(required string)
       and config_file =
         Param.flag "--config-file" ~aliases:[ "config-file" ]
           ~doc:
             "PATH path to a configuration file consisting the genesis ledger"
           Param.(required string)
       in
       test_zkapp_with_genesis_ledger_main keyfile zkapp_keyfile config_file ))


let gen_keys count =
  Quickcheck.random_value ~seed:`Nondeterministic
    (Quickcheck.Generator.list_with_length count Public_key.Compressed.gen)

let output_keys =
  let open Command.Let_syntax in
  Command.basic ~summary:"Generate the given number of public keys on stdout"
    (let%map_open count =
       flag "--count" ~aliases:[ "count" ] ~doc:"NUM Number of keys to generate"
         (required int)
     in
     fun () ->
       List.iter (gen_keys count) ~f:(fun pk ->
           Format.printf "%s@." (Public_key.Compressed.to_base58_check pk) ) )

let output_cmds =
  let open Command.Let_syntax in
  Command.basic ~summary:"Generate the given number of public keys on stdout"
    (let%map_open count =
       flag "--count" ~aliases:[ "count" ] ~doc:"NUM Number of keys to generate"
         (required int)
     and txns_per_block =
       flag "--txn-capacity-per-block"
         ~aliases:[ "txn-capacity-per-block" ]
         ~doc:
           "NUM Transaction capacity per block. Used for rate limiting. \
            (default: 128)"
         (optional_with_default 128 int)
     and slot_time =
       flag "--slot-time" ~aliases:[ "slot-time" ]
         ~doc:
           "NUM_MILLISECONDS Slot duration in milliseconds. (default: 180000)"
         (optional_with_default 180000 int)
     and fill_rate =
       flag "--fill-rate" ~aliases:[ "fill-rate" ]
         ~doc:"FILL_RATE Fill rate (default: 0.75)"
         (optional_with_default 0.75 float)
     and rate_limit =
       flag "--apply-rate-limit" ~aliases:[ "apply-rate-limit" ]
         ~doc:
           "TRUE/FALSE Whether to emit sleep commands between commands to \
            enforce sleeps (default: true)"
         (optional_with_default true bool)
     and rate_limit_level =
       flag "--rate-limit-level" ~aliases:[ "rate-limit-level" ]
         ~doc:
           "NUM Number of transactions that can be sent in a time interval \
            before hitting the rate limit (default: 200)"
         (optional_with_default 200 int)
     and rate_limit_interval =
       flag "--rate-limit-interval" ~aliases:[ "rate-limit-interval" ]
         ~doc:
           "NUM_MILLISECONDS Interval that the rate-limiter is applied over \
            (default: 300000)"
         (optional_with_default 300000 int)
     and sender_key =
       flag "--sender-pk" ~aliases:[ "sender-pk" ]
         ~doc:"PUBLIC_KEY Public key to send the transactions from"
         (required string)
     in
     fun () ->
       let rate_limit =
         if rate_limit then
           let slot_limit =
             Float.(
               of_int txns_per_block /. of_int slot_time *. fill_rate
               *. of_int rate_limit_interval)
           in
           let limit = min (Float.to_int slot_limit) rate_limit_level in
           Some limit
         else None
       in
       let batch_count = ref 0 in
       List.iter (gen_keys count) ~f:(fun pk ->
           Option.iter rate_limit ~f:(fun rate_limit ->
               if !batch_count >= rate_limit then (
                 Format.printf "sleep %f@."
                   Float.(of_int rate_limit_interval /. 1000.) ;
                 batch_count := 0 )
               else incr batch_count ) ;
           Format.printf
             "mina client send-payment --amount 1 --receiver %s --sender %s@."
             (Public_key.Compressed.to_base58_check pk)
             sender_key ) )

let output_there_and_back_cmds =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Generate commands to send funds from a single account to many accounts, \
       then transfer them back again. The 'back again' commands are expressed \
       as GraphQL commands, so that we can pass a signature, rather than \
       having to load the secret key for each account"
    (let%map_open num_txn_per_acct =
       flag "--num-txn-per-acct" ~aliases:[ "num-txn-per-acct" ]
         ~doc:"NUM Number of transactions to run for each generated key"
         (required int)
     and txns_per_block =
       flag "--txn-capacity-per-block"
         ~aliases:[ "txn-capacity-per-block" ]
         ~doc:
           "NUM Number of transaction that a single block can hold.  Used for \
            rate limiting (default: 128)"
         (optional_with_default 128 int)
     and txn_fee_option =
       flag "--txn-fee" ~aliases:[ "txn-fee" ]
         ~doc:
           "FEE_AMOUNT Fee to set, a default is provided if this is not present"
         (optional string)
     and slot_time =
       flag "--slot-time" ~aliases:[ "slot-time" ]
         ~doc:
           "NUM_MILLISECONDS Slot duration in milliseconds. Used for rate \
            limiting (default: 180000)"
         (optional_with_default 180000 int)
     and fill_rate =
       flag "--fill-rate" ~aliases:[ "fill-rate" ]
         ~doc:
           "FILL_RATE The average rate of blocks per slot. Used for rate \
            limiting (default: 0.75)"
         (optional_with_default 0.75 float)
     and rate_limit =
       flag "--apply-rate-limit" ~aliases:[ "apply-rate-limit" ]
         ~doc:
           "TRUE/FALSE Whether to emit sleep commands between commands to \
            enforce sleeps (default: true)"
         (optional_with_default true bool)
     and rate_limit_level =
       flag "--rate-limit-level" ~aliases:[ "rate-limit-level" ]
         ~doc:
           "NUM Number of transactions that can be sent in a time interval \
            before hitting the rate limit. Used for rate limiting (default: \
            200)"
         (optional_with_default 200 int)
     and rate_limit_interval =
       flag "--rate-limit-interval" ~aliases:[ "rate-limit-interval" ]
         ~doc:
           "NUM_MILLISECONDS Interval that the rate-limiter is applied over. \
            Used for rate limiting (default: 300000)"
         (optional_with_default 300000 int)
     and origin_sender_secret_key_path =
       flag "--origin-sender-sk-path"
         ~aliases:[ "origin-sender-sk-path" ]
         ~doc:"PRIVATE_KEY Path to Private key to send the transactions from"
         (required string)
     and origin_sender_secret_key_pw_option =
       flag "--origin-sender-sk-pw" ~aliases:[ "origin-sender-sk-pw" ]
         ~doc:
           "PRIVATE_KEY Password to Private key to send the transactions from, \
            if this is not present then we use the env var MINA_PRIVKEY_PASS"
         (optional string)
     and returner_secret_key_path =
       flag "--returner-sk-path" ~aliases:[ "returner-sk-path" ]
         ~doc:
           "PRIVATE_KEY Path to Private key of account that returns the \
            transactions"
         (required string)
     and returner_secret_key_pw_option =
       flag "--returner-sk-pw" ~aliases:[ "returner-sk-pw" ]
         ~doc:
           "PRIVATE_KEY Password to Private key account that returns the \
            transactions, if this is not present then we use the env var \
            MINA_PRIVKEY_PASS"
         (optional string)
     and graphql_target_node_option =
       flag "--graphql-target-node" ~aliases:[ "graphql-target-node" ]
         ~doc:
           "URL The graphql node to send graphl commands to.  must be in \
            format `<ip>:<port>`.  default is `127.0.0.1:3085`"
         (optional string)
     in
     there_and_back_again ~num_txn_per_acct ~txns_per_block ~txn_fee_option
       ~slot_time ~fill_rate ~rate_limit ~rate_limit_level ~rate_limit_interval
       ~origin_sender_secret_key_path ~origin_sender_secret_key_pw_option
       ~returner_secret_key_path ~returner_secret_key_pw_option
       ~graphql_target_node_option )

let txn_commands =
  [ ("create-zkapp-account", create_zkapp_account)
  ; ("upgrade-zkapp", upgrade_zkapp)
  ; ("transfer-funds", transfer_funds)
  ; ("transfer-funds-one-receiver", transfer_funds_one_receiver)
  ; ("update-state", update_state)
  ; ("update-zkapp-uri", update_zkapp_uri)
  ; ("update-sequence-state", update_action_state)
  ; ("update-token-symbol", update_token_symbol)
  ; ("update-permissions", update_permissions)
  ; ("update-timings", update_timings)
  ; ("test-zkapp-with-genesis-ledger", test_zkapp_with_genesis_ledger)
  ]

let load_commands  =
       [ ("gen-keys", output_keys)
       ; ("gen-txns", output_cmds)
       ; ("gen-there-and-back-txns", output_there_and_back_cmds)
       ]

let commands =
  [ ( "zkapps"
    , Command.group ~summary:"zkapps related commands"
    txn_commands )
    ; ( "load"
    , Command.group ~summary:"load related commands"
    load_commands )
  ]




let () =
  Command.run
    (Command.group ~summary:"ZkApp test transaction"
       ~preserve_subcommand_order:() commands )
