-- Mode defines pipeline goal
--
-- Goal of the pipeline can be either quick feedback for CI changes
-- or Nightly run which supposed to be run only on stable changes.

let Prelude = ../External/Prelude.dhall

let Mode = < PullRequest | Stable >

let capitalName = \(pipelineMode : Mode) ->
  merge {
    PullRequest = "PullRequest"
    , Stable = "Stable"
  } pipelineMode

let toNatural: Mode -> Natural = \(mode: Mode) -> 
  merge {
    PullRequest = 1
    , Stable = 2
  } mode

let equal: Mode -> Mode -> Bool = \(left: Mode) -> \(right: Mode) ->
  Prelude.Natural.equal (toNatural left) (toNatural right) 

in
{ 
    Type = Mode,
    capitalName = capitalName,
    toNatural = toNatural,
    equal = equal,
}