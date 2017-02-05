"use strict";
var lock =
    new Auth0Lock('7C24qBJHcnQ92pJH4m7oTpyaM4hWSsJw', 'fasiha.auth0.com');
lock.on("authenticated", function(authResult) {

  lock.getUserInfo(authResult.accessToken, function(error, profile) {

    if (error) {
      console.log("ERROR", error);
      return;
    }
    // localStorage.setItem('idToken', authResult.idToken); // JWT
    // localStorage.setItem("accessToken", authResult.accessToken);
    // localStorage.setItem("profile", JSON.stringify(profile));
    if (app && app.ports && app.ports.gotAuthenticated) {
      app.ports.gotAuthenticated.send(authResult.idToken);
    }
  });
});
