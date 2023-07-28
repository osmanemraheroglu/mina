let Prelude = ../External/Prelude.dhall

let ProfileName = < Devnet | Lightnet | Hardfork >

let capitalName = \(profileName : ProfileName) ->
  merge {
    Devnet = "Devnet"
    , Lightnet = "Lightnet"
    , Hardfork = "Hardfork"
  } profileName

let lowerName = \(profileName : ProfileName) ->
  merge {
    Devnet = "devnet"
    , Lightnet = "lightnet"
    , Hardfork = "hardfork"
  } profileName

in

{
  ProfileName = ProfileName
  , capitalName = capitalName
  , lowerName = lowerName
}
