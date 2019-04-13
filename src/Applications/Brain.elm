module Brain exposing (main)

import Alien
import Authentication exposing (HypaethralUserData)
import Brain.Authentication as Authentication
import Brain.Core as Core exposing (..)
import Brain.Ports
import Brain.Reply as Reply exposing (Reply(..))
import Brain.Sources.Processing as Processing
import Brain.Sources.Processing.Common as Processing
import Brain.Tracks as Tracks
import Debouncer.Basic as Debouncer
import Json.Decode as Json
import Json.Decode.Pipeline exposing (optional)
import Json.Encode
import Replying exposing (andThen2, return)
import Sources.Encoding as Sources
import Sources.Processing.Encoding as Processing
import Tracks.Encoding as Tracks



-- 🧠


main : Program Flags Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }



-- 🌳


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( -----------------------------------------
      -- Initial model
      -----------------------------------------
      { authentication = Authentication.initialModel
      , hypaethralUserData = Authentication.emptyHypaethralUserData
      , processing = Processing.initialModel
      , tracks = Tracks.initialModel

      --
      , notSoFast =
            2.5
                |> Debouncer.fromSeconds
                |> Debouncer.debounce
                |> Debouncer.toDebouncer
      }
      -----------------------------------------
      -- Initial command
      -----------------------------------------
    , Cmd.batch
        [ Cmd.map AuthenticationMsg Authentication.initialCommand
        , Cmd.map ProcessingMsg Processing.initialCommand
        ]
    )



-- 📣


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Bypass ->
            ( model
            , Cmd.none
            )

        NotifyUI alienEvent ->
            ( model
            , Cmd.batch
                [ Brain.Ports.toUI alienEvent

                -- Sometimes the loading screen is still showing,
                -- so we hide it here just in case.
                , case alienEvent.error of
                    Just _ ->
                        Brain.Ports.toUI (Alien.trigger Alien.HideLoadingScreen)

                    Nothing ->
                        Cmd.none
                ]
            )

        NotSoFast debouncerMsg ->
            let
                ( subModel, subCmd, emittedMsg ) =
                    Debouncer.update debouncerMsg model.notSoFast

                mappedCmd =
                    Cmd.map NotSoFast subCmd

                updatedModel =
                    { model | notSoFast = subModel }
            in
            case emittedMsg of
                Just emitted ->
                    updatedModel
                        |> update emitted
                        |> Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, mappedCmd ])

                Nothing ->
                    ( updatedModel, mappedCmd )

        ToCache alienEvent ->
            ( model
            , Brain.Ports.toCache alienEvent
            )

        -----------------------------------------
        -- Children
        -----------------------------------------
        AuthenticationMsg Authentication.PerformSignOut ->
            -- When signing out, remove all traces of the user's data.
            updateAuthentication
                { model | hypaethralUserData = Authentication.emptyHypaethralUserData }
                Authentication.PerformSignOut

        AuthenticationMsg sub ->
            updateAuthentication model sub

        ProcessingMsg sub ->
            updateProcessing model sub

        TracksMsg sub ->
            updateTracks model sub

        -----------------------------------------
        -- User data
        -----------------------------------------
        --   The hypaethral user data is received in pieces,
        --   pieces which are "cached" here in the web worker.
        --
        --   The reasons for this are:
        --   1. Lesser performance penalty on the UI when saving data
        --      (ie. this avoids having to encode/decode everything each time)
        --   2. The data can be used in the web worker (brain) as well.
        --      (eg. for track-search index)
        --
        LoadHypaethralUserData value ->
            let
                decodedData =
                    value
                        |> Authentication.decodeHypaethral
                        |> Result.withDefault model.hypaethralUserData

                encodedTracks =
                    Json.Encode.list Tracks.encodeTrack decodedData.tracks
            in
            andThen2
                (updateSearchIndex encodedTracks)
                ( { model | hypaethralUserData = decodedData }
                , Brain.Ports.toUI (Alien.broadcast Alien.LoadHypaethralUserData value)
                )

        SaveHypaethralData ->
            model.hypaethralUserData
                |> Authentication.encodeHypaethral
                |> Authentication.SaveHypaethralData
                |> AuthenticationMsg
                |> (\m -> update m model)

        SaveFavourites value ->
            value
                |> Json.decodeValue (Json.list Tracks.favouriteDecoder)
                |> Result.withDefault model.hypaethralUserData.favourites
                |> hypaethralLenses.setFavourites model
                |> saveHypaethralData

        SaveSettings value ->
            value
                |> Json.decodeValue (Json.map Just Authentication.settingsDecoder)
                |> Result.withDefault model.hypaethralUserData.settings
                |> hypaethralLenses.setSettings model
                |> saveHypaethralData

        SaveSources value ->
            value
                |> Json.decodeValue (Json.list Sources.decoder)
                |> Result.withDefault model.hypaethralUserData.sources
                |> hypaethralLenses.setSources model
                |> saveHypaethralData

        SaveTracks value ->
            value
                |> Json.decodeValue (Json.list Tracks.trackDecoder)
                |> Result.withDefault model.hypaethralUserData.tracks
                |> hypaethralLenses.setTracks model
                |> updateSearchIndex value
                |> andThen2 saveHypaethralData


updateSearchIndex : Json.Value -> Model -> ( Model, Cmd Msg )
updateSearchIndex value model =
    update
        (value
            |> Tracks.UpdateSearchIndex
            |> TracksMsg
        )
        model



-- 📣  ░░  REPLIES


translateReply : Reply -> Msg
translateReply reply =
    case reply of
        FabricatedNewSecretKey ->
            SaveHypaethralData

        -----------------------------------------
        -- To UI
        -----------------------------------------
        GiveUI Alien.LoadHypaethralUserData data ->
            LoadHypaethralUserData data

        GiveUI tag data ->
            NotifyUI (Alien.broadcast tag data)

        NudgeUI tag ->
            NotifyUI (Alien.trigger tag)


updateChild =
    Replying.updateChild update translateReply



-- 📣  ░░  CHILDREN


updateAuthentication : Model -> Authentication.Msg -> ( Model, Cmd Msg )
updateAuthentication model sub =
    updateChild
        { mapCmd = AuthenticationMsg
        , mapModel = \child -> { model | authentication = child }
        , update = Authentication.update
        }
        { model = model.authentication
        , msg = sub
        }


updateProcessing : Model -> Processing.Msg -> ( Model, Cmd Msg )
updateProcessing model sub =
    updateChild
        { mapCmd = ProcessingMsg
        , mapModel = \child -> { model | processing = child }
        , update = Processing.update
        }
        { model = model.processing
        , msg = sub
        }


updateTracks : Model -> Tracks.Msg -> ( Model, Cmd Msg )
updateTracks model sub =
    updateChild
        { mapCmd = TracksMsg
        , mapModel = \child -> { model | tracks = child }
        , update = Tracks.update
        }
        { model = model.tracks
        , msg = sub
        }



-- 📣  ░░  USER DATA


hypaethralLenses =
    { setFavourites = makeHypaethralLens (\h f -> { h | favourites = f })
    , setSettings = makeHypaethralLens (\h s -> { h | settings = s })
    , setSources = makeHypaethralLens (\h s -> { h | sources = s })
    , setTracks = makeHypaethralLens (\h t -> { h | tracks = t })
    }


makeHypaethralLens : (HypaethralUserData -> a -> HypaethralUserData) -> Model -> a -> Model
makeHypaethralLens setter model value =
    { model | hypaethralUserData = setter model.hypaethralUserData value }


saveHypaethralData : Model -> ( Model, Cmd Msg )
saveHypaethralData model =
    update
        (SaveHypaethralData
            |> Debouncer.provideInput
            |> NotSoFast
        )
        model



-- 📰


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Brain.Ports.fromAlien alien

        -----------------------------------------
        -- Children
        -----------------------------------------
        , Sub.map ProcessingMsg (Processing.subscriptions model.processing)
        , Sub.map TracksMsg (Tracks.subscriptions model.tracks)
        ]


alien : Alien.Event -> Msg
alien event =
    case event.error of
        Nothing ->
            translateAlienData event

        Just err ->
            translateAlienError event err


translateAlienData : Alien.Event -> Msg
translateAlienData event =
    case Alien.tagFromString event.tag of
        Just Alien.AuthAnonymous ->
            AuthenticationMsg (Authentication.HypaethralDataRetrieved event.data)

        Just Alien.AuthEnclosedData ->
            AuthenticationMsg (Authentication.EnclosedDataRetrieved event.data)

        Just Alien.AuthIpfs ->
            AuthenticationMsg (Authentication.HypaethralDataRetrieved event.data)

        Just Alien.AuthMethod ->
            AuthenticationMsg (Authentication.MethodRetrieved event.data)

        Just Alien.FabricateSecretKey ->
            AuthenticationMsg Authentication.SecretKeyFabricated

        Just Alien.ProcessSources ->
            -- Only proceed to the processing if we got all the necessary data,
            -- otherwise report an error in the UI.
            case Json.decodeValue Processing.argumentsDecoder event.data of
                Ok arguments ->
                    arguments
                        |> Processing.Process
                        |> ProcessingMsg

                Err err ->
                    report Alien.ProcessSources (Json.errorToString err)

        Just Alien.SaveEnclosedUserData ->
            AuthenticationMsg (Authentication.SaveEnclosedData event.data)

        Just Alien.SaveFavourites ->
            SaveFavourites event.data

        Just Alien.SaveSettings ->
            SaveSettings event.data

        Just Alien.SaveSources ->
            SaveSources event.data

        Just Alien.SaveTracks ->
            SaveTracks event.data

        Just Alien.SearchTracks ->
            event.data
                |> Json.decodeValue Json.string
                |> Result.withDefault ""
                |> Tracks.Search
                |> TracksMsg

        Just Alien.SignIn ->
            AuthenticationMsg (Authentication.PerformSignIn event.data)

        Just Alien.SignOut ->
            AuthenticationMsg Authentication.PerformSignOut

        Just Alien.ToCache ->
            case Json.decodeValue Alien.hostDecoder event.data of
                Ok val ->
                    Core.ToCache val

                Err err ->
                    report Alien.ToCache (Json.errorToString err)

        Just Alien.UpdateEncryptionKey ->
            case Json.decodeValue Json.string event.data of
                Ok passphrase ->
                    AuthenticationMsg (Authentication.FabricateSecretKey passphrase)

                Err _ ->
                    Bypass

        _ ->
            Bypass


translateAlienError : Alien.Event -> String -> Msg
translateAlienError event err =
    case Alien.tagFromString event.tag of
        Just Alien.AuthAnonymous ->
            report Alien.AuthAnonymous "I couldn't decrypt your data, maybe you used the wrong passphrase?"

        Just Alien.AuthIpfs ->
            report Alien.AuthIpfs "Something went wrong regarding the IPFS storage. Maybe you used the wrong passphrase, or your IPFS node is offline?"

        Just tag ->
            report tag err

        Nothing ->
            Bypass


report : Alien.Tag -> String -> Msg
report tag err =
    err
        |> Alien.report tag
        |> NotifyUI
