let SelectFiles = ../Lib/SelectFiles.dhall
let PipelineMode = ./Mode.dhall

in

-- Defines info used for selecting a job to run
-- path is relative to `src/jobs/`
{
  Type = {
    path: Text,
    name: Text,
    mode: PipelineMode.Mode,
    dirtyWhen: List SelectFiles.Type
  },
  default = {
    path = ".",
    mode = PipelineMode.Mode.PullRequest
  }
}
