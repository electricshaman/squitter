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
import Navigation exposing (..)


main =
    Navigation.program UrlChange
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }


type alias Model =
    { aircraft : Dict String Aircraft
    , location : Location
    }


init : Location -> ( Model, Cmd Msg )
init location =
    ( Model Dict.empty location
    , Cmd.none
    )


type alias AircraftCategory =
    { set : String
    , category : String
    }


type alias AircraftPosition =
    { lat : Float
    , lon : Float
    }


type alias AircraftAge =
    { address : String
    , age : Int
    }


type alias AircraftTimeout =
    { address : String
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


defaultAircraft =
    { address = ""
    , callsign = ""
    , country = ""
    , registration = ""
    , squawk = ""
    , altitude = 0
    , vr = 0
    , vr_dir = ""
    , velocity_kt = 0
    , category = { set = "", category = "" }
    , heading = 0
    , position = { lat = 0.0, lon = 0.0 }
    , distance = 0.0
    , msgs = 0
    , age = 0
    }


type Msg
    = None
    | AircraftMsg JD.Value
    | AircraftAgeMsg JD.Value
    | AircraftTimeoutMsg JD.Value
    | UrlChange Navigation.Location


socket : Location -> Socket Msg
socket location =
    let
        host =
            location.host
    in
        Socket.init ("ws://" ++ host ++ "/socket/websocket")


channel =
    Channel.init "aircraft:reports"
        |> Channel.on "report" AircraftMsg
        |> Channel.on "age" AircraftAgeMsg
        |> Channel.on "timeout" AircraftTimeoutMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        None ->
            ( model, Cmd.none )

        UrlChange location ->
            ( { model | location = location }, Cmd.none )

        AircraftTimeoutMsg msg ->
            case JD.decodeValue decodeTimeout msg of
                Ok msg ->
                    ( { model | aircraft = Dict.remove msg.address model.aircraft }, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )

        AircraftAgeMsg msg ->
            case JD.decodeValue decodeAge msg of
                Ok msg ->
                    let
                        aircraft : Aircraft
                        aircraft =
                            case Dict.get msg.address model.aircraft of
                                Just a ->
                                    { a | age = msg.age }

                                Nothing ->
                                    { defaultAircraft | address = msg.address, age = msg.age }
                    in
                        ( { model | aircraft = Dict.insert msg.address aircraft model.aircraft }, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )

        AircraftMsg msg ->
            case JD.decodeValue decodeAircraft msg of
                Ok msg ->
                    ( { model | aircraft = Dict.insert msg.address msg model.aircraft }, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        new_socket =
            socket model.location
    in
        Phoenix.connect new_socket [ channel ]


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


decodeAge : Decoder AircraftAge
decodeAge =
    decode AircraftAge
        |> JDP.required "address" string
        |> JDP.required "age" int


decodeTimeout : Decoder AircraftTimeout
decodeTimeout =
    decode AircraftTimeout
        |> JDP.required "address" string


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


intToString : Int -> String
intToString input =
    if input == 0 then
        ""
    else
        toString input


floatToString : Float -> String
floatToString input =
    if input == 0.0 then
        ""
    else
        toString input


renderVr : Int -> String -> String
renderVr vr vr_dir =
    if vr_dir == "up" then
        "+" ++ toString vr
    else if vr_dir == "down" then
        "-" ++ toString vr
    else
        intToString vr


aircraftRow : Aircraft -> Html msg
aircraftRow aircraft =
    tr []
        [ td [] [ text aircraft.address ]
        , td [] [ text aircraft.country ]
        , td [] [ text aircraft.registration ]
        , td [] [ text aircraft.callsign ]
        , td [] [ text aircraft.squawk ]
        , td [] [ text (intToString aircraft.altitude) ]
        , td [] [ text (intToString aircraft.velocity_kt) ]
        , td [] [ text (renderVr aircraft.vr aircraft.vr_dir) ]
        , td [] [ text (floatToString aircraft.distance) ]
        , td [] [ text (intToString aircraft.heading) ]
        , td [] [ text (floatToString aircraft.position.lat) ]
        , td [] [ text (floatToString aircraft.position.lon) ]
        , td [] [ text (intToString aircraft.msgs) ]
        , td [] [ text (toString aircraft.age) ]
        ]
