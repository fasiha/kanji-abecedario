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
import Json.Encode as Encode


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
    | Record
    | Previous
    | Next


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
            case err of
                Http.BadStatus res ->
                    ( { model | err = (toString err) }, Cmd.none )

                _ ->
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

        Record ->
            case model.target of
                Nothing ->
                    ( model, Cmd.none )

                Just target ->
                    ( { model | selected = Set.empty }
                    , record model.token target.target (Set.toList model.selected)
                    )

        Previous ->
            ( model
            , model.target
                |> Maybe.map (.pos >> ((+) -1) >> getPos)
                |> Maybe.withDefault Cmd.none
            )

        Next ->
            ( model
            , model.target
                |> Maybe.map (.pos >> ((+) 1) >> getPos)
                |> Maybe.withDefault Cmd.none
            )


record : String -> String -> List String -> Cmd Msg
record token target deps =
    Http.send GotTarget
        (Http.request
            { method = "POST"
            , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
            , url =
                "http://localhost:3000/secured/record/" ++ target
            , body =
                Http.jsonBody (Encode.list (List.map Encode.string deps))
            , expect = Http.expectJson targetDecoder
            , timeout = Nothing
            , withCredentials = False
            }
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
        , button [] [ text "My kanji" ]
        , button
            [ onClick Previous
            , HA.disabled
                (model.target
                    |> Maybe.map (.pos >> (<=) 1)
                    |> Maybe.withDefault True
                )
            ]
            [ text "Previous kanji" ]
        , button [ onClick Next ] [ text "Next kanji" ]
        , button [ onClick AskFirstNoDeps ] [ text "First kanji without deps" ]
        , button [ onClick Record ] [ text "Record" ]
        , button [] [ text "Type in kanji" ]
        , div []
            [ text
                (toString
                    { model
                        | primitives = (List.take 1 model.primitives)
                        , token = String.slice 0 5 model.token
                    }
                )
            ]
        , renderTarget model.target
        , renderPrimitives model.selected model.primitives
        ]


renderTargetDeps : Target -> Html Msg
renderTargetDeps target =
    Html.ul []
        (List.map
            (\dep ->
                Html.li []
                    [ text
                        (dep.depString
                            ++ " ("
                            ++ (toString dep.count)
                            ++ " votes)"
                        )
                    ]
            )
            target.deps
        )


renderTarget : Maybe Target -> Html Msg
renderTarget maybetarget =
    case maybetarget of
        Just target ->
            div []
                [ Html.h1 [] [ text ("Help us decompose " ++ target.target ++ "!") ]
                , renderTargetDeps target
                ]

        Nothing ->
            div [] [ text "(Waiting for network)" ]


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
