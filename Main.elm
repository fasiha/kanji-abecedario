port module Main exposing (..)

import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)
import Http
import Maybe
import Json.Decode as Decode


main : Program Never Model Msg
main =
    Html.program { init = init, view = view, update = update, subscriptions = subscriptions }



-- MODEL


type alias DependencyCount =
    { depString : String, count : Int }


type alias Target =
    { target : String, pos : Int, deps : Maybe (List DependencyCount) }


type alias Model =
    { err : String, token : String, target : Maybe Target }


init : ( Model, Cmd Msg )
init =
    ( Model "" "invalid token" Maybe.Nothing, getPos 1 )



-- UPDATE


type Msg
    = Login
    | AskFirstNoDeps
    | GotTarget (Result Http.Error Target)
    | GotLocalStorage String


port login : String -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Login ->
            ( model, login "doesntmatter" )

        AskFirstNoDeps ->
            ( model, askFirstNoDeps )

        GotTarget (Ok target) ->
            ( { model | target = Just target }, Cmd.none )

        GotTarget (Err err) ->
            ( { model | err = (toString err) }, Cmd.none )

        GotLocalStorage str ->
            ( { model | token = str }, Cmd.none )


targetDecoder : Decode.Decoder Target
targetDecoder =
    Decode.map2 (\a b -> Target a b Nothing)
        (Decode.at [ "0", "target" ] Decode.string)
        (Decode.at [ "0", "rowid" ] Decode.int)


askFirstNoDeps : Cmd Msg
askFirstNoDeps =
    Http.send GotTarget (Http.get "http://localhost:3000/firstNoDeps" targetDecoder)


getPos : Int -> Cmd Msg
getPos pos =
    Http.send GotTarget (Http.get ("http://localhost:3000/getPos/" ++ (toString pos)) targetDecoder)



-- SUBSCRIPTIONS


port gotLocalStorage : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    gotLocalStorage GotLocalStorage



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ button [ onClick Login ] [ text "Login from Elm" ]
        , button [ onClick AskFirstNoDeps ] [ text "Ask for first target" ]
        , div [] [ text (toString model) ]
        , text (toString model.target)
        , div [] [ text model.err ]
        ]
