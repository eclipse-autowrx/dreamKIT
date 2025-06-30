// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
//
// SPDX-License-Identifier: MIT

const { readFileSync } = require("fs")
const { createServer } = require("https")
const { Server } = require("socket.io")

const httpsServer = createServer({
  key: readFileSync("./cert/key.pem"),
  cert: readFileSync("./cert/cert.pem")
})

const io = new Server(httpsServer);

io.on("connection", (socket) => {
    console.log("new connection")

    socket.on('send_cmd', (payload) => {
        if(!payload) return;
        source = payload.source
        dest   = payload.dest
        data   = payload.data
        console.log("send_cmd: ", source, dest, data.cmd)
        socket.broadcast.emit(dest, {
            data: payload.data
        });
    })
});

httpsServer.listen(39562)
