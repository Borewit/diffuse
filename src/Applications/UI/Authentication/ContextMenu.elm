module UI.Authentication.ContextMenu exposing (moreOptionsMenu)

import ContextMenu exposing (..)
import Coordinates exposing (Coordinates)
import Svg
import UI.Authentication as Authentication
import UI.Reply exposing (Reply(..))
import UI.Svg.Elements



-- 🔱


moreOptionsMenu : Coordinates -> ContextMenu Reply
moreOptionsMenu =
    ContextMenu
        [ Item
            { icon = \_ _ -> Svg.map never UI.Svg.Elements.ipfsLogo
            , label = "IPFS (using the Mutable File System)"
            , msg = PingIpfsForAuth
            , active = False
            }
        , Item
            { icon = \_ _ -> Svg.map never UI.Svg.Elements.textileLogo
            , label = "Textile (Experimental)"
            , msg = PingTextileForAuth
            , active = False
            }
        ]
