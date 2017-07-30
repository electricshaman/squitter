module App exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push
import Json.Encode exposing (..)
import Json.Decode exposing (..)


main =
    Html.program
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }


type alias Aircraft =
    { icao : String
    , callsign : String
    , country : String
    , registration : String
    , squawk : String
    , altitude : Int
    , vr : Float
    , distance : Float
    , speed : Int
    , heading : Int
    , latitude : Float
    , longitude : Float
    , messages : Int
    , age : Int
    }


type alias Model =
    { aircraft : List Aircraft
    , socket : Phoenix.Socket.Socket Msg
    }


type Msg
    = None
    | PhoenixMsg (Phoenix.Socket.Msg Msg)
    | ReceiveAircraft Json.Encode.Value


init : ( Model, Cmd Msg )
init =
    let
        socket =
            Phoenix.Socket.init "ws://endeavour.local:4000/socket/websocket"
                |> Phoenix.Socket.withDebug
                |> Phoenix.Socket.on "new:msg"
                    "rooms:lobby"
                    ReceiveAircraft
                    Phoenix.Channel.init
                    "rooms:lobby"
    in
        ( Model [] socket, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        None ->
            ( model, Cmd.none )

        PhoenixMsg msg ->
            let
                ( socket, phxCmd ) =
                    Phoenix.Socket.update msg model.socket
            in
                ( { model | socket = socket }
                , Cmd.map PhoenixMsg phxCmd
                )


view : Model -> Html Msg
view model =
    div
        [ class "container-fluid" ]
        [ h3 [] [ text "Aircraft" ]
        , table [ class "table", class "table-striped", class "table-condensed" ]
            [ thead []
                [ tr []
                    [ th [] [ text "ICAO" ]
                    , th [] [ text "Country" ]
                    , th [] [ text "Registration" ]
                    , th [] [ text "Callsign" ]
                    , th [] [ text "Squawk" ]
                    , th [] [ text "Altitude (ft)" ]
                    , th [] [ text "Speed (kt)" ]
                    , th [] [ text "Vertical Rate (ft/min)" ]
                    , th [] [ text "Distance (NM)" ]
                    , th [] [ text "Heading" ]
                    , th [] [ text "Latitude" ]
                    , th [] [ text "Longitude" ]
                    , th [] [ text "Messages" ]
                    , th [] [ text "Age" ]
                    ]
                ]
            , tbody []
                (List.map aircraftRow model.aircraft)
            ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.Socket.listen model.socket PhoenixMsg


aircraftRow : Aircraft -> Html msg
aircraftRow aircraft =
    tr []
        [ td [] [ text aircraft.icao ]
        , td [] [ text aircraft.country ]
        , td [] [ text aircraft.registration ]
        , td [] [ text aircraft.callsign ]
        , td [] [ text aircraft.squawk ]
        , td [] [ text (toString aircraft.altitude) ]
        , td [] [ text (toString aircraft.speed) ]
        , td [] [ text (toString aircraft.vr) ]
        , td [] [ text (toString aircraft.distance) ]
        , td [] [ text (toString aircraft.heading) ]
        , td [] [ text (toString aircraft.latitude) ]
        , td [] [ text (toString aircraft.longitude) ]
        , td [] [ text (toString aircraft.messages) ]
        , td [] [ text (toString aircraft.age) ]
        ]
