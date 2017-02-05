port module Main exposing (..)

import Html.Lazy exposing (lazy)
import Time
import Task
import Process
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
    { target : String, pos : Int, deps : List Dependencies, userDeps : Maybe String }


type alias Primitive =
    { i : Int, paths : List String, target : String, heading : String }


type alias Model =
    { err : String
    , loggedIn : Bool
    , target : Maybe Target
    , primitives : Dict String Primitive
    , selected : Set String
    , selectedKanjis : Set String
    , kanjiOnly : Dict String Int
    , myKanji : List UserDeps
    , depsKanjiString : String
    }


init : Navigation.Location -> ( Model, Cmd Msg )
init initialLocation =
    ( Model ""
        False
        Nothing
        Dict.empty
        Set.empty
        Set.empty
        Dict.empty
        []
        ""
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
        , getPing
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
    Decode.map3 (\a b c -> Target a b c Nothing)
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
{- SO.

   Login happens with JWT. When a button click or whatever invokes the `Login` Msg, Elm asks JavaScript to ask Auth0 to do its thing. Then the user provides their GitHub credentials to GitHub, or whatever, and Auth0 reloads this page. In JavaScript-land (cf., `frontend.js`), JavaScript will make a GET request to `/login` with the JWT token Auth0 got for us. This establishes a session on the backend, and once this is done, JavaScript tells Elm, via a subscription called `gotAuthenticated`, which in turn sends the `Authenticated` Msg.

    According to http://cryto.net/~joepie91/blog/2016/06/13/stop-using-jwt-for-sessions/ we shoulnd't use JWT as sessions, so that's why we do this: the client gives the JWT authentication token to the backend and is 'logged in'.

    Once we're `Authenticated`, and at Elm initialization, we send the `getPing` Cmd, which checks whether we're logged into the backend---specifically, if the backend has a session for us. Elm doesn't really care about the response: it's only here so Elm can show a "Login" or a "Logout" button. If you try to make a personalized request, Elm will send your request to the backend, which might reject it as unauthorized 401. In that case, Elm will re-send the `Login` Msg and Auth0 will come up, asking you to log in again.

    So. We authenticate with Auth0 but all the authorization happens with backend sessions. "Logout" means kill the session on the backend. The only thing to do in the frontend is reset `model.loggedIn` boolean and re-request the target---that's how we'll flush that target's `userDeps`.

-}


type Msg
    = Login
    | Authenticated String
    | PingResponse (Result Http.Error String)
    | Logout
    | LoggedOut (Result Http.Error String)
    | AskFirstNoDeps
    | AskFirstNoDepsUser
    | GotTarget (Result Http.Error Target)
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
    | ClearErr


port login : String -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Login ->
            ( model, login "doesntmatter" )

        Authenticated str ->
            ( model, getPing )

        PingResponse (Ok str) ->
            ( { model | loggedIn = True }, Cmd.none )

        PingResponse (Err err) ->
            ( { model | loggedIn = False }, Cmd.none )

        Logout ->
            ( model, logoutCmd )

        LoggedOut _ ->
            ( { model | loggedIn = False }
            , Cmd.batch
                [ getPing
                , (model.target
                    |> Maybe.map (.pos >> getPos)
                    |> withDefault askFirstNoDeps
                  )
                ]
            )

        AskFirstNoDeps ->
            ( model, askFirstNoDeps )

        AskFirstNoDepsUser ->
            ( model, askFirstNoDepsUser )

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
                        , askForUserDeps target.target
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
                            ( { model | err = "Couldn’t find anything at " ++ (res |> .url) ++ "! We forwarded you automatically." }
                            , Cmd.batch [ getPos 1, delayClearErr ]
                            )

                        401 ->
                            ( { model | err = "Hey, looks like you need to be logged in to do that." }
                            , Cmd.batch [ delayClearErr, login "doesntmatter" ]
                            )

                        400 ->
                            ( { model | err = "The server was unhappy with the data you just sent. If it made a mistake, please contact us. Sorry for the inconvenience." }
                            , delayClearErr
                            )

                        _ ->
                            ( { model | err = (toString err) }
                            , Cmd.none
                            )

                _ ->
                    ( { model | err = (toString err) }, delayClearErr )

        AskForUserDeps ->
            ( model
            , model.target
                |> Maybe.map (askForUserDeps << .target)
                |> withDefault Cmd.none
            )

        GotUserDeps (Ok deps) ->
            ( if deps.target == (model.target |> Maybe.map .target |> withDefault "") then
                let
                    ( kanjis, primitives ) =
                        List.partition (flip Dict.member model.kanjiOnly) (String.split "," deps.deps)
                in
                    { model
                        | target = model.target |> Maybe.map (\target -> { target | userDeps = Just deps.deps })
                        , selectedKanjis = Set.fromList kanjis
                        , selected = Set.fromList primitives
                        , depsKanjiString = String.join "" kanjis
                    }
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
                            ( { model | err = (toString err) }, delayClearErr )

                _ ->
                    ( { model | err = (toString err) }, delayClearErr )

        GotPrimitives (Err err) ->
            ( { model | err = (toString err) }, delayClearErr )

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
                    ( { model | selected = Set.empty, selectedKanjis = Set.empty, depsKanjiString = "" }
                    , record
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
            ( { model
                | depsKanjiString = text
                , selectedKanjis =
                    text
                        |> String.split ""
                        |> List.filter ((flip Dict.member) model.kanjiOnly)
                        |> Set.fromList
              }
            , Cmd.none
            )

        Accept str ->
            ( model
            , model.target
                |> Maybe.map
                    (\target -> str |> String.split "," |> record target.target)
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
            ( { model | kanjiOnly = str |> String.split "" |> List.indexedMap (flip (,)) |> Dict.fromList }, Cmd.none )

        GotKanjiOnly (Err err) ->
            ( { model | err = toString err }, delayClearErr )

        MyKanji ->
            ( model, myKanji )

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
                            , Cmd.batch [ delayClearErr, login "doesntmatter" ]
                            )

                        _ ->
                            ( { model | err = (toString err) }
                            , delayClearErr
                            )

                _ ->
                    ( { model | err = (toString err) }, delayClearErr )

        ClearErr ->
            ( { model | err = "" }, Cmd.none )


getPing : Cmd Msg
getPing =
    Http.send PingResponse (Http.getString "http://localhost:3000/secured/ping")


logoutCmd : Cmd Msg
logoutCmd =
    Http.send LoggedOut (Http.getString "http://localhost:3000/logout")


delayClearErr : Cmd Msg
delayClearErr =
    Task.perform identity
        (Process.sleep (2 * Time.second)
            |> Task.andThen (\() -> Task.succeed ClearErr)
        )


myKanji : Cmd Msg
myKanji =
    Http.send GotMyKanji
        (Http.request
            { method = "GET"
            , headers = []
            , url =
                "http://localhost:3000/secured/myDeps"
            , body =
                Http.emptyBody
            , expect = Http.expectJson (Decode.list userDepsDecoder)
            , timeout = Nothing
            , withCredentials = True
            }
        )


askForUserDeps : String -> Cmd Msg
askForUserDeps target =
    Http.send GotUserDeps
        (Http.request
            { method = "GET"
            , headers = []
            , url =
                "http://localhost:3000/secured/userDeps/" ++ target
            , body =
                Http.emptyBody
            , expect = Http.expectJson userDepsDecoder
            , timeout = Nothing
            , withCredentials = True
            }
        )


record : String -> List String -> Cmd Msg
record target deps =
    Http.send GotTarget
        (Http.request
            { method = "POST"
            , headers = []
            , url =
                "http://localhost:3000/secured/record/" ++ target
            , body =
                Http.jsonBody (Encode.list (List.map Encode.string deps))
            , expect = Http.expectJson targetDecoder
            , timeout = Nothing
            , withCredentials = True
            }
        )


getPrimitives : Cmd Msg
getPrimitives =
    Http.send GotPrimitives
        (Http.get "http://localhost:3000/data/paths.json"
            (Decode.list primitiveDecoder)
        )


getKanjiOnly : Cmd Msg
getKanjiOnly =
    Http.send GotKanjiOnly
        (Http.get "http://localhost:3000/data/jouyou_jinmeiyou.json" Decode.string)


askFirstNoDeps : Cmd Msg
askFirstNoDeps =
    Http.send GotTarget (Http.get "http://localhost:3000/firstNoDeps" targetDecoder)


askFirstNoDepsUser : Cmd Msg
askFirstNoDepsUser =
    Http.send GotTarget
        (Http.request
            { method = "GET"
            , headers = []
            , url =
                "http://localhost:3000/secured/firstNoDeps"
            , body =
                Http.emptyBody
            , expect = Http.expectJson targetDecoder
            , timeout = Nothing
            , withCredentials = True
            }
        )


getPos : Int -> Cmd Msg
getPos pos =
    Http.send GotTarget
        (Http.get ("http://localhost:3000/getPos/" ++ (toString pos)) targetDecoder)


getTarget : String -> Cmd Msg
getTarget target =
    Http.send GotTarget (Http.get ("http://localhost:3000/getTarget/" ++ target) targetDecoder)



-- SUBSCRIPTIONS


port gotAuthenticated : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    gotAuthenticated Authenticated



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ if model.loggedIn then
            button [ onClick Logout ] [ text "Logout" ]
          else
            button [ onClick Login ] [ text "Login" ]
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
        , renderTarget model.target model.primitives
        , renderTargetDeps model.target model.primitives
        , renderSelected (Set.union model.selected model.selectedKanjis) model.primitives
        , renderKanjiAsker model.depsKanjiString
        , renderPrimitives model.selected model.primitives
        , lazy renderPrimitivesDispOnly model.primitives
        , renderKanjiJump
        , lazy renderKanjis model.kanjiOnly
        , renderModel model
        ]


renderErr : String -> Html Msg
renderErr err =
    if String.isEmpty err then
        div [] []
    else
        div [ class "error-notification" ] [ text err ]


renderKanjiJump : Html Msg
renderKanjiJump =
    div [ class "jump-section" ]
        [ Html.h2 [] [ text "Enter a kanji to tag!" ]
        , Html.input [ HA.placeholder "Enter kanji here", onInput Input ] []
        , button [ onClick AskForTarget ] [ text "Jump to a kanji" ]
        ]


renderKanjiAsker : String -> Html Msg
renderKanjiAsker depsKanjiString =
    div []
        [ Html.h3 [] [ text "Enter your own decomposition’s components!" ]
        , Html.input [ HA.value depsKanjiString, HA.placeholder "Enter kanji here", onInput Input ] []
        ]


svgKanji : String -> Html msg
svgKanji kanji =
    Svg.svg [ class "dependency", viewBox "0 0 21 21" ]
        [ Svg.text_ [ SA.x "50%", SA.y "50%", SA.textAnchor "middle", SA.dy "30%" ]
            [ Svg.text kanji ]
        ]


renderCheck : Html Msg
renderCheck =
    Html.span [ class "user-vote-check", HA.title "You have voted!" ] [ text " ✅" ]


renderTarget : Maybe Target -> Dict String Primitive -> Html Msg
renderTarget maybetarget primitives =
    case maybetarget of
        Just target ->
            div []
                [ Html.h1 []
                    [ text
                        ((if target.userDeps == Nothing then
                            "Help us decompose #"
                          else
                            "Thanks for decomposing #"
                         )
                            ++ (toString target.pos)
                            ++ "! "
                        )
                    , Dict.get target.target primitives
                        |> Maybe.map (svgPrimitive "heading-svg")
                        |> withDefault (text target.target)
                    , target.userDeps
                        |> Maybe.map (always renderCheck)
                        |> withDefault (text "")
                    ]
                ]

        Nothing ->
            div [] [ text "(Waiting for network)" ]


renderSelected : Set String -> Dict String Primitive -> Html Msg
renderSelected selecteds primitives =
    div [] <|
        if Set.isEmpty selecteds then
            []
        else
            [ Html.h4 [] [ text "Your picks:" ]
            , div []
                (selecteds
                    |> Set.toList
                    |> List.map
                        (\s ->
                            Dict.get s primitives
                                |> Maybe.map (svgPrimitive "dependency")
                                |> withDefault (svgKanji s)
                        )
                )
            , button [ onClick Record ] [ text "Submit" ]
            ]


renderPrimitives : Set String -> Dict String Primitive -> Html Msg
renderPrimitives selected primitives =
    div []
        [ Html.h3 [] [ text "Select any of the following components!" ]
        , div [ HA.class "primitive-container" ]
            (List.map (renderPrimitive selected) <| List.sortBy .i <| Dict.values primitives)
        ]


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


svgPrimitive : String -> Primitive -> Html Msg
svgPrimitive classname primitive =
    Svg.svg
        [ viewBox "0 0 109 109", class classname, SA.title primitive.target ]
        (List.map (\path -> Svg.path [ d path ] []) primitive.paths)


renderOneDeps : Dict String Primitive -> Maybe String -> Dependencies -> Html Msg
renderOneDeps primitives userDeps dep =
    let
        uservote =
            userDeps |> Maybe.map ((==) dep.depString) |> withDefault False
    in
        Html.li
            (if uservote then
                [ class "uservote" ]
             else
                []
            )
            [ span []
                (List.map
                    (\s ->
                        Dict.get s primitives
                            |> Maybe.map (svgPrimitive "dependency")
                            |> withDefault (svgKanji s)
                    )
                    (String.split "," dep.depString)
                )
            , text
                (" ("
                    ++ (toString dep.count)
                    ++ (if dep.count > 1 then
                            " votes) "
                        else
                            " vote) "
                       )
                )
            , if uservote then
                renderCheck
              else
                button [ onClick (Accept dep.depString) ] [ text "Accept" ]
            ]


renderTargetDeps : Maybe Target -> Dict String Primitive -> Html Msg
renderTargetDeps target primitives =
    case target of
        Nothing ->
            text ""

        Just target ->
            div [] <|
                if List.isEmpty target.deps then
                    []
                else
                    [ Html.h3 [] [ text "Are any of these existing decompositions to your liking?" ]
                    , Html.ul [] <| List.map (renderOneDeps primitives target.userDeps) target.deps
                    ]


renderPrimitiveDispOnly : Int -> Primitive -> Html Msg
renderPrimitiveDispOnly pos primitive =
    a [ HA.href <| routeToFragment <| RoutePos <| 1 + pos ]
        [ svgPrimitive "" primitive ]


renderPrimitivesDispOnly : Dict String Primitive -> Html Msg
renderPrimitivesDispOnly primitiveList =
    div [ class "jump-section" ]
        [ Html.h2 [] [ text "Jump to a primitive to tag it!" ]
        , div [ HA.class "primitive-container-disp" ]
            (List.indexedMap renderPrimitiveDispOnly <| List.sortBy .i <| Dict.values primitiveList)
        ]


renderKanji : String -> Html Msg
renderKanji target =
    a [ HA.href <| routeToFragment <| RouteTarget target ]
        [ text target ]


renderKanjis : Dict String Int -> Html Msg
renderKanjis kanjis =
    div [ class "jump-section" ]
        [ Html.h2 [] [ text "Click on a kanji to tag!" ]
        , div [ HA.class "kanji-container" ]
            (kanjis
                |> Dict.toList
                |> List.sortBy Tuple.second
                |> List.map Tuple.first
                |> List.map renderKanji
            )
        ]


renderModel : Model -> Html Msg
renderModel model =
    div []
        [ text
            (toString
                { model
                    | primitives =
                        Dict.empty
                    , kanjiOnly = List.take 10 <| Dict.toList model.kanjiOnly
                }
            )
        ]
