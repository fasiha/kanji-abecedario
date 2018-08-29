"use strict";
var lock =
    new Auth0Lock('7C24qBJHcnQ92pJH4m7oTpyaM4hWSsJw', 'fasiha.auth0.com');
lock.on("authenticated", function(authResult) {
  lock.getUserInfo(authResult.accessToken, function(error, profile) {
    if (error) {
      console.log("AUTH0 ERROR", error);
      return;
    }
    if (app && app.ports && app.ports.gotAuthenticated) {
      app.ports.gotAuthenticated.send(authResult.idToken);
    }
  });
});
