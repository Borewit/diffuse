module Sources.Services.Dropbox exposing (authorizationSourceData, authorizationUrl, defaults, getProperDirectoryPath, initialData, makeTrackUrl, makeTree, parseErrorResponse, parsePreparationResponse, parseTreeResponse, postProcessTree, prepare, properties)

{-| Dropbox Service.
-}

import Base64
import Dict
import Dict.Ext as Dict
import Http
import Json.Decode
import Json.Encode
import Regex
import Sources exposing (Property, SourceData)
import Sources.Pick
import Sources.Processing exposing (..)
import Sources.Services.Common exposing (cleanPath, noPrep)
import Sources.Services.Dropbox.Parser as Parser
import Time
import Url
import Url.Builder as Url



-- PROPERTIES
-- 📟


defaults =
    { appKey = "kwsydtrzban41zr"
    , directoryPath = "/"
    , name = "Music from Dropbox"
    }


{-| The list of properties we need from the user.

Tuple: (property, label, placeholder, isPassword)
Will be used for the forms.

-}
properties : List Property
properties =
    [ { key = "accessToken"
      , label = "Access Token"
      , placeholder = "..."
      , password = True
      }
    , { key = "appKey"
      , label = "App key"
      , placeholder = defaults.appKey
      , password = False
      }
    , { key = "directoryPath"
      , label = "Directory"
      , placeholder = defaults.directoryPath
      , password = False
      }
    ]


{-| Initial data set.
-}
initialData : SourceData
initialData =
    Dict.fromList
        [ ( "accessToken", "" )
        , ( "appKey", defaults.appKey )
        , ( "directoryPath", defaults.directoryPath )
        , ( "name", defaults.name )
        ]



-- AUTHORIZATION


{-| Authorization url.
-}
authorizationUrl : SourceData -> String -> String
authorizationUrl sourceData origin =
    let
        encodeData data =
            data
                |> Dict.toList
                |> List.map (Tuple.mapSecond Json.Encode.string)
                |> Json.Encode.object

        state =
            sourceData
                |> encodeData
                |> Json.Encode.encode 0
                |> Base64.encode
    in
    [ ( "response_type", "token" )
    , ( "client_id", Dict.fetch "appKey" "unknown" sourceData )
    , ( "redirect_uri", origin ++ "/sources/new/dropbox" )
    , ( "state", state )
    ]
        |> List.map (\( a, b ) -> Url.string a b)
        |> Url.toQuery
        |> String.append "https://www.dropbox.com/oauth2/authorize"


{-| Authorization source data.
-}
authorizationSourceData : { codeOrToken : Maybe String, state : Maybe String } -> SourceData
authorizationSourceData args =
    args.state
        |> Maybe.andThen (Base64.decode >> Result.toMaybe)
        |> Maybe.withDefault "{}"
        |> Json.Decode.decodeString (Json.Decode.dict Json.Decode.string)
        |> Result.withDefault Dict.empty
        |> Dict.unionFlipped initialData
        |> Dict.update "accessToken" (\_ -> args.codeOrToken)



-- PREPARATION


prepare : String -> SourceData -> Marker -> (Result Http.Error String -> msg) -> Maybe (Cmd msg)
prepare _ _ _ _ =
    Nothing



-- TREE


{-| Create a directory tree.

List all the tracks in the bucket.
Or a specific directory in the bucket.

-}
makeTree : SourceData -> Marker -> Time.Posix -> (Result Http.Error String -> msg) -> Cmd msg
makeTree srcData marker currentTime toMsg =
    let
        accessToken =
            Dict.fetch "accessToken" "" srcData

        body =
            (case marker of
                TheBeginning ->
                    [ ( "limit", Json.Encode.int 2000 )
                    , ( "path", Json.Encode.string (getProperDirectoryPath srcData) )
                    , ( "recursive", Json.Encode.bool True )
                    ]

                InProgress cursor ->
                    [ ( "cursor", Json.Encode.string cursor )
                    ]

                TheEnd ->
                    []
            )
                |> Json.Encode.object
                |> Http.jsonBody

        url =
            case marker of
                TheBeginning ->
                    "https://api.dropboxapi.com/2/files/list_folder"

                InProgress _ ->
                    "https://api.dropboxapi.com/2/files/list_folder/continue"

                TheEnd ->
                    ""
    in
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Bearer " ++ accessToken) ]
        , url = url
        , body = body
        , expect = Http.expectString toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


getProperDirectoryPath : SourceData -> String
getProperDirectoryPath srcData =
    let
        path =
            srcData
                |> Dict.get "directoryPath"
                |> Maybe.withDefault defaults.directoryPath
                |> cleanPath
    in
    if path == "" then
        ""

    else
        "/" ++ path


{-| Re-export parser functions.
-}
parsePreparationResponse : String -> SourceData -> Marker -> PrepationAnswer Marker
parsePreparationResponse =
    noPrep


parseTreeResponse : String -> Marker -> TreeAnswer Marker
parseTreeResponse =
    Parser.parseTreeResponse


parseErrorResponse : String -> String
parseErrorResponse =
    Parser.parseErrorResponse



-- POST


{-| Post process the tree results.

!!! Make sure we only use music files that we can use.

-}
postProcessTree : List String -> List String
postProcessTree =
    Sources.Pick.selectMusicFiles



-- TRACK URL


{-| Create a public url for a file.

We need this to play the track.

-}
makeTrackUrl : Time.Posix -> SourceData -> HttpMethod -> String -> String
makeTrackUrl currentTime srcData method pathToFile =
    "dropbox://" ++ Dict.fetch "accessToken" "" srcData ++ "@" ++ pathToFile
