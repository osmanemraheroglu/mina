-- Mode defines pipeline stages
--
-- A pipeline in order to be faster and more cost efficient can have up to 3 stages
-- Between each stages there is a '- wait' step defined which cause buildkite to wait 
-- for ALL jobs to complete before running any job from next stage.
-- Current design defines three stages:
-- - Stage 1 -> contains fastest and most independent jobs which are supposed to provide quickest feedback possible 
-- - Stage 2 -> contains heavy jobs that should be run only on clean code (no merges issues or lints problems)
-- - Tear down -> should contains all clean up or reporting jobs. For example test coverage gathering

let Prelude = ../External/Prelude.dhall

let Stage : Type = < Stage1 | Stage2 | TearDown >

let toNatural: Stage -> Natural = \(stage: Stage) -> 
  merge {
    Stage1 = 1
    , Stage2 = 2
    , TearDown = 3
  } stage

let equal: Stage -> Stage -> Bool = \(left: Stage) -> \(right: Stage) ->
  Prelude.Natural.equal (toNatural left) (toNatural right) 

let capitalName = \(stage : Stage) ->
  merge {
    Stage1 = "Stage1"
    , Stage2 = "Stage2"
    , TearDown = "TearDown"
  } stage

let lowerName = \(stage : Stage) ->
  merge {
    Stage1 = "stage1"
    , Stage2 = "stage2"
    , TearDown = "tearDown"
  } stage


in
{ 
  Type = Stage,
  capitalName = capitalName,
  lowerName = lowerName,
  toNatural = toNatural,
  equal = equal
}