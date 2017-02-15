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
    , inputText : String
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

   Login happens with JWT. When a button click or whatever invokes the `Login` Msg, Elm asks JavaScript to ask Auth0 to do its thing. Then the user provides their GitHub credentials to GitHub, or whatever, and Auth0 reloads this page. During the page refresh, in `frontend.js`, Auth0 will take the JWT token, send it to Elm via a subscription called `gotAuthenticated`. Elm will make a GET request to `/login` with the JWT token, which establishes a session on the backend.

    According to http://cryto.net/~joepie91/blog/2016/06/13/stop-using-jwt-for-sessions/ we shoulnd't use JWT as sessions, so that's why we do this: the client gives the JWT authentication token to the backend and is 'logged in'.

    Elm can check whether we're really logged in by sending the `getPing` Cmd, which makes a secured request to the backend. Elm doesn't really care about whether we're really logged in or not: we only `getPing` to know whether we should show a "Login" or a "Logout" button. We don't care because if you try to make a personalized request, Elm will send your request to the backend, which might reject it as unauthorized 401. In that case, Elm will re-send the `Login` Msg and Auth0 will come up, asking you to log in again.

    At no point is there any brittle logic here, in the frontend, trying to guess what the backend thinks of our login status. The frontend just does what it wants to do, and if it's request is rejected, it asks for a fresh login.

    So there's a bit of a difference between Auth0-to-session authentication. "Logout" here means kill the session on the backend---it's got nothing to do with Auth0. After sending the request to `/logout`, the frontend resets `model.loggedIn` boolean and re-requests the target---that's how we'll flush that target's `userDeps`.

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
    | ClearErr


port login : String -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Login ->
            ( model, login "doesntmatter" )

        Authenticated jwt ->
            ( model, provideJwt jwt )

        PingResponse (Ok str) ->
            ( { model | loggedIn = True }, Cmd.none )

        PingResponse (Err err) ->
            ( { model | loggedIn = False }, Cmd.none )

        Logout ->
            ( model, logoutCmd )

        LoggedOut _ ->
            ( { model | loggedIn = False, selected = Set.empty, selectedKanjis = Set.empty }
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
                if List.isEmpty target.deps then
                    ( { model | target = Just target, selected = Set.empty, selectedKanjis = Set.empty, inputText = "" }
                    , Navigation.newUrl url
                    )
                else
                    ( { model | target = Just target }
                    , Cmd.batch
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
                    ( primitives, kanjis ) =
                        List.partition (flip Dict.member model.primitives) (String.split "," deps.deps)
                in
                    { model
                        | target =
                            model.target
                                |> Maybe.map (\target -> { target | userDeps = Just deps.deps })
                        , selectedKanjis = Set.fromList kanjis
                        , selected = Set.fromList primitives
                        , inputText = String.join "" kanjis
                    }
              else
                model
            , Cmd.none
            )

        GotUserDeps (Err err) ->
            let
                newmodel =
                    { model | selectedKanjis = Set.empty, selected = Set.empty, inputText = "" }
            in
                case err of
                    Http.BadStatus res ->
                        case (res |> .status |> .code) of
                            401 ->
                                -- user just browsing, carry on
                                ( newmodel, Cmd.none )

                            404 ->
                                -- no user deps
                                ( newmodel, Cmd.none )

                            _ ->
                                ( { newmodel | err = (toString err) }, delayClearErr )

                    _ ->
                        ( { newmodel | err = (toString err) }, delayClearErr )

        GotPrimitives (Err err) ->
            ( { model | err = (toString err) }, delayClearErr )

        GotPrimitives (Ok list) ->
            ( { model
                | primitives =
                    Dict.fromList <|
                        List.indexedMap (\i p -> ( p.target, { p | i = i } )) list
              }
            , Cmd.none
            )

        SelectPrimitive str ->
            ( { model
                | selected =
                    if Set.member str model.selected then
                        Set.remove str model.selected
                    else
                        Set.insert str model.selected
              }
            , if model.loggedIn then
                Cmd.none
              else
                login ""
            )

        Record ->
            case model.target of
                Nothing ->
                    ( model, Cmd.none )

                Just target ->
                    ( model
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
                | inputText = text
                , selectedKanjis =
                    text
                        |> String.split ""
                        |> List.filter ((flip Dict.member) model.kanjiOnly)
                        |> Set.fromList
                , selected =
                    text
                        |> String.split ""
                        |> List.filter ((flip Dict.member) model.primitives)
                        |> Set.fromList
                        |> Set.union model.selected
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
            if String.isEmpty model.inputText then
                ( model, Cmd.none )
            else
                ( model
                , model.inputText
                    |> String.slice 0 1
                    |> getTarget
                )

        GotKanjiOnly (Ok str) ->
            ( { model | kanjiOnly = str |> String.split "" |> List.indexedMap (flip (,)) |> Dict.fromList }, Cmd.none )

        GotKanjiOnly (Err err) ->
            ( { model | err = toString err }, delayClearErr )

        ClearErr ->
            ( { model | err = "" }, Cmd.none )


provideJwt : String -> Cmd Msg
provideJwt token =
    Http.send PingResponse
        (Http.request
            { method = "GET"
            , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
            , url =
                "/api/login"
            , body =
                Http.emptyBody
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = True
            }
        )


getPing : Cmd Msg
getPing =
    Http.send PingResponse (Http.getString "/api/secured/ping")


logoutCmd : Cmd Msg
logoutCmd =
    Http.send LoggedOut (Http.getString "/api/logout")


delayClearErr : Cmd Msg
delayClearErr =
    Task.perform identity
        (Process.sleep (5 * Time.second)
            |> Task.andThen (\() -> Task.succeed ClearErr)
        )


askForUserDeps : String -> Cmd Msg
askForUserDeps target =
    Http.send GotUserDeps
        (Http.request
            { method = "GET"
            , headers = []
            , url =
                "/api/secured/userDeps/" ++ target
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
                "/api/secured/record/" ++ target
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
        (Http.get "/data/paths.json"
            (Decode.list primitiveDecoder)
        )


getKanjiOnly : Cmd Msg
getKanjiOnly =
    Http.send GotKanjiOnly
        (Http.get "/data/jouyou_jinmeiyou.json" Decode.string)


askFirstNoDeps : Cmd Msg
askFirstNoDeps =
    Http.send GotTarget (Http.get "/api/firstNoDeps" targetDecoder)


askFirstNoDepsUser : Cmd Msg
askFirstNoDepsUser =
    Http.send GotTarget
        (Http.request
            { method = "GET"
            , headers = []
            , url =
                "/api/secured/firstNoDeps"
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
        (Http.get ("/api/getPos/" ++ (toString pos)) targetDecoder)


getTarget : String -> Cmd Msg
getTarget target =
    Http.send GotTarget (Http.get ("/api/getTarget/" ++ target) targetDecoder)



-- SUBSCRIPTIONS


port gotAuthenticated : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    gotAuthenticated Authenticated



-- VIEW


view : Model -> Html Msg
view model =
    div [] [ bulmaNav model, bulma model ]


navButtonClass : String
navButtonClass =
    "button"


bulmaNav : Model -> Html Msg
bulmaNav model =
    Html.nav [ class "nav", HA.style [ ( "padding-top", "1em" ) ] ]
        [ div [ class "container" ]
            [ div [ class "nav-left" ]
                [ if model.loggedIn then
                    Html.a [ class navButtonClass, onClick Logout ] [ text "Logout" ]
                  else
                    Html.a [ class navButtonClass, onClick Login ]
                        [ text "Login" ]
                , text " "
                , Html.a
                    [ onClick Previous
                    , class
                        (if (model.target |> Maybe.map (.pos >> (>=) 1) |> withDefault True) then
                            navButtonClass ++ " is-disabled"
                         else
                            navButtonClass
                        )
                    ]
                    [ text "Previous kanji" ]
                , text " "
                , Html.a [ class navButtonClass, onClick Next ] [ text "Next kanji" ]
                , text " "
                , Html.a [ class navButtonClass, onClick AskFirstNoDeps ] [ text "First kanji without any votes" ]
                , text " "
                , Html.a [ class navButtonClass, onClick AskFirstNoDepsUser ] [ text "First kanji without my vote" ]
                ]
            ]
        ]


bulma : Model -> Html Msg
bulma model =
    div []
        [ Html.section [ class "section" ]
            [ div [ class "container" ]
                [ if String.isEmpty model.err then
                    text ""
                  else
                    Html.article [ class "message is-danger" ]
                        [ div [ class "message-header" ]
                            [ Html.strong []
                                [ text "Oops! "
                                , Html.a [ HA.href "/help.html#errors" ] [ text "Encountered an error." ]
                                ]
                            ]
                        , div [ class "message-body" ] [ text model.err ]
                        ]
                , Html.h1 [ class "title" ] <| renderTarget model.target model.primitives
                , div [ class "columns" ]
                    [ div [ class "column is-one-third" ]
                        [ Html.article [ class "notification" ]
                            [ Html.h2 [ class "subtitle" ] [ text "Your breakdown:" ]
                            , div [ class "contents" ] <| renderSelected (Set.union model.selected model.selectedKanjis) model.primitives
                            ]
                        , Html.h2 [ class "subtitle" ] [ text "Existing choices:" ]
                        , div [ class "contents" ] <| renderTargetDeps model.target model.primitives
                        ]
                    , div [ class "column" ]
                        [ Html.article [ class "notification is-success" ]
                            [ Html.h2 [ class "subtitle" ] [ text "Type kanji to add to breakdown:" ]
                            , div [ class "contents" ] <| renderKanjiAsker model.inputText
                            ]
                        , Html.h2 [ class "subtitle" ] [ text "Select primitives to add to breakdown:" ]
                        , div [ class "contents" ] <| renderPrimitives model.selected model.primitives
                        ]
                    ]
                ]
            ]
        , Html.section [ class "section" ]
            [ div [ class "container" ]
                [ Html.h1 [ class "title" ] [ text "Select what character to break down!" ]
                , div [ class "columns" ]
                    [ div [ class "column is-one-third" ]
                        [ Html.article [ class "notification is-success" ]
                            [ Html.h2 [ class "subtitle" ] [ text "Type in a kanji to break it down!" ]
                            , div [ class "contents" ] <| renderKanjiJump model.inputText
                            ]
                        , Html.h2 [ class "subtitle" ] [ text "Click on a kanji to break it down!" ]
                        , lazy bulmaLazyKanji model.kanjiOnly
                        ]
                    , div [ class "column" ]
                        [ Html.h2 [ class "subtitle" ] [ text "Click on a primitive to break it down!" ]
                        , lazy bulmaLazyPrimitives model.primitives
                        ]
                    ]
                ]
            ]
        , Html.section [ class "hero is-warning" ] [ div [ class "container" ] [ div [] <| renderModel model ] ]
        ]


bulmaLazyKanji : Dict String Int -> Html Msg
bulmaLazyKanji kanjiOnly =
    div [ class "contents kanji-container" ] <| renderKanjis kanjiOnly


bulmaLazyPrimitives : Dict String Primitive -> Html Msg
bulmaLazyPrimitives primitives =
    div [ class "contents primitive-container-disp" ] <| renderPrimitivesDispOnly primitives


renderKanjiJump : String -> List (Html Msg)
renderKanjiJump input =
    [ Html.input [ HA.value input, HA.placeholder "Enter kanji here", onInput Input ] []
    , button [ onClick AskForTarget ] [ text "Jump to a kanji" ]
    ]


renderKanjiAsker : String -> List (Html Msg)
renderKanjiAsker input =
    [ Html.input [ HA.value input, HA.placeholder "Enter kanji here", onInput Input ] [] ]


svgKanji : String -> Html msg
svgKanji kanji =
    Svg.svg [ class "dependency", viewBox "0 0 21 21" ]
        [ Svg.text_ [ SA.x "50%", SA.y "50%", SA.textAnchor "middle", SA.dy "30%" ]
            [ Svg.text kanji ]
        ]


renderCheck : Html Msg
renderCheck =
    Html.span [ class "user-vote-check", HA.title "You have voted!" ] [ text " ✅" ]


renderTarget : Maybe Target -> Dict String Primitive -> List (Html Msg)
renderTarget maybetarget primitives =
    case maybetarget of
        Just target ->
            [ text
                ((if target.userDeps == Nothing then
                    "Help us break down #"
                  else
                    "Thanks for breaking down #"
                 )
                    ++ (toString target.pos)
                    ++ "! "
                )
            , Dict.get target.target primitives
                |> Maybe.map
                    (\s ->
                        Html.span []
                            [ svgPrimitive "heading-svg" s
                            , Html.small [] [ text <| " (" ++ s.target ++ ")" ]
                            ]
                    )
                |> withDefault (text target.target)
            ]

        Nothing ->
            [ text "(Waiting for network)" ]


renderSelected : Set String -> Dict String Primitive -> List (Html Msg)
renderSelected selecteds primitives =
    if Set.isEmpty selecteds then
        []
    else
        [ div []
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


renderPrimitives : Set String -> Dict String Primitive -> List (Html Msg)
renderPrimitives selected primitives =
    [ div [ HA.class "primitive-container" ]
        (List.indexedMap (renderPrimitive selected) <| List.sortBy .i <| Dict.values primitives)
    ]


renderPrimitive : Set String -> Int -> Primitive -> Html Msg
renderPrimitive selecteds pos primitive =
    Html.span [ HA.title ("#" ++ toString (1 + pos)) ]
        [ Svg.svg
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
        ]


svgPrimitive : String -> Primitive -> Html Msg
svgPrimitive classname primitive =
    Svg.svg
        [ viewBox "0 0 109 109", class classname ]
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


renderTargetDeps : Maybe Target -> Dict String Primitive -> List (Html Msg)
renderTargetDeps target primitives =
    case target of
        Nothing ->
            [ text "" ]

        Just target ->
            if List.isEmpty target.deps then
                [ text "" ]
            else
                [ Html.ul [] <| List.map (renderOneDeps primitives target.userDeps) target.deps ]


renderPrimitiveDispOnly : Int -> Primitive -> Html Msg
renderPrimitiveDispOnly pos primitive =
    a [ HA.href <| routeToFragment <| RoutePos <| 1 + pos, HA.title ("#" ++ toString (1 + pos)) ]
        [ svgPrimitive "" primitive ]


renderPrimitivesDispOnly : Dict String Primitive -> List (Html Msg)
renderPrimitivesDispOnly primitiveList =
    (List.indexedMap renderPrimitiveDispOnly <| List.sortBy .i <| Dict.values primitiveList)


renderKanji : String -> Html Msg
renderKanji target =
    a [ HA.href <| routeToFragment <| RouteTarget target ]
        [ text target ]


renderKanjis : Dict String Int -> List (Html Msg)
renderKanjis kanjis =
    kanjis
        |> Dict.toList
        |> List.sortBy Tuple.second
        |> List.map Tuple.first
        |> List.map renderKanji


renderModel : Model -> List (Html Msg)
renderModel model =
    [ text
        (toString
            { model
                | primitives =
                    Dict.empty
                , kanjiOnly = List.take 10 <| Dict.toList model.kanjiOnly
            }
        )
    ]
