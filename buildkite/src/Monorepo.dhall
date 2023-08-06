let Prelude = ./External/Prelude.dhall
let List/map = Prelude.List.map
let List/filter = Prelude.List.filter


let SelectFiles = ./Lib/SelectFiles.dhall
let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall
let Docker = ./Command/Docker/Type.dhall
let JobSpec = ./Pipeline/JobSpec.dhall
let Pipeline = ./Pipeline/Dsl.dhall
let PipelineMode = ./Pipeline/Mode.dhall
let PipelineStage = ./Pipeline/Stage.dhall
let Size = ./Command/Size.dhall
let triggerCommand = ./Pipeline/TriggerCommand.dhall

let jobs : List JobSpec.Type =
  List/map
    Pipeline.CompoundType
    JobSpec.Type
    (\(composite: Pipeline.CompoundType) -> composite.spec)
    ./gen/Jobs.dhall
  
let prefixCommands = [
  Cmd.run "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt", -- Tell git where to find certs for https connections
  Cmd.run "git fetch origin", -- Freshen the cache
  Cmd.run "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
]

let commands: PipelineStage.Type -> PipelineMode.Type -> List Cmd.Type  =  \(stage: PipelineStage.Type) -> \(mode: PipelineMode.Type) ->
  Prelude.List.map 
    JobSpec.Type 
    Cmd.Type 
    (\(job: JobSpec.Type) ->
      let job_mode = PipelineMode.lowerName job.mode
      let job_stage = PipelineStage.lowerName job.stage
      let target_mode = PipelineMode.lowerName mode
      let target_stage = PipelineStage.lowerName stage

      let dirtyWhen = SelectFiles.compile job.dirtyWhen
      let trigger = triggerCommand "src/Jobs/${job.path}/${job.name}.dhall"
      let pipelineHandlers = {
        PullRequest = ''
          if [ "${job_mode}" == "${target_mode}" ] && [ "${job_stage}" == "${target_stage}" ]; then
            if (cat _computed_diff.txt | egrep -q '${dirtyWhen}'); then
              echo "Triggering ${job.name} for reason:"
              cat _computed_diff.txt | egrep '${dirtyWhen}'
              ${Cmd.format trigger}
            fi 
          fi
        '',
        Stable = ''
          if [ "${job_mode}" == "${target_mode}" ] && [ "${job_stage}" == "${target_stage}" ]; then
            echo "Triggering ${job.name} because this is a stable buildkite run"
            ${Cmd.format trigger}
          fi
        ''
      }
      in Cmd.quietly (merge pipelineHandlers job.mode)
    ) 
    jobs

in
(
  \(args : { stage : PipelineStage.Type, mode: PipelineMode.Type}) ->
  Pipeline.build Pipeline.Config::{
    spec = JobSpec::{
      name = "monorepo-triage",
      -- TODO: Clean up this code so we don't need an unused dirtyWhen here
      dirtyWhen = [ SelectFiles.everything ]
    },
    steps = [
    Command.build
      Command.Config::{
        commands = commands args.stage args.mode,
        label = "Monorepo triage ${PipelineStage.capitalName args.stage}",
        key = "cmds-${PipelineStage.lowerName args.stage}",
        target = Size.Small,
        docker = Some Docker::{
          image = (./Constants/ContainerImages.dhall).toolchainBase,
          environment = ["BUILDKITE_AGENT_ACCESS_TOKEN", "BUILDKITE_INCREMENTAL"]
        }
      }
    ]
  }
) : { stage : PipelineStage.Type, mode: PipelineMode.Type } -> Pipeline.CompoundType
