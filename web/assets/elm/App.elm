module App exposing (..)

import Debug
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Encode as JE
import Json.Decode as JD exposing (..)
import Json.Decode.Pipeline as JDP exposing (decode, required, optional, hardcoded)
import Phoenix
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Socket as Socket exposing (Socket, AbnormalClose)
import Phoenix.Push as Push
import Time exposing (Time)
import Dict exposing (Dict)


main =
    Html.program
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }


type alias AircraftCategory =
    { set : String
    , category : String
    }


type alias AircraftPosition =
    { lat : Float
    , lon : Float
    }


type alias Aircraft =
    { address : String
    , callsign : String
    , country : String
    , registration : String
    , squawk : String
    , altitude : Int
    , vr : Int
    , vr_dir : String
    , velocity_kt : Int
    , category : AircraftCategory
    , heading : Int
    , position : AircraftPosition
    , distance : Float
    , msgs : Int
    , age : Int
    }


type alias Model =
    { aircraft : Dict String Aircraft
    }


type Msg
    = None
    | AircraftReport JD.Value


socket =
    Socket.init "ws://localhost:4000/socket/websocket"


channel =
    Channel.init "aircraft:reports"
        |> Channel.on "report" AircraftReport


init : ( Model, Cmd Msg )
init =
    ( Model Dict.empty, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        None ->
            ( model, Cmd.none )

        AircraftReport msg ->
            case JD.decodeValue decodeAircraft msg of
                Ok msg ->
                    ( { model | aircraft = Dict.insert msg.address msg model.aircraft }, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.connect socket [ channel ]


decodeAircraft : Decoder Aircraft
decodeAircraft =
    decode Aircraft
        |> JDP.required "address" string
        |> JDP.required "callsign" string
        |> JDP.required "country" string
        |> JDP.required "registration" string
        |> JDP.required "squawk" string
        |> JDP.optional "altitude" int 0
        |> JDP.optional "vr" int 0
        |> JDP.optional "vr_dir" string ""
        |> JDP.optional "velocity_kt" int 0
        |> JDP.required "category" decodeCategory
        |> JDP.optional "heading" int 0
        |> JDP.required "position" decodePosition
        |> JDP.required "distance" float
        |> JDP.required "msgs" int
        |> JDP.required "age" int


decodeCategory : Decoder AircraftCategory
decodeCategory =
    decode AircraftCategory
        |> JDP.required "set" string
        |> JDP.required "category" string


decodePosition : Decoder AircraftPosition
decodePosition =
    decode AircraftPosition
        |> JDP.optional "lat" float 0.0
        |> JDP.optional "lon" float 0.0


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
                (List.map aircraftRow (Dict.values model.aircraft))
            ]
        ]


aircraftRow : Aircraft -> Html msg
aircraftRow aircraft =
    tr []
        [ td [] [ text aircraft.address ]
        , td [] [ text aircraft.country ]
        , td [] [ text aircraft.registration ]
        , td [] [ text aircraft.callsign ]
        , td [] [ text aircraft.squawk ]
        , td [] [ text (toString aircraft.altitude) ]
        , td [] [ text (toString aircraft.velocity_kt) ]
        , td [] [ text (toString aircraft.vr) ]
        , td [] [ text (toString aircraft.distance) ]
        , td [] [ text (toString aircraft.heading) ]
        , td [] [ text (toString aircraft.position.lat) ]
        , td [] [ text (toString aircraft.position.lon) ]
        , td [] [ text (toString aircraft.msgs) ]
        , td [] [ text (toString aircraft.age) ]
        ]
