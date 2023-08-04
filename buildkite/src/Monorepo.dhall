let Prelude = ./External/Prelude.dhall
let List/map = Prelude.List.map

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

let jobsByStage: List JobSpec.Type -> PipelineStage.Type -> List JobSpec.Type  = \(jobs: List JobSpec.Type) -> \(stage: PipelineStage.Type) -> 
  Prelude.List.filter 
  JobSpec.Type 
  (\(job: JobSpec.Type) ->  
      PipelineStage.equal job.stage stage) 
  jobs

let jobsByMode: List JobSpec.Type -> PipelineMode.Type -> List JobSpec.Type = \(jobs: List JobSpec.Type) -> \(mode: PipelineMode.Type) ->
  merge {
    PullRequest = Prelude.List.filter 
                    JobSpec.Type 
                    (\(job: JobSpec.Type) ->  
                        PipelineMode.equal job.mode mode) 
                    jobs, 
    Stable = jobs
  } mode

-- Run a job if we touched a dirty path
let makeCommand : JobSpec.Type -> Cmd.Type = \(job : JobSpec.Type) ->
  let dirtyWhen = SelectFiles.compile job.dirtyWhen
  let trigger = triggerCommand "src/Jobs/${job.path}/${job.name}.dhall"
  let pipelineHandlers = {
    PullRequest = ''
      if (cat _computed_diff.txt | egrep -q '${dirtyWhen}'); then
        echo "Triggering ${job.name} for reason:"
        cat _computed_diff.txt | egrep '${dirtyWhen}'
        ${Cmd.format trigger}
      fi
    '',
    Stable = ''
      echo "Triggering ${job.name} because this is a stable buildkite run"
      ${Cmd.format trigger}
    ''
  }
  in Cmd.quietly (merge pipelineHandlers job.mode)

let stagedCommands: List JobSpec.Type -> PipelineStage.Type -> List Cmd.Type = \(jobs: List JobSpec.Type) -> \(stage: PipelineStage.Type) -> 
  Prelude.List.map JobSpec.Type Cmd.Type makeCommand (jobsByStage jobs stage)

let prefixCommands = [
  Cmd.run "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt", -- Tell git where to find certs for https connections
  Cmd.run "git fetch origin", -- Freshen the cache
  Cmd.run "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
]

let stablePipelineCommands:  List Cmd.Type  = 
  let jobs = jobsByMode jobs PipelineMode.Type.Stable
    in prefixCommands
    # (stagedCommands jobs PipelineStage.Type.Stage1)
    # (stagedCommands jobs PipelineStage.Type.Stage2)
    # [Cmd.wait]
    # (stagedCommands jobs PipelineStage.Type.TearDown)
  
let pullRequestPipelineCommands:  List Cmd.Type = 
  let jobs = jobsByMode jobs PipelineMode.Type.PullRequest
    in prefixCommands
    # (stagedCommands jobs PipelineStage.Type.Stage1) 
    # [Cmd.wait]
    # (stagedCommands jobs PipelineStage.Type.Stage2)
    # [Cmd.wait]
    # (stagedCommands jobs PipelineStage.Type.TearDown)

let pipeline:  List Cmd.Type -> Pipeline.CompoundType = \(commands : List Cmd.Type) -> 
  Pipeline.build Pipeline.Config::{
    spec = JobSpec::{
      name = "monorepo-triage",
      -- TODO: Clean up this code so we don't need an unused dirtyWhen here
      dirtyWhen = [ SelectFiles.everything ]
    },
    steps = [
    Command.build
      Command.Config::{
        commands = commands,
        label = "Monorepo triage",
        key = "cmds",
        target = Size.Small,
        docker = Some Docker::{
          image = (./Constants/ContainerImages.dhall).toolchainBase,
          environment = ["BUILDKITE_AGENT_ACCESS_TOKEN", "BUILDKITE_INCREMENTAL"]
        }
      }
    ]
  }
  
in 
{
  stable = pipeline stablePipelineCommands,
  pullRequest = pipeline pullRequestPipelineCommands
}