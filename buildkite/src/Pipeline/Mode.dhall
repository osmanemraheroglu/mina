let Prelude = ../External/Prelude.dhall

let Mode = <PullRequest | Stable>

let capitalName = \(pipelineMode : Mode) ->
  merge {
    PullRequest = "PullRequest"
    , Stable = "Stable"
  } pipelineMode

in
{ 
    Mode = Mode,
    capitalName = capitalName
}