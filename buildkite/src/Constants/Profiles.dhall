let Prelude = ../External/Prelude.dhall

let ProfileName = < Devnet | Lightnet >

let capitalName = \(profileName : ProfileName) ->
  merge {
    Devnet = "Devnet"
    , Lightnet = "Lightnet"
  } profileName

let lowerName = \(profileName : ProfileName) ->
  merge {
    Devnet = "devnet"
    , Lightnet = "lightnet"
  } profileName

in

{
  ProfileName = ProfileName
  , capitalName = capitalName
  , lowerName = lowerName
}
