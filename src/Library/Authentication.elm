module Authentication exposing (EnclosedUserData, HypaethralUserData, Method(..), Settings, decodeEnclosed, decodeHypaethral, decodeMethod, emptyHypaethralUserData, enclosedDecoder, encodeEnclosed, encodeHypaethral, encodeMethod, encodeSettings, hypaethralDecoder, methodFromString, methodToString, settingsDecoder)

import Equalizer
import Json.Decode as Json
import Json.Decode.Ext as Json
import Json.Decode.Pipeline exposing (optional)
import Json.Encode
import Maybe.Extra as Maybe
import Playlists
import Playlists.Encoding as Playlists
import Sources
import Sources.Encoding as Sources
import Tracks
import Tracks.Encoding as Tracks



-- 🌳


type Method
    = Blockstack
    | Dropbox { token : String }
    | Ipfs { apiOrigin : String }
    | Local
    | RemoteStorage { userAddress : String, token : String }
    | Textile { apiOrigin : String }


type alias EnclosedUserData =
    { cachedTracks : List String
    , equalizerSettings : Equalizer.Settings
    , grouping : Maybe Tracks.Grouping
    , onlyShowCachedTracks : Bool
    , onlyShowFavourites : Bool
    , repeat : Bool
    , searchTerm : Maybe String
    , selectedPlaylist : Maybe String
    , shuffle : Bool
    , sortBy : Tracks.SortBy
    , sortDirection : Tracks.SortDirection
    }


type alias HypaethralUserData =
    { favourites : List Tracks.Favourite
    , playlists : List Playlists.Playlist
    , settings : Maybe Settings
    , sources : List Sources.Source
    , tracks : List Tracks.Track
    }


type alias Settings =
    { backgroundImage : Maybe String
    , hideDuplicates : Bool
    }



-- 🔱  ░░  METHOD


decodeMethod : Json.Value -> Maybe Method
decodeMethod =
    Json.decodeValue (Json.map methodFromString Json.string) >> Result.toMaybe >> Maybe.join


encodeMethod : Method -> Json.Value
encodeMethod =
    methodToString >> Json.Encode.string


methodFromString : String -> Maybe Method
methodFromString string =
    case String.split methodSeparator string of
        [ "BLOCKSTACK" ] ->
            Just Blockstack

        [ "DROPBOX", t ] ->
            Just (Dropbox { token = t })

        [ "IPFS", a ] ->
            Just (Ipfs { apiOrigin = a })

        [ "LOCAL" ] ->
            Just Local

        [ "REMOTE_STORAGE", u, t ] ->
            Just (RemoteStorage { userAddress = u, token = t })

        [ "TEXTILE", a ] ->
            Just (Textile { apiOrigin = a })

        _ ->
            Nothing


methodToString : Method -> String
methodToString method =
    case method of
        Blockstack ->
            "BLOCKSTACK"

        Dropbox { token } ->
            String.join
                methodSeparator
                [ "DROPBOX"
                , token
                ]

        Ipfs { apiOrigin } ->
            String.join
                methodSeparator
                [ "IPFS"
                , apiOrigin
                ]

        Local ->
            "LOCAL"

        RemoteStorage { userAddress, token } ->
            String.join
                methodSeparator
                [ "REMOTE_STORAGE"
                , userAddress
                , token
                ]

        Textile { apiOrigin } ->
            String.join
                methodSeparator
                [ "TEXTILE"
                , apiOrigin
                ]


methodSeparator : String
methodSeparator =
    "___"



-- 🔱  ░░  ENCLOSED


decodeEnclosed : Json.Value -> Result Json.Error EnclosedUserData
decodeEnclosed =
    Json.decodeValue enclosedDecoder


enclosedDecoder : Json.Decoder EnclosedUserData
enclosedDecoder =
    Json.succeed EnclosedUserData
        |> optional "cachedTracks" (Json.list Json.string) []
        |> optional "equalizerSettings" Equalizer.settingsDecoder Equalizer.defaultSettings
        |> optional "grouping" (Json.maybe Tracks.groupingDecoder) Nothing
        |> optional "onlyShowCachedTracks" Json.bool False
        |> optional "onlyShowFavourites" Json.bool False
        |> optional "repeat" Json.bool False
        |> optional "searchTerm" (Json.maybe Json.string) Nothing
        |> optional "selectedPlaylist" (Json.maybe Json.string) Nothing
        |> optional "shuffle" Json.bool False
        |> optional "sortBy" Tracks.sortByDecoder Tracks.Artist
        |> optional "sortDirection" Tracks.sortDirectionDecoder Tracks.Asc


encodeEnclosed : EnclosedUserData -> Json.Value
encodeEnclosed { cachedTracks, equalizerSettings, grouping, onlyShowCachedTracks, onlyShowFavourites, repeat, searchTerm, selectedPlaylist, shuffle, sortBy, sortDirection } =
    Json.Encode.object
        [ ( "cachedTracks", Json.Encode.list Json.Encode.string cachedTracks )
        , ( "equalizerSettings", Equalizer.encodeSettings equalizerSettings )
        , ( "grouping", Maybe.unwrap Json.Encode.null Tracks.encodeGrouping grouping )
        , ( "onlyShowCachedTracks", Json.Encode.bool onlyShowCachedTracks )
        , ( "onlyShowFavourites", Json.Encode.bool onlyShowFavourites )
        , ( "repeat", Json.Encode.bool repeat )
        , ( "searchTerm", Maybe.unwrap Json.Encode.null Json.Encode.string searchTerm )
        , ( "selectedPlaylist", Maybe.unwrap Json.Encode.null Json.Encode.string selectedPlaylist )
        , ( "shuffle", Json.Encode.bool shuffle )
        , ( "sortBy", Tracks.encodeSortBy sortBy )
        , ( "sortDirection", Tracks.encodeSortDirection sortDirection )
        ]



-- 🔱  ░░  HYPAETHRAL


decodeHypaethral : Json.Value -> Result Json.Error HypaethralUserData
decodeHypaethral =
    Json.decodeValue hypaethralDecoder


emptyHypaethralUserData : HypaethralUserData
emptyHypaethralUserData =
    { favourites = []
    , playlists = []
    , settings = Nothing
    , sources = []
    , tracks = []
    }


encodeHypaethral : HypaethralUserData -> Json.Value
encodeHypaethral { favourites, playlists, settings, sources, tracks } =
    Json.Encode.object
        [ ( "favourites", Json.Encode.list Tracks.encodeFavourite favourites )
        , ( "playlists", Json.Encode.list Playlists.encode playlists )
        , ( "settings", Maybe.unwrap Json.Encode.null encodeSettings settings )
        , ( "sources", Json.Encode.list Sources.encode sources )
        , ( "tracks", Json.Encode.list Tracks.encodeTrack tracks )
        ]


encodeSettings : Settings -> Json.Value
encodeSettings settings =
    Json.Encode.object
        [ ( "backgroundImage"
          , Maybe.unwrap Json.Encode.null Json.Encode.string settings.backgroundImage
          )
        , ( "hideDuplicates"
          , Json.Encode.bool settings.hideDuplicates
          )
        ]


hypaethralDecoder : Json.Decoder HypaethralUserData
hypaethralDecoder =
    Json.succeed HypaethralUserData
        |> optional "favourites" (Json.listIgnore Tracks.favouriteDecoder) []
        |> optional "playlists" (Json.listIgnore Playlists.decoder) []
        |> optional "settings" (Json.maybe settingsDecoder) Nothing
        |> optional "sources" (Json.listIgnore Sources.decoder) []
        |> optional "tracks" (Json.listIgnore Tracks.trackDecoder) []


settingsDecoder : Json.Decoder Settings
settingsDecoder =
    Json.succeed Settings
        |> optional "backgroundImage" (Json.maybe Json.string) Nothing
        |> optional "hideDuplicates" Json.bool False
