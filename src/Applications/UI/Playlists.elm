module UI.Playlists exposing (Model, Msg(..), importHypaethral, initialModel, update, view)

import Chunky exposing (..)
import Color exposing (Color)
import Color.Ext as Color
import Common
import Conditional exposing (ifThenElse)
import Coordinates
import Css
import Html.Events.Extra.Mouse as Mouse
import Html.Styled as Html exposing (Html, fromUnstyled, text)
import Html.Styled.Attributes exposing (css, href, placeholder, style, value)
import Html.Styled.Events exposing (onInput, onSubmit)
import List.Extra as List
import Material.Icons exposing (Coloring(..))
import Material.Icons.Content as Icons
import Material.Icons.File as Icons
import Material.Icons.Navigation as Icons
import Playlists exposing (..)
import Return3 as Return exposing (..)
import Tachyons.Classes as T
import UI.Kit exposing (ButtonType(..))
import UI.List
import UI.Navigation exposing (..)
import UI.Page as Page
import UI.Playlists.Directory
import UI.Playlists.Page exposing (Page(..))
import UI.Reply exposing (Reply(..))
import Url
import User.Layer exposing (HypaethralData)



-- 🌳


type alias Model =
    { collection : List Playlist
    , lastModifiedPlaylist : Maybe String
    , newContext : Maybe String
    , editContext : Maybe { oldName : String, newName : String }
    , playlistToActivate : Maybe String
    }


initialModel : Model
initialModel =
    { collection = []
    , lastModifiedPlaylist = Nothing
    , newContext = Nothing
    , editContext = Nothing
    , playlistToActivate = Nothing
    }



-- 📣


type Msg
    = Activate Playlist
    | Bypass
    | Create
    | Deactivate
    | Modify
    | RemoveFromCollection { playlistName : String }
    | SetCreationContext String
    | SetModificationContext String String
    | ShowListMenu Playlist Mouse.Event


update : Msg -> Model -> Return Model Msg Reply
update msg model =
    case msg of
        Activate playlist ->
            returnRepliesWithModel
                model
                [ ActivatePlaylist playlist
                , GoToPage Page.Index
                ]

        Create ->
            case model.newContext of
                Just playlistName ->
                    let
                        alreadyExists =
                            List.any
                                (.name >> (==) playlistName)
                                (List.filterNot .autoGenerated model.collection)

                        playlist =
                            { autoGenerated = False
                            , name = playlistName
                            , tracks = []
                            }
                    in
                    if alreadyExists then
                        returnReplyWithModel
                            model
                            (ShowErrorNotification "There's already a playlist with this name")

                    else
                        returnRepliesWithModel
                            { model
                                | collection = playlist :: model.collection
                                , lastModifiedPlaylist = Just playlist.name
                                , newContext = Nothing
                            }
                            [ GoToPage (Page.Playlists Index)
                            , SavePlaylists
                            ]

                Nothing ->
                    return model

        Bypass ->
            return model

        Deactivate ->
            returnReplyWithModel
                model
                DeactivatePlaylist

        Modify ->
            case model.editContext of
                Just { oldName, newName } ->
                    let
                        properName =
                            String.trim newName

                        validName =
                            String.isEmpty properName == False

                        ( autoGenerated, notAutoGenerated ) =
                            List.partition .autoGenerated model.collection

                        alreadyExists =
                            List.any
                                (.name >> (==) properName)
                                notAutoGenerated

                        newCollection =
                            List.map
                                (\p -> ifThenElse (p.name == oldName) { p | name = properName } p)
                                notAutoGenerated
                    in
                    if alreadyExists then
                        returnReplyWithModel
                            { model | editContext = Nothing }
                            (ShowErrorNotification "There's already a playlist with this name")

                    else if validName then
                        returnRepliesWithModel
                            { model
                                | collection = newCollection ++ autoGenerated
                                , lastModifiedPlaylist = Just properName
                                , editContext = Nothing
                            }
                            [ GoToPage (Page.Playlists Index)
                            , SavePlaylists
                            ]

                    else
                        returnRepliesWithModel
                            model
                            [ GoToPage (Page.Playlists Index) ]

                Nothing ->
                    returnRepliesWithModel
                        model
                        [ GoToPage (Page.Playlists Index) ]

        RemoveFromCollection { playlistName } ->
            model.collection
                |> List.filter
                    (\p ->
                        if p.autoGenerated then
                            True

                        else
                            p.name /= playlistName
                    )
                |> (\col -> { model | collection = col })
                |> return
                |> addReply SavePlaylists

        SetCreationContext playlistName ->
            return { model | newContext = Just playlistName }

        SetModificationContext oldName newName ->
            return { model | editContext = Just { oldName = oldName, newName = newName } }

        ShowListMenu playlist mouseEvent ->
            let
                coordinates =
                    Coordinates.fromTuple mouseEvent.clientPos
            in
            returnRepliesWithModel model [ ShowPlaylistListMenu coordinates playlist ]


importHypaethral : Model -> HypaethralData -> Return Model Msg Reply
importHypaethral model data =
    return
        { model
            | collection = data.playlists ++ UI.Playlists.Directory.generate data.sources data.tracks
            , playlistToActivate = Nothing
        }



-- 🗺


view : Page -> Model -> Maybe Playlist -> Maybe Color -> Html Msg
view page model selectedPlaylist bgColor =
    UI.Kit.receptacle
        { scrolling = True }
        (case page of
            Edit encodedName ->
                let
                    playlists =
                        List.filter
                            (.autoGenerated >> (==) False)
                            model.collection
                in
                encodedName
                    |> Url.percentDecode
                    |> Maybe.andThen (\n -> List.find (.name >> (==) n) playlists)
                    |> Maybe.map (edit model)
                    |> Maybe.withDefault [ nothing ]

            Index ->
                index model selectedPlaylist bgColor

            New ->
                new model
        )



-- INDEX


index : Model -> Maybe Playlist -> Maybe Color -> List (Html Msg)
index model selectedPlaylist bgColor =
    let
        selectedPlaylistName =
            Maybe.map .name selectedPlaylist

        customPlaylists =
            model.collection
                |> List.filterNot .autoGenerated
                |> List.sortBy .name

        customPlaylistListItem playlist =
            if selectedPlaylistName == Just playlist.name then
                selectedPlaylistListItem playlist bgColor

            else
                { label = text playlist.name
                , actions =
                    [ { color = Inherit
                      , icon = Icons.more_vert
                      , msg = Just (ShowListMenu playlist)
                      , title = "Menu"
                      }
                    ]
                , msg = Just (Activate playlist)
                , isSelected = False
                }

        directoryPlaylists =
            model.collection
                |> List.filter .autoGenerated
                |> List.sortBy .name

        directoryPlaylistListItem playlist =
            if selectedPlaylistName == Just playlist.name then
                selectedPlaylistListItem playlist bgColor

            else
                { label = text playlist.name
                , actions = []
                , msg = Just (Activate playlist)
                , isSelected = False
                }
    in
    [ -----------------------------------------
      -- Navigation
      -----------------------------------------
      UI.Navigation.local
        [ ( Icon Icons.arrow_back
          , Label Common.backToIndex Hidden
          , NavigateToPage Page.Index
          )
        , ( Icon Icons.add
          , Label "Create a new playlist" Shown
          , NavigateToPage (Page.Playlists New)
          )
        ]

    -----------------------------------------
    -- Content
    -----------------------------------------
    , if List.isEmpty model.collection then
        chunk
            [ T.relative ]
            [ chunk
                [ T.absolute, T.left_0, T.top_0 ]
                [ UI.Kit.canister [ UI.Kit.h1 "Playlists" ] ]
            ]

      else
        UI.Kit.canister
            [ UI.Kit.h1 "Playlists"

            -- Intro
            --------
            , intro

            -- Custom Playlists
            -------------------
            , if List.isEmpty customPlaylists then
                nothing

              else
                raw
                    [ category "Your Playlists"
                    , UI.List.view
                        UI.List.Normal
                        (List.map customPlaylistListItem customPlaylists)
                    ]

            -- Directory Playlists
            ----------------------
            , if List.isEmpty directoryPlaylists then
                nothing

              else
                raw
                    [ category "Autogenerated Directory Playlists"
                    , UI.List.view
                        UI.List.Normal
                        (List.map directoryPlaylistListItem directoryPlaylists)
                    ]
            ]

    --
    , if List.isEmpty model.collection then
        UI.Kit.centeredContent
            [ slab
                Html.a
                [ href (Page.toString <| Page.Playlists New) ]
                [ T.color_inherit, T.db, T.link, T.o_30 ]
                [ fromUnstyled (Icons.waves 64 Inherit) ]
            , slab
                Html.a
                [ href (Page.toString <| Page.Playlists New) ]
                [ T.color_inherit, T.db, T.lh_copy, T.link, T.mt2, T.o_40, T.tc ]
                [ text "No playlists found, create one"
                , lineBreak
                , text "or enable directory playlists."
                ]
            ]

      else
        nothing
    ]


intro : Html Msg
intro =
    [ text "Playlists are not tied to the sources of its tracks, "
    , text "same goes for favourites."
    , lineBreak
    , text "There's also directory playlists, which are playlists derived from root directories."
    ]
        |> raw
        |> UI.Kit.intro


category : String -> Html Msg
category cat =
    brick
        [ css categoryStyles ]
        [ T.f7, T.mb3, T.mt4, T.truncate, T.ttu ]
        [ UI.Kit.inlineIcon Icons.folder
        , inline [ T.fw7, T.ml2 ] [ text cat ]
        ]


categoryStyles : List Css.Style
categoryStyles =
    [ Css.color (Color.toElmCssColor UI.Kit.colorKit.base06)
    , Css.fontFamilies UI.Kit.headerFontFamilies
    , Css.fontSize (Css.px 11)
    ]


selectedPlaylistListItem : Playlist -> Maybe Color -> UI.List.Item Msg
selectedPlaylistListItem playlist bgColor =
    let
        selectionColor =
            Maybe.withDefault UI.Kit.colors.selection bgColor
    in
    { label =
        brick
            [ selectionColor
                |> Color.toCssString
                |> style "color"
            ]
            []
            [ text playlist.name ]
    , actions =
        [ { color = Color selectionColor
          , icon = Icons.check
          , msg = Nothing
          , title = "Selected playlist"
          }
        ]
    , msg = Just Deactivate
    , isSelected = False
    }



-- NEW


new : Model -> List (Html Msg)
new _ =
    [ -----------------------------------------
      -- Navigation
      -----------------------------------------
      UI.Navigation.local
        [ ( Icon Icons.arrow_back
          , Label "Back to list" Hidden
          , NavigateToPage (Page.Playlists Index)
          )
        ]

    -----------------------------------------
    -- Content
    -----------------------------------------
    , [ UI.Kit.h2 "Name your playlist"

      --
      , UI.Kit.textField
            [ onInput SetCreationContext
            , placeholder "The Classics"
            ]

      -- Button
      ---------
      , chunk
            [ T.mt4, T.pt2 ]
            [ UI.Kit.button
                Normal
                Bypass
                (text "Create playlist")
            ]
      ]
        |> UI.Kit.canisterForm
        |> List.singleton
        |> UI.Kit.centeredContent
        |> List.singleton
        |> slab
            Html.form
            [ onSubmit Create ]
            [ T.flex
            , T.flex_grow_1
            , T.tc
            ]
    ]



-- EDIT


edit : Model -> Playlist -> List (Html Msg)
edit model playlist =
    [ -----------------------------------------
      -- Navigation
      -----------------------------------------
      UI.Navigation.local
        [ ( Icon Icons.arrow_back
          , Label "Back to list" Hidden
          , NavigateToPage (Page.Playlists Index)
          )
        ]

    -----------------------------------------
    -- Content
    -----------------------------------------
    , [ UI.Kit.h2 "Name your playlist"

      --
      , UI.Kit.textField
            [ onInput (SetModificationContext playlist.name)
            , placeholder "The Classics"

            --
            , case model.editContext of
                Just { oldName, newName } ->
                    if playlist.name == oldName then
                        value newName

                    else
                        value playlist.name

                Nothing ->
                    value playlist.name
            ]

      -- Button
      ---------
      , chunk
            [ T.mt4, T.pt2 ]
            [ UI.Kit.button
                Normal
                Bypass
                (text "Save")
            ]
      ]
        |> UI.Kit.canisterForm
        |> List.singleton
        |> UI.Kit.centeredContent
        |> List.singleton
        |> slab
            Html.form
            [ onSubmit Modify ]
            [ T.flex
            , T.flex_grow_1
            , T.tc
            ]
    ]
