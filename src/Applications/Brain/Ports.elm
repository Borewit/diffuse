port module Brain.Ports exposing (deconstructBlockstack, deconstructRemoteStorage, fabricateSecretKey, fromAlien, handlePendingBlockstackSignIn, initialize, receiveSearchResults, receiveTags, redirectToBlockstackSignIn, removeCache, removeTracksFromCache, requestBlockstack, requestCache, requestDropbox, requestIpfs, requestLegacyLocalData, requestRemoteStorage, requestSearch, requestTags, requestTextile, storeTracksInCache, toBlockstack, toCache, toDropbox, toIpfs, toRemoteStorage, toTextile, toUI, updateSearchIndex)

import Alien
import Json.Encode as Json
import Sources.Processing exposing (ContextForTags)



-- 📣


port fabricateSecretKey : Alien.Event -> Cmd msg


port removeCache : Alien.Event -> Cmd msg


port removeTracksFromCache : Json.Value -> Cmd msg


port requestCache : Alien.Event -> Cmd msg


port requestSearch : String -> Cmd msg


port requestTags : ContextForTags -> Cmd msg


port storeTracksInCache : Json.Value -> Cmd msg


port toCache : Alien.Event -> Cmd msg


port toUI : Alien.Event -> Cmd msg


port updateSearchIndex : Json.Value -> Cmd msg



-- 📣  ░░  USER LAYER SERVICES


port deconstructBlockstack : () -> Cmd msg


port deconstructRemoteStorage : () -> Cmd msg


port handlePendingBlockstackSignIn : String -> Cmd msg


port redirectToBlockstackSignIn : () -> Cmd msg


port requestBlockstack : Alien.Event -> Cmd msg


port requestDropbox : Alien.Event -> Cmd msg


port requestIpfs : Alien.Event -> Cmd msg


port requestLegacyLocalData : Alien.Event -> Cmd msg


port requestRemoteStorage : Alien.Event -> Cmd msg


port requestTextile : Alien.Event -> Cmd msg


port toBlockstack : Alien.Event -> Cmd msg


port toDropbox : Alien.Event -> Cmd msg


port toIpfs : Alien.Event -> Cmd msg


port toRemoteStorage : Alien.Event -> Cmd msg


port toTextile : Alien.Event -> Cmd msg



-- 📰


port fromAlien : (Alien.Event -> msg) -> Sub msg


port initialize : (String -> msg) -> Sub msg


port receiveSearchResults : (List String -> msg) -> Sub msg


port receiveTags : (ContextForTags -> msg) -> Sub msg
