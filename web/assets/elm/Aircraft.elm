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
    { aircraft : Dict String StateVector
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


type alias AircraftAgeList =
    { messages : List AircraftAge
    }


type alias AircraftAge =
    { address : String
    , age : Int
    }


type alias AircraftTimeoutList =
    { messages : List AircraftTimeout
    }


type alias AircraftTimeout =
    { address : String
    }


type alias StateVectorList =
    { messages : List StateVector
    }


type alias StateVector =
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


type Msg
    = None
    | AircraftStateVectorsMsg JD.Value
    | AircraftAgesMsg JD.Value
    | AircraftTimeoutsMsg JD.Value
    | UrlChange Navigation.Location


socket : Location -> Socket Msg
socket location =
    let
        host =
            location.host
    in
        Socket.init ("ws://" ++ host ++ "/socket/websocket")


channel =
    Channel.init "aircraft:messages"
        |> Channel.on "state_vector" AircraftStateVectorsMsg
        |> Channel.on "age" AircraftAgesMsg
        |> Channel.on "timeout" AircraftTimeoutsMsg


removeAircraftAfterTimeout : AircraftTimeout -> Model -> Model
removeAircraftAfterTimeout timeout model =
    { model | aircraft = Dict.remove timeout.address model.aircraft }


updateAircraftAge : AircraftAge -> Model -> Model
updateAircraftAge age model =
    case Dict.get age.address model.aircraft of
        Just a ->
            { model | aircraft = Dict.insert age.address { a | age = age.age } model.aircraft }

        Nothing ->
            -- If we don't have the aircraft yet, ignore the age message
            model


updateStateVector : StateVector -> Model -> Model
updateStateVector vector model =
    { model | aircraft = Dict.insert vector.address vector model.aircraft }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        None ->
            ( model, Cmd.none )

        UrlChange location ->
            ( { model | location = location }, Cmd.none )

        AircraftTimeoutsMsg msg ->
            case JD.decodeValue decodeTimeouts msg of
                Ok msg ->
                    ( List.foldr (removeAircraftAfterTimeout) model msg.messages, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )

        AircraftAgesMsg msg ->
            case JD.decodeValue decodeAges msg of
                Ok msg ->
                    ( List.foldr (updateAircraftAge) model msg.messages, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )

        AircraftStateVectorsMsg msg ->
            case JD.decodeValue decodeStateVectors msg of
                Ok msg ->
                    ( List.foldr (updateStateVector) model msg.messages, Cmd.none )

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


decodeStateVectors : Decoder StateVectorList
decodeStateVectors =
    decode StateVectorList
        |> JDP.required "messages" (JD.list decodeStateVector)


decodeStateVector : Decoder StateVector
decodeStateVector =
    decode StateVector
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


decodeAges : Decoder AircraftAgeList
decodeAges =
    decode AircraftAgeList
        |> JDP.required "messages" (JD.list decodeAge)


decodeAge : Decoder AircraftAge
decodeAge =
    decode AircraftAge
        |> JDP.required "address" string
        |> JDP.required "age" int


decodeTimeouts : Decoder AircraftTimeoutList
decodeTimeouts =
    decode AircraftTimeoutList
        |> JDP.required "messages" (JD.list decodeTimeout)


decodeTimeout : Decoder AircraftTimeout
decodeTimeout =
    decode AircraftTimeout
        |> JDP.required "address" string


view : Model -> Html Msg
view model =
    div
        [ class "container-fluid" ]
        [ h3 [] [ text "Aircraft" ]
        , table [ class "table", class "table-striped", class "table-condensed", id "aircraft-table" ]
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


intToHeading : Int -> String
intToHeading heading =
    let
        headingString =
            intToString heading
    in
        if headingString == "" then
            headingString
        else
            headingString ++ "°"


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


aircraftRow : StateVector -> Html msg
aircraftRow vector =
    tr []
        [ td [] [ text vector.address ]
        , td [] [ text vector.country ]
        , td [] [ text vector.registration ]
        , td [] [ text vector.callsign ]
        , td [] [ text vector.squawk ]
        , td [] [ text (intToString vector.altitude) ]
        , td [] [ text (intToString vector.velocity_kt) ]
        , td [] [ text (renderVr vector.vr vector.vr_dir) ]
        , td [] [ text (floatToString vector.distance) ]
        , td [] [ text (intToHeading vector.heading) ]
        , td [] [ text (floatToString vector.position.lat) ]
        , td [] [ text (floatToString vector.position.lon) ]
        , td [] [ text (intToString vector.msgs) ]
        , td [] [ text (toString vector.age) ]
        ]
