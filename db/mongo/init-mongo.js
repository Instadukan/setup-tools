db.createUser({
    user : "instadukan",
    pwd : "pakodas",
    roles:[
        {
            role: "readWrite",
            db: "bots-instadukan-com"
        }
    ]
})