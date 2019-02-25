module UI.Tracks.Scene.List exposing (view)

import Chunky exposing (..)
import Color
import Color.Ext as Color
import Conditional exposing (ifThenElse)
import Css
import Html as UnstyledHtml
import Html.Attributes as UnstyledHtmlAttributes
import Html.Styled as Html exposing (Html, text)
import Html.Styled.Attributes exposing (css, fromUnstyled)
import Html.Styled.Lazy
import InfiniteList
import Material.Icons.Navigation as Icons
import Tachyons.Classes as T
import Tracks exposing (..)
import UI.Kit
import UI.Tracks.Core exposing (..)



-- 🗺


type alias Necessities =
    { height : Float
    }


view : Necessities -> Model -> Html Msg
view necessities model =
    let
        { infiniteList } =
            model
    in
    brick
        [ fromUnstyled (InfiniteList.onScroll InfiniteListMsg) ]
        [ T.flex_grow_1
        , T.vh_25
        , T.overflow_x_hidden
        , T.overflow_y_scroll
        ]
        [ Html.Styled.Lazy.lazy2 header model.sortBy model.sortDirection
        , Html.fromUnstyled
            (InfiniteList.view
                (infiniteListConfig necessities model)
                infiniteList
                model.collection.harvested
            )
        ]



-- HEADERS


header : SortBy -> SortDirection -> Html Msg
header sortBy sortDirection =
    let
        color =
            Color.rgb255 207 207 207

        sortIcon =
            (if sortDirection == Desc then
                Icons.expand_less

             else
                Icons.expand_more
            )
                color
                15

        sortIconHtml =
            Html.fromUnstyled sortIcon

        maybeSortIcon s =
            ifThenElse (sortBy == s) (Just sortIconHtml) Nothing
    in
    brick
        [ css headerStyles ]
        [ T.bg_white, T.flex, T.fw6, T.relative, T.z_5 ]
        [ headerColumn "" 4.5 First Nothing
        , headerColumn "Title" 37.5 Between (maybeSortIcon Title)
        , headerColumn "Artist" 29.0 Between (maybeSortIcon Artist)
        , headerColumn "Album" 29.0 Last (maybeSortIcon Album)
        ]


headerStyles : List Css.Style
headerStyles =
    [ Css.borderBottom3 (Css.px 1) Css.solid (Color.toElmCssColor UI.Kit.colors.subtleBorder)
    , Css.color (Color.toElmCssColor headerTextColor)
    , Css.fontSize (Css.px 11)
    ]


headerTextColor : Color.Color
headerTextColor =
    Color.rgb255 207 207 207



-- HEADER COLUMN


type Pos
    = First
    | Between
    | Last


headerColumn :
    String
    -> Float
    -> Pos
    -> Maybe (Html msg)
    -> Html msg
headerColumn text_ width pos maybeSortIcon =
    let
        paddingLeft =
            ifThenElse (pos == First) T.pl2 T.pl1

        paddingRight =
            ifThenElse (pos == Last) T.pr2 T.pr1
    in
    brick
        [ css
            [ Css.borderLeft3
                (Css.px <| ifThenElse (pos /= First) 1 0)
                Css.solid
                (Color.toElmCssColor UI.Kit.colors.subtleBorder)
            , Css.width (Css.pct width)
            ]
        ]
        [ T.lh_title
        , T.ph2
        , T.pv1
        , T.relative

        --
        , ifThenElse (pos == First) "" T.pointer
        ]
        [ brick
            [ css [ Css.top (Css.px 1) ] ]
            [ T.relative ]
            [ text text_ ]
        , case maybeSortIcon of
            Just sortIcon ->
                brick
                    [ css sortIconStyles ]
                    [ T.absolute, T.mr1, T.right_0 ]
                    [ sortIcon ]

            Nothing ->
                nothing
        ]


sortIconStyles : List Css.Style
sortIconStyles =
    [ Css.fontSize (Css.px 0)
    , Css.lineHeight (Css.px 0)
    , Css.top (Css.pct 50)
    , Css.transform (Css.translateY <| Css.pct -50)
    ]



-- ROWS


rowHeight : Float
rowHeight =
    35


rowStyles : Int -> Identifiers -> List Css.Style
rowStyles idx { isNowPlaying } =
    let
        bgColor =
            if isNowPlaying then
                Color.toElmCssColor UI.Kit.colorKit.base0D

            else if modBy 2 idx == 1 then
                Css.rgb 252 252 252

            else
                Css.rgb 255 255 255
    in
    [ Css.backgroundColor bgColor
    ]



-- COLUMNS


favouriteColumn : Bool -> Identifiers -> Html msg
favouriteColumn favouritesOnly identifiers =
    brick
        [ css (favouriteColumnStyles favouritesOnly identifiers) ]
        [ T.dtc, T.pl3, T.v_mid ]
        [ if identifiers.isFavourite then
            text "t"

          else
            text "f"
        ]


favouriteColumnStyles : Bool -> Identifiers -> List Css.Style
favouriteColumnStyles favouritesOnly { isFavourite, isNowPlaying, isSelected } =
    let
        color =
            if isSelected then
                Color.toElmCssColor UI.Kit.colors.selection

            else if isNowPlaying && isFavourite then
                Css.rgb 255 255 255

            else if isNowPlaying then
                Css.rgba 255 255 255 0.4

            else if favouritesOnly || not isFavourite then
                Css.rgb 222 222 222

            else
                Color.toElmCssColor UI.Kit.colorKit.base08
    in
    [ Css.color color
    , Css.fontFamilies [ "or-favourites" ]
    , Css.height (Css.px rowHeight)
    , Css.width (Css.pct 4.5)
    ]


otherColumn : Float -> Bool -> String -> Html msg
otherColumn width isLast text_ =
    brick
        [ css (otherColumnStyles width) ]
        [ T.dtc
        , T.pl2
        , T.truncate
        , T.v_mid

        --
        , ifThenElse isLast T.pr3 T.pr2
        ]
        [ text text_ ]


otherColumnStyles : Float -> List Css.Style
otherColumnStyles columnWidth =
    [ Css.height (Css.px rowHeight)
    , Css.width (Css.pct columnWidth)
    ]



-- INFINITE LIST


infiniteListConfig : Necessities -> Model -> InfiniteList.Config IdentifiedTrack Msg
infiniteListConfig necessities model =
    InfiniteList.withCustomContainer
        infiniteListContainer
        (InfiniteList.config
            { itemView = itemView model
            , itemHeight = InfiniteList.withConstantHeight (round rowHeight)
            , containerHeight = round necessities.height
            }
        )


infiniteListContainer :
    List ( String, String )
    -> List (UnstyledHtml.Html msg)
    -> UnstyledHtml.Html msg
infiniteListContainer styles children =
    UnstyledHtml.div
        (List.map (\( k, v ) -> UnstyledHtmlAttributes.style k v) styles)
        [ (Html.toUnstyled << rawy) <|
            slab
                Html.ol
                [ css listStyles ]
                [ T.dt
                , T.dt__fixed
                , T.f6
                , T.list
                , T.ma0
                , T.ph0
                , T.pv1
                ]
                (List.map Html.fromUnstyled children)
        ]


listStyles : List Css.Style
listStyles =
    [ Css.fontSize (Css.px 12.5)
    ]


itemView : Model -> Int -> Int -> IdentifiedTrack -> UnstyledHtml.Html Msg
itemView { favouritesOnly } _ idx ( identifiers, track ) =
    Html.toUnstyled <|
        slab
            Html.li
            [ css (rowStyles idx identifiers) ]
            [ T.dt_row

            --
            , ifThenElse identifiers.isMissing "" T.pointer
            , ifThenElse identifiers.isSelected T.fw6 ""
            ]
            [ favouriteColumn favouritesOnly identifiers
            , otherColumn 37.5 False track.tags.title
            , otherColumn 29.0 False track.tags.artist
            , otherColumn 29.0 True track.tags.album
            ]
