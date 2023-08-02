let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let CoverageTearDown = ../../Command/CoverageTearDown.dhall

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [ SelectFiles.everything ],
    path = "Test",
    mode = PipelineMode.Mode.PullRequestTearDown,
    name = "CoverageTearDown"
  },
  steps = [
    CoverageTearDown.execute
  ]
}