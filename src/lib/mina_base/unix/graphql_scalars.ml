open Graphql_basic_scalars

module TokenId =
  Make_scalar_using_to_string
    (Mina_base.Token_id)
    (struct
      let name = "TokenId"

      let doc = "String representation of a token's UInt64 identifier"
    end)

module StateHash =
  Make_scalar_using_base58_check
    (Mina_base.State_hash)
    (struct
      let name = "StateHash"

      let doc = "Base58Check-encoded state hash"
    end)

module ChainHash =
  Make_scalar_using_base58_check
    (Mina_base.Receipt.Chain_hash)
    (struct
      let name = "ChainHash"

      let doc = "Base58Check-encoded chain hash"
    end)

module EpochSeed =
  Make_scalar_using_base58_check
    (Mina_base.Epoch_seed)
    (struct
      let name = "EpochSeed"

      let doc = "Base58Check-encoded epoch seed"
    end)

module LedgerHash =
  Make_scalar_using_base58_check
    (Mina_base.Ledger_hash)
    (struct
      let name = "LedgerHash"

      let doc = "Base58Check-encoded ledger hash"
    end)

module TransactionHash =
  Make_scalar_using_base58_check
    (Mina_base.Transaction_hash)
    (struct
      let name = "TransactionHash"

      let doc = "Base58Check-encoded transaction hash"
    end)

module TransactionStatusFailure :
  Json_intf with type t = Mina_base.Transaction_status.Failure.t = struct
  open Mina_base.Transaction_status.Failure

  type nonrec t = t

  let parse json =
    json |> Yojson.Basic.Util.to_string |> of_string
    |> Base.Result.ok_or_failwith

  let serialize x = `String (to_string x)

  let typ () =
    Graphql_async.Schema.scalar "TransactionStatusFailure"
      ~doc:"transaction status failure" ~coerce:serialize
end
