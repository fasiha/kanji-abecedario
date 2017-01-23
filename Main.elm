port module Main exposing (..)

import Html exposing (Html, button, div, text)
import Html.Attributes as HA
import Set
import Svg
import Svg.Attributes exposing (viewBox, d, class)
import Html.Events exposing (onClick)
import Http
import Maybe
import Json.Decode as Decode


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Dependencies =
    { depString : String, count : Int }


type alias Target =
    { target : String, pos : Int, deps : List Dependencies }


type alias Primitive =
    { paths : List String, target : String, heading : String }


type alias Model =
    { err : String
    , token : String
    , target : Maybe Target
    , primitives : List Primitive
    , selected : Set.Set String
    }


init : ( Model, Cmd Msg )
init =
    ( Model ""
        "invalid token"
        Maybe.Nothing
        []
        Set.empty
    , Cmd.batch [ getPos 1, getPrimitives ]
    )


depsDecoder : Decode.Decoder Dependencies
depsDecoder =
    Decode.map2 Dependencies
        (Decode.field "sortedDeps" Decode.string)
        (Decode.field "cnt" Decode.int)


targetDecoder : Decode.Decoder Target
targetDecoder =
    Decode.map3 Target
        (Decode.field "target" Decode.string)
        (Decode.field "rowid" Decode.int)
        (Decode.field "deps" (Decode.list depsDecoder))


primitiveDecoder : Decode.Decoder Primitive
primitiveDecoder =
    Decode.map3 Primitive
        (Decode.field "paths" (Decode.list Decode.string))
        (Decode.field "target" Decode.string)
        (Decode.field "heading" Decode.string)



-- UPDATE


type Msg
    = Login
    | AskFirstNoDeps
    | GotTarget (Result Http.Error Target)
    | GotLocalStorage String
    | GotPrimitives (Result Http.Error (List Primitive))
    | SelectPrimitive String


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

        GotPrimitives (Err err) ->
            ( { model | err = (toString err) }, Cmd.none )

        GotPrimitives (Ok list) ->
            ( { model | primitives = list }, Cmd.none )

        SelectPrimitive str ->
            ( { model
                | selected =
                    if Set.member str model.selected then
                        Set.remove str model.selected
                    else
                        Set.insert str model.selected
              }
            , Cmd.none
            )


getPrimitives : Cmd Msg
getPrimitives =
    Http.send GotPrimitives (Http.get "http://localhost:3000/data/paths.json" (Decode.list primitiveDecoder))


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
        , div []
            [ text
                (toString
                    { model
                        | primitives = (List.take 1 model.primitives)
                        , token = String.slice 0 5 model.token
                    }
                )
            ]
        , text (toString model.target)
        , div [] [ text model.err ]
        , renderPrimitives model.selected model.primitives
        ]


renderPrimitive : Set.Set String -> Primitive -> Html Msg
renderPrimitive selecteds primitive =
    Svg.svg
        [ viewBox "0 0 109 109"
        , class
            (String.join " "
                [ ("col-" ++ primitive.heading)
                , if Set.member primitive.target selecteds then
                    "primitive-selected"
                  else
                    ""
                ]
            )
        , onClick (SelectPrimitive primitive.target)
        ]
        (List.map (\path -> Svg.path [ d path ] []) primitive.paths)


renderPrimitives : Set.Set String -> List Primitive -> Html Msg
renderPrimitives selected primitives =
    div [ HA.class "primitive-container" ]
        (List.map (renderPrimitive selected) primitives)
