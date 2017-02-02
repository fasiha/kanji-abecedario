port module Main exposing (..)

import Html exposing (Html, button, div, text, a, span)
import Html.Attributes as HA
import Set exposing (Set)
import Dict exposing (Dict)
import Svg
import Svg.Attributes as SA exposing (viewBox, d, class)
import Html.Events exposing (onClick, onInput)
import Http
import Maybe exposing (withDefault)
import Json.Decode as Decode
import Json.Encode as Encode
import Navigation
import UrlParser as Url exposing ((</>), (<?>), s, int, string, top)


main : Program Never Model Msg
main =
    Navigation.program UrlChange
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
    { i : Int, paths : List String, target : String, heading : String }


type alias Model =
    { err : String
    , token : String
    , target : Maybe Target
    , primitives : Dict String Primitive
    , selected : Set String
    , selectedKanjis : Set String
    , userDeps : Maybe String
    , kanjiOnly : List String
    , myKanji : List UserDeps
    }


init : Navigation.Location -> ( Model, Cmd Msg )
init initialLocation =
    ( Model ""
        "invalid token"
        Nothing
        Dict.empty
        Set.empty
        Set.empty
        Nothing
        []
        []
    , Cmd.batch
        [ (case Url.parseHash route initialLocation of
            Just (RoutePos pos) ->
                getPos pos

            Just (RouteTarget target) ->
                getTarget target

            _ ->
                askFirstNoDeps
          )
        , getPrimitives
        , getKanjiOnly
        ]
    )


type alias UserDeps =
    -- NOT used in Model! Just for decoding JSON. Model will get `deps` field only.
    { target : String, deps : String }


userDepsDecoder : Decode.Decoder UserDeps
userDepsDecoder =
    Decode.map2 UserDeps
        (Decode.field "target" Decode.string)
        (Decode.field "deps" Decode.string)


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
    Decode.map3 (Primitive -1)
        (Decode.field "paths" (Decode.list Decode.string))
        (Decode.field "target" Decode.string)
        (Decode.field "heading" Decode.string)



-- URL PARSING


type Route
    = Home
    | RoutePos Int
    | RouteTarget String


route : Url.Parser (Route -> a) a
route =
    Url.oneOf
        [ Url.map Home top
        , Url.map RoutePos (s "pos" </> int)
        , Url.map RouteTarget (s "target" </> string)
        ]


routeToFragment : Route -> String
routeToFragment route =
    case route of
        RoutePos i ->
            "#pos/" ++ (toString i)

        RouteTarget s ->
            "#target/" ++ s

        _ ->
            ""



-- UPDATE


type Msg
    = Login
    | AskFirstNoDeps
    | AskFirstNoDepsUser
    | GotTarget (Result Http.Error Target)
    | GotLocalStorage String
    | GotPrimitives (Result Http.Error (List Primitive))
    | SelectPrimitive String
    | Record
    | Previous
    | Next
    | Input String
    | Accept String
    | AskForUserDeps
    | GotUserDeps (Result Http.Error UserDeps)
    | UrlChange Navigation.Location
    | AskForTarget
    | GotKanjiOnly (Result Http.Error String)
    | MyKanji
    | GotMyKanji (Result Http.Error (List UserDeps))


port login : String -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Login ->
            ( model, login "doesntmatter" )

        AskFirstNoDeps ->
            ( model, askFirstNoDeps )

        AskFirstNoDepsUser ->
            ( model, askFirstNoDepsUser model.token )

        GotTarget (Ok target) ->
            let
                url =
                    routeToFragment (RoutePos target.pos)
            in
                ( { model | target = Just target }
                , if List.isEmpty target.deps then
                    Navigation.newUrl url
                  else
                    Cmd.batch
                        [ Navigation.newUrl url
                        , askForUserDeps model.token target.target
                        ]
                )

        GotTarget (Err err) ->
            case err of
                -- Could be because of getPos/-1, getTarget/foo, or invalid record
                -- Could be unauthorized
                -- Could mean no targets lacking dependencies (in general or for a user)
                Http.BadStatus res ->
                    case (res |> .status |> .code) of
                        404 ->
                            ( { model | err = "Couldn’t find anything at " ++ (res |> .url) ++ "! Forwarding you to automatically…" }
                            , getPos 1
                            )

                        401 ->
                            ( { model | err = "Hey, looks like you need to be logged in to do that." }
                            , login "doesntmatter"
                            )

                        400 ->
                            ( { model | err = "The server was unhappy with the data you just sent. If it made a mistake, please contact us. Sorry for the inconvenience." }
                            , Cmd.none
                            )

                        _ ->
                            ( { model | err = (toString err) }
                            , Cmd.none
                            )

                _ ->
                    ( { model | err = (toString err) }, Cmd.none )

        AskForUserDeps ->
            ( model
            , model.target
                |> Maybe.map (askForUserDeps model.token << .target)
                |> withDefault Cmd.none
            )

        GotUserDeps (Ok deps) ->
            ( if deps.target == (model.target |> Maybe.map .target |> withDefault "") then
                { model | userDeps = Just deps.deps }
              else
                model
            , Cmd.none
            )

        GotUserDeps (Err err) ->
            case err of
                Http.BadStatus res ->
                    case (res |> .status |> .code) of
                        401 ->
                            -- user just browsing, carry on
                            ( model, Cmd.none )

                        404 ->
                            -- no user deps
                            ( model, Cmd.none )

                        _ ->
                            ( { model | err = (toString err), userDeps = Nothing }, Cmd.none )

                _ ->
                    ( { model | err = (toString err) }, Cmd.none )

        GotLocalStorage str ->
            ( { model | token = str }, Cmd.none )

        GotPrimitives (Err err) ->
            ( { model | err = (toString err) }, Cmd.none )

        GotPrimitives (Ok list) ->
            ( { model | primitives = List.indexedMap (\i p -> ( p.target, { p | i = i } )) list |> Dict.fromList }, Cmd.none )

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
                    , record
                        model.token
                        target.target
                        (Set.toList <| Set.union model.selected model.selectedKanjis)
                    )

        Previous ->
            ( model
            , model.target
                |> Maybe.map (.pos >> ((+) -1) >> getPos)
                |> withDefault Cmd.none
            )

        Next ->
            ( model
            , model.target
                |> Maybe.map (.pos >> ((+) 1) >> getPos)
                |> withDefault Cmd.none
            )

        Input text ->
            ( { model | selectedKanjis = text |> String.split "" |> Set.fromList }
            , Cmd.none
            )

        Accept str ->
            ( model
            , model.target
                |> Maybe.map
                    (\target -> str |> String.split "," |> record model.token target.target)
                |> withDefault Cmd.none
            )

        UrlChange location ->
            let
                thisroute =
                    Url.parseHash route location
            in
                case thisroute of
                    Just (RoutePos pos) ->
                        ( model
                        , if model.target |> Maybe.map (.pos >> ((/=) pos)) |> withDefault True then
                            getPos pos
                          else
                            Cmd.none
                        )

                    Just (RouteTarget target) ->
                        ( model
                        , if model.target |> Maybe.map (.target >> ((/=) target)) |> withDefault True then
                            getTarget target
                          else
                            Cmd.none
                        )

                    _ ->
                        ( model, Cmd.none )

        AskForTarget ->
            if Set.isEmpty model.selectedKanjis then
                ( model, Cmd.none )
            else
                ( model
                , model.selectedKanjis
                    |> Set.toList
                    |> List.head
                    |> withDefault ""
                    |> getTarget
                )

        GotKanjiOnly (Ok str) ->
            ( { model | kanjiOnly = String.toList str |> List.map String.fromChar }, Cmd.none )

        GotKanjiOnly (Err err) ->
            ( { model | err = toString err }, Cmd.none )

        MyKanji ->
            ( model, myKanji model.token )

        GotMyKanji (Ok list) ->
            ( { model | myKanji = list }, Cmd.none )

        GotMyKanji (Err err) ->
            case err of
                -- Could be because of getPos/-1, getTarget/foo, or invalid record
                -- Could be unauthorized
                -- Could mean no targets lacking dependencies (in general or for a user)
                Http.BadStatus res ->
                    case (res |> .status |> .code) of
                        401 ->
                            ( { model | err = "Hey, looks like you need to be logged in to do that." }
                            , login "doesntmatter"
                            )

                        _ ->
                            ( { model | err = (toString err) }
                            , Cmd.none
                            )

                _ ->
                    ( { model | err = (toString err) }, Cmd.none )


myKanji : String -> Cmd Msg
myKanji token =
    Http.send GotMyKanji
        (Http.request
            { method = "GET"
            , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
            , url =
                "http://localhost:3000/secured/myDeps"
            , body =
                Http.emptyBody
            , expect = Http.expectJson (Decode.list userDepsDecoder)
            , timeout = Nothing
            , withCredentials = False
            }
        )


askForUserDeps : String -> String -> Cmd Msg
askForUserDeps token target =
    Http.send GotUserDeps
        (Http.request
            { method = "GET"
            , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
            , url =
                "http://localhost:3000/secured/userDeps/" ++ target
            , body =
                Http.emptyBody
            , expect = Http.expectJson userDepsDecoder
            , timeout = Nothing
            , withCredentials = False
            }
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
    Http.send GotPrimitives
        (Http.get "http://localhost:3000/data/pathsNonKanji.json"
            (Decode.list primitiveDecoder)
        )


getKanjiOnly : Cmd Msg
getKanjiOnly =
    Http.send GotKanjiOnly
        (Http.get "http://localhost:3000/data/jouyou_jinmeiyou.json" Decode.string)


askFirstNoDeps : Cmd Msg
askFirstNoDeps =
    Http.send GotTarget (Http.get "http://localhost:3000/firstNoDeps" targetDecoder)


askFirstNoDepsUser : String -> Cmd Msg
askFirstNoDepsUser token =
    Http.send GotTarget
        (Http.request
            { method = "GET"
            , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
            , url =
                "http://localhost:3000/secured/firstNoDeps"
            , body =
                Http.emptyBody
            , expect = Http.expectJson targetDecoder
            , timeout = Nothing
            , withCredentials = False
            }
        )


getPos : Int -> Cmd Msg
getPos pos =
    Http.send GotTarget
        (Http.get ("http://localhost:3000/getPos/" ++ (toString pos))
            targetDecoder
        )


getTarget : String -> Cmd Msg
getTarget target =
    Http.send GotTarget (Http.get ("http://localhost:3000/getTarget/" ++ target) targetDecoder)



-- SUBSCRIPTIONS


port gotLocalStorage : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    gotLocalStorage GotLocalStorage



-- VIEW


renderModel : Model -> Html Msg
renderModel model =
    div []
        [ text
            (toString
                { model
                    | primitives = Dict.toList model.primitives |> List.take 1
                    , token = String.slice 0 5 model.token
                    , kanjiOnly = List.take 10 model.kanjiOnly
                }
            )
        ]


view : Model -> Html Msg
view model =
    div []
        [ renderErr model.err
        , button [ onClick Login ] [ text "Login from Elm" ]
        , button [ onClick MyKanji ] [ text "My kanji" ]
        , button
            [ onClick Previous
            , HA.disabled
                (model.target
                    |> Maybe.map (.pos >> (>=) 1)
                    |> withDefault True
                )
            ]
            [ text "Previous kanji" ]
        , button [ onClick Next ] [ text "Next kanji" ]
        , button [ onClick AskFirstNoDeps ] [ text "First kanji without any votes" ]
        , button [ onClick AskFirstNoDepsUser ] [ text "First kanji without my vote" ]
        , button [ onClick Record ] [ text "Record" ]
        , Html.input [ HA.placeholder "Enter kanji here", onInput Input ] []
        , button [ onClick AskForTarget, HA.disabled (Set.isEmpty model.selectedKanjis) ] [ text "Jump to a kanji" ]
        , renderTarget model.target model.userDeps model.primitives
        , renderPrimitives model.selected model.primitives
        , renderPrimitivesDispOnly model.primitives
        , renderKanjis model.kanjiOnly
        , renderModel model
        ]


renderErr : String -> Html Msg
renderErr err =
    if String.isEmpty err then
        div [] []
    else
        div [ class "error-notification" ] [ text err ]


svgKanji : String -> Html msg
svgKanji kanji =
    Svg.svg [ class "dependency", viewBox "0 0 21 21" ]
        [ Svg.text_ [ SA.x "50%", SA.y "50%", SA.textAnchor "middle", SA.dy "30%" ]
            [ Svg.text kanji ]
        ]


renderTargetDeps : Target -> Maybe String -> Dict String Primitive -> Html Msg
renderTargetDeps target maybeuserdeps primitives =
    Html.ul []
        (List.map
            (\dep ->
                let
                    uservote =
                        maybeuserdeps |> Maybe.map ((==) dep.depString) |> withDefault False
                in
                    Html.li
                        (if uservote then
                            [ class "uservote" ]
                         else
                            []
                        )
                    <|
                        (String.split "," dep.depString
                            |> List.map
                                (\s ->
                                    Dict.get s primitives
                                        |> Maybe.map (svgPrimitive "dependency")
                                        |> withDefault (svgKanji s)
                                )
                        )
                            ++ [ text
                                    (" ("
                                        ++ (toString dep.count)
                                        ++ " votes) "
                                    )
                               , if uservote then
                                    text "(Your selection!)"
                                 else
                                    button [ onClick (Accept dep.depString) ] [ text "Accept" ]
                               ]
            )
            target.deps
        )


renderTarget : Maybe Target -> Maybe String -> Dict String Primitive -> Html Msg
renderTarget maybetarget maybeuserdeps primitives =
    case maybetarget of
        Just target ->
            div []
                [ Html.h1 []
                    [ text
                        ("Help us decompose #"
                            ++ (toString target.pos)
                            ++ "! "
                        )
                    , Dict.get target.target primitives
                        |> Maybe.map (svgPrimitive "heading-svg")
                        |> withDefault (text target.target)
                    ]
                , renderTargetDeps target maybeuserdeps primitives
                ]

        Nothing ->
            div [] [ text "(Waiting for network)" ]


renderPrimitive : Set String -> Primitive -> Html Msg
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


renderPrimitives : Set String -> Dict String Primitive -> Html Msg
renderPrimitives selected primitives =
    div [ HA.class "primitive-container" ]
        (List.map (renderPrimitive selected) <| List.sortBy .i <| Dict.values primitives)


svgPrimitive : String -> Primitive -> Html Msg
svgPrimitive classname primitive =
    Svg.svg
        [ viewBox "0 0 109 109", class classname, SA.title primitive.target ]
        (List.map (\path -> Svg.path [ d path ] []) primitive.paths)


renderPrimitiveDispOnly : Int -> Primitive -> Html Msg
renderPrimitiveDispOnly pos primitive =
    a [ HA.href <| routeToFragment <| RoutePos <| 1 + pos ]
        [ svgPrimitive "" primitive ]


renderPrimitivesDispOnly : Dict String Primitive -> Html Msg
renderPrimitivesDispOnly primitiveList =
    div [ HA.class "primitive-container-disp" ]
        ((Html.h2 [] [ text "Jump to a primitive to tag it!" ])
            :: (List.indexedMap renderPrimitiveDispOnly <| List.sortBy .i <| Dict.values primitiveList)
        )


renderKanji : String -> Html Msg
renderKanji target =
    a [ HA.href <| routeToFragment <| RouteTarget target ]
        [ text target ]


renderKanjis : List String -> Html Msg
renderKanjis stringList =
    div [ HA.class "kanji-container" ]
        ((Html.h2 [] [ text "Jump to a kanji!" ])
            :: (List.map renderKanji stringList)
        )
