docker run --name skynet-mysql \
           -e MYSQL_ROOT_PASSWORD=123456 \
           -e MYSQL_DATABASE=game_goldmine \
           -p 33006:3306 \
           -v /etc/localtime:/etc/localtime:ro \
           -v /root/skynetNew/lua/project/goldmine/db/game.sql:/docker-entrypoint-initdb.d/game_tables.sql \
           -d mysql:5.6 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci