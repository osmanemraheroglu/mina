let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ./Base.dhall
let Summon = ./Summon/Type.dhall
let Size = ./Size.dhall
let Libp2p = ./Libp2pHelperBuild.dhall
let DockerImage = ./DockerImage.dhall
let DebianVersions = ../Constants/DebianVersions.dhall
let Profiles = ../Constants/Profiles.dhall

in

let pipeline : DebianVersions.DebVersion -> Profiles.ProfileName -> Pipeline.Config.Type = \(debVersion : DebianVersions.DebVersion) ->
  \(profile: Profiles.ProfileName) ->
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen debVersion,
          path = "Release",
          name = "MinaArtifact${DebianVersions.capitalName debVersion}${Profiles.capitalName profile}"
        },
      steps = [
        Libp2p.step debVersion,
        Command.build
          Command.Config::{
            commands = DebianVersions.toolchainRunner debVersion [
              "DUNE_PROFILE=${Profiles.lowerName profile}",
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}"
            ] "./buildkite/scripts/build-artifact.sh",
            label = "Build Mina for ${DebianVersions.capitalName debVersion} ${Profiles.capitalName profile}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          },

        -- daemon berkeley image
        let daemonBerkeleySpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          deb_profile="${Profiles.lowerName profile}",
          step_key="daemon-berkeley-${DebianVersions.lowerName debVersion}-${Profiles.lowerName profile}-docker-image"
        }

        in

        DockerImage.generateStep daemonBerkeleySpec,

        -- test_executive image
        let testExecutiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-test-executive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="test-executive-${DebianVersions.lowerName debVersion}-${Profiles.lowerName profile}-docker-image"
        }
        in
        DockerImage.generateStep testExecutiveSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-archive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          deb_profile="${Profiles.lowerName profile}",
          step_key="archive-${DebianVersions.lowerName debVersion}-${Profiles.lowerName profile}-docker-image"
        }
        in
        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          service="mina-rosetta",
          extra_args="--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --cache-from ${DebianVersions.toolchainImage debVersion}",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="rosetta-${DebianVersions.lowerName debVersion}-${Profiles.lowerName profile}-docker-image"
        }
        in

        DockerImage.generateStep rosettaSpec,

        -- ZkApp test transaction image
        let zkappTestTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-zkapp-test-transaction",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="zkapp-test-transaction-${DebianVersions.lowerName debVersion}-${Profiles.lowerName profile}-docker-image"
        }

        in

        DockerImage.generateStep zkappTestTxnSpec

      ]
    }

in
{
  bullseye  = pipeline DebianVersions.DebVersion.Bullseye Profiles.ProfileName.Devnet
  , bullseye-lighnet  = pipeline DebianVersions.DebVersion.Bullseye Profiles.ProfileName.Lightnet
  , buster  = pipeline DebianVersions.DebVersion.Buster Profiles.ProfileName.Devnet
  , focal   = pipeline DebianVersions.DebVersion.Focal Profiles.ProfileName.Devnet
}
