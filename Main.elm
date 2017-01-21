port module Main exposing (..)

import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode


main : Program Never Model Msg
main =
    Html.program { init = init, view = view, update = update, subscriptions = subscriptions }



-- MODEL


type alias Model =
    { num : Int, target : String }


init : ( Model, Cmd Msg )
init =
    ( Model 0 "", Cmd.none )



-- UPDATE


type Msg
    = Increment
    | Decrement
    | Login
    | AskFirstNoDeps
    | FirstNoDeps (Result Http.Error String)


port login : String -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Increment ->
            ( { model | num = model.num + 1 }, Cmd.none )

        Decrement ->
            ( { model | num = model.num - 1 }, Cmd.none )

        Login ->
            ( model, login "doesntmatter" )

        AskFirstNoDeps ->
            ( model, askFirstNoDeps )

        FirstNoDeps (Ok target) ->
            ( { model | target = target }, Cmd.none )

        FirstNoDeps (Err err) ->
            ( { model | target = (toString err) }, Cmd.none )


firstNoDepsDecoder : Decode.Decoder String
firstNoDepsDecoder =
    Decode.at [ "0", "target" ] Decode.string


askFirstNoDeps : Cmd Msg
askFirstNoDeps =
    Http.send FirstNoDeps (Http.get "http://localhost:3000/firstNoDeps" firstNoDepsDecoder)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ button [ onClick Login ] [ text "Login from Elm" ]
        , button [ onClick AskFirstNoDeps ] [ text "Ask for first target" ]
        , button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (toString model) ]
        , button [ onClick Increment ] [ text "+" ]
        , text model.target
        ]
