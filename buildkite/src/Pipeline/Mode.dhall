let Prelude = ../External/Prelude.dhall

let Mode = <PullRequest | PullRequestTearDown | Stable>

let capitalName = \(pipelineMode : Mode) ->
  merge {
    PullRequest = "PullRequest"
    , PullRequestTearDown = "PullRequestTearDown"
    , Stable = "Stable"
  } pipelineMode

in
{ 
    Mode = Mode,
    capitalName = capitalName
}