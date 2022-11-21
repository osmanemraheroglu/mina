(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Allow.t : Allow specifies supported Operation status, Operation types, and all possible error statuses. This Allow object is used by clients to validate the correctness of a Rosetta Server implementation. It is expected that these clients will error if they receive some response that contains any of the above information that is not specified here. 
 *)

type t =
  { (* All Operation.Status this implementation supports. Any status that is returned during parsing that is not listed here will cause client validation to error.  *)
    operation_statuses : Operation_status.t list
  ; (* All Operation.Type this implementation supports. Any type that is returned during parsing that is not listed here will cause client validation to error.  *)
    operation_types : string list
  ; (* All Errors that this implementation could return. Any error that is returned during parsing that is not listed here will cause client validation to error.  *)
    errors : Error.t list
  ; (* Any Rosetta implementation that supports querying the balance of an account at any height in the past should set this to true.  *)
    historical_balance_lookup : bool
  ; (* If populated, `timestamp_start_index` indicates the first block index where block timestamps are considered valid (i.e. all blocks less than `timestamp_start_index` could have invalid timestamps). This is useful when the genesis block (or blocks) of a network have timestamp 0.  If not populated, block timestamps are assumed to be valid for all available blocks.  *)
    timestamp_start_index : int64 option [@default None]
  ; (* All methods that are supported by the /call endpoint. Communicating which parameters should be provided to /call is the responsibility of the implementer (this is en lieu of defining an entire type system and requiring the implementer to define that in Allow).  *)
    call_methods : string list
  ; (* BalanceExemptions is an array of BalanceExemption indicating which account balances could change without a corresponding Operation.  BalanceExemptions should be used sparingly as they may introduce significant complexity for integrators that attempt to reconcile all account balance changes.  If your implementation relies on any BalanceExemptions, you MUST implement historical balance lookup (the ability to query an account balance at any BlockIdentifier).  *)
    balance_exemptions : Balance_exemption.t list
  ; (* Any Rosetta implementation that can update an AccountIdentifier's unspent coins based on the contents of the mempool should populate this field as true. If false, requests to `/account/coins` that set `include_mempool` as true will be automatically rejected.  *)
    mempool_coins : bool
  ; block_hash_case : Enums.case option [@default None]
  ; transaction_hash_case : Enums.case option [@default None]
  }
[@@deriving yojson { strict = false }, show, eq]

(** Allow specifies supported Operation status, Operation types, and all possible error statuses. This Allow object is used by clients to validate the correctness of a Rosetta Server implementation. It is expected that these clients will error if they receive some response that contains any of the above information that is not specified here.  *)
let create (operation_statuses : Operation_status.t list)
    (operation_types : string list) (errors : Error.t list)
    (historical_balance_lookup : bool) (call_methods : string list)
    (balance_exemptions : Balance_exemption.t list) (mempool_coins : bool) : t =
  { operation_statuses
  ; operation_types
  ; errors
  ; historical_balance_lookup
  ; timestamp_start_index = None
  ; call_methods
  ; balance_exemptions
  ; mempool_coins
  ; block_hash_case = None
  ; transaction_hash_case = None
  }
