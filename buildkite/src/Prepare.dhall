-- Autogenerates any pre-reqs for monorepo triage execution
-- Keep these rules lean! They have to run unconditionally.

let SelectFiles = ./Lib/SelectFiles.dhall
let Cmd = ./Lib/Cmds.dhall
let Prelude = ./External/Prelude.dhall
let Command = ./Command/Base.dhall
let Docker = ./Command/Docker/Type.dhall
let JobSpec = ./Pipeline/JobSpec.dhall
let Pipeline = ./Pipeline/Dsl.dhall
let PipelineStage = ./Pipeline/Stage.dhall
let PipelineMode = ./Pipeline/Mode.dhall
let Size = ./Command/Size.dhall
let triggerCommand = ./Pipeline/TriggerCommand.dhall

in (
  \(args : { stage : Text, mode: Text}) ->
 Pipeline.Config::{
  spec = JobSpec::{
    name = "prepare",
    -- TODO: Clean up this code so we don't need an unused dirtyWhen here
    dirtyWhen = [ SelectFiles.everything ]
  },
  steps = [
    Command.build Command.Config::{
      commands = [
        Cmd.run "./buildkite/scripts/generate-jobs.sh > buildkite/src/gen/Jobs.dhall",
        Cmd.quietly "dhall-to-yaml --quoted <<< '(./buildkite/src/Monorepo.dhall { stage = (./buildkite/src/Pipeline/Stage.dhall).Type.${args.stage}, mode = (./buildkite/src/Pipeline/Mode.dhall).Type.${args.mode} }).pipeline' | buildkite-agent pipeline upload" 
      ],
      label = "Prepare monorepo triage",
      key = "monorepo-${args.stage}",
      target = Size.Small,
      docker = Some Docker::{
        image = (./Constants/ContainerImages.dhall).toolchainBase,
        environment = ["BUILDKITE_AGENT_ACCESS_TOKEN"]
      }
    }
  ]
 }
) :  { stage : Text, mode: Text } -> Pipeline.Config.Type