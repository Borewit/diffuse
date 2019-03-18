module UI.Page exposing (Page(..), fromUrl, sameBase, toString)

import UI.Queue.Page as Queue
import UI.Settings.Page as Settings
import UI.Sources.Page as Sources
import Url exposing (Url)
import Url.Parser exposing (..)



-- 🌳


type Page
    = Equalizer
    | Index
    | Queue Queue.Page
    | Settings Settings.Page
    | Sources Sources.Page



-- 🔱


fromUrl : Url -> Maybe Page
fromUrl =
    parse route


toString : Page -> String
toString page =
    case page of
        Equalizer ->
            "/equalizer"

        Index ->
            "/"

        -----------------------------------------
        -- Queue
        -----------------------------------------
        Queue Queue.History ->
            "/queue/history"

        Queue Queue.Index ->
            "/queue"

        -----------------------------------------
        -- Settings
        -----------------------------------------
        Settings Settings.ImportExport ->
            "/settings/import-export"

        Settings Settings.Index ->
            "/settings"

        -----------------------------------------
        -- Sources
        -----------------------------------------
        Sources Sources.Index ->
            "/sources"

        Sources Sources.New ->
            "/sources/new"


{-| Are the bases of these two pages the same?
-}
sameBase : Page -> Page -> Bool
sameBase a b =
    case ( a, b ) of
        ( Queue _, Queue _ ) ->
            True

        ( Settings _, Settings _ ) ->
            True

        ( Sources _, Sources _ ) ->
            True

        ( Index, Equalizer ) ->
            True

        _ ->
            a == b



-- ⚗️


route : Parser (Page -> a) a
route =
    oneOf
        [ map Index top

        --
        , map Equalizer (s "equalizer")

        -----------------------------------------
        -- Queue
        -----------------------------------------
        , map (Queue Queue.History) (s "queue" </> s "history")
        , map (Queue Queue.Index) (s "queue")

        -----------------------------------------
        -- Settings
        -----------------------------------------
        , map (Settings Settings.ImportExport) (s "settings" </> s "import-export")
        , map (Settings Settings.Index) (s "settings")

        -----------------------------------------
        -- Sources
        -----------------------------------------
        , map (Sources Sources.Index) (s "sources")
        , map (Sources Sources.New) (s "sources" </> s "new")
        ]
