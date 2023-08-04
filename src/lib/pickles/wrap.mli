open Pickles_types
open Import

type scalar_challenge_constant = Challenge.Constant.t Scalar_challenge.t

val wrap :
     max_proofs_verified:'max_proofs_verified Nat.t
  -> (module Pickles_types.Hlist.Maxes.S
        with type length = 'max_proofs_verified
         and type ns = 'max_local_max_proofs_verifieds )
  -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
  -> dlog_plonk_index:
       Kimchi_pasta_basic.Pallas.Affine.t Plonk_verification_key_evals.t
  -> (   ( Impls.Wrap.Digest.t
         , Impls.Wrap.Digest.t Kimchi_types.scalar_challenge
         , Impls.Wrap.Digest.t Shifted_value.Type1.t
         , ( Impls.Wrap.Digest.t Kimchi_types.scalar_challenge
             Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
           , Pasta_bindings.Fq.t Challenge.t Snarky_backendless.Boolean.t )
           Plonk_types.Opt.t
         , Impls.Wrap.Impl.Boolean.var
         , Pasta_bindings.Fq.t Challenge.t
         , Pasta_bindings.Fq.t Challenge.t
         , Pasta_bindings.Fq.t Challenge.t
         , ( Pasta_bindings.Fq.t Challenge.t Kimchi_types.scalar_challenge
             Bulletproof_challenge.t
           , Nat.z Backend.Tick.Rounds.plus_n )
           Vector.vec
         , Pasta_bindings.Fq.t Challenge.t )
         Types.Wrap.Statement.In_circuit.t
      -> unit )
  -> typ:('a, 'b) Impls.Step.Typ.t
  -> step_vk:Kimchi_bindings.Protocol.VerifierIndex.Fp.t
  -> actual_wrap_domains:(int, 'c) Vector.vec
  -> step_plonk_indices:'d
  -> actual_feature_flags:bool Plonk_types.Features.t
  -> ?tweak_statement:
       (   ( Challenge.Constant.t
           , scalar_challenge_constant
           , Pasta_bindings.Fp.t Shifted_value.Type1.t
           , ( scalar_challenge_constant
               Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
             , bool )
             Plonk_types.Opt.t
           , bool
           , 'max_proofs_verified
             Reduced_messages_for_next_proof_over_same_field.Wrap.t
           , (int64, Nat.N4.n) Vector.vec
           , ( 'b
             , ( Backend.Tock.Proof.G.Affine.t
               , 'actual_proofs_verified )
               Vector.vec
             , ( ( Challenge.Constant.t Kimchi_types.scalar_challenge
                   Bulletproof_challenge.t
                 , 'e )
                 Vector.vec
               , 'actual_proofs_verified )
               Vector.vec )
             Reduced_messages_for_next_proof_over_same_field.Step.t
           , Challenge.Constant.t Kimchi_types.scalar_challenge
             Bulletproof_challenge.t
             Step_bp_vec.t
           , Branch_data.t )
           Types.Wrap.Statement.In_circuit.t
        -> ( Challenge.Constant.t
           , scalar_challenge_constant
           , Pasta_bindings.Fp.t Shifted_value.Type1.t
           , ( scalar_challenge_constant
               Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
             , bool )
             Plonk_types.Opt.t
           , bool
           , 'max_proofs_verified
             Reduced_messages_for_next_proof_over_same_field.Wrap.t
           , (int64, Nat.N4.n) Vector.vec
           , ( 'b
             , ( Backend.Tock.Proof.G.Affine.t
               , 'actual_proofs_verified )
               Vector.vec
             , ( ( Challenge.Constant.t Kimchi_types.scalar_challenge
                   Bulletproof_challenge.t
                 , 'e )
                 Vector.vec
               , 'actual_proofs_verified )
               Vector.vec )
             Reduced_messages_for_next_proof_over_same_field.Step.t
           , Challenge.Constant.t Kimchi_types.scalar_challenge
             Bulletproof_challenge.t
             Step_bp_vec.t
           , Branch_data.t )
           Types.Wrap.Statement.In_circuit.t )
  -> Backend.Tock.Keypair.t
  -> ( 'b
     , ( ( Challenge.Constant.t
         , Challenge.Constant.t Kimchi_types.scalar_challenge
         , Pasta_bindings.Fq.t Shifted_value.Type2.t
         , ( Challenge.Constant.t Kimchi_types.scalar_challenge
             Bulletproof_challenge.t
           , Backend.Tock.Rounds.n )
           Vector.vec
         , Impls.Wrap.Digest.Constant.t
         , bool )
         Types.Step.Proof_state.Per_proof.In_circuit.t
       , 'max_proofs_verified )
       Vector.vec
     , (Backend.Tock.Proof.G.Affine.t, 'actual_proofs_verified) Vector.vec
     , ( ( Challenge.Constant.t Kimchi_types.scalar_challenge
           Bulletproof_challenge.t
         , 'e )
         Vector.vec
       , 'actual_proofs_verified )
       Vector.vec
     , 'max_local_max_proofs_verifieds
       Hlist0.H1(Reduced_messages_for_next_proof_over_same_field.Wrap).t
     , ( (Pasta_bindings.Fq.t, Pasta_bindings.Fq.t array) Plonk_types.All_evals.t
       , 'max_proofs_verified )
       Vector.vec )
     Proof.Base.Step.t
  -> ( 'max_proofs_verified
       Reduced_messages_for_next_proof_over_same_field.Wrap.t
     , ( 'b
       , (Backend.Tock.Proof.G.Affine.t, 'actual_proofs_verified) Vector.vec
       , ( ( Challenge.Constant.t Kimchi_types.scalar_challenge
             Bulletproof_challenge.t
           , 'e )
           Vector.vec
         , 'actual_proofs_verified )
         Vector.vec )
       Reduced_messages_for_next_proof_over_same_field.Step.t )
     Proof.Base.Wrap.t
     Promise.t

val combined_inner_product :
     env:Backend.Tick.Field.t Plonk_checks.Scalars.Env.t
  -> domain:< shifts : Backend.Tick.Field.t array ; .. >
  -> ft_eval1:Backend.Tick.Field.t
  -> actual_proofs_verified:
       (module Pickles_types.Nat.Add.Intf with type n = 'actual_proofs_verified)
  -> ( Backend.Tick.Field.t * Backend.Tick.Field.t
     , Backend.Tick.Field.t array * Backend.Tick.Field.t array )
     Pickles_types.Plonk_types.All_evals.With_public_input.t
  -> old_bulletproof_challenges:
       ( (Backend.Tick.Field.t, 'a) Pickles_types.Vector.t
       , 'actual_proofs_verified )
       Pickles_types.Vector.t
  -> r:Backend.Tick.Field.t
  -> plonk:
       ( Backend.Tick.Field.t
       , Backend.Tick.Field.t
       , bool )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
  -> xi:Backend.Tick.Field.t
  -> zeta:Backend.Tick.Field.t
  -> zetaw:Backend.Tick.Field.t
  -> Backend.Tick.Field.t

val challenge_polynomial :
     Backend.Tick.Field.t array
  -> (Backend.Tick.Field.t -> Backend.Tick.Field.t) Core_kernel.Staged.t

module Type1 :
    module type of
      Plonk_checks.Make
        (Pickles_types.Shifted_value.Type1)
        (Plonk_checks.Scalars.Tick)
