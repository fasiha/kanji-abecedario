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

    // Establish a session on the server
    let header = new Headers();
    header.append('Authorization', 'Bearer ' + authResult.idToken);
    fetch('http://localhost:3000/login',
          {method : 'GET', headers : header, credentials : 'same-origin'})
        .then(res => {
          if (res.status !== 200) {
            console.error(`Response status: ${res.status}`);
          }
          if (app && app.ports && app.ports.gotAuthenticated) {
            app.ports.gotAuthenticated.send('!');
          }
        });

  });
});
