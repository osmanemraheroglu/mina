let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineStage = ../../Pipeline/Stage.dhall

let CheckGraphQLSchema = ../../Command/CheckGraphQLSchema.dhall

let dependsOn = [
    { name = "MinaArtifactBullseye", key = "build-deb-pkg" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
      S.strictlyStart (S.contains "src"),
      S.exactly "buildkite/scripts/check-graphql-schema" "sh",
      S.strictly (S.contains "Makefile")
    ],
    path = "Test",
    name = "CheckGraphQLSchema",
    stage = PipelineStage.Type.Stage2
  },
  steps = [
    CheckGraphQLSchema.step dependsOn
  ]
}
